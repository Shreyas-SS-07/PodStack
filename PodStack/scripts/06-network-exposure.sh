#!/usr/bin/env bash
# =============================================================================
# Script 06 – Network Exposure  (Task 6)
# Covers: RH124 Ch 16, RH134 Ch 6
#
# PURPOSE:
#   - Publish the container port so it is reachable from another machine
#   - Open the port in firewalld permanently
#   - Verify reachability
#
# RUN AS: podstack (non-root) for Podman steps
#         root / sudo for firewalld steps
# =============================================================================

set -euo pipefail

HOST_PORT="8080"
SERVICE_NAME="podstack-web"

echo "=================================================================="
echo " Task 6 – Network Exposure"
echo "=================================================================="

# ── PART A: Podman port publishing ───────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " PART A – Container Port Publishing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "[INFO] The container is already running with --publish ${HOST_PORT}:8080"
echo "  This maps HOST port ${HOST_PORT} → CONTAINER port 8080"
echo ""

echo "[STEP 1] Confirm port mapping:"
podman port "${SERVICE_NAME}" 2>/dev/null || \
    echo "  (Start the container first with script 03 or 05)"

echo ""
echo "[STEP 2] Confirm port is listening on the host:"
ss -tlnp | grep ":${HOST_PORT}" || echo "  Port ${HOST_PORT} not yet listening (start container first)"

echo ""
echo "[STEP 3] Local curl test:"
if curl -sf "http://localhost:${HOST_PORT}/health" &>/dev/null; then
    curl -sf "http://localhost:${HOST_PORT}/health"
    echo ""
    echo "[OK] Service responds on localhost:${HOST_PORT}"
else
    echo "[WARN] Service not responding yet — is the container running?"
fi

# ── PART B: firewalld configuration ──────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " PART B – firewalld Configuration (run steps below as root/sudo)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "[INFO] firewalld commands to open port ${HOST_PORT} (requires sudo):"
echo ""
echo "  # 1. Verify firewalld is running:"
echo "  sudo systemctl status firewalld --no-pager"
echo ""
echo "  # 2. Check current active zone:"
echo "  sudo firewall-cmd --get-active-zones"
echo ""
echo "  # 3. Add port ${HOST_PORT}/tcp to the public zone — RUNTIME (immediate, lost on reload):"
echo "  sudo firewall-cmd --zone=public --add-port=${HOST_PORT}/tcp"
echo ""
echo "  # 4. Add port ${HOST_PORT}/tcp to the public zone — PERMANENT (survives reboot):"
echo "  sudo firewall-cmd --zone=public --add-port=${HOST_PORT}/tcp --permanent"
echo ""
echo "  # 5. Reload firewalld to apply permanent rules:"
echo "  sudo firewall-cmd --reload"
echo ""
echo "  # 6. Verify the rule is active:"
echo "  sudo firewall-cmd --zone=public --list-ports"
echo ""

# Attempt to run if we have sudo
if sudo -n true 2>/dev/null; then
    echo "[AUTO] sudo available — applying firewall rules automatically..."

    echo "  Checking firewalld status..."
    sudo systemctl is-active firewalld &>/dev/null || sudo systemctl start firewalld

    ACTIVE_ZONE=$(sudo firewall-cmd --get-default-zone 2>/dev/null || echo "public")
    echo "  Active zone: ${ACTIVE_ZONE}"

    # Add runtime rule
    sudo firewall-cmd --zone="${ACTIVE_ZONE}" --add-port="${HOST_PORT}/tcp" 2>/dev/null && \
        echo "  [OK] Runtime rule added."

    # Add permanent rule
    sudo firewall-cmd --zone="${ACTIVE_ZONE}" --add-port="${HOST_PORT}/tcp" --permanent 2>/dev/null && \
        echo "  [OK] Permanent rule added."

    # Reload
    sudo firewall-cmd --reload 2>/dev/null && \
        echo "  [OK] Firewall reloaded."

    echo ""
    echo "  Current open ports in zone '${ACTIVE_ZONE}':"
    sudo firewall-cmd --zone="${ACTIVE_ZONE}" --list-ports
else
    echo "[NOTE] No passwordless sudo available. Run the commands above manually."
fi

# ── PART C: Reachability from another machine ─────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " PART C – Remote Reachability Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

HOST_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "[INFO] This server's IP address: ${HOST_IP}"
echo ""
echo "  From a SECOND machine (e.g., your workstation), run:"
echo "    curl http://${HOST_IP}:${HOST_PORT}/health"
echo "    curl http://${HOST_IP}:${HOST_PORT}/"
echo ""
echo "  Or open in a browser:"
echo "    http://${HOST_IP}:${HOST_PORT}/"
echo ""
echo "[DONE] Task 6 – Network Exposure complete."
