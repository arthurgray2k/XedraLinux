# Stage 3 — First Debian Root Filesystem

## 1. Objective

Bootstrap and inspect a pure Debian 13 "Trixie" base root filesystem into `/workspace/build/rootfs` using `debootstrap` inside the isolated builder container. The educational goal is to understand how Debian populates a root filesystem directory tree, initializes the DPKG database, and configures base packages.

---

## 2. What Was Built

- `scripts/bootstrap-rootfs.sh`: Runs `debootstrap` with explicit arguments to construct `/workspace/build/rootfs`.
- `scripts/inspect-rootfs.sh`: Non-destructive inspection tool analyzing filesystem size, FHS directories, DPKG database (`/var/lib/dpkg/status`), and PID 1 package ownership.
- `scripts/enter-rootfs.sh`: Educational `chroot` entry script setting a custom prompt `[XEDRA-ROOTFS] root@builder:/#` and providing automated pseudo-filesystem unmounting traps.
- `.gitignore`: Configured to prevent staging large rootfs build trees or ISO artifacts into Git.

---

## 3. Host & Container Execution Flow

```text
Mint Host (Terminal)
   │
   └── Run: ./scripts/enter-builder.sh
           │
           ▼
   Container Environment (/workspace)
           │
           ├── 1. Run: /workspace/scripts/bootstrap-rootfs.sh
           │       - Invokes: debootstrap --arch=amd64 trixie /workspace/build/rootfs https://deb.debian.org/debian
           │       - Result: Creates ~350-450 MB pristine Debian rootfs
           │
           ├── 2. Run: /workspace/scripts/inspect-rootfs.sh
           │       - Analyzes: /etc/os-release, /var/lib/dpkg/status, directory hierarchy
           │
           └── 3. Run: /workspace/scripts/enter-rootfs.sh
                   - Enters: chroot into /workspace/build/rootfs
                   - Educational examination of base tools
```

---

## 4. Key Tools Explained

- **`debootstrap`**: Bootstraps the initial root filesystem from upstream `.deb` archives without needing an existing package manager in the target directory.
- **`dpkg`**: The underlying package manager that records installed state in `/var/lib/dpkg/status`.
- **`apt`**: The dependency solver that downloads packages from Debian repositories.
- **`chroot`**: Changes the apparent root directory (`/`) for a shell process.

---

## 5. Exact Commands to Execute

```bash
# 1. Enter the isolated Debian Trixie build container (HOST)
./scripts/enter-builder.sh

# 2. Bootstrap Debian Trixie root filesystem (CONTAINER)
/workspace/scripts/bootstrap-rootfs.sh

# 3. Inspect the bootstrapped root filesystem (CONTAINER)
/workspace/scripts/inspect-rootfs.sh

# 4. Enter educational chroot (CONTAINER)
/workspace/scripts/enter-rootfs.sh
```

---

## 6. Important Files Created

- `/workspace/build/rootfs/etc/os-release`: Identifies the system as Debian 13 (Trixie).
- `/workspace/build/rootfs/var/lib/dpkg/status`: Plain-text package registry listing every installed package.
- `/workspace/build/rootfs/var/lib/dpkg/info/*.list`: File lists recording ownership for every package.
- `/workspace/build/rootfs/bin/sh` $\rightarrow$ `/bin/dash`: Default POSIX system shell in Debian.

---

## 7. Current State

- **Scripts Prepared**: `bootstrap-rootfs.sh`, `inspect-rootfs.sh`, and `enter-rootfs.sh` are implemented and validated.
- **Execution**: Pending manual user execution in container.

---

## 8. What Stage 3 Deliberately Does NOT Do

- ❌ Does NOT install a Linux kernel or initramfs (`linux-image-amd64`).
- ❌ Does NOT configure SysVinit as PID 1 yet (planned for Stage 4).
- ❌ Does NOT install X11, Fluxbox, or xterm.
- ❌ Does NOT configure GRUB or UEFI bootloaders.
- ❌ Does NOT build an ISO image or live filesystem squashfs.
- ❌ Does NOT touch the `xedra-lab` VM.
