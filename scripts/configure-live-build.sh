#!/usr/bin/env bash
# ==============================================================================
# Xedra Linux - Stage 7: Configure live-build for Xedra 0.4.2 ISO Generation
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Purpose:
#   Initializes and configures the Debian 'live-build' workspace under
#   ~/XedraLinux/build/live-build with Xedra's exact specifications:
#     - Reads multi-profile configuration from config/xedra-build.json
#     - Supports profiles: dev (fast package & bootstrap cache), release, minimal
#     - Base: Debian 13 "Trixie" (amd64)
#     - Init System: SysVinit (sysvinit-core) via pre-cached packages & hook
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
DISTRO_VERSION="0.4.2"
DISTRO_CODENAME="genesis"
ISO_VOLUME="XEDRA_0_4_2"
ISO_APPLICATION="Xedra Linux 0.4.2"
ISO_PUBLISHER="Xedra Linux Project"
ISO_NAME="xedra-0.4.2-amd64.iso"
CACHE_PACKAGES=true
PURGE_ON_CLEAN=false
DEBIAN_DISTRIBUTION="trixie"
DEBIAN_ARCH="amd64"
DEBIAN_ARCHIVE_AREAS="main contrib non-free non-free-firmware"
DEBIAN_MIRROR_BOOTSTRAP="https://deb.debian.org/debian"
DEBIAN_MIRROR_BINARY="https://deb.debian.org/debian"
LIVE_HOSTNAME="xedra"
LIVE_USERNAME="live"
LIVE_USER_GROUPS="sudo,audio,video,cdrom,plugdev,kvm,input,tty"
LIVE_AUTOLOGIN=true
ENABLE_SSH=true
ENABLE_TELNET=false

# Parse JSON manifest if present
if [[ -f "${JSON_CONFIG}" ]] && command -v python3 >/dev/null 2>&1; then
    eval "$(python3 -c "
import json
with open('${JSON_CONFIG}') as f:
    d = json.load(f)
p = d.get('profiles', {}).get('${BUILD_PROFILE}', d.get('profiles', {}).get('dev', {}))
ver = d.get('distro', {}).get('version', '0.4.2')
iso_name = p.get('iso_name', f'xedra-{ver}-amd64.iso')
iso_vol = p.get('iso_volume', d.get('distro', {}).get('iso_volume', 'XEDRA_0_4_2'))
iso_app = p.get('iso_application', d.get('distro', {}).get('iso_application', 'Xedra Linux 0.4.2'))

srv = d.get('services', {})
prof_srv = p.get('services', {})
merged_ssh = prof_srv.get('ssh', srv.get('ssh', {}))
merged_telnet = prof_srv.get('telnet', srv.get('telnet', {}))

if isinstance(merged_ssh, dict):
    enable_ssh = merged_ssh.get('enabled', True)
    ssh_port = merged_ssh.get('port', 22)
    ssh_pass_auth = merged_ssh.get('password_authentication', True)
    ssh_root_login = merged_ssh.get('permit_root_login', 'prohibit-password')
elif isinstance(merged_ssh, bool):
    enable_ssh = merged_ssh
    ssh_port = 22
    ssh_pass_auth = True
    ssh_root_login = 'prohibit-password'
else:
    enable_ssh = True
    ssh_port = 22
    ssh_pass_auth = True
    ssh_root_login = 'prohibit-password'

if isinstance(merged_telnet, dict):
    enable_telnet = merged_telnet.get('enabled', False)
    telnet_port = merged_telnet.get('port', 23)
    telnet_root_login = merged_telnet.get('permit_root_login', False)
elif isinstance(merged_telnet, bool):
    enable_telnet = merged_telnet
    telnet_port = 23
    telnet_root_login = False
else:
    enable_telnet = False
    telnet_port = 23
    telnet_root_login = False

