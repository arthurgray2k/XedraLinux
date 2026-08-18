#!/usr/bin/env bash
# ==============================================================================
# Xedra Linux - Stage 3: Bootstrap Debian Trixie Base Root Filesystem
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Purpose:
#   Bootstraps a pristine Debian 13 "Trixie" root filesystem into
#   /workspace/build/rootfs using debootstrap inside the isolated build container.
#
# Safety:
#   - Confirms execution environment is the isolated Debian builder.
#   - Validates paths strictly; will not overwrite existing rootfs without --force.
#   - Never executes against host system paths.
# ==============================================================================

set -euo pipefail

# ANSI color codes
readonly COLOR_RESET="\033[0m"
readonly COLOR_BOLD="\033[1m"
readonly COLOR_GREEN="\033[32m"
readonly COLOR_RED="\033[31m"
readonly COLOR_YELLOW="\033[33m"
readonly COLOR_CYAN="\033[36m"

# Configuration variables
readonly TARGET_RELEASE="trixie"
readonly TARGET_ARCH="amd64"
readonly DEBIAN_MIRROR="https://deb.debian.org/debian"

# Path definitions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
ROOTFS_DIR="${BUILD_DIR}/rootfs"

print_header() {
    echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Xedra Linux - Stage 3: Debian Rootfs Bootstrap       ${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================${COLOR_RESET}"
    echo "Target Distribution: Debian 13 (${TARGET_RELEASE})"
    echo "Target Architecture: ${TARGET_ARCH}"
    echo "Debian Mirror:       ${DEBIAN_MIRROR}"
    echo "Target Location:     ${ROOTFS_DIR}"
    echo ""
}

# 1. Environment Verification
verify_builder_environment() {
    # Check if running inside the Debian builder container
    if [[ ! -f /etc/os-release ]] || ! grep -qi 'ID=debian' /etc/os-release || [[ ! -d /workspace ]]; then
        echo -e "${COLOR_RED}Error: This script must be run INSIDE the isolated Debian builder container.${COLOR_RESET}" >&2
        echo ""
        echo "Please execute this script via:"
        echo "  ./scripts/enter-builder.sh /workspace/scripts/bootstrap-rootfs.sh"
        echo ""
        echo "Or enter the container interactively first:"
        echo "  ./scripts/enter-builder.sh"
        echo "  /workspace/scripts/bootstrap-rootfs.sh"
        exit 1
    fi

    # Verify debootstrap is available
    if ! command -v debootstrap >/dev/null 2>&1; then
        echo -e "${COLOR_RED}Error: 'debootstrap' command not found inside the builder environment.${COLOR_RESET}" >&2
        exit 1
    fi

    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] Execution environment: Debian builder container ($(dpkg --print-architecture))"
    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] debootstrap utility: $(debootstrap --version 2>/dev/null || echo 'installed')"
}

# 2. Target Path & Overwrite Safeguards
prepare_directories() {
    local force_flag="${1:-}"

    # Ensure build directory exists
    mkdir -p "${BUILD_DIR}"

    # Check if rootfs already exists
    if [[ -d "${ROOTFS_DIR}" && -n "$(ls -A "${ROOTFS_DIR}" 2>/dev/null || true)" ]]; then
        if [[ "${force_flag}" == "--force" || "${force_flag}" == "-f" ]]; then
            echo -e "  [ ${COLOR_YELLOW}WARN${COLOR_RESET} ] Existing rootfs detected at '${ROOTFS_DIR}'. --force supplied: cleaning directory..."
            # Strict safety check before removing
            if [[ "${ROOTFS_DIR}" == *"/build/rootfs" && "${ROOTFS_DIR}" != "/" && "${ROOTFS_DIR}" != "/root" ]]; then
                rm -rf "${ROOTFS_DIR}"
                mkdir -p "${ROOTFS_DIR}"
            else
                echo -e "${COLOR_RED}Error: Refusing to delete safety-violating path: ${ROOTFS_DIR}${COLOR_RESET}" >&2
                exit 1
            fi
        else
            echo -e "${COLOR_RED}Error: Target rootfs directory '${ROOTFS_DIR}' already exists and is not empty.${COLOR_RESET}" >&2
            echo "To perform a clean rebuild, pass --force:"
            echo "  /workspace/scripts/bootstrap-rootfs.sh --force"
            exit 1
        fi
    else
        mkdir -p "${ROOTFS_DIR}"
    fi

    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] Target directory initialized: ${ROOTFS_DIR}"
    echo ""
}

# 3. Main Bootstrap Execution
run_bootstrap() {
    echo -e "${COLOR_BOLD}--- Executing Debian Bootstrap ---${COLOR_RESET}"
    echo "Running debootstrap with explicit parameters:"
    echo ""
    echo -e "  ${COLOR_CYAN}debootstrap \\${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}    --arch=${TARGET_ARCH} \\${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}    ${TARGET_RELEASE} \\${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}    ${ROOTFS_DIR} \\${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}    ${DEBIAN_MIRROR}${COLOR_RESET}"
    echo ""

    # Execute debootstrap
    debootstrap \
        --arch="${TARGET_ARCH}" \
        "${TARGET_RELEASE}" \
        "${ROOTFS_DIR}" \
        "${DEBIAN_MIRROR}"

    echo ""
    echo -e "${COLOR_BOLD}${COLOR_GREEN}======================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}  Debian Trixie Root Filesystem Successfully Created!  ${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}======================================================${COLOR_RESET}"
    echo ""
    echo "Next step: Inspect the created filesystem using:"
    echo "  /workspace/scripts/inspect-rootfs.sh"
    echo ""
}

main() {
    print_header
    verify_builder_environment
    prepare_directories "${1:-}"
    run_bootstrap
}

main "$@"
