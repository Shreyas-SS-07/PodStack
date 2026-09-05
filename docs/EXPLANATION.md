# Technical Explanation – PodStack Container Platform

> RH134 Ch 6, 14, 17 · RH124 Ch 16

---

## Task 1 – Rootless Setup

### What is "Rootless" Podman?

Traditional container engines (Docker daemon) run a privileged background daemon as **root**. If the daemon or a container is compromised, the attacker has root on the host.

Podman's rootless mode runs the **entire container lifecycle — including the runtime, image storage, and network — within the user's own UID namespace**, with zero root involvement:

```
┌─ RHEL Host ────────────────────────────────────────────────────────┐
│  UID 1000: podstack (unprivileged)                                 │
│    └─ podman run ...                                               │
│         └─ conmon (monitor) ← UID 1000                            │
│              └─ runc/crun (OCI runtime) ← UID 1000               │
│                   └─ container process ← mapped UIDs in user ns   │
└────────────────────────────────────────────────────────────────────┘
```

### Sub-UID/GID Ranges (`/etc/subuid`, `/etc/subgid`)

For a container to have its own `root` (UID 0) internally, the host must be able to map that internal UID 0 to an **unprivileged** host UID. This is done through Linux **user namespaces**:

```
Container UID 0  →  Host UID 100000   (invisible to host as root)
Container UID 1  →  Host UID 100001
...
Container UID 65535 → Host UID 165535
```

The `subuid`/`subgid` files define what subordinate UID ranges a user is allowed to use for this mapping.

### Lingering (`loginctl enable-linger`)

By default, a user's systemd instance starts at **first login** and stops at **last logout**. Lingering overrides this: the user's systemd instance starts at **boot** and persists forever, even with no active sessions. This is what makes user services survive reboots.

---

## Task 2 – Image Management

### UBI (Universal Base Image)

Red Hat's UBI images are freely available and fully supported on RHEL. Using `ubi9/python-311` means:
- No proprietary licence required for distribution
- Pre-configured for RHEL security policies
- Receives CVE patches from Red Hat

### Layer Caching in Containerfile

The `Containerfile` deliberately copies `requirements.txt` **before** `app.py`:

```dockerfile
COPY app/requirements.txt ./requirements.txt
RUN pip3 install --no-cache-dir -r requirements.txt   # ← expensive layer
COPY app/app.py ./app.py                               # ← cheap layer
```

If only `app.py` changes, Podman reuses the cached pip install layer. If `requirements.txt` changes, everything below it rebuilds. This halves rebuild time during development.

### Running as Non-Root Inside the Container

```dockerfile
RUN useradd --uid 1001 --gid 0 ...
USER 1001
```

Even inside the container, the process does not run as UID 0. This is defence-in-depth: even if a container escape vulnerability exists, the attacker gets an unprivileged UID on both the container side and the host side.

---

## Task 3 – Persistent Data

### Why Container Layers are Ephemeral

Every container gets a **writable layer** on top of the read-only image layers. When the container is deleted, this writable layer is destroyed. Any data written inside the container (e.g., `/data/visits.txt`) is lost **unless** it is on a bind-mount or named volume.

### Bind Mount vs Named Volume

| | Bind Mount | Named Volume |
|---|---|---|
| Host path | Explicit (`~/podstack-data`) | Managed by Podman (`~/.local/share/containers/storage/volumes/`) |
| Visibility | Easy to inspect/back up | Opaque |
| Portability | Depends on path existing | More portable |
| **This project uses** | ✅ Bind mount | |

Bind mounts are preferred for capstone demos because you can directly `cat` the file on the host to prove persistence.

---

## Task 4 – SELinux Integration

### Mandatory Access Control (MAC) vs DAC

**DAC (Discretionary Access Control)**: traditional Unix `rwxrwxrwx` permissions. The file owner decides who can access it. Root can override everything.

**MAC (Mandatory Access Control)**: the OS policy decides. Even root cannot override MAC without changing the policy itself. SELinux is MAC.

### Type Enforcement

SELinux labels every process and file with a **context**: `user:role:type:level`.

```
Container process context:  system_u:system_r:container_t:s0:c123,c456
Host directory context:     unconfined_u:object_r:user_home_t:s0
```

The SELinux policy has NO `allow` rule for:
```
allow container_t user_home_t : dir { write };
```

So even though the `podstack` user owns both the container and the directory (DAC would allow it), SELinux's MAC layer **denies** the write and logs an AVC (Access Vector Cache denial).

### The `:Z` Mount Option

`:Z` triggers Podman to run `chcon -Rt svirt_sandbox_file_t <host-path>` before the mount, relabelling the directory to a type that the container policy **does** allow:

```
allow container_t svirt_sandbox_file_t : dir { read write create ... };
```