print(f'DISTRO_NAME=\"{d.get(\"distro\", {}).get(\"name\", \"Xedra Linux\")}\"')
print(f'DISTRO_VERSION=\"{ver}\"')
print(f'DISTRO_CODENAME=\"{d.get(\"distro\", {}).get(\"codename\", \"genesis\")}\"')
print(f'ISO_VOLUME=\"{iso_vol}\"')
print(f'ISO_APPLICATION=\"{iso_app}\"')
print(f'ISO_NAME=\"{iso_name}\"')
print(f'ISO_PUBLISHER=\"{d.get(\"distro\", {}).get(\"iso_publisher\", \"Xedra Linux Project\")}\"')
print(f'DEBIAN_DISTRIBUTION=\"{d.get(\"debian_base\", {}).get(\"distribution\", \"trixie\")}\"')
print(f'DEBIAN_ARCH=\"{d.get(\"debian_base\", {}).get(\"architecture\", \"amd64\")}\"')
print(f'DEBIAN_ARCHIVE_AREAS=\"{d.get(\"debian_base\", {}).get(\"archive_areas\", \"main contrib non-free non-free-firmware\")}\"')
print(f'DEBIAN_MIRROR_BOOTSTRAP=\"{d.get(\"debian_base\", {}).get(\"mirror_bootstrap\", \"https://deb.debian.org/debian\")}\"')
print(f'DEBIAN_MIRROR_BINARY=\"{d.get(\"debian_base\", {}).get(\"mirror_binary\", \"https://deb.debian.org/debian\")}\"')
print(f'CACHE_PACKAGES={str(p.get(\"cache_packages\", True)).lower()}')
print(f'CACHE_BOOTSTRAP={str(p.get(\"cache_bootstrap\", True)).lower()}')
print(f'FAST_IO={str(p.get(\"fast_io\", True)).lower()}')
print(f'PURGE_ON_CLEAN={str(p.get(\"purge_on_clean\", False)).lower()}')
print(f'SQUASHFS_COMPRESSION=\"{p.get(\"squashfs_compression\", \"gzip\")}\"')
print(f'LIVE_HOSTNAME=\"{d.get(\"live_session\", {}).get(\"hostname\", \"xedra\")}\"')
print(f'LIVE_USERNAME=\"{d.get(\"live_session\", {}).get(\"username\", \"live\")}\"')
print(f'LIVE_USER_GROUPS=\"{d.get(\"live_session\", {}).get(\"user_groups\", \"sudo,audio,video,cdrom,plugdev,kvm,input,tty\")}\"')
print(f'LIVE_AUTOLOGIN={str(d.get(\"live_session\", {}).get(\"autologin\", True)).lower()}')
print(f'ENABLE_SSH={str(enable_ssh).lower()}')
print(f'SSH_PORT={ssh_port}')
print(f'SSH_PASSWORD_AUTH={str(ssh_pass_auth).lower()}')
print(f'SSH_PERMIT_ROOT_LOGIN=\"{ssh_root_login}\"')
print(f'ENABLE_TELNET={str(enable_telnet).lower()}')
print(f'TELNET_PORT={telnet_port}')
print(f'TELNET_PERMIT_ROOT_LOGIN={str(telnet_root_login).lower()}')
")"
fi

