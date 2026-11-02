#!/usr/bin/env bash
# Opens the finished ISO and checks that Zombie OS branding really made it in,
# so a silent "stock Arch" build can never pass again.
set -euo pipefail

OUT="${OUT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/out}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "VERIFY FAILED: $*" >&2; exit 1; }
ok()   { echo "  ok: $*"; }

ISO="$(ls "$OUT"/zombie-os-*.iso 2>/dev/null | head -n1 || true)"
[[ -n "$ISO" ]] || fail "no ISO found in $OUT"
echo "Verifying $ISO"

SIZE=$(stat -c %s "$ISO")
(( SIZE > 300*1024*1024 )) || fail "ISO is suspiciously small ($SIZE bytes)"
ok "size $(( SIZE / 1024 / 1024 )) MiB"

bsdtar -C "$TMP" -xf "$ISO" arch/x86_64/airootfs.sfs || fail "root filesystem image missing from ISO"
SFS="$TMP/arch/x86_64/airootfs.sfs"

unsquashfs -cat "$SFS" etc/os-release > "$TMP/os-release" || fail "cannot read os-release from image"
grep -q 'PRETTY_NAME="Zombie OS"' "$TMP/os-release" || fail "os-release is not Zombie OS"
ok "os-release says Zombie OS"

LIST="$TMP/sfs-list.txt"
unsquashfs -n -l "$SFS" > "$LIST"
for f in \
  usr/share/plymouth/themes/zombie-os/logo.png \
  usr/share/plymouth/themes/zombie-os/zombie-os.script \
  usr/share/zombie-os/fastfetch-logo.txt \
  etc/fastfetch/config.jsonc \
  etc/calamares/settings.conf \
  etc/calamares/modules/unpackfs.conf \
  etc/calamares/modules/installkernel.conf \
  etc/calamares/branding/zombie-os/branding.desc \
  etc/xdg/kwinrc \
  usr/bin/calamares \
  usr/local/bin/zombie-look-toggle \
  usr/share/color-schemes/Zombie-OS-Dark.colors \
  usr/share/color-schemes/Zombie-OS-Light.colors \
  usr/share/aurorae/themes/zombie-toxic-glass/metadata.desktop \
  usr/share/aurorae/themes/zombie-toxic-glass/decoration.svg \
  usr/share/aurorae/themes/zombie-toxic-glass/zombie-toxic-glassrc \
  usr/share/aurorae/themes/zombie-toxic-glass/close.svg \
  usr/share/aurorae/themes/zombie-toxic-glass/minimize.svg \
  usr/share/aurorae/themes/zombie-toxic-glass/maximize.svg \
  usr/share/aurorae/themes/zombie-toxic-glass/restore.svg \
  usr/share/wallpapers/Zombie\ OS/wallpaper.svg \
  usr/bin/fastfetch; do
  grep -Fq "squashfs-root/$f" "$LIST" || fail "missing from image: $f"
done
ok "boot theme, desktop, installer, and fastfetch assets present"

unsquashfs -cat "$SFS" etc/calamares/settings.conf > "$TMP/calamares-settings.conf" || fail "cannot read Calamares settings"
grep -q 'branding: zombie-os' "$TMP/calamares-settings.conf" || fail "Calamares is not using Zombie OS branding"
grep -q 'shellprocess@livecleanup' "$TMP/calamares-settings.conf" || fail "Calamares live-system cleanup is not configured"
grep -q 'shellprocess@installkernel' "$TMP/calamares-settings.conf" || fail "Calamares kernel install step is not configured"
unsquashfs -cat "$SFS" etc/calamares/branding/zombie-os/branding.desc > "$TMP/branding.desc" || fail "cannot read Calamares branding config"
grep -q '^images: {}$' "$TMP/branding.desc" || fail "Calamares branding images map is missing"
grep -q '^style: {}$' "$TMP/branding.desc" || fail "Calamares branding style map is missing"
grep -q '^slideshow: "show.qml"$' "$TMP/branding.desc" || fail "Calamares slideshow is not selected"
grep -Fq 'squashfs-root/etc/calamares/branding/zombie-os/show.qml' "$LIST" || fail "Calamares slideshow QML is missing from image"
ok "Calamares uses the distro installer flow and cleanup job"

unsquashfs -cat "$SFS" usr/share/aurorae/themes/zombie-toxic-glass/metadata.desktop > "$TMP/dots-theme.desktop" || fail "Aurorae titlebar theme is missing"
grep -q 'X-KDE-PluginInfo-Name=zombie-toxic-glass' "$TMP/dots-theme.desktop" || fail "Aurorae theme ID is incorrect"
unsquashfs -cat "$SFS" usr/share/aurorae/themes/zombie-toxic-glass/close.svg > "$TMP/close.svg" || fail "red close control is missing"
unsquashfs -cat "$SFS" usr/share/aurorae/themes/zombie-toxic-glass/minimize.svg > "$TMP/minimize.svg" || fail "yellow minimize control is missing"
unsquashfs -cat "$SFS" usr/share/aurorae/themes/zombie-toxic-glass/maximize.svg > "$TMP/maximize.svg" || fail "green maximize control is missing"
grep -qi '#FF4545' "$TMP/close.svg" || fail "close control is not red"
grep -qi '#FFD60A' "$TMP/minimize.svg" || fail "minimize control is not yellow"
grep -qi '#9BFF3A' "$TMP/maximize.svg" || fail "maximize control is not green"
unsquashfs -cat "$SFS" etc/xdg/kwinrc > "$TMP/kwinrc" || fail "KWin defaults are missing"
grep -q 'theme=__aurorae__svg__zombie-toxic-glass' "$TMP/kwinrc" || fail "Zombie Toxic Glass is not the selected window decoration"
ok "colored titlebar controls and custom window decoration are installed"

unsquashfs -cat "$SFS" etc/plymouth/plymouthd.conf > "$TMP/plymouthd.conf" || fail "cannot read plymouthd.conf from image"
grep -q '^Theme=zombie-os' "$TMP/plymouthd.conf" || fail "Plymouth theme not selected"
ok "Plymouth theme selected"

bsdtar -xOf "$ISO" arch/boot/x86_64/vmlinuz-linux > "$TMP/vmlinuz-linux" || fail "kernel image missing from ISO"
[[ -s "$TMP/vmlinuz-linux" ]] || fail "kernel image is empty"
ok "kernel image available for installed system"
bsdtar -C "$TMP" -xf "$ISO" arch/boot/x86_64/initramfs-linux.img || fail "initramfs missing from ISO"
lsinitcpio "$TMP/arch/boot/x86_64/initramfs-linux.img" > "$TMP/initramfs-list.txt"
grep -q 'plymouth' "$TMP/initramfs-list.txt" || fail "plymouth is not inside the initramfs"
grep -q 'themes/zombie-os' "$TMP/initramfs-list.txt" || fail "Zombie OS theme is not inside the initramfs"
ok "initramfs contains plymouth and the Zombie OS theme"

bsdtar -xOf "$ISO" boot/syslinux/archiso_sys-linux.cfg > "$TMP/syslinux.cfg" || fail "Syslinux boot menu missing from ISO"
grep -q 'Zombie OS' "$TMP/syslinux.cfg" || fail "Syslinux menu is not branded"
grep -q 'quiet splash' "$TMP/syslinux.cfg" || fail "Syslinux entries lack quiet splash"
ok "boot menu branded, quiet splash enabled"

echo "ALL CHECKS PASSED"
