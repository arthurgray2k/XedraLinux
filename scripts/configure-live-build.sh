#!/usr/bin/env bash
# ==============================================================================
# Xedra Linux - Stage 7: Configure live-build for Xedra 0.3 ISO Generation
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Purpose:
#   Initializes and configures the Debian 'live-build' workspace under
#   ~/XedraLinux/build/live-build with Xedra's exact specifications:
#     - Base: Debian 13 "Trixie" (amd64)
#     - Init System: SysVinit (sysvinit-core) via chroot transition hook
#     - Desktop: X11 + Fluxbox + xterm + SPICE agent + xsetroot (1600x900 wide)
#     - Hardware/Input: udev + kmod + libinput + xserver-xorg-legacy
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
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Xedra Linux - Configure live-build (v0.3)             ${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================${COLOR_RESET}"
    echo "Live-Build Workspace: ${LB_DIR}"
    echo "Distribution Base:    Debian 13 (Trixie) amd64"
    echo "Init System:          SysVinit (PID 1)"
    echo "Desktop:              Fluxbox + xterm + SPICE (1600x900)"
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

    # Clean intermediate build stages but PRESERVE local downloaded package archives (cache/packages.*)
    if [[ -d "${LB_DIR}/config" ]]; then
        echo "Cleaning previous live-build stages (preserving local package cache)..."
        lb clean --stage --binary --chroot 2>/dev/null || true
    fi

    # Run lb config with package cache enabled and stage cache disabled
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
        --iso-application "Xedra Linux 0.3" \
        --iso-publisher "Xedra Linux Project" \
        --iso-volume "XEDRA_0_3" \
        --system live \
        --cache true \
        --cache-packages true \
        --cache-stages none \
        --bootappend-live "boot=live components hostname=xedra username=xedra quiet" \
        --apt-recommends false \
        --verbose

    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] Base live-build configuration generated (package cache enabled)"
    echo ""
}

configure_xedra_packages() {
    echo -e "${COLOR_BOLD}--- 2. Configuring Xedra Package Lists ---${COLOR_RESET}"
    mkdir -p "${LB_DIR}/config/package-lists"

    # Complete Xedra Core Package List
    cat << 'EOF' > "${LB_DIR}/config/package-lists/xedra.list.chroot"
# Xedra 0.3 Core Package List

# 1. Linux Kernel & Hardware Device Subsystem
linux-image-amd64
live-boot
live-config
udev
kmod

# 2. Display Server, Window Manager & Input Drivers
xserver-xorg-core
xserver-xorg-legacy
xserver-xorg-video-all
xserver-xorg-video-qxl
xserver-xorg-input-all
xserver-xorg-input-libinput
xinit
x11-xserver-utils
x11-utils
xauth
fluxbox
xterm
spice-vdagent
dbus-x11

# 3. Networking & System Utilities
iproute2
iputils-ping
dhcpcd-base
net-tools
pciutils
usbutils
coreutils
util-linux
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

    # Remove any stale archive configs
    rm -rf "${LB_DIR}/config/archives"

    cat << 'EOF' > "${LB_DIR}/config/hooks/normal/0100-sysvinit-transition.hook.chroot"
#!/bin/sh
set -e
echo "=== [XEDRA HOOK] Transitioning chroot to SysVinit PID 1 & elogind ==="
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
    sysvinit-core \
    initscripts \
    insserv \
    orphan-sysvinit-scripts \
    live-config-sysvinit \
    systemd-sysv- \
    elogind \
    libpam-elogind \
    --allow-remove-essential

echo "=== [XEDRA HOOK] Setting default users and passwords ==="
# Set root password to 'root'
echo "root:root" | chpasswd

# Create xedra live user with password 'xedra' and input/audio/video privileges
useradd -m -s /bin/bash -G sudo,audio,video,cdrom,plugdev,kvm,input,tty xedra 2>/dev/null || true
echo "xedra:xedra" | chpasswd

# Grant passwordless sudo to xedra user
mkdir -p /etc/sudoers.d
echo "xedra ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/xedra
chmod 0440 /etc/sudoers.d/xedra

# Enable udev and essential SysVinit services
update-rc.d udev defaults 2>/dev/null || true
update-rc.d dbus defaults 2>/dev/null || true
update-rc.d elogind defaults 2>/dev/null || true

# Configure auto-startx on tty1 for xedra user directly on VT1
cat << 'PROFILE_EOF' > /home/xedra/.profile
# ~/.profile: executed by Bourne-compatible login shells
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx -- vt1 -keeptty
fi
PROFILE_EOF
chown xedra:xedra /home/xedra/.profile

# Configure networking interfaces for automatic DHCP
cat << 'NET_EOF' > /etc/network/interfaces
# Loopback network interface
auto lo
iface lo inet loopback

# Ethernet interfaces with automatic DHCP
allow-hotplug eth0
iface eth0 inet dhcp

allow-hotplug enp1s0
iface enp1s0 inet dhcp
NET_EOF

echo "=== [XEDRA HOOK] SysVinit installed; input & users configured ==="
EOF

    chmod +x "${LB_DIR}/config/hooks/normal/0100-sysvinit-transition.hook.chroot"
    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] SysVinit chroot hook installed"
    echo ""
}