print_header() {
    echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Xedra Linux - Configure live-build (v${DISTRO_VERSION})             ${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================${COLOR_RESET}"
    echo "Manifest File:        ${JSON_CONFIG}"
    echo "Distribution:         ${DISTRO_NAME} ${DISTRO_VERSION} (${DISTRO_CODENAME})"
    echo "Active Profile:       ${BUILD_PROFILE}"
    echo "Target ISO Output:    ${ISO_NAME}"
    echo "SSH Server:           ${ENABLE_SSH} (Port: ${SSH_PORT}, PasswordAuth: ${SSH_PASSWORD_AUTH}, PermitRootLogin: ${SSH_PERMIT_ROOT_LOGIN})"
    echo "Telnet Server:        ${ENABLE_TELNET} (Port: ${TELNET_PORT}, PermitRootLogin: ${TELNET_PERMIT_ROOT_LOGIN})"
    echo "Package Caching:      ${CACHE_PACKAGES}"
    echo "Bootstrap Caching:    ${CACHE_BOOTSTRAP}"
    echo "Fast I/O:             ${FAST_IO}"
    echo "Squashfs Compression: ${SQUASHFS_COMPRESSION}"
    echo "Purge on Clean:       ${PURGE_ON_CLEAN}"
    echo "Workspace:            ${LB_DIR}"
    echo "Init System:          SysVinit (PID 1)"
    if [[ "${BUILD_PROFILE}" == "minimal" ]]; then
        echo "Environment:          Text Console CLI (No GUI)"
    else
        echo "Environment:          Fluxbox Desktop + xterm + SPICE (1600x900)"
    fi
    echo "Languages & Tools:    Python 3, Golang, Micro, Native Installer"
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
            echo "Cleaning previous live-build stages (preserving local package cache for profile: ${BUILD_PROFILE})..."
            lb clean --stage --binary --chroot 2>/dev/null || true
        fi
    fi

    local cache_flag="false"
    local cache_packages_flag="false"
    local cache_stages_flag="none"
    if [[ "${CACHE_PACKAGES}" == "true" ]]; then
        cache_flag="true"
        cache_packages_flag="true"
    fi
    if [[ "${CACHE_BOOTSTRAP}" == "true" ]]; then
        cache_stages_flag="bootstrap"
    fi

    # Configure squashfs compression flags directly for lb config
    local compression_type="gzip"
    local compression_level_opt=()
    if [[ "${SQUASHFS_COMPRESSION}" == "xz" ]]; then
        compression_type="xz"
    elif [[ "${SQUASHFS_COMPRESSION}" == "gzip" ]]; then
        compression_type="gzip"
        compression_level_opt=("--chroot-squashfs-compression-level" "1")
    elif [[ "${SQUASHFS_COMPRESSION}" == "zstd" ]]; then
        compression_type="zstd"
        compression_level_opt=("--chroot-squashfs-compression-level" "1")
    fi

    # Run lb config with optimized cache and compression parameters
    echo "Executing 'lb config' (Profile: ${BUILD_PROFILE}, Compression: ${compression_type})..."
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
        --cache-stages "${cache_stages_flag}" \
        --chroot-squashfs-compression-type "${compression_type}" \
        "${compression_level_opt[@]}" \
        --bootappend-live "boot=live components hostname=${LIVE_HOSTNAME} username=${LIVE_USERNAME} quiet" \
        --apt-recommends false \
        --verbose

    # Inject force-unsafe-io into dpkg to eliminate 130,000 fsync bottlenecks in VM
    if [[ "${FAST_IO}" == "true" ]]; then
        mkdir -p "${LB_DIR}/config/includes.bootstrap/etc/dpkg/dpkg.cfg.d"
        mkdir -p "${LB_DIR}/config/includes.chroot/etc/dpkg/dpkg.cfg.d"
        echo "force-unsafe-io" > "${LB_DIR}/config/includes.bootstrap/etc/dpkg/dpkg.cfg.d/01-fast"
        echo "force-unsafe-io" > "${LB_DIR}/config/includes.chroot/etc/dpkg/dpkg.cfg.d/01-fast"
        echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] Fast I/O (force-unsafe-io) enabled for dpkg"
    fi

    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] Base live-build configuration generated (Profile: ${BUILD_PROFILE}, Compression: ${compression_type})"
    echo ""
}

