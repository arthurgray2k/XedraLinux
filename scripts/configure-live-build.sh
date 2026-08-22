#!/usr/bin/env bash
# ==============================================================================
# Xedra Linux - Stage 7: Configure live-build for Xedra 0.1 ISO Generation
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Purpose:
#   Initializes and configures the Debian 'live-build' workspace under
#   ~/XedraLinux/build/live-build with Xedra's exact specifications:
#     - Base: Debian 13 "Trixie" (amd64)
#     - Init System: SysVinit (sysvinit-core) via chroot hook
#     - Desktop: X11 + Fluxbox + xterm
#     - Kernel: linux-image-amd64 + live-boot
#     - Bootloader: Hybrid UEFI + BIOS (GRUB + Syslinux)
# ==============================================================================

set -euo pipefail

# ANSI color codes
readonly COLOR_RESET="\033[0m"
readonly COLOR_BOLD="\033[1m"
readonly COLOR_GREEN="\033[32m"
readonly COLOR_RED="\033[31m"
readonly COLOR_YELLOW="\033[33m"
readonly COLOR_CYAN="\033[36m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LB_DIR="${REPO_ROOT}/build/live-build"
CONFIG_DIR="${REPO_ROOT}/config"

print_header() {
    echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Xedra Linux - Configure live-build Environment       ${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================${COLOR_RESET}"
    echo "Live-Build Workspace: ${LB_DIR}"
    echo "Distribution Base:    Debian 13 (Trixie) amd64"
    echo "Init System:          SysVinit (PID 1)"
    echo "Desktop:              Fluxbox + xterm"
    echo ""
}

verify_environment() {
    if ! command -v lb >/dev/null 2>&1; then
        echo -e "${COLOR_RED}Error: 'live-build' (lb) is not installed in this environment.${COLOR_RESET}" >&2
        echo "Please run: sudo apt-get install -y live-build" >&2
        exit 1
    fi
}

prepare_workspace() {
    echo -e "${COLOR_BOLD}--- 1. Initializing live-build Workspace ---${COLOR_RESET}"
    mkdir -p "${LB_DIR}"
    cd "${LB_DIR}"

    # Clean any previous build artifacts completely
    if [[ -d "${LB_DIR}/config" ]]; then
        echo "Purging previous live-build config and chroot..."
        lb clean --purge 2>/dev/null || true
    fi

    # Run lb config with explicit parameters
    echo "Executing 'lb config'..."
    lb config \
        --distribution trixie \
        --architectures amd64 \
        --binary-images iso-hybrid \
        --bootloader grub-efi \
        --archive-areas "main contrib non-free non-free-firmware" \
        --mirror-bootstrap "https://deb.debian.org/debian" \
        --mirror-binary "https://deb.debian.org/debian" \
        --linux-packages "linux-image" \
        --linux-flavours "amd64" \
        --iso-application "Xedra Linux" \
        --iso-publisher "Xedra Linux Project" \
        --iso-volume "XEDRA_0_1" \
        --system live \
        --apt-recommends false \
        --verbose

    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] Base live-build configuration generated"
    echo ""
}

configure_xedra_packages() {
    echo -e "${COLOR_BOLD}--- 2. Configuring Xedra Package Lists ---${COLOR_RESET}"
    mkdir -p "${LB_DIR}/config/package-lists"

    # Core Xedra 0.1 Package List
    cat << 'EOF' > "${LB_DIR}/config/package-lists/xedra.list.chroot"
# Xedra 0.1 Core Package List

# 1. Linux Kernel & Live Boot Infrastructure
linux-image-amd64
live-boot
live-config

# 2. Minimal Display Server & Window Manager
xserver-xorg-core
xserver-xorg-video-all
xserver-xorg-input-all
xinit
x11-xserver-utils
x11-utils
xauth
fluxbox
xterm
dbus-x11

# 3. Essential System Utilities
coreutils
util-linux
pciutils
usbutils
iproute2
iputils-ping
dhcpcd-base
procps
nano
vim-tiny
sudo
EOF

    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] ${LB_DIR}/config/package-lists/xedra.list.chroot created"
    echo ""
}

