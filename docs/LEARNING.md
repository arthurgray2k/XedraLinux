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

- **Status**: `In Progress (Two-Stage Architecture Implemented)`
- **Focus**: Bootstrapping a pure Debian Trixie base directory tree using `debootstrap` and inspecting its internal structure.

### Practical Lessons & Problems Encountered:

#### Problem 1: Rootless Container `test-dev-null` Mount Failure
- **Symptom**: `mount: /workspace/build/rootfs/test-dev-null: permission denied.` followed by `E: Cannot install into target '/workspace/build/rootfs' mounted with noexec`.
- **Root Cause Analysis**:
  1. `debootstrap` executes a pre-flight helper `check_sane_mount()` in `/usr/share/debootstrap/functions`.
  2. It attempts `mknod "$TARGET/test-dev-null" c 1 3`.
  3. Inside a rootless Podman container (unprivileged user namespace `CLONE_NEWUSER`), the Linux kernel forbids creating real device nodes (`mknod` returns `EPERM`).
  4. When `mknod` fails, `check_sane_mount()` falls back to `mount -o bind /dev/null "$TARGET/test-dev-null"`.
  5. In an unprivileged container without mount privileges on host bind volumes, `mount` fails with `permission denied`.
  6. `debootstrap` emits a misleading error claiming the mount has `noexec`.
- **Why `--privileged` Was Rejected**:
  Running `--privileged` disables container security namespaces entirely. The educational objective is to learn why standard Debian tools behave this way and use the native solution.
- **Solution (Two-Stage Bootstrap)**:
  1. `export container=lxc` signals to `debootstrap` that it is running in an unprivileged container, skipping the invalid `test-dev-null` `mknod`/`mount` check.
  2. `debootstrap --foreign` downloads and extracts all `.deb` archives (Stage 3A).
  3. `chroot /workspace/build/rootfs /debootstrap/debootstrap --second-stage` configures all packages in dependency order and initializes `/var/lib/dpkg/status` (Stage 3B).

### Key Commands:
```bash
# Stage 3A: Download & Extract base packages
/workspace/scripts/bootstrap-rootfs.sh --clean

# Stage 3B: Complete package configuration
/workspace/scripts/complete-rootfs.sh

# Inspect finalized rootfs
/workspace/scripts/inspect-rootfs.sh

# Educational chroot entry
/workspace/scripts/enter-rootfs.sh
```
