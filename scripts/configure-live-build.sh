#!/usr/bin/env bash
# ==============================================================================
# Xedra Linux - Stage 7: Configure live-build for Xedra 0.3 ISO Generation
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Purpose:
#   Initializes and configures the Debian 'live-build' workspace under
#   ~/XedraLinux/build/live-build with Xedra's exact specifications:
#     - Reads multi-profile declarative JSON manifest from config/xedra-build.json
#     - Uses APT pinning to install SysVinit (sysvinit-core) natively without systemd conflicts
#     - Base: Debian 13 "Trixie" (amd64)
#     - Desktop: X11 + Fluxbox + xterm + SPICE agent + xsetroot
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
JSON_CONFIG="${CONFIG_DIR}/xedra-build.json"

# Determine target build profile from arguments
BUILD_PROFILE="dev"
for arg in "$@"; do
    case "${arg}" in
        --profile=*)
            BUILD_PROFILE="${arg#*=}"
            ;;
        --purge)
            BUILD_PROFILE="release"
            ;;
    esac
done

# Default variables
DISTRO_NAME="Xedra Linux"
DISTRO_VERSION="0.3"
DISTRO_CODENAME="genesis"
ISO_VOLUME="XEDRA_0_3"
ISO_APPLICATION="Xedra Linux 0.3"
ISO_PUBLISHER="Xedra Linux Project"
CACHE_PACKAGES=true
PURGE_ON_CLEAN=false
DEBIAN_DISTRIBUTION="trixie"
DEBIAN_ARCH="amd64"
DEBIAN_ARCHIVE_AREAS="main contrib non-free non-free-firmware"
DEBIAN_MIRROR_BOOTSTRAP="https://deb.debian.org/debian"
DEBIAN_MIRROR_BINARY="https://deb.debian.org/debian"
LIVE_HOSTNAME="xedra"
LIVE_USERNAME="xedra"
LIVE_USER_GROUPS="sudo,audio,video,cdrom,plugdev,kvm,input,tty"
LIVE_AUTOLOGIN=true

# Parse JSON manifest if present
if [[ -f "${JSON_CONFIG}" ]] && command -v python3 >/dev/null 2>&1; then
    eval "$(python3 -c "
import json
with open('${JSON_CONFIG}') as f:
    d = json.load(f)
p = d.get('profiles', {}).get('${BUILD_PROFILE}', d.get('profiles', {}).get('dev', {}))
print(f'DISTRO_NAME=\"{d.get(\"distro\", {}).get(\"name\", \"Xedra Linux\")}\"')
print(f'DISTRO_VERSION=\"{d.get(\"distro\", {}).get(\"version\", \"0.3\")}\"')
print(f'DISTRO_CODENAME=\"{d.get(\"distro\", {}).get(\"codename\", \"genesis\")}\"')
print(f'ISO_VOLUME=\"{d.get(\"distro\", {}).get(\"iso_volume\", \"XEDRA_0_3\")}\"')
print(f'ISO_APPLICATION=\"{d.get(\"distro\", {}).get(\"iso_application\", \"Xedra Linux 0.3\")}\"')
print(f'ISO_PUBLISHER=\"{d.get(\"distro\", {}).get(\"iso_publisher\", \"Xedra Linux Project\")}\"')
print(f'DEBIAN_DISTRIBUTION=\"{d.get(\"debian_base\", {}).get(\"distribution\", \"trixie\")}\"')
print(f'DEBIAN_ARCH=\"{d.get(\"debian_base\", {}).get(\"architecture\", \"amd64\")}\"')
print(f'DEBIAN_ARCHIVE_AREAS=\"{d.get(\"debian_base\", {}).get(\"archive_areas\", \"main contrib non-free non-free-firmware\")}\"')
print(f'DEBIAN_MIRROR_BOOTSTRAP=\"{d.get(\"debian_base\", {}).get(\"mirror_bootstrap\", \"https://deb.debian.org/debian\")}\"')
print(f'DEBIAN_MIRROR_BINARY=\"{d.get(\"debian_base\", {}).get(\"mirror_binary\", \"https://deb.debian.org/debian\")}\"')
print(f'CACHE_PACKAGES={str(p.get(\"cache_packages\", True)).lower()}')
print(f'PURGE_ON_CLEAN={str(p.get(\"purge_on_clean\", False)).lower()}')
print(f'LIVE_HOSTNAME=\"{d.get(\"live_session\", {}).get(\"hostname\", \"xedra\")}\"')
print(f'LIVE_USERNAME=\"{d.get(\"live_session\", {}).get(\"username\", \"xedra\")}\"')
print(f'LIVE_USER_GROUPS=\"{d.get(\"live_session\", {}).get(\"user_groups\", \"sudo,audio,video,cdrom,plugdev,kvm,input,tty\")}\"')
print(f'LIVE_AUTOLOGIN={str(d.get(\"live_session\", {}).get(\"autologin\", True)).lower()}')
")"
fi

