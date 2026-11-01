# Zombie OS

Zombie OS is a custom Arch Linux live and installation image with a frosted-glass inspired
Plasma desktop and radioactive green branding. GitHub Actions builds the ISO and checks its
contents before it is uploaded.

## Included

- Plasma desktop, SDDM login, Firefox, Dolphin, and Konsole
- Toxic Glass dark colors by default, plus an app menu item to switch to light colors
- A custom radioactive wallpaper, green highlights, blur, and enabled desktop transitions
- Custom Aurorae window decoration with red close, yellow minimize, and green maximize dots
- Zombie OS boot menus, splash, system identity, and `fastfetch` artwork
- Calamares graphical installer, configured to install the live system to disk
- `archinstall` retained as a command-line fallback
- BIOS and UEFI boot through the stock Arch `releng` profile
- ISO verification checks the branding, desktop configuration, and installer are inside the image

The live desktop is meant for a machine or VM with at least 4 GB RAM. The theme uses KDE's
compositor blur, so transparency effects depend on working graphics acceleration.

## Build

The ISO is built by GitHub Actions; a local Arch machine is not part of the workflow.

1. Upload the contents of this folder to the root of a GitHub repository, keeping `.github/` at the repository root.
2. Open the **Actions** tab, pick **Build Zombie OS ISO**, click **Run workflow**.
3. When it finishes, download the `zombie-os-iso` artifact (ISO + `SHA256SUMS`).

The workflow first builds Calamares from its Arch User Repository recipe, then builds and
inspects the ISO. The log must end with `ALL CHECKS PASSED` from the verify step.

## VirtualBox settings

Type **Linux**, Version **Arch Linux (64-bit)** (or Other Linux 64-bit). RAM 4096 MB or more,
2+ CPUs, Display: VMSVGA. Attach the ISO to the optical drive (skip unattended install).

## Layout

| Path | What |
|------|------|
| `.github/workflows/build-iso.yml` | Builds in a privileged Arch container, verifies, uploads |
| `build.sh` | Copies the stock archiso profile, applies the overlay, runs `mkarchiso` |
| `verify-iso.sh` | Post-build checks on the ISO contents |
| `profile-overlay/` | Files layered onto the ISO (branding, Plymouth theme, fastfetch) |
| `desktop/` | Plasma color schemes, wallpaper, effects, light/dark switcher, and Aurorae decoration |
| `calamares/` | Calamares install sequence and branded installer settings |
| `build-calamares.sh` | Builds Calamares as an unprivileged user and makes a temporary local package repo |
| `snapshot-date.txt` | Optional: freeze packages to a dated Arch Archive snapshot |
| `branding/` | Palette, logo generator, symbol files |

## Build status

This project is now wired for a full desktop build, but the ISO has not been boot-tested yet.
Run the GitHub Actions workflow and test the resulting image in VirtualBox before installing it
on a real machine. Calamares is built from the community AUR recipe at build time, so that
dependency follows its current upstream package state.
