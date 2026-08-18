# Xedra Linux

Xedra is a small, educational Debian-based Linux distribution engineered from first principles to understand how Linux distributions are constructed, configured, and packaged end-to-end.

## Core Design (0.1 Milestone)

- **Base**: Debian Stable (`trixie`, `amd64`)
- **Init System**: SysVinit (as PID 1; `systemd-sysv` is explicitly excluded)
- **Display Server**: X11 (structured for future XLibre compatibility)
- **Window Manager**: Fluxbox
- **Terminal**: `xterm`
- **Package Management**: `apt` / `dpkg` (direct upstream Debian packages)
- **Bootloader & Firmware**: GRUB with UEFI support
- **Image Tooling**: Debian `live-build` / `debootstrap` within an isolated build environment
- **Target Test VM**: `xedra-lab` on QEMU/KVM via `libvirt`

## Repository Structure

```text
.
├── LICENSE          # GPL-3.0-or-later
├── README.md        # Distro architecture and documentation
├── container/       # Isolated Debian build container definition
│   └── Containerfile
├── config/          # Distro configurations (live-build configs, package lists, overlay roots)
├── output/          # Build artifacts and target ISO images
└── scripts/         # Safe, modular, single-responsibility automation scripts
    ├── check-host.sh
    ├── check-container-runtime.sh
    ├── build-builder-image.sh
    ├── enter-builder.sh
    └── check-builder.sh
```

## Quick Start

### 1. Validate Development Host

Before building any components or testing in the virtual machine, verify your host tooling:

```bash
./scripts/check-host.sh
```

### 2. Validate Container Runtime (Podman)

```bash
./scripts/check-container-runtime.sh
```

### 3. Build the Isolated Debian Trixie Container

```bash
./scripts/build-builder-image.sh
```

### 4. Validate Isolated Build Environment

```bash
./scripts/check-builder.sh
```

## License

- Xedra scripts, build tooling, and code: [GPL-3.0-or-later](LICENSE)
- Documentation: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
- Upstream packages (Debian, Linux kernel, Fluxbox, X11, etc.) retain their respective upstream licenses.