configure_xedra_packages() {
    echo -e "${COLOR_BOLD}--- 2. Configuring Xedra Package Lists ---${COLOR_RESET}"
    mkdir -p "${LB_DIR}/config/package-lists"

    # Core Package List for All Profiles (Kernel, Languages, Editors, Installer, CLI Tools)
    cat << 'EOF' > "${LB_DIR}/config/package-lists/xedra.list.chroot"
# Xedra 0.4.2 Core Package List

# 1. Linux Kernel & Hardware Device Subsystem
linux-image-amd64
live-boot
live-config
udev
kmod

# 2. Languages, Toolchains & Editors
python3
python3-pip
python3-venv
golang-go
micro
nano
vim-tiny

# 3. Native Disk Installer & Filesystem Utilities
dialog
parted
dosfstools
e2fsprogs
rsync
grub-efi-amd64
grub-pc-bin
grub2-common

# 4. Networking & System Utilities
iproute2
iputils-ping
dhcpcd-base
net-tools
telnet
curl
wget
ca-certificates
pciutils
usbutils
coreutils
util-linux
procps
sudo
EOF

    # Conditionally include OpenSSH Server
    if [[ "${ENABLE_SSH}" == "true" ]]; then
        echo "openssh-server" >> "${LB_DIR}/config/package-lists/xedra.list.chroot"
    fi

    # Conditionally include Telnet Server
    if [[ "${ENABLE_TELNET}" == "true" ]]; then
        echo "telnetd" >> "${LB_DIR}/config/package-lists/xedra.list.chroot"
        echo "openbsd-inetd" >> "${LB_DIR}/config/package-lists/xedra.list.chroot"
    fi

    # 5. Display Server, Window Manager & Input Drivers (GUI Profiles Only)
    if [[ "${BUILD_PROFILE}" != "minimal" ]]; then
        cat << 'EOF' >> "${LB_DIR}/config/package-lists/xedra.list.chroot"

# 5. Graphical Desktop Environment (Fluxbox + X11 + SPICE)
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
EOF
    fi

    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] ${LB_DIR}/config/package-lists/xedra.list.chroot created (Profile: ${BUILD_PROFILE})"
    echo ""
}

