# PodStack Security Hardening & Compliance Audit

> **Evaluation Standard:** Red Hat Enterprise Linux 9 Security Baseline  
> **Classification:** Production-Grade Rootless Container Architecture

---

## 1. Threat Model & Defense-in-Depth

The PodStack platform implements five concentric rings of defense:

```
[ Ring 5: firewalld / Network Filtering (Port 8080 restricted) ]
   └── [ Ring 4: cgroup v2 Hardware Caps (256M RAM, 0.5 CPU) ]
        └── [ Ring 3: SELinux MCS Type Enforcement (svirt_sandbox_file_t) ]
             └── [ Ring 2: Linux User Namespaces (UID 1000 -> 100000) ]
                  └── [ Ring 1: Unprivileged In-Container User (UID 1001 appuser) ]
```

---

## 2. Comprehensive Security Audit Checklist

| Threat Vector | Mitigation Mechanism | Verification Command | Status |
|---|---|---|---|
| **Daemon Exploitation** | Daemonless execution: Podman has no central background daemon running as root. | `ps -ef \| grep podmand` (Returns null) | **COMPLIANT** |
| **Privilege Escalation** | Dual user namespaces: host user `podstack` (1000) runs container as non-root `appuser` (1001). Container root maps to host UID `100000`. | `podman inspect podstack-web --format '{{.Config.User}}'` | **COMPLIANT** |
| **Host Filesystem Access** | SELinux Mandatory Access Control blocks reads/writes to unauthorized host types. Volume uses private `:Z` MCS isolation. | `ls -lZd ~/podstack-data` (type `svirt_sandbox_file_t`) | **COMPLIANT** |
| **Resource Starvation (DoS)** | Hard cgroup limits: max 256 MiB RAM (OOM kill ceiling) and 50% CPU ceiling (CFS bandwidth control). | `cat /sys/fs/cgroup/.../memory.max` | **COMPLIANT** |
| **Lateral Host Infiltration** | Network isolation via unprivileged slirp4netns bridge; firewalld restricts inbound access to explicitly published port 8080. | `sudo firewall-cmd --list-ports` | **COMPLIANT** |
| **Capability Leaks** | Rootless Podman drops all administrative Linux capabilities (`CAP_SYS_ADMIN`, `CAP_NET_ADMIN`, `CAP_SYS_RAWIO`). | `podman exec podstack-web grep CapEff /proc/self/status` | **COMPLIANT** |

---

## 3. SELinux AVC Audit Trail Analysis

When attempting to mount host directories without the `:Z` flag, the audit daemon logs:

```
type=AVC msg=audit(1725472312.847:234): avc: denied { write } for
  pid=12345 comm="python3"
  path="/home/podstack/podstack-data/visits.txt"
  scontext=system_u:system_r:container_t:s0:c247,c941
  tcontext=unconfined_u:object_r:user_home_t:s0
  tclass=file permissive=0
```

### Remediation Impact
Executing `podman run --volume ~/podstack-data:/data:Z` invokes:
```bash
chcon -Rt svirt_sandbox_file_t ~/podstack-data
```
This aligns the target object type with the container's security context without compromising host directories.

---

## 4. Auditor Conclusion

PodStack achieves **full compliance** with RH134 and enterprise unprivileged container standards. Developers can operate independently without grant of `sudo` or root privileges.
