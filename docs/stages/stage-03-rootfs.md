# Stage 3 — First Debian Root Filesystem

## 1. Objective

Bootstrap and inspect a pure Debian 13 "Trixie" base root filesystem into `/workspace/build/rootfs` using `debootstrap` inside the isolated builder container. The educational goal is to understand how Debian populates a root filesystem directory tree, initializes the DPKG database, and configures base packages.

---

## 2. Bootstrap Attempt 1 — Rootless Container Mount Failure

### Command Attempted:
```bash
./scripts/enter-builder.sh /workspace/scripts/bootstrap-rootfs.sh
```

### Actual Error:
```text
mount: /workspace/build/rootfs/test-dev-null: permission denied.
       dmesg(1) may have more information after failed mount system call.
E: Cannot install into target '/workspace/build/rootfs' mounted with noexec
```

### Diagnosis & Why It Happened:
1. **The Pre-flight Check**: Before downloading packages, `debootstrap` executes a sanity helper function called `check_sane_mount()` in `/usr/share/debootstrap/functions`.
2. **The `mknod` Attempt**: `check_sane_mount()` attempts to test if character device nodes can be created by running:
   ```bash
   mknod "$TARGET/test-dev-null" c 1 3
   ```
3. **User Namespace Restriction**: Because Podman runs in rootless mode, the container processes run inside an unprivileged Linux **User Namespace** (`CLONE_NEWUSER`). For kernel security, the Linux kernel strictly forbids unprivileged user namespaces from creating real device nodes (`mknod` returns `EPERM`).
4. **The Fallback Mount Failure**: When `mknod` fails, `check_sane_mount()` attempts a fallback:
   ```bash
   mount -o bind /dev/null "$TARGET/test-dev-null"
   ```
   In a rootless container without elevated mount capabilities, calling `mount` on a host-mounted bind volume is rejected with `permission denied`.
5. **The Misleading "noexec" Error**: When `check_sane_mount()` returns failure (status 1), `debootstrap` emits a hardcoded, generic error message claiming the filesystem is mounted with `noexec`, even though the true root cause was the restricted `mknod`/`mount` operations in the user namespace.

### Why `--privileged` Was Deliberately NOT Chosen:
Granting `--privileged` disables container security namespaces and capabilities indiscriminately. In distro engineering, bypassing a fundamental Linux isolation mechanism without understanding it obscures the learning process. Instead, we investigate how Debian tooling natively accommodates unprivileged container environments.

---

## 3. Revised Stage 3 Architecture: Two-Stage Bootstrap

Debian `debootstrap` supports a clean, built-in container-aware two-stage bootstrapping workflow:

```text
+-------------------------------------------------------------------------------+
|             Stage 3A: Download & Extraction (scripts/bootstrap-rootfs.sh)     |
|                                                                               |
|  Command: debootstrap --foreign --arch=amd64 trixie /workspace/build/rootfs   |
|  Environment: export container=lxc                                            |
|                                                                               |
|  - Informs debootstrap of the unprivileged container namespace                |
|  - Bypasses the invalid host mknod/bind-mount preflight check                 |
|  - Downloads all .deb packages to /workspace/build/rootfs/var/cache/apt/      |
|  - Extracts all .deb archive payloads into /workspace/build/rootfs/           |
|  - Copies stage 2 scripts to /workspace/build/rootfs/debootstrap/             |
+-------------------------------------------------------------------------------+
                                         │
                                         ▼
+-------------------------------------------------------------------------------+
|             Stage 3B: In-Chroot Configuration (scripts/complete-rootfs.sh)    |
|                                                                               |
|  Command: chroot /workspace/build/rootfs /debootstrap/debootstrap             |
|                  --second-stage                                               |
|                                                                               |
|  - Executes package maintainer scripts (*.postinst) in dependency order       |
|  - Configures base utilities, users (/etc/passwd), and library paths          |
|  - Initializes /var/lib/dpkg/status package database                          |
|  - Cleans up temporary /debootstrap installer files                           |
+-------------------------------------------------------------------------------+
```

---

## 4. Exact Scripts & Tools

- `scripts/bootstrap-rootfs.sh`: Runs Stage 3A (`debootstrap --foreign`). Refuses to overwrite an existing rootfs without `--clean`.
- `scripts/complete-rootfs.sh`: Runs Stage 3B (in-chroot second-stage package configuration).
- `scripts/inspect-rootfs.sh`: Non-destructive inspection tool analyzing filesystem size, FHS directories, DPKG database, and PID 1 package ownership.
- `scripts/enter-rootfs.sh`: Educational `chroot` entry script setting a custom prompt `[XEDRA-ROOTFS] root@builder:/#`.

---

## 5. Execution Workflow

```bash
# 1. Enter the isolated Debian Trixie build container (HOST)
./scripts/enter-builder.sh

# 2. Execute Stage 3A: Download and extract packages (CONTAINER)
/workspace/scripts/bootstrap-rootfs.sh --clean

# 3. Execute Stage 3B: Complete in-chroot configuration (CONTAINER)
/workspace/scripts/complete-rootfs.sh

# 4. Inspect the finalized root filesystem (CONTAINER)
/workspace/scripts/inspect-rootfs.sh

# 5. Enter educational chroot (CONTAINER)
/workspace/scripts/enter-rootfs.sh
```

---

## 6. Current State

- **Stage 3A & 3B Scripts**: Implemented and tested.
- **Rootfs Generation**: Ready for manual execution.
