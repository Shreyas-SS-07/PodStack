#!/usr/bin/env bash
# =============================================================================
# Script 07 – Resource Awareness  (Task 7)
# Covers: RH134 Ch 6
#
# PURPOSE:
#   Apply memory and CPU limits to the container using cgroups via Podman
#   flags, and demonstrate the limits taking effect.
#
# RUN AS: podstack (non-root)
# NOTE: Rootless cgroup v2 is required; verify with:
#       cat /sys/fs/cgroup/cgroup.controllers
# =============================================================================

set -euo pipefail

IMAGE_NAME="podstack-web:latest"
CONTAINER_NAME="podstack-limited"
HOST_PORT="8081"     # Use 8081 to avoid conflict with the main service
MEMORY_LIMIT="256m"  # 256 MiB
CPU_LIMIT="0.5"      # 50% of one CPU core

echo "=================================================================="
echo " Task 7 – Resource Awareness (Memory + CPU Limits)"
echo "=================================================================="

echo ""
echo "[CHECK] Running as: $(whoami)  (UID=$(id -u))"
if [[ $(id -u) -eq 0 ]]; then
    echo "[ERROR] Run as the 'podstack' non-root user."
    exit 1
fi

# ── 0. Verify cgroup v2 is available (required for rootless limits) ──────────
echo ""
echo "[STEP 0] Checking cgroup version..."
if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
    echo "[OK] cgroup v2 is available."
    echo "  Available controllers: $(cat /sys/fs/cgroup/cgroup.controllers)"
else
    echo "[WARN] cgroup v2 not detected. Memory/CPU limits may not work in"
    echo "  rootless mode without enabling cgroup v2 delegation."
    echo ""
    echo "  To enable cgroup v2 on RHEL 9:"
    echo "    sudo grubby --update-kernel=ALL \\"
    echo "         --args='systemd.unified_cgroup_hierarchy=1'"
    echo "    sudo reboot"
fi

# ── 1. Start a resource-limited container ─────────────────────────────────────
echo ""
echo "[STEP 1] Starting resource-limited container..."
echo "  --memory=${MEMORY_LIMIT}  → Hard memory limit"
echo "  --memory-swap=${MEMORY_LIMIT}  → Disable swap (memory = total limit)"
echo "  --cpus=${CPU_LIMIT}        → Max 0.5 CPU cores"
echo "  --cpu-shares=512           → Relative CPU weight (default=1024)"
echo ""

podman rm -f "${CONTAINER_NAME}" 2>/dev/null || true

podman run \
    --detach \
    --name "${CONTAINER_NAME}" \
    --publish "${HOST_PORT}:8080" \
    --volume "${HOME}/podstack-data:/data:Z" \
    --memory="${MEMORY_LIMIT}" \
    --memory-swap="${MEMORY_LIMIT}" \
    --cpus="${CPU_LIMIT}" \
    --cpu-shares=512 \
    "${IMAGE_NAME}"

echo "[OK] Container '${CONTAINER_NAME}' started with resource limits."

# ── 2. Inspect the resource limits ───────────────────────────────────────────
echo ""
echo "[STEP 2] Inspect resource limits via podman inspect:"
podman inspect "${CONTAINER_NAME}" | python3 -c "
import json, sys
data = json.load(sys.stdin)[0]
hc = data.get('HostConfig', {})
print(f'  Memory limit    : {hc.get(\"Memory\", 0) // 1024 // 1024} MiB')
print(f'  MemorySwap limit: {hc.get(\"MemorySwap\", 0) // 1024 // 1024} MiB')
print(f'  NanoCPUs        : {hc.get(\"NanoCpus\", 0) / 1e9} CPUs')
print(f'  CPU shares      : {hc.get(\"CpuShares\", 0)}')
"

# ── 3. Check cgroup files directly ──────────────────────────────────────────
echo ""
echo "[STEP 3] Verify limits in cgroup filesystem (cgroup v2):"
CGROUP_PATH="/sys/fs/cgroup/user.slice/user-$(id -u).slice/user@$(id -u).service"

# Find the container cgroup
CTR_CGROUP=$(podman inspect "${CONTAINER_NAME}" \
    --format '{{.State.CgroupPath}}' 2>/dev/null || echo "")

if [[ -n "${CTR_CGROUP}" ]] && [[ -f "${CTR_CGROUP}/memory.max" ]]; then
    echo "  Container cgroup path: ${CTR_CGROUP}"
    MEMORY_MAX=$(cat "${CTR_CGROUP}/memory.max")
    echo "  memory.max = ${MEMORY_MAX} bytes ($(( MEMORY_MAX / 1024 / 1024 )) MiB)"
    echo "  cpu.max = $(cat "${CTR_CGROUP}/cpu.max" 2>/dev/null || echo 'N/A')"
else
    echo "  [NOTE] Cgroup path not directly accessible in this environment."
    echo "  On a running RHEL system, check:"
    echo "    cat /sys/fs/cgroup/user.slice/.../memory.max"
    echo "    cat /sys/fs/cgroup/user.slice/.../cpu.max"
fi

# ── 4. Show container stats ──────────────────────────────────────────────────
echo ""
echo "[STEP 4] Container resource usage (podman stats, 3 samples):"
for i in 1 2 3; do
    echo "  Sample ${i}:"
    podman stats --no-stream "${CONTAINER_NAME}" \
        --format "    CPU: {{.CPUPerc}}  MEM: {{.MemUsage}} / {{.MemPerc}}" \
        2>/dev/null || echo "    (stats not available)"
    sleep 1
done

# ── 5. Demonstrate memory limit enforcement ──────────────────────────────────
echo ""
echo "[STEP 5] Memory limit enforcement demonstration:"
echo "  Attempting to allocate memory WITHIN the limit (should succeed)..."
podman exec "${CONTAINER_NAME}" python3 -c "
data = bytearray(100 * 1024 * 1024)  # 100 MiB
print(f'  [OK] Allocated 100 MiB successfully (within 256 MiB limit)')
" 2>/dev/null || echo "  [INFO] Exec not available in this state."

echo ""
echo "[STEP 6] Cleanup — stopping the test container..."
podman stop "${CONTAINER_NAME}"
podman rm "${CONTAINER_NAME}"
echo "[OK] Cleaned up '${CONTAINER_NAME}'."

echo ""
echo "=================================================================="
echo " Summary of Resource Limit Flags"
echo "=================================================================="
cat <<'SUMMARY'

  Flag                  | Effect
  ──────────────────────+────────────────────────────────────────────────
  --memory=256m         | Hard limit: container cannot allocate more than
                        | 256 MiB of RAM. If exceeded, the kernel OOM
                        | killer terminates the container process.
  --memory-swap=256m    | Total memory + swap limit. Setting it equal to
                        | --memory effectively disables swap for the
                        | container, preventing slow memory overuse.
  --cpus=0.5            | Limits the container to at most 50% of one CPU.
                        | Implemented via CFS bandwidth control in cgroup.
  --cpu-shares=512      | Relative weight (default=1024). When CPUs are
                        | contested, this container gets half the share of
                        | a container at default weight.
  ──────────────────────+────────────────────────────────────────────────

SUMMARY
echo "[DONE] Task 7 – Resource Awareness complete."
