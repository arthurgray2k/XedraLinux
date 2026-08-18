# Concept: APT vs. DPKG

Understanding the division of responsibilities between **DPKG** and **APT** is fundamental to Debian distro engineering.

---

## 1. High-Level Comparison

```text
+-------------------------------------------------------------------------------+
|                                    USER                                       |
+-------------------------------------------------------------------------------+
                                      │
                                      ▼ (apt install fluxbox)
+-------------------------------------------------------------------------------+
|                            APT (Advanced Package Tool)                        |
|  - Queries remote package mirrors (deb.debian.org)                            |
|  - Reads repository metadata (/var/lib/apt/lists/)                            |
|  - Resolves dependency graphs (DAG)                                           |
|  - Downloads required .deb files into cache (/var/cache/apt/archives/)        |
+-------------------------------------------------------------------------------+
                                      │
                                      ▼ Calls dpkg -i with exact .deb list
+-------------------------------------------------------------------------------+
|                           DPKG (Debian Package Manager)                       |
|  - Unpacks individual .deb archives onto disk                                 |
|  - Tracks installed files in /var/lib/dpkg/info/<pkg>.list                    |
|  - Maintains package state in /var/lib/dpkg/status                            |
|  - Runs maintainer scripts (preinst, postinst, prerm, postrm)                 |
+-------------------------------------------------------------------------------+
                                      │
                                      ▼ Writes files to disk
+-------------------------------------------------------------------------------+
|                               FILESYSTEM ROOT                                 |
+-------------------------------------------------------------------------------+
```

---

## 2. Detailed Technical Comparison

| Feature | DPKG (`dpkg`) | APT (`apt`, `apt-get`) |
| :--- | :--- | :--- |
| **Layer** | Low-Level Mechanical Tool | High-Level Management & Resolution Engine |
| **Network Awareness** | ❌ None (works only with local `.deb` files) | ✅ Full (HTTP/HTTPS mirror querying & downloading) |
| **Dependency Resolution** | ❌ None (fails if dependencies are missing) | ✅ Complete (resolves multi-package dependency trees) |
| **State Registry** | Owns and manages `/var/lib/dpkg/status` | Reads `/var/lib/dpkg/status` to determine current state |
| **Package Format** | Directly unpacks `ar` archives | Does not unpack archives; passes them to `dpkg` |
| **Maintainer Scripts** | Executes `preinst`, `postinst`, etc. | Coordinates when `dpkg` runs them |

---

## 3. Essential Commands & What They Show

### DPKG Commands
```bash
# List all installed packages recorded in the DPKG database
dpkg -l

# Find which package owns a specific file on disk
dpkg -S /etc/os-release
# Output: base-files: /etc/os-release

# Inspect installed files belonging to a specific package
dpkg -L fluxbox

# Check package status directly against an alternate root
dpkg-query --admindir=/workspace/build/rootfs/var/lib/dpkg -W
```

### APT Commands
```bash
# Download latest package indexes from /etc/apt/sources.list
apt update

# Resolve dependencies, download .deb archives, and call dpkg
apt install fluxbox

# Search package repository metadata for matching names or descriptions
apt search fluxbox
```

---

## 4. Key Takeaway for Distro Builders

When building Xedra:
- We configure **APT** with clean Debian Stable mirror sources.
- We inspect **DPKG** to verify what files and dependencies were actually placed onto the root filesystem.
- We rely on `dpkg-query` to audit our rootfs size and package counts before creating ISO images.
