# Xedra Linux

Xedra is a small, educational Debian-based Linux distribution engineered from first principles to understand how Linux distributions are constructed, configured, and packaged end-to-end.

## Core Environments

```text
Non-Debian Linux Host (Physical Workstation)
     │
     ├── libvirt / QEMU/KVM
     │     │
     │     ├── xedra-builder (Debian 13 Trixie Builder VM)
     │     │      ├── Development Desktop: Fluxbox, Firefox-ESR, xterm, Git
     │     │      ├── Toolchain: debootstrap, live-build, xorriso, squashfs-tools
     │     │      └── Local Repository: ~/XedraLinux
     │     │
     │     └── xedra-lab (Disposable Test VM)
     │            └── Boots & verifies Xedra 0.1 ISO
     │
     └── Source Repository: ~/XedraLinux
```

- **Development Host**: Non-Debian Linux host (`x86_64`) — Physical workstation; manages Git and hypervisor.
- **Authoritative Builder VM (`xedra-builder`)**: Debian 13 Trixie (`amd64`, UEFI, 4 GB RAM, 35 GB Disk) — Houses the complete build toolchain.
- **Target Xedra 0.1**: Minimal distribution (Debian 13 base, SysVinit PID 1, X11, Fluxbox, xterm).
- **Test VM (`xedra-lab`)**: Disposable libvirt VM (2 vCPU, 2 GB RAM, UEFI) — Boots and tests the output ISO.

---

## Core Design (Xedra 0.1 Milestone)

- **Base**: Debian Stable (`trixie`, `amd64`)
- **Init System**: SysVinit (as PID 1; `systemd-sysv` is explicitly excluded)
- **Display Server**: X11 (structured for future XLibre compatibility)
- **Window Manager**: Fluxbox
- **Terminal**: `xterm`
- **Package Management**: `apt` / `dpkg` (direct upstream Debian packages)
- **Bootloader & Firmware**: GRUB with UEFI support
- **Image Tooling**: Debian `live-build` & `debootstrap` inside `xedra-builder` VM
- **Testing Target**: `xedra-lab` on QEMU/KVM via `libvirt`

---

## Repository Structure

```text
~/XedraLinux/
├── LICENSE          # GPL-3.0-or-later
├── README.md        # Distro architecture and documentation
├── config/          # live-build configs, package lists, overlay roots
├── docs/            # Architecture, concepts, decisions, and stage logs
├── output/          # Build artifacts and target ISO images
└── scripts/         # Modular automation scripts
    ├── check-host.sh
    └── vm/          # Builder VM lifecycle & bootstrap scripts
```

---

## Quick Start

### 1. Validate Host Virtualization
```bash
./scripts/check-host.sh
```

### 2. Validate Builder VM Host Prerequisites
```bash
./scripts/vm/check-builder-vm-host.sh /path/to/debian-13-netinst.iso
```

### 3. Create the 'xedra-builder' VM
```bash
./scripts/vm/create-builder-vm.sh /path/to/debian-13-netinst.iso
```

### 4. Bootstrap Build Toolchain (Inside 'xedra-builder' VM)
```bash
sudo ~/XedraLinux/scripts/vm/bootstrap-builder.sh
```

---

## License

- Xedra scripts, build tooling, and code: [GPL-3.0-or-later](LICENSE)
- Documentation: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
- Upstream packages retain their respective upstream licenses.