print_header() {
    echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Xedra Linux - Configure live-build Environment       ${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================${COLOR_RESET}"
    echo "Manifest File:        ${JSON_CONFIG}"
    echo "Distribution:         ${DISTRO_NAME} ${DISTRO_VERSION} (${DISTRO_CODENAME})"
    echo "Active Profile:       ${BUILD_PROFILE}"
    echo "Package Caching:      ${CACHE_PACKAGES}"
    echo "Purge on Clean:       ${PURGE_ON_CLEAN}"
    echo "Workspace:            ${LB_DIR}"
    echo "Init System:          SysVinit (PID 1)"
    echo "Desktop:              Fluxbox + xterm + SPICE"
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

    # Clean intermediate build stages according to profile caching policy
    if [[ -d "${LB_DIR}/config" ]]; then
        if [[ "${PURGE_ON_CLEAN}" == "true" ]]; then
            echo "Purging previous live-build config, chroot, and download cache (Profile: ${BUILD_PROFILE})..."
            lb clean --purge 2>/dev/null || true
        else
            echo "Cleaning previous live-build state (preserving local package cache for profile: ${BUILD_PROFILE})..."
            lb clean --binary --chroot 2>/dev/null || true
        fi
    fi

    local cache_flag="false"
    local cache_packages_flag="false"
    if [[ "${CACHE_PACKAGES}" == "true" ]]; then
        cache_flag="true"
        cache_packages_flag="true"
    fi

    # Run lb config with explicit parameters
    echo "Executing 'lb config' (Profile: ${BUILD_PROFILE})..."
    lb config \
        --distribution "${DEBIAN_DISTRIBUTION}" \
        --architectures "${DEBIAN_ARCH}" \
        --binary-images iso-hybrid \
        --bootloader grub-efi \
        --archive-areas "${DEBIAN_ARCHIVE_AREAS}" \
        --mirror-bootstrap "${DEBIAN_MIRROR_BOOTSTRAP}" \
        --mirror-binary "${DEBIAN_MIRROR_BINARY}" \
        --linux-packages "linux-image" \
        --linux-flavours "${DEBIAN_ARCH}" \
        --iso-application "${ISO_APPLICATION}" \
        --iso-publisher "${ISO_PUBLISHER}" \
        --iso-volume "${ISO_VOLUME}" \
        --system live \
        --cache "${cache_flag}" \
        --cache-packages "${cache_packages_flag}" \
        --cache-stages "bootstrap chroot" \
        --bootappend-live "boot=live components hostname=${LIVE_HOSTNAME} username=${LIVE_USERNAME} quiet" \
        --apt-recommends false \
        --verbose

    # Setup APT Preferences (Pinning) to guarantee SysVinit selection without systemd conflicts
    mkdir -p "${LB_DIR}/config/archives"
    cat << 'PREF_EOF' > "${LB_DIR}/config/archives/sysvinit.pref.chroot"
Package: systemd-sysv
Pin: release *
Pin-Priority: -1

Package: sysvinit-core
Pin: release *
Pin-Priority: 1001

Package: live-config-sysvinit
Pin: release *
Pin-Priority: 1001
PREF_EOF

    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] Base live-build configuration and APT pinning generated"
    echo ""
}