| Option | Scope | Use case |
|--------|-------|----------|
| `:z` (lowercase) | Shared between all containers | Config directories shared by multiple containers |
| `:Z` (uppercase) | Private to this container (unique MCS pair) | Data directories for a single container |

### Investigating AVC Denials

```bash
# See recent denials
sudo ausearch -m avc -ts recent

# Human-readable with suggested fixes
sudo sealert -a /var/log/audit/audit.log

# Check if SELinux is in enforcing mode
getenforce
sestatus
```

---

## Task 5 – Boot Persistence

### systemd User Instance

Every logged-in user has their own `systemd --user` instance (PID different from PID 1). It manages user-level services in `~/.config/systemd/user/`.

```
PID 1: systemd (system)
  └─ user@1000.service
       └─ systemd --user (for UID 1000)
            └─ podstack-web.service
                 └─ podman run ...
                      └─ gunicorn (container process)
```

### Key Unit File Directives

| Directive | Purpose |
|-----------|---------|
| `After=network-online.target` | Don't start until network is up |
| `Type=notify` | Podman sends a readiness notification via sd_notify |
| `ExecStartPre=` | Clean up stale PID/CID files before start |
| `ExecStop=` | Gracefully stop the container |
| `ExecStopPost=` | Remove the stopped container |
| `Restart=on-failure` | Restart if the container exits non-zero |
| `WantedBy=default.target` | Start when user's default target is reached |

### Why `%h`, `%U`, `%t` in the Unit File?

These are **systemd specifiers** (template variables):
- `%h` → User's home directory
- `%U` → User's UID (numeric)
- `%t` → Runtime directory (`/run/user/<UID>`)
- `%n` → Full unit name

---

## Task 6 – Network Exposure

### Podman Rootless Networking

In rootless mode, Podman uses **slirp4netns** (or Pasta/netavark) — a user-space network stack that tunnels container traffic through the unprivileged user's UID. The `--publish 8080:8080` flag maps a host port to the container port via iptables rules written by slirp4netns (no root required for ports > 1024).

### firewalld Zone Model

firewalld uses **zones** (public, trusted, internal, etc.) to group network interfaces. The `public` zone is the default for external-facing interfaces.

```
Internet → [NIC: eth0] → firewalld (zone: public)
                              ↓ rule: allow TCP 8080
                         host TCP stack
                              ↓ Podman iptables DNAT rule
                         container:8080
```

**Runtime vs Permanent rules:**
- Runtime rules (`--add-port`) take effect immediately but are lost on `firewall-cmd --reload` or reboot
- Permanent rules (`--add-port --permanent`) are written to disk and survive reboot
- Best practice: add both, or add permanent then `--reload`

---

## Task 7 – Resource Awareness

### Linux cgroups (Control Groups)

cgroups is the kernel subsystem that groups processes and enforces resource limits. Podman uses **cgroup v2** (unified hierarchy) for rootless containers.

```
/sys/fs/cgroup/
  user.slice/
    user-1000.slice/
      user@1000.service/
        libpod-<container-id>.scope/
          memory.max      ← 268435456 (256 MiB)
          cpu.max         ← 50000 100000 (50% of one CPU)
```

### Memory Limit (`--memory`)

When a container's memory usage reaches the `memory.max` value, the kernel's **OOM (Out of Memory) killer** terminates processes within that cgroup. Setting `--memory-swap` equal to `--memory` disables swap, making the limit hard and immediate.

### CPU Limit (`--cpus`)

Implemented via the **CFS (Completely Fair Scheduler) Bandwidth Control**:
- `cpu.max` = `<quota> <period>` in microseconds
- `--cpus=0.5` → `50000 100000` (50ms quota per 100ms period)
- The container can use at most 50% of a single CPU core, burst-averaged over 100ms windows

### `--cpu-shares` (Relative Weight)

This only matters when CPUs are **contested**. A container with `--cpu-shares=512` gets half the CPU time of a container with the default 1024 shares, but can use 100% of the CPU when the system is idle.

---

## Syllabus Cross-Reference

| Task | RHEL Course | Chapter | Topic |
|------|------------|---------|-------|
| 1 – Rootless Setup | RH134 + RH124 | Ch 6, Ch 16 | Podman rootless, user namespaces |
| 2 – Image Management | RH134 | Ch 6 | Containerfile, registries, inspect |
| 3 – Persistent Data | RH134 | Ch 6, Ch 14 | Bind mounts, volumes |
| 4 – SELinux | RH134 | Ch 17 | MAC, AVC denials, chcon, :Z |
| 5 – Boot Persistence | RH134 | Ch 14 | systemd user units, lingering |
| 6 – Network Exposure | RH124 | Ch 16 | firewalld zones, port rules |
| 7 – Resource Awareness | RH134 | Ch 6 | cgroups v2, memory/CPU limits |
