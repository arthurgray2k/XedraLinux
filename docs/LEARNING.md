# Xedra Linux - Chronological Learning Log

This document tracks technical insights, practical lessons, encountered challenges, and solutions discovered during each stage of building Xedra Linux.

---

## Stage 1 - Host Environment & Virtualization Validation

- **Status**: `Verified`
- **Focus**: Validating the non-Debian Linux host machine for hypervisor readiness without modifying the host OS.

### What Was Learned:
1. **Host Immutability**: The physical machine is strictly the development workstation. Debian is never installed directly on host metal to protect the working environment.
2. **KVM Virtualization Pipeline**:
   - Hardware CPU extensions (`VMX` for Intel, `SVM` for AMD) allow near-native virtualization speeds via hardware acceleration.
   - The Linux kernel module `kvm_intel` exposes the character device node `/dev/kvm`.
   - QEMU (`qemu-system-x86_64`) acts as the userland machine emulator and connects to `/dev/kvm` via ioctl calls.
   - `libvirt` provides a unified daemon API (`libvirtd`) and management CLI (`virsh`) used by `virt-manager`.
3. **Safety Automation**: Using `set -euo pipefail` in inspection scripts ensures that command failures and unset variables halt execution immediately before any side effects occur.

---

## Stage 2 - Isolated Build Environment Experiment (Podman)

- **Status**: `Completed Learning Exercise`
- **Focus**: Evaluating a rootless Debian 13 (Trixie) userland container using Podman to prevent host contamination.

### What Was Learned & Challenges Encountered:
1. **Container Userspace vs. Kernel**:
   - A container shares the host kernel.
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

- **Status**: `Verified & Complete`
- **Focus**: Setting up a dedicated Debian 13 (Trixie) VM as the authoritative build environment on libvirt/KVM.

### What Was Learned:
1. **Builder VM vs. Target Distro**:
   - The builder VM is developer infrastructure. It can comfortably have a desktop (`fluxbox`), web browser (`firefox-esr`), and full build tools without polluting the target Xedra distribution.
   - Xedra's target package list remains completely minimal and independent of the builder VM.
2. **UEFI Virtual Machine Automation**:
   - Using `virt-install` with `--boot uefi`, `--osinfo debian12`, `--graphics spice`, and `--disk pool=default,size=35,format=qcow2,bus=virtio` creates a fully reproducible, hardware-accelerated Debian development VM.
3. **Git as the Sole Source of Truth**:
   - Both the host system and the `xedra-builder` VM synchronize via `~/XedraLinux` through Git (`https://github.com/arthurgray2k/XedraLinux`).

---

## Stage 4 - First Debian Root Filesystem

- **Status**: `Verified & Complete`
- **Focus**: Natively bootstrapping the pure Debian 13 base rootfs inside the dedicated builder VM.

### What Was Learned:
1. **Hermetic Rootfs Generation**:
   - Bootstrapping directly from pristine upstream repositories ensures zero leakage of local build-machine state, credentials, or caches.
2. **Merged-/usr Layout**:
   - In modern Debian 13 (Trixie), `/bin`, `/sbin`, and `/lib` are symbolic links pointing into `/usr/bin`, `/usr/sbin`, and `/usr/lib`.
3. **Upstream Init Baseline**:
   - Default debootstrap installs 146 base packages with `systemd-sysv` providing `/sbin/init`.

---

## Stage 5 - Xedra Package Selection & SysVinit Transition

- **Status**: `Verified & Complete`
- **Focus**: Replacing `systemd-sysv` with SysVinit (`sysvinit-core`) as PID 1 inside the target rootfs.

### What Was Learned:
1. **APT Atomic Package Replacement (`systemd-sysv-`)**:
   - Appending a minus sign (`pkg-`) instructs APT to remove the conflicting package in the exact same transaction as installing its replacement.
2. **PID 1 Transition**:
   - `/sbin/init` was transitioned from a symlink to systemd into a direct SysVinit executable binary (~53 KB).
3. **Inittab Runlevels**:
   - SysVinit uses `/etc/inittab` to orchestrate system runlevels (default runlevel 2 for multi-user mode, `rcS` for boot scripts, and gettys on `tty1`–`tty6`).

---

## Stage 6 - Minimal Graphical Desktop (X11 + Fluxbox + xterm)

- **Status**: `Verified & Complete`
- **Focus**: Installing and configuring the minimal X11 display server, Fluxbox window manager, and xterm terminal.

### What Was Learned:
1. **X11 Graphics Stack Footprint**:
   - While Fluxbox is only ~3 MB, the hardware graphics acceleration stack (Mesa, DRI drivers, and Xorg core) accounts for ~300 MB uncompressed, which compresses down to ~80 MB with `mksquashfs`.
2. **Update-Alternatives Integration**:
   - Debian automatically registered `startfluxbox` as the system's default `x-window-manager`.
3. **Skeleton Configuration**:
   - Placing `.xinitrc` and `.fluxbox/menu` in `/etc/skel/` ensures every new user inherits the minimal Xedra desktop environment.
