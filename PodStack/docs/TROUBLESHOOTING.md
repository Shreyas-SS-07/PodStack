# PodStack Troubleshooting & Operational Runbook

> **RH134 / RH124 Common Incident Scenarios & Interview Q&A**

---

## 1. Issue: "XDG_RUNTIME_DIR is not set" or "Cannot connect to Podman socket"

### Symptoms
Running `podman ps` or `systemctl --user` yields:
```
Failed to connect to bus: No medium found
Error: XDG_RUNTIME_DIR not set in the environment
```

### Root Cause
Switching users with plain `su podstack` does not initialize a complete PAM login session.

### Resolution
Always switch to the user account using a proper login shell:
```bash
# Correct syntax:
sudo -i -u podstack

# Or export the standard runtime directory manually:
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
```

---

## 2. Issue: SELinux Permission Denied When Accessing Host Directory

### Symptoms
The container fails to start, or application logs show:
```
PermissionError: [Errno 13] Permission denied: '/data/visits.txt'
```

### Diagnostics
Check the audit log for Access Vector Cache (AVC) denials:
```bash
sudo ausearch -m avc -ts recent | grep container_t
```

### Resolution
Ensure the `:Z` flag is appended to the volume argument:
```bash
# Wrong:
podman run -v ~/podstack-data:/data ...

# Correct:
podman run -v ~/podstack-data:/data:Z ...
```
To fix existing permissions manually:
```bash
chcon -Rt svirt_sandbox_file_t ~/podstack-data
```

---

## 3. Issue: User systemd Services Terminate on SSH Logout

### Symptoms
Containers stop running as soon as you close your SSH session or terminal window.

### Root Cause
systemd kills user processes upon session logout unless **lingering** is explicitly enabled.

### Resolution
Run as root:
```bash
sudo loginctl enable-linger podstack

# Confirm lingering status:
ls -l /var/lib/systemd/linger/podstack
```

---

## 4. Issue: "Error: user namespaces are not enabled" or subuid allocation error

### Symptoms
```
Error: cannot find mappings for user podstack: subuid allocation failed
```

### Diagnostics
Verify that subordinate UID/GID entries exist:
```bash
grep podstack /etc/subuid /etc/subgid
```

### Resolution
Add standard 65,536 subordinate UID/GID allocations:
```bash
sudo usermod --add-subuids 100000-165535 podstack
sudo usermod --add-subgids 100000-165535 podstack
podman system migrate
```

---

## 5. Issue: Service Accessible Locally via `curl localhost:8080`, but Times Out Remotely

### Symptoms
Remote browser shows `ERR_CONNECTION_TIMED_OUT`.

### Diagnostics
Verify firewalld active zone and open ports:
```bash
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --zone=public --list-ports
```

### Resolution
Add port to both runtime and permanent configuration, then reload:
```bash
sudo firewall-cmd --zone=public --add-port=8080/tcp
sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
sudo firewall-cmd --reload
```

---

## 6. Issue: Memory or CPU Limits Ignored in Rootless Mode

### Symptoms
`podman stats` shows memory limit as total host RAM instead of 256 MiB.

### Root Cause
The host is running cgroups v1 or user delegation is not enabled for the user slice.

### Diagnostics
```bash
cat /sys/fs/cgroup/cgroup.controllers
```

### Resolution
On RHEL 9, ensure unified cgroup hierarchy is active:
```bash
# Enable cgroup v2
sudo grubby --update-kernel=ALL --args="systemd.unified_cgroup_hierarchy=1"
sudo systemctl reboot
```
Ensure controllers are delegated to user slices in `/etc/systemd/system/user@.service.d/delegate.conf`:
```ini
[Service]
Delegate=cpu cpuset io memory pids
```
