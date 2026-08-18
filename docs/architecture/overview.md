# Xedra Linux - Architectural Overview

## 1. System Topology

Xedra Linux development uses a strict three-tier architecture that separates the development workstation, the build toolchain, and the target testing environment:

```text
+-------------------------------------------------------------------------------+
|                            1. LINUX MINT HOST                                 |
|  - Physical workstation OS: Linux Mint 22.3 (x86_64)                          |
|  - Manages Git source tree at ~/XedraLinux                                    |
|  - Runs hypervisor services (libvirt, QEMU/KVM) & container runtime (Podman)   |
|  - Unmodified: Host bootloader, kernel, and package trees are NEVER altered   |
+-------------------------------------------------------------------------------+
                                         │
                 Mounted as Volume: ~/XedraLinux -> /workspace
                                         │
                                         ▼
+-------------------------------------------------------------------------------+
|             2. ISOLATED DEBIAN BUILD ENVIRONMENT (Podman Container)           |
|  Image: localhost/xedra-builder:trixie                                        |
|                                                                               |
|  - Base: Debian 13 "Trixie" (amd64)                                           |
|  - Role: Constructs rootfs and ISO images using pure Debian Stable utilities  |
|  - Tools: debootstrap, apt, dpkg, coreutils (live-build planned for later)    |
|  - Output: Writes generated rootfs/ISOs into /workspace/build & /output       |
+-------------------------------------------------------------------------------+
                                         │
                     Generated Artifact: output/xedra-0.1-amd64.iso
                                         │
                                         ▼
+-------------------------------------------------------------------------------+
|                     3. DISPOSABLE TEST TARGET (xedra-lab VM)                  |
|  Hypervisor: QEMU/KVM via libvirt                                             |
|                                                                               |
|  - Specifications: 2 vCPUs, 2 GB RAM, 8 GB Virtual Disk, UEFI Firmware        |
|  - Role: Boots the generated Xedra image in real virtualized hardware         |
|  - Verifies: SysVinit PID 1, X11 display, Fluxbox WM, and xterm               |
+-------------------------------------------------------------------------------+
```

---

## 2. Target Operating System Stack (Xedra 0.1 Milestone)

When assembled and booted in the `xedra-lab` VM, Xedra 0.1 consists of the following technical layers:

```text
+-------------------------------------------------------------------------------+
|                                USER INTERFACE                                 |
|  - Window Manager:  Fluxbox                                                   |
|  - Terminal:        xterm                                                     |
+-------------------------------------------------------------------------------+
                                        │
                                        ▼
+-------------------------------------------------------------------------------+
|                                DISPLAY SERVER                                 |
|  - Protocol & Server: X11 (structured for future XLibre compatibility)        |
+-------------------------------------------------------------------------------+
                                        │
                                        ▼
+-------------------------------------------------------------------------------+
|                              INIT SYSTEM (PID 1)                              |
|  - Daemon: SysVinit (/sbin/init from sysvinit-core)                           |
|  - Services: /etc/init.d/ scripts and /etc/rc*.d/ runlevel symlinks           |
|  - Rule: systemd-sysv is explicitly forbidden from running as PID 1           |
+-------------------------------------------------------------------------------+
                                        │
                                        ▼
+-------------------------------------------------------------------------------+
|                             USERLAND / BASE ROOTFS                            |
|  - Distribution: Debian 13 "Trixie" (amd64)                                   |
|  - Package Management: Native apt and dpkg from official Debian repositories  |
|  - Hierarchy: Standard Filesystem Hierarchy Standard (FHS)                    |
+-------------------------------------------------------------------------------+
                                        │
                                        ▼
+-------------------------------------------------------------------------------+
|                             KERNEL & HARDWARE INIT                            |
|  - Linux Kernel: Debian upstream linux-image-amd64                            |
|  - Initramfs: initramfs-tools                                                 |
|  - Bootloader: GRUB with UEFI boot support                                    |
+-------------------------------------------------------------------------------+
```

---

## 3. Directory Layout & Roles

| Directory | Purpose |
| :--- | :--- |
| `container/` | Containerfile definitions for the isolated Debian Trixie build container. |
| `config/` | Distribution configuration overlays, package lists, and SysVinit init scripts. |
| `scripts/` | Modular, single-responsibility automation scripts adhering to `set -euo pipefail`. |
| `docs/` | Comprehensive technical and educational documentation explaining the *how* and *why*. |
| `build/` | Intermediate build staging area (e.g. bootstrapped Debian root filesystem). |
| `output/` | Final distribution artifacts (e.g. bootable ISO images). |
