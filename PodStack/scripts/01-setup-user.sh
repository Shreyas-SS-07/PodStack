#!/usr/bin/env bash
# =============================================================================
# Script 01 – Rootless Setup  (Task 1)
# Covers: RH134 Ch 6, RH124 Ch 16
#
# PURPOSE:
#   Create a dedicated non-root service account "podstack" and verify that
#   Podman can run containers without any root privileges.
#
# RUN AS:  root  (only this script needs root — all others run as podstack)
# =============================================================================

set -euo pipefail

PODSTACK_USER="podstack"
PODSTACK_HOME="/home/${PODSTACK_USER}"

echo "=================================================================="
echo " Task 1 – Rootless Setup"
echo "=================================================================="

# ── 1. Create the non-root service account ──────────────────────────────────
if id "${PODSTACK_USER}" &>/dev/null; then
    echo "[INFO] User '${PODSTACK_USER}' already exists — skipping creation."
else
    useradd \
        --create-home \
        --home-dir "${PODSTACK_HOME}" \
        --shell /bin/bash \
        --comment "PodStack service account" \
        "${PODSTACK_USER}"
    echo "[OK] Created user '${PODSTACK_USER}' (UID=$(id -u ${PODSTACK_USER}))"
fi

# ── 2. Assign subordinate UID/GID ranges (required for rootless Podman) ──────
# These ranges let the container runtime map a range of UIDs inside the
# container to unprivileged UIDs on the host — the core of rootless operation.
if ! grep -q "^${PODSTACK_USER}:" /etc/subuid 2>/dev/null; then
    usermod --add-subuids 100000-165535 "${PODSTACK_USER}"
    echo "[OK] Assigned subUID range 100000-165535 to '${PODSTACK_USER}'"
fi

if ! grep -q "^${PODSTACK_USER}:" /etc/subgid 2>/dev/null; then
    usermod --add-subgids 100000-165535 "${PODSTACK_USER}"
    echo "[OK] Assigned subGID range 100000-165535 to '${PODSTACK_USER}'"
fi

# ── 3. Enable lingering so user systemd units survive logout ─────────────────
# Without lingering, all user-level systemd services are killed when the
# user's last session ends.
loginctl enable-linger "${PODSTACK_USER}"
echo "[OK] Lingering enabled for '${PODSTACK_USER}'"

# ── 4. Install Podman if not already present ─────────────────────────────────
if ! command -v podman &>/dev/null; then
    echo "[INFO] Installing Podman..."
    dnf install -y podman
else
    echo "[OK] Podman already installed: $(podman --version)"
fi

echo ""
echo "=================================================================="
echo " Verification – switch to '${PODSTACK_USER}' and run the checks"
echo "=================================================================="
echo ""
echo "  sudo -i -u ${PODSTACK_USER}"
echo ""
echo "  # 1. Confirm you are NOT root:"
echo "  whoami && id"
echo ""
echo "  # 2. Run a test container (rootless):"
echo "  podman run --rm registry.access.redhat.com/ubi9/ubi:latest id"
echo ""
echo "  # 3. Confirm no root in process tree:"
echo "  podman run -d --name rootless-test ubi9/ubi:latest sleep 300"
echo "  ps -aux | grep 'sleep 300'    # UID column shows '${PODSTACK_USER}', not root"
echo "  podman stop rootless-test"
echo ""
echo "  # 4. Check Podman info for rootless confirmation:"
echo "  podman info | grep -A3 'rootless'"
echo ""
echo "[DONE] Task 1 setup complete."