configure_sysvinit_hook() {
    echo -e "${COLOR_BOLD}--- 3. Installing SysVinit Transition Chroot Hook ---${COLOR_RESET}"
    mkdir -p "${LB_DIR}/config/hooks/normal"

    # Clean old archives preferences if any
    rm -rf "${LB_DIR}/config/archives"

    cat << EOF > "${LB_DIR}/config/hooks/normal/0100-sysvinit-transition.hook.chroot"
#!/bin/sh
set -e
echo "=== [XEDRA HOOK] Transitioning chroot to SysVinit PID 1 & elogind ==="
export DEBIAN_FRONTEND=noninteractive

apt-get update -o Acquire::Languages=none
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

echo "=== [XEDRA HOOK] Setting default live and root users ==="
# Set root password to 'root'
echo "root:root" | chpasswd

# Create live user with password 'live' and input/audio/video privileges
useradd -m -s /bin/bash -G sudo,audio,video,cdrom,plugdev,kvm,input,tty live 2>/dev/null || true
echo "live:live" | chpasswd

# Grant passwordless sudo to live user
mkdir -p /etc/sudoers.d
echo "live ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/live
chmod 0440 /etc/sudoers.d/live

# Enable essential SysVinit services
update-rc.d udev defaults 2>/dev/null || true
update-rc.d dbus defaults 2>/dev/null || true
update-rc.d elogind defaults 2>/dev/null || true
EOF

    # Configure SSH service in chroot hook if enabled
    if [[ "${ENABLE_SSH}" == "true" ]]; then
        local ssh_pass_flag="no"
        local kbd_flag="no"
        if [[ "${SSH_PASSWORD_AUTH}" == "true" ]]; then
            ssh_pass_flag="yes"
            kbd_flag="yes"
        fi
        cat << SSH_HOOK_EOF >> "${LB_DIR}/config/hooks/normal/0100-sysvinit-transition.hook.chroot"
echo "=== [XEDRA HOOK] Configuring SSH daemon (port=${SSH_PORT}, password_auth=${ssh_pass_flag}, permit_root=${SSH_PERMIT_ROOT_LOGIN}) ==="
mkdir -p /etc/ssh/sshd_config.d
cat << SSHD_CONF > /etc/ssh/sshd_config.d/01-xedra.conf
# Xedra Linux - Declarative OpenSSH Configuration
Port ${SSH_PORT}
PasswordAuthentication ${ssh_pass_flag}
KbdInteractiveAuthentication ${kbd_flag}
PermitRootLogin ${SSH_PERMIT_ROOT_LOGIN}
SSHD_CONF
ssh-keygen -A 2>/dev/null || true
update-rc.d ssh defaults 2>/dev/null || true
SSH_HOOK_EOF
    fi

    # Configure Telnet service in chroot hook if enabled
    if [[ "${ENABLE_TELNET}" == "true" ]]; then
        cat << TELNET_HOOK_EOF >> "${LB_DIR}/config/hooks/normal/0100-sysvinit-transition.hook.chroot"
echo "=== [XEDRA HOOK] Configuring Telnet in /etc/inetd.conf (port=${TELNET_PORT}, permit_root=${TELNET_PERMIT_ROOT_LOGIN}) ==="
touch /etc/inetd.conf
if ! grep -q "in.telnetd" /etc/inetd.conf 2>/dev/null; then
    echo "${TELNET_PORT}          stream  tcp     nowait  root    /usr/sbin/in.telnetd    in.telnetd" >> /etc/inetd.conf
fi
if [[ "${TELNET_PERMIT_ROOT_LOGIN}" == "true" ]]; then
    mkdir -p /etc
    for i in \$(seq 0 9); do
        if ! grep -qx "pts/\$i" /etc/securetty 2>/dev/null; then
            echo "pts/\$i" >> /etc/securetty
        fi
    done
fi
update-rc.d openbsd-inetd defaults 2>/dev/null || true
TELNET_HOOK_EOF
    fi

    if [[ "${BUILD_PROFILE}" != "minimal" ]]; then
        cat << 'EOF' >> "${LB_DIR}/config/hooks/normal/0100-sysvinit-transition.hook.chroot"
cat << 'PROFILE_EOF' > /etc/skel/.profile
# ~/.profile: executed by Bourne-compatible login shells
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    startx -- vt1 -keeptty
fi
PROFILE_EOF
EOF
    else
        cat << 'EOF' >> "${LB_DIR}/config/hooks/normal/0100-sysvinit-transition.hook.chroot"
cat << 'PROFILE_EOF' > /etc/skel/.profile
# ~/.profile: executed by Bourne-compatible login shells
# Minimal Profile: pure text console
PROFILE_EOF
EOF
    fi

    cat << 'EOF' >> "${LB_DIR}/config/hooks/normal/0100-sysvinit-transition.hook.chroot"
cp /etc/skel/.profile /home/live/.profile
chown -R live:live /home/live

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

echo "=== [XEDRA HOOK] SysVinit installed; SSH, input & live user configured ==="
EOF

    chmod +x "${LB_DIR}/config/hooks/normal/0100-sysvinit-transition.hook.chroot"
    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] SysVinit chroot hook installed"
    echo ""
}

