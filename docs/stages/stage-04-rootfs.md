# Stage 4 — First Debian Root Filesystem

## 1. Objective

Bootstrap and inspect a pure Debian 13 "Trixie" base root filesystem into `~/XedraLinux/build/rootfs` using `debootstrap` inside the dedicated `xedra-builder` virtual machine. The educational goal is to understand how Debian populates a root filesystem directory tree, initializes the DPKG database, and configures base packages natively.

---

## 2. Historical Context: Container Isolation vs. Native VM Execution

In **Stage 2 & Stage 3**, we observed that running `debootstrap` inside a rootless user namespace encountered restrictions when attempting `mknod` and nested `mount` operations.

Inside the **`xedra-builder` VM (Stage 3)**:
- We operate with full native Linux kernel capabilities.
- `debootstrap` executes natively without artificial user namespace workarounds or `--foreign` splits.
- Loop device mounting (`losetup`) and filesystem image generation operate with 100% native kernel support.

---

## 3. Execution Flow Inside `xedra-builder`

```text
Inside xedra-builder VM
   │
   └── cd ~/XedraLinux
           │
           ├── 1. Run: debootstrap --arch=amd64 trixie ~/XedraLinux/build/rootfs https://deb.debian.org/debian
           │       - Downloads base Debian 13 packages
           │       - Unpacks and configures them in dependency order
           │       - Initializes /var/lib/dpkg/status
           │
           ├── 2. Run: scripts/inspect-rootfs.sh
           │       - Analyzes: /etc/os-release, DPKG database, FHS hierarchy
           │
           └── 3. Run: scripts/enter-rootfs.sh
                   - Enters: chroot into ~/XedraLinux/build/rootfs
                   - Educational examination of base tools
```

---

## 4. Key Tools Explained

- **`debootstrap`**: Bootstraps the initial root filesystem from upstream `.deb` archives without needing an existing package manager in the target directory.
- **`dpkg`**: The underlying package manager that records installed state in `/var/lib/dpkg/status`.
- **`apt`**: The dependency solver that downloads packages from Debian repositories.
- **`chroot`**: Changes the apparent root directory (`/`) for a shell process.

---

## 5. Current State

- **Stage 4 Status**: Planned for execution inside `xedra-builder` once the VM is installed.
