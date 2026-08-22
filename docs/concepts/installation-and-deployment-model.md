# Xedra Linux - Installation & Deployment Model

## 1. Executive Summary

Xedra Linux uses a progressive deployment model:
- **Milestone 0.1 (Current)**: Packaged and distributed as a **Live Hybrid ISO** running ephemerally in RAM.
- **Milestone 0.2+ (Future)**: Support for permanent disk installations on bare-metal and virtual machine storage drives via manual UNIX installation and automated installers (Calamares / CLI installer).

This document explains how the Live RAM overlay operates, how manual disk installation works from the live session, and the roadmap for automated system installers.

---

## 2. Milestone 0.1: Live Hybrid ISO Architecture

In Xedra 0.1, the operating system is delivered as an ephemeral live environment:

```text
+-------------------------------------------------------------------------------+
|                            XEDRA 0.1 LIVE ENVIRONMENT                         |
|                                                                               |
|  [ Virtual/Physical RAM ]                                                     |
|         │                                                                     |
|         ├── OverlayFS Upper Layer: tmpfs (Read-Write RAM Disk)                |
|         │    ├── User modifications, temporary files, downloaded packages     |
|         │    └── Discarded on power-off / reboot                              |
|         │                                                                     |
|         └── OverlayFS Lower Layer: /live/filesystem.squashfs (Read-Only)      |
|              └── Compressed Debian 13 base rootfs, SysVinit, Xorg, Fluxbox    |
+-------------------------------------------------------------------------------+
```

### Why Live ISO First for Milestone 0.1?
1. **Safety**: Does not modify or repartition physical or virtual host hard drives during testing.
2. **Speed & Reproducibility**: Allows rapid testing cycles in `xedra-lab` without disk re-imaging.
3. **Hardware Independence**: Boots uniformly across diverse UEFI motherboards and virtual machines without hardcoded disk UUID dependencies.

---

## 3. Direct Disk Installation (The UNIX / Arch Way)

Because Xedra's root filesystem is a standard FHS-compliant Debian system with SysVinit, it can be installed directly to any local block device (e.g., `/dev/sda` or `/dev/vda`) from within the live session without needing third-party tools.

### Step-by-Step Manual Installation Procedure:

```bash
# 1. Partition the target disk (GPT with EFI System Partition and root partition)
sudo cfdisk /dev/vda
#   /dev/vda1 -> 512 MB (EFI System Partition)
#   /dev/vda2 -> Remaining space (Linux Filesystem)

# 2. Format the partitions
sudo mkfs.vfat -F32 /dev/vda1
sudo mkfs.ext4 /dev/vda2

# 3. Mount the target filesystem
sudo mkdir -p /mnt/target
sudo mount /dev/vda2 /mnt/target
sudo mkdir -p /mnt/target/boot/efi
sudo mount /dev/vda1 /mnt/target/boot/efi

# 4. Copy the live rootfs to the target disk (preserving all attributes and permissions)
sudo rsync -aAXv \
    --exclude=/run/* \
    --exclude=/proc/* \
    --exclude=/sys/* \
    --exclude=/tmp/* \
    --exclude=/mnt/* \
    --exclude=/live \
    / /mnt/target/

# 5. Generate /etc/fstab with real disk UUIDs
ROOT_UUID=$(blkid -s UUID -o value /dev/vda2)
EFI_UUID=$(blkid -s UUID -o value /dev/vda1)

cat << EOF | sudo tee /mnt/target/etc/fstab
# /etc/fstab: Static file system information
UUID=${ROOT_UUID}   /          ext4   errors=remount-ro,noatime   0   1
UUID=${EFI_UUID}    /boot/efi  vfat   umask=0077                  0   1
tmpfs               /tmp       tmpfs  defaults,nosuid,nodev       0   0
EOF

# 6. Bind pseudo-filesystems and chroot to install the bootloader
sudo mount --bind /dev /mnt/target/dev
sudo mount --bind /proc /mnt/target/proc
sudo mount --bind /sys /mnt/target/sys

sudo chroot /mnt/target /bin/bash << 'CHROOT_EOF'
# Install GRUB EFI bootloader to the disk
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Xedra --recheck
update-grub
exit
CHROOT_EOF

# 7. Unmount and reboot into the installed system
sudo umount -R /mnt/target
sudo reboot
```

---

## 4. Installer Roadmap (Milestones 0.2+)

For future releases, automated installation options will be integrated directly into the live ISO:

| Installer Option | Type | Description | Target Milestone |
| :--- | :--- | :--- | :--- |
| **`xedra-installer`** | Terminal / CLI TUI | Minimal shell/whiptail menu asking for disk selection, hostname, timezone, and user setup. Completes installation in <60 seconds. | **Milestone 0.2** |
| **Calamares** | Modern Qt Graphical Installer | Modular GUI installer wizard with visual disk partitioning, timezone maps, and automated user creation. Used by distributions like EndeavourOS, Manjaro, and Lubuntu. | **Milestone 0.3** |

---

## 5. Architectural Summary

- **Xedra 0.1** is packaged as a **Live Hybrid ISO** for rapid testing, demonstration, and system recovery.
- Its internal root filesystem is **100% standard and fully installable** to persistent block devices.
- Milestone 0.2+ will introduce integrated CLI and GUI installers for streamlined, one-click disk deployment.
