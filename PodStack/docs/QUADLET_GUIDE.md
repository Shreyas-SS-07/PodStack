# Modern RHEL Container Orchestration: Podman Quadlets

> **Introduced:** Podman 4.4+ / RHEL 9.2+  
> **Replaces:** `podman generate systemd` (Deprecated)  
> **File Locations:** `~/.config/containers/systemd/*.container` (User) or `/etc/containers/systemd/` (System)

---

## 1. What is Quadlet?

Historically in RH134, administrators used `podman generate systemd` to generate lengthy shell-based unit files containing commands like `podman run --cidfile...`.

In modern Red Hat Enterprise Linux 9, Red Hat introduced **Quadlet**, a systemd generator that converts declarative container definitions directly into native systemd units at boot time without manual bash scripting.

```
+------------------------------------+
|  ~/.config/containers/systemd/     |
|  podstack-web.container            |  <--- Human-friendly declarative file
+------------------------------------+
                 |
                 v  (systemd daemon-reload)
+------------------------------------+
|  /run/user/1000/systemd/generator/ |
|  podstack-web.service              |  <--- Generated automatically by Quadlet
+------------------------------------+
```

---

## 2. Declarative Comparison

### Legacy systemd Unit (`systemd/podstack-web.service`)
```ini
[Service]
ExecStart=/usr/bin/podman run --cidfile=%t/podstack-web.ctr-id --sdnotify=conmon --replace --detach --name=podstack-web --publish=8080:8080 --volume=%h/podstack-data:/data:Z --memory=256m --cpus=0.5 localhost/podstack-web:latest
ExecStop=/usr/bin/podman stop --ignore --cidfile=%t/podstack-web.ctr-id
```

### Modern Quadlet Definition (`quadlet/podstack-web.container`)
```ini
[Unit]
Description=PodStack Web Frontend

[Container]
Image=localhost/podstack-web:latest
ContainerName=podstack-web
PublishPort=8080:8080
Volume=%h/podstack-data:/data:Z
Memory=256m
CPUQuota=50%
AutoUpdate=registry

[Service]
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target
```

---

## 3. How to Deploy Quadlets on RHEL 9.2+

```bash
# 1. Ensure user Quadlet directory exists
mkdir -p ~/.config/containers/systemd/

# 2. Copy Quadlet files
cp quadlet/*.container ~/.config/containers/systemd/
cp quadlet/*.network ~/.config/containers/systemd/

# 3. Reload systemd (Quadlet generator runs automatically)
systemctl --user daemon-reload

# 4. View the automatically generated service
systemctl --user cat podstack-web.service

# 5. Start and enable service
systemctl --user start podstack-web.service
systemctl --user status podstack-web.service
```

---

## 4. Key Advantages for Enterprise Deployments

1. **Self-Healing Updates:** Incorporating `AutoUpdate=registry` allows `podman auto-update` via systemd timers to automatically pull new image releases and roll back on health-check failure.
2. **Native Dependency Modeling:** Quadlets can declare `Network=podstack-net.network` and `Volume=data.volume`, allowing systemd to manage virtual networks and storage volumes as first-class system dependencies.
3. **No Brittle Shell Escaping:** Eliminates errors caused by quoting issues in `ExecStart` strings.
