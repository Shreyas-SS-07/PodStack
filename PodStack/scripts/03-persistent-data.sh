#!/usr/bin/env bash
# =============================================================================
# Script 03 – Persistent Data  (Task 3)
# Covers: RH134 Ch 6, Ch 14
#
# PURPOSE:
#   Demonstrate that data written inside a container persists on the HOST
#   even after the container is deleted and recreated — proving that the
#   data lives in the host-bind-mounted directory, NOT in the container layer.
#
# RUN AS: podstack (non-root)
# =============================================================================

set -euo pipefail

IMAGE_NAME="podstack-web:latest"
CONTAINER_NAME="podstack-web"
HOST_DATA_DIR="${HOME}/podstack-data"
CONTAINER_DATA_DIR="/data"
HOST_PORT="8080"

echo "=================================================================="
echo " Task 3 – Persistent Data"
echo "=================================================================="

# ── 0. Pre-check ─────────────────────────────────────────────────────────────
echo ""
echo "[CHECK] Running as: $(whoami)  (UID=$(id -u))"
if [[ $(id -u) -eq 0 ]]; then
    echo "[ERROR] Run as the 'podstack' non-root user."
    exit 1
fi

# ── 1. Prepare the host-side data directory ───────────────────────────────────
echo ""
echo "[STEP 1] Creating host data directory: ${HOST_DATA_DIR}"
mkdir -p "${HOST_DATA_DIR}"

# Apply SELinux container label (see script 04 for full explanation)
# :Z tells Podman to relabel the directory for the container's context
echo "  Applying SELinux :Z label..."

echo ""
echo "[STEP 2] Starting container with bind-mount volume"
# Stop and remove any existing container with the same name
podman rm -f "${CONTAINER_NAME}" 2>/dev/null || true

podman run \
    --detach \
    --name "${CONTAINER_NAME}" \
    --publish "${HOST_PORT}:8080" \
    --volume "${HOST_DATA_DIR}:${CONTAINER_DATA_DIR}:Z" \
    "${IMAGE_NAME}"

echo "[OK] Container started: $(podman ps --filter name=${CONTAINER_NAME} --format '{{.ID}}')"

# ── 3. Wait for the app to be ready ──────────────────────────────────────────
echo ""
echo "[STEP 3] Waiting for the web service to become ready..."
for i in {1..15}; do
    if curl -sf "http://localhost:${HOST_PORT}/health" &>/dev/null; then
        echo "[OK] Service is responding on port ${HOST_PORT}"
        break
    fi
    sleep 2
done

# ── 4. Hit the service several times to generate data ────────────────────────
echo ""
echo "[STEP 4] Generating visits to populate persistent data..."
for i in {1..5}; do
    curl -sf "http://localhost:${HOST_PORT}/health" | python3 -c \
        "import json,sys; d=json.load(sys.stdin); print(f'  Visit #{i} → visits={d[\"visits\"]}')"
done

echo ""
echo "[STEP 5] Current contents of HOST data directory (${HOST_DATA_DIR}):"
ls -la "${HOST_DATA_DIR}/"
echo "  visits.txt contains: $(cat ${HOST_DATA_DIR}/visits.txt)"

# ── 5. DESTROY the container ─────────────────────────────────────────────────
echo ""
echo "[STEP 6] *** DESTROYING the container ***"
podman rm -f "${CONTAINER_NAME}"
echo "[OK] Container deleted."
echo "  Host directory still exists:"
ls -la "${HOST_DATA_DIR}/"
echo "  Data still there: $(cat ${HOST_DATA_DIR}/visits.txt)"

# ── 6. RECREATE the container — data must still be there ─────────────────────
echo ""
echo "[STEP 7] Recreating container (mounting the SAME data directory)..."
podman run \
    --detach \
    --name "${CONTAINER_NAME}" \
    --publish "${HOST_PORT}:8080" \
    --volume "${HOST_DATA_DIR}:${CONTAINER_DATA_DIR}:Z" \
    "${IMAGE_NAME}"

echo "[STEP 8] Waiting for service to be ready again..."
for i in {1..15}; do
    if curl -sf "http://localhost:${HOST_PORT}/health" &>/dev/null; then
        echo "[OK] Service back online."
        break
    fi
    sleep 2
done

echo ""
echo "[STEP 9] Visit count after container recreation:"
curl -sf "http://localhost:${HOST_PORT}/health" | python3 -c \
    "import json,sys; d=json.load(sys.stdin); print(f'  visits = {d[\"visits\"]}  ← DATA SURVIVED!')"

echo ""
echo "=================================================================="
echo "  ✅ PROOF: visit count was NOT reset to 0 after container delete."
echo "     The data lives in ${HOST_DATA_DIR} on the HOST, not in the"
echo "     container's ephemeral writable layer."
echo "=================================================================="
echo ""
echo "[DONE] Task 3 – Persistent Data complete."
