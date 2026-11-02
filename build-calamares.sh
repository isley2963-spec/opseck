#!/usr/bin/env bash
# Build Calamares from its Arch User Repository recipe for this ISO.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_REPO="${CALAMARES_REPO:-$REPO/out/calamares-repo}"
BUILD_DIR="${CALAMARES_BUILD_DIR:-/tmp/zombie-calamares-build}"

[[ $EUID -eq 0 ]] || { echo "Run as root in the Arch build container." >&2; exit 1; }
pacman -Syu --noconfirm --needed base-devel git sudo
getent passwd zombie-builder >/dev/null || useradd --create-home --shell /bin/bash zombie-builder
printf 'zombie-builder ALL=(ALL:ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/zombie-builder
chmod 0440 /etc/sudoers.d/zombie-builder

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$PKG_REPO"
chown zombie-builder:zombie-builder "$BUILD_DIR"
sudo -u zombie-builder git clone https://aur.archlinux.org/calamares.git "$BUILD_DIR/calamares"
sudo -u zombie-builder bash -c 'cd "$1" && makepkg --syncdeps --noconfirm --needed' _ "$BUILD_DIR/calamares"

shopt -s nullglob
packages=("$BUILD_DIR"/calamares/*.pkg.tar.zst)
(( ${#packages[@]} > 0 )) || { echo "AUR build produced no package." >&2; exit 1; }
cp "${packages[@]}" "$PKG_REPO/"
repo-add "$PKG_REPO/zombie-local.db.tar.gz" "$PKG_REPO"/*.pkg.tar.zst
echo "Calamares package repository ready: $PKG_REPO"
