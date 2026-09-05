# PodStack Capstone Presentation & Video Demo Script

> **Duration:** 5–7 Minutes  
> **Audience:** Technical Evaluators, Red Hat Instructors, VMware Internship Leads  
> **Format:** Live Terminal & Browser Demonstration

---

## Slide / Introduction (0:00 – 0:45)

**Spoken Script:**
> *"Hello everyone. Today, I am presenting the **PodStack Container Platform** — an integrated Red Hat Enterprise Linux 9 capstone project covering courses RH134 and RH124.
> 
> The core business requirement: A development team needs to deploy three separate application services on a single RHEL host. The constraints are strict: developers must **never** be granted root access, we cannot spin up expensive separate virtual machines, and all services must store data persistently and survive a cold server reboot.
> 
> Over the next few minutes, I will demonstrate how PodStack solves this using rootless Podman, systemd user services, SELinux Mandatory Access Control, firewalld, and cgroups v2."*

---

## Task 1: Rootless Setup (0:45 – 1:30)

**Action:** Open terminal on RHEL host. Run:
```bash
whoami && id
podman info | grep -A3 rootless
ps -eo user,comm | grep podman
```

**Spoken Script:**
> *"Here on the terminal, you can see I am logged in as `podstack` — an unprivileged service account with standard UID 1000.
> When I query `podman info`, the runtime reports `rootless: true`.
> In `/etc/subuid`, this user is assigned a range of 65,536 subordinate UIDs. Inside our containers, UID 0 maps back to host UID 100000. This means even if a process breaks out of the container, it holds zero administrative privileges on the host system."*

---

## Task 2: Image Management (1:30 – 2:15)

**Action:** Show the Containerfile and inspect the built image:
```bash
cat Containerfile | grep -E "FROM|USER|EXPOSE|VOLUME"
podman inspect localhost/podstack-web:latest | grep -E '"User"|"ExposedPorts"'
```

**Spoken Script:**
> *"For image management, we built our container using Red Hat's Universal Base Image — `ubi9/python-311`. 
> Looking at our Containerfile, we implement defense-in-depth: we explicitly switch to unprivileged user `1001` (`appuser`) inside the container before running our production Gunicorn WSGI server. We expose port 8080, declare the `/data` volume, and configure automated health check polling."*

---

## Task 3 & 4: Persistent Data & SELinux Integration (2:15 – 3:30)

**Action:** Show data, delete container, recreate container, show data persisted:
```bash
cat ~/podstack-data/visits.txt
podman rm -f podstack-web
cat ~/podstack-data/visits.txt
podman run -d --name podstack-web -p 8080:8080 -v ~/podstack-data:/data:Z podstack-web:latest
curl http://localhost:8080/health
ls -lZd ~/podstack-data
```

**Spoken Script:**
> *"Now for the most critical proof: data persistence.
> Our application records cumulative visit counts in `/data/visits.txt`. On the host, this maps directly to `~/podstack-data`.
> Notice that when I forcibly destroy the container using `podman rm -f`, the host file remains untouched with all visits preserved. When I recreate the container, the health check immediately reports the exact same visit count.
> 
> Crucially, look at the SELinux context: `svirt_sandbox_file_t`. Without the `:Z` flag, SELinux policy enforces Type Enforcement and blocks `container_t` from writing to `user_home_t`, logging an AVC denial in `/var/log/audit/audit.log`. The `:Z` option instructs Podman to automatically relabel the host folder with a unique Multi-Category Security pair private to this specific container."*

---

## Task 5: Boot Persistence Across Cold Reboot (3:30 – 4:30)

**Action:** Show systemd user unit status and reboot:
```bash
systemctl --user status podstack-web.service
sudo systemctl reboot
# ... Wait for system reboot ...
ssh podstack@<host-ip>
uptime
systemctl --user status podstack-web.service
curl http://localhost:8080/health
```

**Spoken Script:**
> *"In Task 5, we ensure this service behaves like an enterprise daemon without needing root access.
> We configured a systemd user unit in `~/.config/systemd/user/podstack-web.service`.
> Using `loginctl enable-linger podstack`, systemd starts the user's service instance at system boot, rather than on interactive login.
> 
> As you can see, after a full cold reboot of the server, the uptime is just 1 minute, yet `podstack-web.service` is already `active (running)`. No human logged in or started it manually, and all previous data was loaded immediately."*

---

## Task 6: Network Exposure & Remote Testing (4:30 – 5:15)

**Action:** Show firewalld rule on RHEL, then switch to a secondary machine or browser:
```bash
sudo firewall-cmd --zone=public --list-ports
# On client machine:
curl http://192.168.11.130:8080/
```

**Spoken Script:**
> *"For network exposure, we published port 8080. On the host, firewalld protects inbound traffic. We permanently opened port 8080/tcp in the `public` zone.
> 
> Now, switching to our second machine on the network, I navigate to `http://192.168.11.130:8080/`. The web application responds with HTTP 200, rendering our live telemetry dashboard."*

---

## Task 7: Resource Throttling with cgroup v2 (5:15 – 6:00)

**Action:** Run the stress test benchmark:
```bash
bash scripts/stress-test.sh
```

**Spoken Script:**
> *"Finally, Task 7 addresses resource awareness. We configured strict cgroup v2 limits: a hard memory ceiling of 256 MiB and a CPU cap of 0.5 cores.
> Under simulated peak load, `podman stats` proves that the Linux Completely Fair Scheduler throttles the container process to exactly 50% CPU utilization. Even if the container encounters a runaway loop, it cannot exhaust host resources or starve neighbor services."*

---

## Conclusion (6:00 – 6:30)

**Spoken Script:**
> *"In conclusion, PodStack fulfills all requirements of the business case and syllabus coverage for RH134 and RH124. We have proven that production-ready, highly-available container workloads can be deployed securely in unprivileged user space.
> The complete project, automated verification scripts, and architectural documentation are fully open-source in our repository. Thank you!"*
