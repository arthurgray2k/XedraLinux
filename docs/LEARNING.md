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

## Stage 2 - Isolated Build Environment Experiment (Podman)

- **Status**: `Completed Learning Exercise`
- **Focus**: Evaluating a rootless Debian 13 (Trixie) userland container using Podman to prevent host contamination.

### What Was Learned & Challenges Encountered:
1. **Container Userspace vs. Kernel**:
   - A container shares the Linux Mint host kernel (`7.0.0-28-generic`).
   - The container provides an isolated Debian *userspace* via Linux namespaces (mount, PID, network, user).
2. **The `mknod` & Mount Limitation in Rootless Containers**:
   - Standard `debootstrap` executes `check_sane_mount()`, which calls `mknod "$TARGET/test-dev-null" c 1 3`.
   - Inside an unprivileged Linux User Namespace (`CLONE_NEWUSER`), the kernel strictly blocks `mknod` for device nodes and nested loop mounts.
   - The fallback `mount -o bind /dev/null "$TARGET/test-dev-null"` failed with `permission denied`.
   - `debootstrap` emitted a misleading generic error message: `E: Cannot install into target mounted with noexec`.
3. **Why `--privileged` Was Rejected**:
   - Running containers with `--privileged` indiscriminately disables container security namespaces on the host.
   - The educational conclusion: Debian distro building requires real Linux kernel capabilities (`losetup`, `mksquashfs`, loop devices, real `mknod`), which belong in a dedicated virtual machine rather than a compromised host container.

---

## Stage 3 - Debian Builder VM Setup (`xedra-builder`)

- **Status**: `Implemented & Verified on Host`
- **Focus**: Setting up a dedicated Debian 13 (Trixie) VM as the authoritative build environment on libvirt/KVM.

### What Was Learned:
1. **Builder VM vs. Target Distro**:
   - The builder VM is developer infrastructure. It can comfortably have a desktop (`fluxbox`), web browser (`firefox-esr`), and full build tools without polluting the target Xedra distribution.
   - Xedra's target package list remains completely minimal and independent of the builder VM.
2. **UEFI Virtual Machine Automation**:
   - Using `virt-install` with `--boot uefi`, `--osinfo debian12`, `--graphics spice`, and `--disk pool=default,size=35,format=qcow2,bus=virtio` creates a fully reproducible, hardware-accelerated Debian development VM.
3. **Git as the Sole Source of Truth**:
   - Both the Linux Mint host and the `xedra-builder` VM synchronize via `~/XedraLinux` through Git (`https://github.com/arthurgray2k/XedraLinux`).

### Key Commands:
```bash
# Validate host for builder VM creation
./scripts/vm/check-builder-vm-host.sh /path/to/debian-13-netinst.iso

# Create the xedra-builder VM
./scripts/vm/create-builder-vm.sh /path/to/debian-13-netinst.iso

# Inside the VM: Bootstrap the build toolchain
sudo ~/XedraLinux/scripts/vm/bootstrap-builder.sh
```

---

## Stage 4 - First Debian Root Filesystem

- **Status**: `Planned (Inside xedra-builder VM)`
- **Focus**: Natively bootstrapping the pure Debian 13 base rootfs inside the dedicated builder VM.
