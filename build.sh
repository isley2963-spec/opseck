#!/usr/bin/env bash
# Zombie OS ISO builder. Runs as root inside an Arch Linux container
# (see .github/workflows/build-iso.yml). Fails loudly on any missing step.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${WORK:-/tmp/zombie-build}"
OUT="${OUT:-$REPO/out}"
PROFILE="$WORK/profile"
OVERLAY="$REPO/profile-overlay"

die() { echo "ERROR: $*" >&2; exit 1; }
step() { echo; echo "==> $*"; }

[[ $EUID -eq 0 ]] || die "run as root (inside the Arch container)"

# ---------------------------------------------------------------- snapshot pin
SNAP="${SNAPSHOT_DATE:-}"
if [[ -z "$SNAP" && -f "$REPO/snapshot-date.txt" ]]; then
  SNAP="$(grep -vE '^\s*(#|$)' "$REPO/snapshot-date.txt" | head -n1 | tr -d '[:space:]' || true)"
fi
if [[ -n "$SNAP" ]]; then
  [[ "$SNAP" =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]] || die "bad snapshot date '$SNAP' (want YYYY/MM/DD)"
  step "Pinning packages to Arch Linux Archive snapshot $SNAP"
  echo "Server = https://archive.archlinux.org/repos/$SNAP/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist
else
  step "No snapshot pin: using current mirrors"
fi

step "Installing archiso"
pacman -Syyuu --noconfirm --needed archiso

[[ -d /usr/share/archiso/configs/releng ]] || die "archiso releng profile not found"

# ------------------------------------------------------------- start from releng
step "Copying the stock archiso profile"
rm -rf "$WORK"
mkdir -p "$WORK" "$OUT"
cp -r /usr/share/archiso/configs/releng "$PROFILE"

# ------------------------------------------------------------------ apply overlay
step "Applying Zombie OS overlay"
cp -r "$OVERLAY/airootfs/." "$PROFILE/airootfs/"
grep -vE '^\s*(#|$)' "$OVERLAY/packages.extra" >> "$PROFILE/packages.x86_64"

# Calamares is built by the workflow from its AUR recipe and supplied through
# a temporary, unsigned local repository. No package or signing key is retained.
LOCAL_REPO="${CALAMARES_REPO:-$REPO/out/calamares-repo}"
if [[ -f "$LOCAL_REPO/calamares.db.tar.gz" ]]; then
  printf '\n[zombie-local]\nSigLevel = Optional TrustAll\nServer = file://%s\n' "$LOCAL_REPO" >> "$PROFILE/pacman.conf"
else
  die "Calamares package repo not found at $LOCAL_REPO (run build-calamares.sh first)"
fi

# The live desktop user only exists in the RAM-backed session.
mkdir -p "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants"
ln -sfn /usr/lib/systemd/system/zombie-live-user.service \
  "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/zombie-live-user.service"
ln -sfn /usr/lib/systemd/system/sddm.service \
  "$PROFILE/airootfs/etc/systemd/system/display-manager.service"
ln -sfn /usr/lib/systemd/system/NetworkManager.service \
  "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
mkdir -p "$PROFILE/airootfs/etc/sddm.conf.d"
# Install the Calamares distro configuration, theme, switcher, and wallpaper.
mkdir -p "$PROFILE/airootfs/etc/calamares/modules" \
  "$PROFILE/airootfs/etc/calamares/branding/zombie-os" \
  "$PROFILE/airootfs/usr/share/color-schemes" \
  "$PROFILE/airootfs/usr/share/aurorae/themes/zombie-toxic-glass" \
  "$PROFILE/airootfs/usr/share/wallpapers/Zombie OS" \
  "$PROFILE/airootfs/usr/local/bin" \
  "$PROFILE/airootfs/usr/share/applications" \
  "$PROFILE/airootfs/etc/sudoers.d" \
  "$PROFILE/airootfs/etc/skel/.config" \
  "$PROFILE/airootfs/etc/skel/.config/autostart" \
  "$PROFILE/airootfs/etc/skel/Desktop"
cp -r "$REPO/calamares/." "$PROFILE/airootfs/etc/calamares/"
mkdir -p "$PROFILE/airootfs/etc/calamares/branding/zombie-os"
cp "$REPO/desktop/branding/zombie-os/branding.desc" \
  "$PROFILE/airootfs/etc/calamares/branding/zombie-os/branding.desc"
cp "$REPO/desktop/Zombie-OS-Dark.colors" "$PROFILE/airootfs/usr/share/color-schemes/"
cp "$REPO/desktop/Zombie-OS-Light.colors" "$PROFILE/airootfs/usr/share/color-schemes/"
cp "$REPO/desktop/wallpaper.svg" "$PROFILE/airootfs/usr/share/wallpapers/Zombie OS/wallpaper.svg"
cp "$REPO/desktop/zombie-look-toggle" "$PROFILE/airootfs/usr/local/bin/zombie-look-toggle"
chmod 0755 "$PROFILE/airootfs/usr/local/bin/zombie-look-toggle"
cp "$REPO/desktop/zombie-look-toggle.desktop" "$PROFILE/airootfs/usr/share/applications/"
printf 'zombie ALL=(ALL:ALL) NOPASSWD: /usr/bin/calamares\n' \
  > "$PROFILE/airootfs/etc/sudoers.d/zombie-installer"
