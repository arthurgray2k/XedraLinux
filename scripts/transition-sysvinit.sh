#!/usr/bin/env bash
# ==============================================================================
# Xedra Linux - Stage 5: SysVinit PID 1 Transition Script
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Purpose:
#   Configures the target Debian 13 rootfs to use SysVinit ('sysvinit-core') as
#   PID 1. Purges 'systemd-sysv', installs standard SysVinit initscripts, and
#   installs /etc/inittab, fulfilling Xedra ADR #2.
#
# Safety:
#   - Runs inside the 'xedra-builder' VM against ~/XedraLinux/build/rootfs.
#   - Uses robust trap cleanup to ensure pseudo-filesystems are always unmounted.
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
ROOTFS_DIR="${1:-${REPO_ROOT}/build/rootfs}"
CONFIG_DIR="${REPO_ROOT}/config"

print_header() {
    echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Xedra Linux - SysVinit PID 1 Transition             ${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================${COLOR_RESET}"
    echo "Target Rootfs: ${ROOTFS_DIR}"
    echo "Init Target:   SysVinit (sysvinit-core) as PID 1"
    echo ""
}

verify_environment() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo -e "${COLOR_RED}Error: This script must be run as root (e.g. sudo $0)${COLOR_RESET}" >&2
        exit 1
    fi

    if [[ ! -d "${ROOTFS_DIR}" ]] || [[ ! -f "${ROOTFS_DIR}/etc/os-release" ]]; then
        echo -e "${COLOR_RED}Error: Bootstrapped rootfs not found at '${ROOTFS_DIR}'.${COLOR_RESET}" >&2
        echo "Please complete Step 04 first."
        exit 1
    fi
}

cleanup_mounts() {
    local target="$1"
    echo "Cleaning up mount bindings..."
    for mnt in "${target}/dev/pts" "${target}/dev" "${target}/sys" "${target}/proc"; do
        if mountpoint -q "${mnt}" 2>/dev/null; then
            umount "${mnt}" 2>/dev/null || true
        fi
    done
}

mount_pseudo_filesystems() {
    echo -e "${COLOR_BOLD}--- 1. Binding Pseudo-Filesystems into Rootfs ---${COLOR_RESET}"
    mkdir -p "${ROOTFS_DIR}/proc" "${ROOTFS_DIR}/sys" "${ROOTFS_DIR}/dev" "${ROOTFS_DIR}/dev/pts"
    
    mount -t proc proc "${ROOTFS_DIR}/proc"
    mount -t sysfs sysfs "${ROOTFS_DIR}/sys"
    mount --bind /dev "${ROOTFS_DIR}/dev"
    mount -t devpts devpts "${ROOTFS_DIR}/dev/pts"

    trap 'cleanup_mounts "${ROOTFS_DIR}"' EXIT INT TERM
    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] /proc, /sys, /dev, /dev/pts mounted"
    echo ""
}

configure_apt_and_install_sysvinit() {
    echo -e "${COLOR_BOLD}--- 2. Configuring APT Sources & Installing SysVinit ---${COLOR_RESET}"
    
    # Configure official Debian Trixie repository sources inside rootfs
    cat << 'EOF' > "${ROOTFS_DIR}/etc/apt/sources.list"
deb https://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb https://deb.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
deb https://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
EOF

    # Prevent interactive debconf questions
    export DEBIAN_FRONTEND=noninteractive

    # Update package lists and install SysVinit packages
    echo "Updating package lists inside rootfs..."
    chroot "${ROOTFS_DIR}" apt-get update

    echo "Installing sysvinit-core and related utilities..."
    chroot "${ROOTFS_DIR}" apt-get install -y --no-install-recommends \
        sysvinit-core \
        initscripts \
        insserv

    # Install orphan-sysvinit-scripts if available in Trixie
    chroot "${ROOTFS_DIR}" apt-get install -y --no-install-recommends orphan-sysvinit-scripts 2>/dev/null || true

    # Explicitly remove systemd-sysv package (the provider of systemd /sbin/init)
    echo "Removing systemd-sysv..."
    chroot "${ROOTFS_DIR}" apt-get purge -y systemd-sysv || true

    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] SysVinit packages installed and systemd-sysv purged"
    echo ""
}

configure_xedra_system_files() {
    echo -e "${COLOR_BOLD}--- 3. Installing Xedra inittab, Hostname, and Hosts ---${COLOR_RESET}"
    
    # Install /etc/inittab
    if [[ -f "${CONFIG_DIR}/inittab" ]]; then
        cp "${CONFIG_DIR}/inittab" "${ROOTFS_DIR}/etc/inittab"
        chmod 644 "${ROOTFS_DIR}/etc/inittab"
        echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] /etc/inittab installed"
    fi

    # Set hostname
    echo "xedra" > "${ROOTFS_DIR}/etc/hostname"
    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] /etc/hostname configured as 'xedra'"

    # Configure /etc/hosts
    cat << 'EOF' > "${ROOTFS_DIR}/etc/hosts"
127.0.0.1   localhost
127.0.1.1   xedra

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] /etc/hosts configured"
    echo ""
}

verify_transition() {
    echo -e "${COLOR_BOLD}--- 4. Verifying PID 1 Init Binary & Symlinks ---${COLOR_RESET}"
    
    if [[ -e "${ROOTFS_DIR}/sbin/init" || -L "${ROOTFS_DIR}/sbin/init" ]]; then
        echo -e "  [ ${COLOR_GREEN}PASS${COLOR_RESET} ] /sbin/init details: $(ls -l "${ROOTFS_DIR}/sbin/init")"
    else
        echo -e "  [ ${COLOR_RED}FAIL${COLOR_RESET} ] /sbin/init is missing!"
    fi

    if [[ -f "${ROOTFS_DIR}/etc/inittab" ]]; then
        echo -e "  [ ${COLOR_GREEN}PASS${COLOR_RESET} ] /etc/inittab exists (Default runlevel: $(grep '^id:' "${ROOTFS_DIR}/etc/inittab" | awk -F: '{print $2}'))"
    else
        echo -e "  [ ${COLOR_RED}FAIL${COLOR_RESET} ] /etc/inittab is missing!"
    fi

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_GREEN}======================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}  SysVinit Transition Successfully Completed!          ${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}======================================================${COLOR_RESET}"
    echo ""
}

main() {
    print_header
    verify_environment
    mount_pseudo_filesystems
    configure_apt_and_install_sysvinit
    configure_xedra_system_files
    verify_transition
}

main "$@"
