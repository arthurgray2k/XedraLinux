# Xedra Linux - Future Ideas & Optimization Roadmap

This document serves as a parking lot and architectural backlog for future optimizations, tooling enhancements, and features to be evaluated in upcoming milestones.

---

## 1. Build Pipeline & Performance Optimizations

### 1.1 Stage-by-Stage Stopwatch Instrumentation
* **Concept**: Refactor `scripts/build-iso.sh` to invoke `live-build`'s discrete sub-stages (`lb bootstrap`, `lb chroot`, `lb binary`) rather than a single opaque `lb build` call.
* **Goal**: Measure and print exact elapsed wall-clock seconds for each sub-stage to output a structured benchmark summary at the end of every compilation.
* **Target Milestone**: Future tooling refresh.

### 1.2 RAM-Disk (`tmpfs`) Chroot Workspace
* **Concept**: Mount a temporary memory-backed filesystem (`tmpfs`) at `~/XedraLinux/build/live-build/chroot/` before `lb chroot` package extraction begins.
* **Benefit**: Eliminates virtualized storage latency and host journal write barriers, allowing `dpkg` package extraction to operate at memory bus bandwidth (~10–15 GB/s).
* **Considerations**: Requires ensuring adequate RAM allocation on the builder VM (e.g. 6–8 GB RAM allocated to `xedra-builder`).

### 1.3 Debian Build-Time Trigger Deferral
* **Concept**: Suppress redundant background indexing and regeneration tasks during live image generation:
  * **`man-db` auto-update**: Disable via debconf during build (`man-db man-db/auto-update boolean false`).
  * **`update-initramfs`**: Defer kernel initramfs regeneration during individual package unpacks and execute it exactly once during final chroot assembly.

### 1.4 Multi-Threaded Compression Algorithms (`zstd` vs. `gzip`)
* **Concept**: Systematically benchmark `zstd -1` against `gzip -1` for live SquashFS generation.
* **Metrics to evaluate**:
  1. Build-time compression throughput (seconds to compress 1.5 GB rootfs across 2–4 CPU cores).
  2. Boot-time decompression latency inside disposable test VMs (`xedra-lab`).
  3. Resulting ISO image size.

---

## 2. Desktop & Installer Enhancements

### 2.1 Graphical Installer (Calamares Integration)
* **Concept**: Integrate the modular Qt-based Calamares installer alongside the existing native `/usr/local/bin/xedra-installer`.
* **Features**: Visual disk partitioner, timezone map selector, and locale configuration.

### 2.2 Dedicated Package Repository (APT Mirror)
* **Concept**: Host a standalone Xedra package repository (`deb.xedralinux.org` / GitHub Pages raw pool) for distribution-specific packages, themes, and customized SysVinit scripts.

### 2.3 Automated Builder VM Resource Tuning
* **Concept**: Provide a host helper script to dynamically scale `xedra-builder`'s CPU core and RAM allocation based on host hardware availability before launching heavy release builds.