configure_chroot_overlays() {
    echo -e "${COLOR_BOLD}--- 4. Installing Xedra Overlay Configurations ---${COLOR_RESET}"
    mkdir -p "${LB_DIR}/config/includes.chroot/etc/skel/.fluxbox"
    mkdir -p "${LB_DIR}/config/includes.chroot/root/.fluxbox"
    mkdir -p "${LB_DIR}/config/includes.chroot/home/xedra/.fluxbox"
    mkdir -p "${LB_DIR}/config/includes.chroot/etc/X11"

    # Configure Xorg wrapper permissions for non-root console startx
    cat << 'XWRAP_EOF' > "${LB_DIR}/config/includes.chroot/etc/X11/Xwrapper.config"
# /etc/X11/Xwrapper.config: Allow non-root users to start X on active console
allowed_users = console
needs_root_rights = yes
XWRAP_EOF

    # Copy inittab
    if [[ -f "${CONFIG_DIR}/inittab" ]]; then
        cp "${CONFIG_DIR}/inittab" "${LB_DIR}/config/includes.chroot/etc/inittab"
        echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] /etc/inittab overlay added"
    fi

    # Copy .xinitrc
    if [[ -f "${CONFIG_DIR}/xinitrc" ]]; then
        cp "${CONFIG_DIR}/xinitrc" "${LB_DIR}/config/includes.chroot/etc/skel/.xinitrc"
        cp "${CONFIG_DIR}/xinitrc" "${LB_DIR}/config/includes.chroot/root/.xinitrc"
        cp "${CONFIG_DIR}/xinitrc" "${LB_DIR}/config/includes.chroot/home/xedra/.xinitrc"
        chmod 755 "${LB_DIR}/config/includes.chroot/etc/skel/.xinitrc"
        chmod 755 "${LB_DIR}/config/includes.chroot/root/.xinitrc"
        chmod 755 "${LB_DIR}/config/includes.chroot/home/xedra/.xinitrc"
        echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] .xinitrc overlay added"
    fi

    # Copy Fluxbox menu
    if [[ -f "${CONFIG_DIR}/fluxbox/menu" ]]; then
        cp "${CONFIG_DIR}/fluxbox/menu" "${LB_DIR}/config/includes.chroot/etc/skel/.fluxbox/menu"
        cp "${CONFIG_DIR}/fluxbox/menu" "${LB_DIR}/config/includes.chroot/root/.fluxbox/menu"
        cp "${CONFIG_DIR}/fluxbox/menu" "${LB_DIR}/config/includes.chroot/home/xedra/.fluxbox/menu"
        echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] Fluxbox menu overlay added"
    fi

    # Install custom Xedra 0.3 branding and ASCII issue banner
    cat << 'ISSUE_EOF' > "${LB_DIR}/config/includes.chroot/etc/issue"
 __  __          _           _     _                  
 \ \/ /___  __| |_ __ __ _  | |   (_)_ __  _   ___  __
  \  // _ \/ _` | '__/ _` | | |   | | '_ \| | | \ \/ /
  /  \  __/ (_| | | | (_| | | |___| | | | | |_| |>  < 
 /_/\_\___|\__,_|_|  \__,_| |_____|_|_| |_|\__,_/_/\_\

 Xedra Linux 0.3 (amd64) — Genesis
 Kernel \r on an \m (\l)

ISSUE_EOF

    cp "${LB_DIR}/config/includes.chroot/etc/issue" "${LB_DIR}/config/includes.chroot/etc/issue.net"

    # Install custom Xedra /etc/os-release
    cat << 'OS_EOF' > "${LB_DIR}/config/includes.chroot/etc/os-release"
NAME="Xedra Linux"
PRETTY_NAME="Xedra Linux 0.3 (Genesis)"
ID=xedra
ID_LIKE=debian
VERSION="0.3"
VERSION_ID="0.3"
VERSION_CODENAME=genesis
HOME_URL="https://github.com/arthurgray2k/XedraLinux"
SUPPORT_URL="https://github.com/arthurgray2k/XedraLinux/issues"
BUG_REPORT_URL="https://github.com/arthurgray2k/XedraLinux/issues"
OS_EOF

    # Configure auto-login for live session
    mkdir -p "${LB_DIR}/config/includes.chroot/etc/live/config.conf.d"
    cat << 'EOF' > "${LB_DIR}/config/includes.chroot/etc/live/config.conf.d/xedra.conf"
LIVE_HOSTNAME="xedra"
LIVE_USERNAME="xedra"
LIVE_USER_DEFAULT_GROUPS="sudo,audio,video,cdrom,plugdev,kvm,input,tty"
LIVE_CONFIG_NOAUTOLOGIN="false"
EOF

    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] Xedra branding, ASCII issue banner, and live hooks added"
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
    echo "Next Step: Compile the bootable ISO using:"
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