configure_xedra_packages() {
    echo -e "${COLOR_BOLD}--- 2. Configuring Xedra Package Lists ---${COLOR_RESET}"
    mkdir -p "${LB_DIR}/config/package-lists"

    # Complete Xedra Core Package List with explicit SysVinit components
    cat << 'EOF' > "${LB_DIR}/config/package-lists/xedra.list.chroot"
# Xedra Core Package List

# 1. Linux Kernel & Hardware Device Subsystem
linux-image-amd64
live-boot
live-config-sysvinit
sysvinit-core
initscripts
insserv
orphan-sysvinit-scripts
elogind
libpam-elogind
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
    echo -e "${COLOR_BOLD}--- 3. Installing System Configuration Chroot Hook ---${COLOR_RESET}"
    mkdir -p "${LB_DIR}/config/hooks/normal"

    cat << 'EOF' > "${LB_DIR}/config/hooks/normal/0100-sysvinit-transition.hook.chroot"
#!/bin/sh
set -e
echo "=== [XEDRA HOOK] Setting default users, passwords, and service defaults ==="

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

echo "=== [XEDRA HOOK] Users, permissions, and network configured ==="
EOF

    chmod +x "${LB_DIR}/config/hooks/normal/0100-sysvinit-transition.hook.chroot"
    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] Configuration chroot hook installed"
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

    # Install custom Xedra branding and ASCII issue banner
    cat << ISSUE_EOF > "${LB_DIR}/config/includes.chroot/etc/issue"
 __  __          _           _     _                  
 \ \/ /___  __| |_ __ __ _  | |   (_)_ __  _   ___  __
  \  // _ \/ _` | '__/ _` | | |   | | '_ \| | | \ \/ /
  /  \  __/ (_| | | | (_| | | |___| | | | | |_| |>  < 
 /_/\_\___|\__,_|_|  \__,_| |_____|_|_| |_|\__,_/_/\_\

 ${DISTRO_NAME} ${DISTRO_VERSION} (${DEBIAN_ARCH}) — ${DISTRO_CODENAME^}
 Kernel \r on an \m (\l)

ISSUE_EOF

    cp "${LB_DIR}/config/includes.chroot/etc/issue" "${LB_DIR}/config/includes.chroot/etc/issue.net"

    # Install custom Xedra /etc/os-release
    cat << OS_EOF > "${LB_DIR}/config/includes.chroot/etc/os-release"
NAME="${DISTRO_NAME}"
PRETTY_NAME="${DISTRO_NAME} ${DISTRO_VERSION} (${DISTRO_CODENAME^})"
ID=xedra
ID_LIKE=debian
VERSION="${DISTRO_VERSION}"
VERSION_ID="${DISTRO_VERSION}"
VERSION_CODENAME=${DISTRO_CODENAME}
HOME_URL="https://github.com/arthurgray2k/XedraLinux"
SUPPORT_URL="https://github.com/arthurgray2k/XedraLinux/issues"
BUG_REPORT_URL="https://github.com/arthurgray2k/XedraLinux/issues"
OS_EOF

    # Configure auto-login for live session
    mkdir -p "${LB_DIR}/config/includes.chroot/etc/live/config.conf.d"
    cat << EOF > "${LB_DIR}/config/includes.chroot/etc/live/config.conf.d/xedra.conf"
LIVE_HOSTNAME="${LIVE_HOSTNAME}"
LIVE_USERNAME="${LIVE_USERNAME}"
LIVE_USER_DEFAULT_GROUPS="${LIVE_USER_GROUPS}"
LIVE_CONFIG_NOAUTOLOGIN="$([[ "${LIVE_AUTOLOGIN}" == "true" ]] && echo "false" || echo "true")"
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
    echo "  sudo ./scripts/build-iso.sh --profile=${BUILD_PROFILE}"
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