chmod 0440 "$PROFILE/airootfs/etc/sudoers.d/zombie-installer"
cp "$REPO/desktop/kdeglobals" "$PROFILE/airootfs/etc/xdg/kdeglobals"
cp "$REPO/desktop/kwinrc" "$PROFILE/airootfs/etc/xdg/kwinrc"
cp -r "$REPO/desktop/aurorae/zombie-toxic-glass/." \
  "$PROFILE/airootfs/usr/share/aurorae/themes/zombie-toxic-glass/"
mkdir -p "$PROFILE/airootfs/etc/skel/.config" \
  "$PROFILE/airootfs/etc/skel/.config/autostart" \
  "$PROFILE/airootfs/etc/skel/Desktop"
cp "$REPO/desktop/kdeglobals" "$PROFILE/airootfs/etc/skel/.config/kdeglobals"
cp "$REPO/desktop/kwinrc" "$PROFILE/airootfs/etc/skel/.config/kwinrc"
cp "$REPO/desktop/zombie-wallpaper.desktop" "$PROFILE/airootfs/etc/skel/.config/autostart/"
cp "$REPO/desktop/install-zombie-os.desktop" "$PROFILE/airootfs/usr/share/applications/"
cp "$REPO/desktop/install-zombie-os.desktop" "$PROFILE/airootfs/etc/skel/Desktop/"
chmod 0755 "$PROFILE/airootfs/etc/skel/Desktop/install-zombie-os.desktop"

# fastfetch config for root (live session) and new users (installed system)
for d in root/.config/fastfetch etc/skel/.config/fastfetch; do
  mkdir -p "$PROFILE/airootfs/$d"
  cp "$OVERLAY/airootfs/etc/fastfetch/config.jsonc" "$PROFILE/airootfs/$d/config.jsonc"
done

# ------------------------------------------------- boot splash in the initramfs
step "Enabling Plymouth in the initramfs"
MKCONF="$PROFILE/airootfs/etc/mkinitcpio.conf.d/archiso.conf"
[[ -f "$MKCONF" ]] || die "mkinitcpio archiso.conf not found ($MKCONF)"
sed -i '/^HOOKS=/ s/ udev / udev plymouth /' "$MKCONF"
grep -q '^HOOKS=.*plymouth' "$MKCONF" || die "could not add the plymouth hook to $MKCONF"

# ----------------------------------------------- boot menus: name + quiet splash
step "Branding boot menus and enabling quiet splash"
BOOTDIRS=()
for d in syslinux grub efiboot; do [[ -d "$PROFILE/$d" ]] && BOOTDIRS+=("$PROFILE/$d"); done
[[ ${#BOOTDIRS[@]} -gt 0 ]] || die "no bootloader config directories found"

grep -rlE 'Arch Linux' "${BOOTDIRS[@]}" | while read -r f; do
  sed -i -e 's/Arch Linux install medium/Zombie OS/g' -e 's/MENU TITLE Arch Linux/MENU TITLE Zombie OS/' "$f"
done
grep -rl 'archisobasedir=%INSTALL_DIR%' "${BOOTDIRS[@]}" | while read -r f; do
  sed -i 's/archisobasedir=%INSTALL_DIR%/quiet splash archisobasedir=%INSTALL_DIR%/' "$f"
done
grep -rq 'Zombie OS' "${BOOTDIRS[@]}" || die "boot menu branding did not apply"
grep -rq 'quiet splash' "${BOOTDIRS[@]}" || die "quiet splash did not apply to any boot entry"

if [[ -f "$PROFILE/syslinux/splash.png" && -f "$REPO/branding/syslinux-splash.png" ]]; then
  cp "$REPO/branding/syslinux-splash.png" "$PROFILE/syslinux/splash.png"
fi

# ------------------------------------------------------------------- ISO naming
step "Setting ISO identity"
PD="$PROFILE/profiledef.sh"
sed -i \
  -e 's|^iso_name=.*|iso_name="zombie-os"|' \
  -e 's|^iso_label=.*|iso_label="ZOMBIEOS_$(date +%Y%m)"|' \
  -e 's|^iso_publisher=.*|iso_publisher="Zombie OS"|' \
  -e 's|^iso_application=.*|iso_application="Zombie OS Live/Install ISO"|' \
  "$PD"
grep -q '^iso_name="zombie-os"' "$PD" || die "profiledef.sh rename failed"

# ------------------------------------------------------------------------ build
step "Building the ISO (this takes a while)"
mkarchiso -v -w "$WORK/work" -o "$OUT" "$PROFILE"

ls -lh "$OUT"
compgen -G "$OUT/zombie-os-*.iso" > /dev/null || die "mkarchiso finished but no zombie-os ISO was produced"
step "Build finished"
