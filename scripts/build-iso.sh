#!/usr/bin/env bash
# ==============================================================================
# Xedra Linux - Stage 8: Build Bootable Xedra 0.1 Live ISO
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Purpose:
#   Compiles the complete bootable Xedra 0.1 ISO image using Debian live-build
#   inside the 'xedra-builder' VM, and outputs the result to output/xedra-0.1-amd64.iso.
#
# Output Artifacts:
#   - output/xedra-0.1-amd64.iso
#   - output/xedra-0.1-amd64.iso.sha256
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
OUTPUT_DIR="${REPO_ROOT}/output"
ISO_NAME="xedra-0.1-amd64.iso"
TARGET_ISO="${OUTPUT_DIR}/${ISO_NAME}"

print_header() {
    echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}  Xedra Linux - Stage 8: Compile Live ISO Image        ${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_CYAN}======================================================${COLOR_RESET}"
    echo "Workspace:      ${LB_DIR}"
    echo "Output Target:  ${TARGET_ISO}"
    echo ""
}

verify_environment() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo -e "${COLOR_RED}Error: This script must be run as root (e.g. sudo $0)${COLOR_RESET}" >&2
        exit 1
    fi

    if ! command -v lb >/dev/null 2>&1; then
        echo -e "${COLOR_RED}Error: 'live-build' (lb) is not installed.${COLOR_RESET}" >&2
        exit 1
    fi

    mkdir -p "${OUTPUT_DIR}"
}

setup_and_configure() {
    echo -e "${COLOR_BOLD}--- 1. Generating Fresh live-build Configuration ---${COLOR_RESET}"
    # Invoke configure-live-build.sh to cleanly wipe old chroot, run lb config, and stage overlays
    "${SCRIPT_DIR}/configure-live-build.sh"
    echo ""
}

compile_iso() {
    echo -e "${COLOR_BOLD}--- 2. Executing 'lb build' ---${COLOR_RESET}"
    echo "Compiling live rootfs, kernel, squashfs, bootloaders, and hybrid ISO..."
    echo "This may take 3–7 minutes depending on network and CPU speed."
    echo ""

    cd "${LB_DIR}"
    lb build

    echo ""
    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] 'lb build' completed successfully"
    echo ""
}

package_artifacts() {
    echo -e "${COLOR_BOLD}--- 3. Packaging Output Artifacts ---${COLOR_RESET}"
    mkdir -p "${OUTPUT_DIR}"

    # Locate generated ISO
    local generated_iso=""
    if [[ -f "${LB_DIR}/live-image-amd64.hybrid.iso" ]]; then
        generated_iso="${LB_DIR}/live-image-amd64.hybrid.iso"
    elif [[ -f "${LB_DIR}/live-image-amd64.iso" ]]; then
        generated_iso="${LB_DIR}/live-image-amd64.iso"
    else
        generated_iso="$(find "${LB_DIR}" -maxdepth 1 -name "*.iso" | head -n 1)"
    fi

    if [[ -z "${generated_iso}" || ! -f "${generated_iso}" ]]; then
        echo -e "${COLOR_RED}Error: Generated ISO file not found in ${LB_DIR}.${COLOR_RESET}" >&2
        exit 1
    fi

    # Move ISO to output directory
    echo "Copying ${generated_iso} -> ${TARGET_ISO}..."
    cp "${generated_iso}" "${TARGET_ISO}"
    chmod 644 "${TARGET_ISO}"

    # Calculate SHA256 checksum
    echo "Generating SHA256 checksum..."
    cd "${OUTPUT_DIR}"
    sha256sum "${ISO_NAME}" > "${TARGET_ISO}.sha256"

    echo -e "  [ ${COLOR_GREEN}OK${COLOR_RESET} ] Artifacts created in ${OUTPUT_DIR}/"
    echo ""
}

verify_iso() {
    echo -e "${COLOR_BOLD}--- 4. Verifying Final ISO Artifact ---${COLOR_RESET}"
    
    local size_human
    size_human="$(du -sh "${TARGET_ISO}" | awk '{print $1}')"
    echo -e "  [ ${COLOR_GREEN}INFO${COLOR_RESET} ] ISO Filename:    ${COLOR_BOLD}${TARGET_ISO}${COLOR_RESET}"
    echo -e "  [ ${COLOR_GREEN}INFO${COLOR_RESET} ] ISO File Size:   ${COLOR_BOLD}${size_human}${COLOR_RESET}"
    echo -e "  [ ${COLOR_GREEN}INFO${COLOR_RESET} ] SHA256 Checksum: $(cat "${TARGET_ISO}.sha256")"
    echo ""

    echo -e "${COLOR_BOLD}${COLOR_GREEN}======================================================${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}  Xedra 0.1 ISO Successfully Built!                   ${COLOR_RESET}"
    echo -e "${COLOR_BOLD}${COLOR_GREEN}======================================================${COLOR_RESET}"
    echo ""
    echo "Next Stage (Stage 9): Test the bootable ISO in the 'xedra-lab' VM!"
    echo ""
}

main() {
    print_header
    verify_environment
    setup_and_configure
    compile_iso
    package_artifacts
    verify_iso
}

main "$@"