configure_chroot_overlays() {
    echo -e "${COLOR_BOLD}--- 4. Installing Xedra Overlay Configurations ---${COLOR_RESET}"
    mkdir -p "${LB_DIR}/config/includes.chroot/etc/skel"
    mkdir -p "${LB_DIR}/config/includes.chroot/root"
    mkdir -p "${LB_DIR}/config/includes.chroot/home/live"
    mkdir -p "${LB_DIR}/config/includes.chroot/etc/X11"
    mkdir -p "${LB_DIR}/config/includes.chroot/usr/local/bin"

    # Install native Xedra System Installer
    if [[ -f "${CONFIG_DIR}/xedra-installer" ]]; then
        cp "${CONFIG_DIR}/xedra-installer" "${LB_DIR}/config/includes.chroot/usr/local/bin/xedra-installer"
        chmod 755 "${LB_DIR}/config/includes.chroot/usr/local/bin/xedra-installer"
        echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] /usr/local/bin/xedra-installer installed"
    fi

    # Copy inittab
    if [[ -f "${CONFIG_DIR}/inittab" ]]; then
        cp "${CONFIG_DIR}/inittab" "${LB_DIR}/config/includes.chroot/etc/inittab"
        echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] /etc/inittab overlay added"
    fi

    # Configure SSH daemon settings if enabled
    if [[ "${ENABLE_SSH}" == "true" ]]; then
        local ssh_pass_flag="no"
        local kbd_flag="no"
        if [[ "${SSH_PASSWORD_AUTH}" == "true" ]]; then
            ssh_pass_flag="yes"
            kbd_flag="yes"
        fi
        mkdir -p "${LB_DIR}/config/includes.chroot/etc/ssh/sshd_config.d"
        cat << SSHD_CONF_EOF > "${LB_DIR}/config/includes.chroot/etc/ssh/sshd_config.d/01-xedra.conf"
# Xedra Linux - Declarative OpenSSH Configuration
Port ${SSH_PORT}
PasswordAuthentication ${ssh_pass_flag}
KbdInteractiveAuthentication ${kbd_flag}
PermitRootLogin ${SSH_PERMIT_ROOT_LOGIN}
SSHD_CONF_EOF
        echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] SSH overlay added (port: ${SSH_PORT}, password_auth: ${ssh_pass_flag}, permit_root: ${SSH_PERMIT_ROOT_LOGIN})"
    fi

    # Configure Telnet daemon settings if enabled
    if [[ "${ENABLE_TELNET}" == "true" ]]; then
        mkdir -p "${LB_DIR}/config/includes.chroot/etc"
        cat << INETD_CONF_EOF > "${LB_DIR}/config/includes.chroot/etc/inetd.conf"
${TELNET_PORT}          stream  tcp     nowait  root    /usr/sbin/in.telnetd    in.telnetd
INETD_CONF_EOF
        if [[ "${TELNET_PERMIT_ROOT_LOGIN}" == "true" ]]; then
            for i in $(seq 0 9); do
                echo "pts/$i" >> "${LB_DIR}/config/includes.chroot/etc/securetty"
            done
        fi
        echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] Telnet /etc/inetd.conf overlay added (port: ${TELNET_PORT}, permit_root: ${TELNET_PERMIT_ROOT_LOGIN})"
    fi

    # Configure GUI overlays only for non-minimal builds
    if [[ "${BUILD_PROFILE}" != "minimal" ]]; then
        mkdir -p "${LB_DIR}/config/includes.chroot/etc/skel/.fluxbox"
        mkdir -p "${LB_DIR}/config/includes.chroot/root/.fluxbox"
        mkdir -p "${LB_DIR}/config/includes.chroot/home/live/.fluxbox"

        # Configure Xorg wrapper permissions for non-root console startx
        cat << 'XWRAP_EOF' > "${LB_DIR}/config/includes.chroot/etc/X11/Xwrapper.config"
