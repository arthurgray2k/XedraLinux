# Antigravity Operating Rules for Xedra Linux Project

## 1. Core Operating Principles
- **No Rushing / Deep Thinking First**: Never react impulsively to build or runtime errors. Always diagnose the exact root cause by reading full logs and tracing the entire execution pipeline before proposing or making changes.
- **Strict Scope Lockdown**: When fixing an issue, modify only the specific lines directly responsible for that issue.
- **Never Overwrite Entire Scripts**: Never use `write_to_file` with `Overwrite: true` on established multi-stage scripts. Always use `replace_file_content` for precise, surgical line edits to prevent accidental removal of existing features (e.g. JSON manifest parsing, caching logic, profile definitions).

## 2. Git & Change Control Guidelines
- **No Autonomous Git Pushes**: Never run `git commit` or `git push` without first presenting the proposed diff and receiving user confirmation when requested.
- **Keep Workspace Clean**: Ensure no dangling temporary files or uncommitted breaking edits.

## 3. Mandatory Pre-Flight Validation
- **Syntax Verification**: Every edited shell script must be validated using `bash -n <script_path>` before concluding a turn.
- **Manifest Validation**: All JSON configuration files (e.g. `config/xedra-build.json`) must be syntax-validated using `python3 -m json.tool <file>`.

## 4. Protected Architectural Baselines
The following architectural features must be preserved across all builds and iterations:
1. **Multi-Profile JSON Manifest Engine**: `config/xedra-build.json` supports `dev` (fast package caching), `release` (pristine fresh build), and `minimal` profiles.
2. **Package Caching Strategy**: Preserve `.deb` archives in `cache/packages.*` while setting `--cache-stages none` to prevent intermediate rootfs snapshot conflicts.
3. **SysVinit PID 1 Architecture**: Standard Debian 13 "Trixie" base with atomic SysVinit transition (`sysvinit-core`, `initscripts`, `insserv`, `live-config-sysvinit`, `elogind`, `systemd-sysv-`).
4. **Desktop Environment & Permissions**: `xserver-xorg-legacy`, `/etc/X11/Xwrapper.config` (`needs_root_rights = yes`), `xinitrc` with `1600x900` widescreen KVM resolution, and Fluxbox power options.
5. **UEFI Boot & Restart Reliability**: `create-lab-vm.sh` with permanent `<boot order='1'/>` on the CD-ROM drive and `on_reboot=restart`.
