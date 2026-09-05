# Screenshots & Demo Evidence

Place your screenshots and recordings here to document the demonstration.

## Recommended Screenshots

| # | Filename | What to capture |
|---|----------|-----------------|
| 1 | `01-whoami-id.png` | `whoami && id` showing non-root user |
| 2 | `02-podman-info-rootless.png` | `podman info` showing `rootless: true` |
| 3 | `03-image-build.png` | `podman build` output + `podman images` |
| 4 | `04-container-running.png` | `podman ps` + browser showing the web page |
| 5 | `05-data-persistence.png` | `cat visits.txt` before and after container delete |
| 6 | `06-selinux-context.png` | `ls -lZ` showing `svirt_sandbox_file_t` label |
| 7 | `07-systemd-status.png` | `systemctl --user status podstack-web.service` |
| 8 | `08-after-reboot.png` | Service running without manual start after reboot |
| 9 | `09-firewalld-ports.png` | `firewall-cmd --list-ports` showing 8080/tcp |
| 10 | `10-remote-curl.png` | `curl` from a second machine returning HTTP 200 |
| 11 | `11-resource-limits.png` | `podman stats` showing memory/CPU within limits |
| 12 | `12-cgroup-values.png` | `cat memory.max` and `cat cpu.max` from cgroup fs |

## Recording Tips

- Use `asciinema` for terminal recordings: `asciinema rec demo.cast`
- Convert to GIF with `agg`: `agg demo.cast demo.gif`
- Place GIFs in this directory and embed in README with:
  `![Task 1 Demo](docs/screenshots/demo.gif)`