configure_sysvinit_hook() {
    echo -e "${COLOR_BOLD}--- 3. Installing SysVinit Transition Chroot Hook ---${COLOR_RESET}"
    mkdir -p "${LB_DIR}/config/hooks/normal"

    # Clean old archives preferences if any
    rm -rf "${LB_DIR}/config/archives"

    # In live-build, chroot hooks run inside the chroot during assembly.
    # This allows an atomic apt-get transition to sysvinit-core without
    # triggering live-build's pre-flight package conflict solver.
    cat << 'EOF' > "${LB_DIR}/config/hooks/normal/0100-sysvinit-transition.hook.chroot"
#!/bin/sh
set -e
echo "=== [XEDRA HOOK] Transitioning chroot to SysVinit PID 1 ==="
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
    sysvinit-core \
    initscripts \
    insserv \
    live-config-sysvinit \
    systemd-sysv- \
    --allow-remove-essential

echo "=== [XEDRA HOOK] Setting default users and passwords ==="
# Set root password to 'root'
echo "root:root" | chpasswd

# Create xedra live user with password 'xedra' and sudo privileges
useradd -m -s /bin/bash -G sudo,audio,video,cdrom,plugdev,kvm xedra 2>/dev/null || true
echo "xedra:xedra" | chpasswd

# Grant passwordless sudo to xedra user
mkdir -p /etc/sudoers.d
echo "xedra ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/xedra
chmod 0440 /etc/sudoers.d/xedra

# Ensure user directory ownership and xinitrc
cp /etc/skel/.xinitrc /home/xedra/.xinitrc 2>/dev/null || true
mkdir -p /home/xedra/.fluxbox
cp /etc/skel/.fluxbox/menu /home/xedra/.fluxbox/menu 2>/dev/null || true
chown -R xedra:xedra /home/xedra 2>/dev/null || true

echo "=== [XEDRA HOOK] SysVinit installed; credentials configured ==="
EOF

    chmod +x "${LB_DIR}/config/hooks/normal/0100-sysvinit-transition.hook.chroot"
    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] SysVinit chroot hook installed"
    echo ""
}

configure_chroot_overlays() {
    echo -e "${COLOR_BOLD}--- 4. Installing Xedra Overlay Configurations ---${COLOR_RESET}"
    mkdir -p "${LB_DIR}/config/includes.chroot/etc/skel/.fluxbox"
    mkdir -p "${LB_DIR}/config/includes.chroot/root/.fluxbox"

    # Copy inittab
    if [[ -f "${CONFIG_DIR}/inittab" ]]; then
        cp "${CONFIG_DIR}/inittab" "${LB_DIR}/config/includes.chroot/etc/inittab"
        echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] /etc/inittab overlay added"
    fi

    # Copy .xinitrc
    if [[ -f "${CONFIG_DIR}/xinitrc" ]]; then
        cp "${CONFIG_DIR}/xinitrc" "${LB_DIR}/config/includes.chroot/etc/skel/.xinitrc"
        cp "${CONFIG_DIR}/xinitrc" "${LB_DIR}/config/includes.chroot/root/.xinitrc"
        chmod 755 "${LB_DIR}/config/includes.chroot/etc/skel/.xinitrc"
        chmod 755 "${LB_DIR}/config/includes.chroot/root/.xinitrc"
        echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] .xinitrc overlay added"
    fi

    # Copy Fluxbox menu
    if [[ -f "${CONFIG_DIR}/fluxbox/menu" ]]; then
        cp "${CONFIG_DIR}/fluxbox/menu" "${LB_DIR}/config/includes.chroot/etc/skel/.fluxbox/menu"
        cp "${CONFIG_DIR}/fluxbox/menu" "${LB_DIR}/config/includes.chroot/root/.fluxbox/menu"
        echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] Fluxbox menu overlay added"
    fi

    # Configure auto-login for live session (SysVinit auto-login hook)
    mkdir -p "${LB_DIR}/config/includes.chroot/etc/live/config.conf.d"
    cat << 'EOF' > "${LB_DIR}/config/includes.chroot/etc/live/config.conf.d/xedra.conf"
LIVE_HOSTNAME="xedra"
LIVE_USERNAME="user"
LIVE_USER_DEFAULT_GROUPS="sudo,audio,video,cdrom,plugdev,kvm"
LIVE_CONFIG_NOAUTOLOGIN="false"
EOF

    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] Live configuration hooks added (/etc/live/config.conf.d/xedra.conf)"
    echo ""
}

verify_configuration() {
    echo -e "${COLOR_BOLD}--- 5. Verifying live-build Tree ---${COLOR_RESET}"
    echo "  Structure in ${LB_DIR}/config/:"
    ls -lah "${LB_DIR}/config" | sed 's/^/    /'

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_GREEN}======================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}  live-build Workspace Successfully Configured!        ${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}======================================================${COLOR_RESET}"
    echo ""
    echo "Next Step (Stage 8): Compile the bootable Xedra 0.1 ISO using:"
    echo "  sudo ./scripts/build-iso.sh"
    echo ""
}

main() {
    print_header
    verify_environment
    prepare_workspace
    configure_xedra_packages
    configure_sysvinit_hook
    configure_chroot_overlays
    verify_configuration
}

main "$@"
