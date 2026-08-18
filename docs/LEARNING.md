# Xedra Linux - Chronological Learning Log

This document tracks technical insights, practical lessons, encountered challenges, and solutions discovered during each stage of building Xedra Linux.

---

## Stage 1 - Host Environment & Virtualization Validation

- **Status**: `Verified`
- **Focus**: Validating the Linux Mint host machine for hypervisor readiness without modifying the host OS.

### What Was Learned:
1. **Host Immutability**: The physical machine running Linux Mint is strictly the development workstation. Debian is never installed directly on host metal to protect the working environment.
2. **KVM Virtualization Pipeline**:
   - Hardware CPU extensions (`VMX` for Intel, `SVM` for AMD) allow near-native virtualization speeds via hardware acceleration.
   - The Linux kernel module `kvm_intel` exposes the character device node `/dev/kvm`.
   - QEMU (`qemu-system-x86_64`) acts as the userland machine emulator and connects to `/dev/kvm` via ioctl calls.
   - `libvirt` provides a unified daemon API (`libvirtd`) and management CLI (`virsh`) used by `virt-manager`.
3. **Safety Automation**: Using `set -euo pipefail` in inspection scripts ensures that command failures and unset variables halt execution immediately before any side effects occur.

### Key Commands:
```bash
# Verify KVM hardware support
grep -E '(vmx|svm)' /proc/cpuinfo

# Test libvirt daemon connectivity
virsh --connect qemu:///system list --all

# Run host check
./scripts/check-host.sh
```

### Problems & Solutions:
- *Challenge*: Detecting loaded KVM kernel modules across differing `lsmod` string formats.
- *Solution*: Replaced regex pattern matching with robust column-specific `awk` parsing (`awk '$1 ~ /^(kvm_intel|kvm_amd)$/ {print $1}'`).

---

## Stage 2 - Isolated Debian Trixie Build Environment

- **Status**: `Verified`
- **Focus**: Setting up an isolated Debian 13 (Trixie) userland container using Podman to prevent host contamination.

### What Was Learned:
1. **Container Userspace vs. Kernel**:
   - A container does *not* boot a separate kernel; it shares the Linux Mint host kernel (`7.0.0-28-generic`).
   - The container provides an isolated Debian *userspace* (glibc, APT, DPKG, shared libraries) via Linux namespaces (mount, PID, network, user).
   - This ensures build tools resolve packages against pure Debian 13 repositories rather than Linux Mint/Ubuntu package trees.
2. **Podman Advantages**:
   - Podman runs daemonless and rootless, avoiding background root daemons.
   - Mounting `~/XedraLinux` into `/workspace` allows artifacts written inside the container to persist directly on the host.
3. **Minimalism in Build Environments**:
   - Installing only `bash`, `ca-certificates`, `git`, `coreutils`, `util-linux`, `procps`, and `debootstrap` keeps the build container lightweight (~118 MB).

### Key Commands:
```bash
# Build Debian Trixie container image
./scripts/build-builder-image.sh

# Validate the container toolchain and mount
./scripts/check-builder.sh

# Enter interactive build shell
./scripts/enter-builder.sh
```

---

## Stage 3 - First Debian Root Filesystem

- **Status**: `Implemented (Scripts Ready for Execution)`
- **Focus**: Bootstrapping a pure Debian Trixie base directory tree using `debootstrap` and inspecting its internal structure.

### What Was Learned:
1. **What `debootstrap` Actually Does**:
   - It downloads `.deb` archives directly from `https://deb.debian.org/debian`.
   - It unpacks the binary payloads into `/workspace/build/rootfs` using `ar` and `tar`.
   - It initializes the DPKG package database at `/var/lib/dpkg/status` and runs package `postinst` scripts to set up basic configurations.
2. **Rootfs vs. Bootable OS**:
   - A root filesystem is a directory structure containing binaries and libraries, but it cannot boot by itself.
   - It requires a bootloader (GRUB), a Linux kernel (`vmlinuz`), an initial ramdisk (`initrd.img`), and a PID 1 init system (SysVinit in Xedra) to become an operating system.
3. **The Role of `chroot`**:
   - `chroot` changes the visible root directory (`/`) for a process tree.
   - It does not boot a kernel or start an init system; it simply allows running binaries against the target rootfs libraries.

### Key Commands:
```bash
# Bootstrap rootfs inside container
/workspace/scripts/bootstrap-rootfs.sh

# Inspect rootfs size, DPKG database, and structure
/workspace/scripts/inspect-rootfs.sh

# Educational chroot entry
/workspace/scripts/enter-rootfs.sh
```
