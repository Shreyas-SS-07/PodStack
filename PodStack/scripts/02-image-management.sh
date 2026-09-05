#!/usr/bin/env bash
# =============================================================================
# Script 02 – Image Management  (Task 2)
# Covers: RH134 Ch 6
#
# PURPOSE:
#   - Pull a base image from a public registry
#   - Inspect the pulled image
#   - Build a custom image from our Containerfile
#   - Tag and verify the final image
#
# RUN AS: podstack (non-root)
# =============================================================================

set -euo pipefail

# ── Paths (all relative to project root — adjust if needed) ──────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

IMAGE_NAME="podstack-web"
IMAGE_TAG="1.0.0"
BASE_IMAGE="registry.access.redhat.com/ubi9/python-311:latest"

echo "=================================================================="
echo " Task 2 – Image Management"
echo "=================================================================="

# ── 1. Confirm we are NOT root ───────────────────────────────────────────────
echo ""
echo "[CHECK] Running as: $(whoami)  (UID=$(id -u))"
if [[ $(id -u) -eq 0 ]]; then
    echo "[ERROR] This script must NOT be run as root for a rootless demo."
    exit 1
fi

# ── 2. Pull the base image ───────────────────────────────────────────────────
echo ""
echo "[STEP 1] Pulling base image: ${BASE_IMAGE}"
podman pull "${BASE_IMAGE}"
echo "[OK] Pull complete."

# ── 3. Inspect the pulled image ──────────────────────────────────────────────
echo ""
echo "[STEP 2] Inspecting base image..."
echo "--- Image layers and configuration (key fields) ---"
podman inspect "${BASE_IMAGE}" | python3 -c "
import json, sys
data = json.load(sys.stdin)[0]
print(f'  ID          : {data[\"Id\"][:24]}...')
print(f'  Created     : {data[\"Created\"]}')
print(f'  Architecture: {data[\"Architecture\"]}')
print(f'  OS          : {data[\"Os\"]}')
print(f'  Layers      : {len(data[\"RootFS\"][\"Layers\"])}')
print(f'  Exposed Port: {list(data[\"Config\"].get(\"ExposedPorts\", {}).keys())}')
print(f'  EntryPoint  : {data[\"Config\"].get(\"Entrypoint\", [])}')
print(f'  CMD         : {data[\"Config\"].get(\"Cmd\", [])}')
print(f'  Labels:')
for k,v in (data[\"Config\"].get(\"Labels\") or {}).items():
    print(f'    {k}: {v}')
"

# ── 4. Build our custom image from the Containerfile ─────────────────────────
echo ""
echo "[STEP 3] Building custom image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "  Containerfile: ${PROJECT_ROOT}/Containerfile"

podman build \
    --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
    --tag "${IMAGE_NAME}:latest" \
    --file "${PROJECT_ROOT}/Containerfile" \
    "${PROJECT_ROOT}"

echo "[OK] Build complete."

# ── 5. Verify the built image ────────────────────────────────────────────────
echo ""
echo "[STEP 4] Local images (filtered to podstack):"
podman images | grep "${IMAGE_NAME}" || true

echo ""
echo "[STEP 5] Inspect custom image – key metadata:"
podman inspect "${IMAGE_NAME}:${IMAGE_TAG}" | python3 -c "
import json, sys
data = json.load(sys.stdin)[0]
print(f'  ID          : {data[\"Id\"][:24]}...')
print(f'  Size        : {data[\"Size\"] // 1024 // 1024} MB')
print(f'  Layers      : {len(data[\"RootFS\"][\"Layers\"])}')
print(f'  User        : {data[\"Config\"].get(\"User\", \"root\")}')
print(f'  Exposed Port: {list(data[\"Config\"].get(\"ExposedPorts\", {}).keys())}')
print(f'  Volumes     : {list(data[\"Config\"].get(\"Volumes\", {}).keys())}')
labels = data[\"Config\"].get(\"Labels\") or {}
print(f'  Labels:')
for k,v in labels.items():
    print(f'    {k}: {v}')
"

echo ""
echo "[DONE] Task 2 – Image Management complete."
echo "  Next: run script 03-persistent-data.sh"
