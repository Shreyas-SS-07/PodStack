#!/usr/bin/env bash
# =============================================================================
# Script 05 – Boot Persistence  (Task 5)
# Covers: RH134 Ch 14
#
# PURPOSE:
#   Configure the podstack-web container to start automatically at system
#   boot as a systemd USER service under the non-root 'podstack' account.
#   Demonstrate it survives a full reboot.
#
# RUN AS: podstack (non-root)
# =============================================================================

set -euo pipefail

SERVICE_NAME="podstack-web"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

echo "=================================================================="
echo " Task 5 – Boot Persistence (systemd user service)"
echo "=================================================================="

echo ""
echo "[CHECK] Running as: $(whoami)  (UID=$(id -u))"
if [[ $(id -u) -eq 0 ]]; then
    echo "[ERROR] This script must run as 'podstack', not root."
    exit 1
fi

# ── 1. Create the systemd user directory ─────────────────────────────────────
echo ""
echo "[STEP 1] Creating systemd user unit directory: ${SYSTEMD_USER_DIR}"
mkdir -p "${SYSTEMD_USER_DIR}"

# ── 2. Copy the unit file ────────────────────────────────────────────────────
echo ""
echo "[STEP 2] Installing unit file..."
cp "${PROJECT_ROOT}/systemd/${SERVICE_NAME}.service" \
   "${SYSTEMD_USER_DIR}/${SERVICE_NAME}.service"
echo "[OK] Unit file installed at: ${SYSTEMD_USER_DIR}/${SERVICE_NAME}.service"
cat "${SYSTEMD_USER_DIR}/${SERVICE_NAME}.service"

# ── 3. Reload systemd user daemon ────────────────────────────────────────────
echo ""
echo "[STEP 3] Reloading systemd user daemon..."
systemctl --user daemon-reload
echo "[OK] Daemon reloaded."

# ── 4. Enable the service (so it starts at boot via lingering) ───────────────
echo ""
echo "[STEP 4] Enabling ${SERVICE_NAME}.service..."
systemctl --user enable "${SERVICE_NAME}.service"
echo "[OK] Service enabled."

# ── 5. Start the service now ─────────────────────────────────────────────────
echo ""
echo "[STEP 5] Starting ${SERVICE_NAME}.service now..."
systemctl --user start "${SERVICE_NAME}.service"
sleep 5

echo "[OK] Service started."
echo ""
echo "[STEP 6] Checking service status:"
systemctl --user status "${SERVICE_NAME}.service" --no-pager

echo ""
echo "[STEP 7] Confirm container is running:"
podman ps --filter "name=${SERVICE_NAME}"

echo ""
echo "[STEP 8] Quick health check:"
sleep 3
curl -sf "http://localhost:8080/health" | python3 -c \
    "import json,sys; d=json.load(sys.stdin); print(f'  Health: {d}')"

echo ""
echo "=================================================================="
echo " Boot Persistence Verification"
echo "=================================================================="
echo ""
echo "  The service will start automatically at boot because:"
echo "  1. systemctl --user enable creates a symlink in:"
echo "     ~/.config/systemd/user/default.target.wants/${SERVICE_NAME}.service"
echo "  2. loginctl enable-linger (done in script 01) ensures that the"
echo "     user's systemd instance starts at BOOT, not just at login."
echo ""
echo "  To verify after reboot:"
echo ""
echo "    # After rebooting the RHEL host, SSH in as podstack and run:"
echo "    systemctl --user status ${SERVICE_NAME}.service"
echo "    podman ps"
echo "    curl http://localhost:8080/health"
echo ""
echo "  Expected: service is 'active (running)' WITHOUT you manually"
echo "  starting it — the data from before the reboot is still there!"
echo ""
echo "  Reboot command (run as root):"
echo "    sudo systemctl reboot"
echo ""
echo "[DONE] Task 5 – Boot Persistence complete."