# /etc/X11/Xwrapper.config: Allow non-root users to start X on active console
allowed_users = console
needs_root_rights = yes
XWRAP_EOF

        # Copy .xinitrc
        if [[ -f "${CONFIG_DIR}/xinitrc" ]]; then
            cp "${CONFIG_DIR}/xinitrc" "${LB_DIR}/config/includes.chroot/etc/skel/.xinitrc"
            cp "${CONFIG_DIR}/xinitrc" "${LB_DIR}/config/includes.chroot/root/.xinitrc"
            cp "${CONFIG_DIR}/xinitrc" "${LB_DIR}/config/includes.chroot/home/live/.xinitrc"
            chmod 755 "${LB_DIR}/config/includes.chroot/etc/skel/.xinitrc"
            chmod 755 "${LB_DIR}/config/includes.chroot/root/.xinitrc"
            chmod 755 "${LB_DIR}/config/includes.chroot/home/live/.xinitrc"
            echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] .xinitrc overlay added"
        fi

        # Copy Fluxbox menu
        if [[ -f "${CONFIG_DIR}/fluxbox/menu" ]]; then
            cp "${CONFIG_DIR}/fluxbox/menu" "${LB_DIR}/config/includes.chroot/etc/skel/.fluxbox/menu"
            cp "${CONFIG_DIR}/fluxbox/menu" "${LB_DIR}/config/includes.chroot/root/.fluxbox/menu"
            cp "${CONFIG_DIR}/fluxbox/menu" "${LB_DIR}/config/includes.chroot/home/live/.fluxbox/menu"
            echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] Fluxbox menu overlay added"
        fi

        # Install .profile with autostart into /etc/skel and /home/live
        cat << 'PROFILE_EOF' > "${LB_DIR}/config/includes.chroot/etc/skel/.profile"
# ~/.profile: executed by Bourne-compatible login shells
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    startx -- vt1 -keeptty
fi
PROFILE_EOF
        cp "${LB_DIR}/config/includes.chroot/etc/skel/.profile" "${LB_DIR}/config/includes.chroot/home/live/.profile"
        chmod 644 "${LB_DIR}/config/includes.chroot/etc/skel/.profile"
        chmod 644 "${LB_DIR}/config/includes.chroot/home/live/.profile"
        echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] .profile (auto-startx) overlay added to /etc/skel and /home/live"
    else
        # Minimal Profile: pure CLI login
        cat << 'PROFILE_EOF' > "${LB_DIR}/config/includes.chroot/etc/skel/.profile"
# ~/.profile: executed by Bourne-compatible login shells
# Minimal Edition: pure text console
PROFILE_EOF
        cp "${LB_DIR}/config/includes.chroot/etc/skel/.profile" "${LB_DIR}/config/includes.chroot/home/live/.profile"
        chmod 644 "${LB_DIR}/config/includes.chroot/etc/skel/.profile"
        chmod 644 "${LB_DIR}/config/includes.chroot/home/live/.profile"
        echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] .profile (CLI console) overlay added to /etc/skel and /home/live"
    fi

    # Install custom Xedra branding and ASCII issue banner
    local issue_title="${DISTRO_NAME} ${DISTRO_VERSION}"
    if [[ "${BUILD_PROFILE}" == "minimal" ]]; then
        issue_title="${DISTRO_NAME} ${DISTRO_VERSION} Minimal"
    fi

    cat << ISSUE_EOF > "${LB_DIR}/config/includes.chroot/etc/issue"
      __  __        _               _     _                  
      \ \/ /___  __| |_ __ __ _    | |   (_)_ __  _   ___  __
       \  // _ \/ _` | '__/ _` |   | |   | | '_ \| | | \ \/ /
       /  \  __/ (_| | | | (_| |   | |___| | | | | |_| |>  < 
      /_/\_\___|\__,_|_|  \__,_|   |_____|_|_| |_|\__,_/_/\_\

     ${issue_title} (${DEBIAN_ARCH}) — ${DISTRO_CODENAME^}
     Kernel \r on an \m (\l)

ISSUE_EOF

    cp "${LB_DIR}/config/includes.chroot/etc/issue" "${LB_DIR}/config/includes.chroot/etc/issue.net"

    # Install custom Xedra /etc/os-release
    cat << OS_EOF > "${LB_DIR}/config/includes.chroot/etc/os-release"
NAME="${DISTRO_NAME}"
PRETTY_NAME="${issue_title} (${DISTRO_CODENAME^})"
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
