# VMware Virtual Machine Networking & Setup Guide

> **Target Hypervisors:** VMware Workstation Pro / Player, VMware Fusion, VMware ESXi  
> **Guest OS:** Red Hat Enterprise Linux 9 (RHEL 9)

---

## 1. Selecting the Network Adapter Mode

To reach the PodStack service from your host machine or another device on the local network, you can configure VMware in one of two modes:

### Option A: Bridged Networking (Recommended for Multi-Machine Testing)
*   **Behavior:** The VM receives its own independent IP address directly from your local router's DHCP pool (e.g., `192.168.1.130`).
*   **Best for:** Accessing PodStack from your physical laptop, phone, or another VM on your home/office network without any port forwarding.
*   **VMware Configuration:**
    1. Open VM Settings &rarr; **Hardware** &rarr; **Network Adapter**.
    2. Select **Bridged: Connected directly to the physical network**.
    3. Check **Replicate physical network connection state**.
    4. In the RHEL guest, restart the network connection:
       ```bash
       sudo nmcli connection reload
       sudo nmcli connection up ens192 # or your active interface
       ip -brief address show
       ```

### Option B: NAT (Network Address Translation) with Port Forwarding
*   **Behavior:** The VM sits on a private virtual subnet (e.g., `192.168.11.0/24`) managed by VMware's virtual DHCP server.
*   **Best for:** Working on public/campus Wi-Fi where routers block device-to-device traffic.
*   **Configuring VMware Port Forwarding:**
    1. In VMware Workstation, go to **Edit** &rarr; **Virtual Network Editor**.
    2. Select **VMnet8 (NAT)** &rarr; click **Change Settings** (requires administrator).
    3. Click **NAT Settings...** &rarr; under *Port Forwarding*, click **Add...**:
       *   **Host Port:** `8080`
       *   **Type:** `TCP`
       *   **Virtual machine IP address:** Enter the RHEL guest IP (found via `ip a`)
       *   **Virtual machine port:** `8080`
       *   **Description:** `PodStack Web Gateway`
    4. Click **OK** &rarr; **Apply**.
    5. You can now access the app on your host machine via:
       ```
       http://localhost:8080/
       ```

---

## 2. RHEL Guest Network Configuration

Find your active IP address inside the RHEL guest:

```bash
# Display IP configuration
ip -brief address show

# Verify the default gateway and internet reachability
ip route
ping -c 3 access.redhat.com
```

---

## 3. VMware Shared Folders (Optional Development Workflow)

If you want to edit code on your Windows/macOS host and run it directly inside the RHEL guest:

1. VM Settings &rarr; **Options** &rarr; **Shared Folders** &rarr; **Always enabled**.
2. Add your host folder (e.g. `C:\Users\KIIT\Downloads\PodStack`).
3. Inside the guest, VMware mounts shared folders under:
   ```bash
   ls -la /mnt/hgfs/
   ```
4. Note: Podman rootless volume mounts work best on native Linux filesystems (XFS/ext4) due to SELinux label support.
