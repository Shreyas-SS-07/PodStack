#!/usr/bin/env bash
# =============================================================================
# Script 04 – SELinux Integration  (Task 4)
# Covers: RH134 Ch 6, Ch 17
#
# PURPOSE:
#   Demonstrate the SELinux denial that occurs when mounting host storage
#   into a container WITHOUT proper labelling, then fix it using the :Z
#   mount option and explain what it does.
#
# RUN AS: podstack (non-root)
# =============================================================================

set -euo pipefail

IMAGE_NAME="podstack-web:latest"
HOST_DATA_DIR="${HOME}/podstack-data"

echo "=================================================================="
echo " Task 4 – SELinux Integration"
echo "=================================================================="

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " PART A – Reproduce the SELinux AVC denial (without :Z)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p "${HOST_DATA_DIR}"

echo ""
echo "[INFO] SELinux context of host directory BEFORE labelling:"
ls -lZd "${HOST_DATA_DIR}"
echo "  ↑ Context is likely 'user_home_t' or 'default_t' — NOT container-safe"

echo ""
echo "[INFO] What would happen without :Z ?"
echo "  If you run:"
echo "    podman run --volume ${HOST_DATA_DIR}:/data <image>"
echo "  SELinux enforces that the container process (running with 'container_t'"
echo "  label) may NOT read or write directories labelled 'user_home_t'."
echo ""
echo "  The denial appears in the audit log:"
echo "    sudo ausearch -m avc -ts recent | grep container_t"
echo ""
echo "  Example AVC denial (what you would see):"
cat <<'AVC_EXAMPLE'
  type=AVC msg=audit(...): avc: denied { write } for
    pid=12345 comm="python3"
    path="/home/podstack/podstack-data/visits.txt"
    scontext=system_u:system_r:container_t:s0:c123,c456
    tcontext=unconfined_u:object_r:user_home_t:s0
    tclass=file permissive=0
AVC_EXAMPLE

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " PART B – The Fix: using the :Z mount option"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "[STEP 1] Apply the correct SELinux context using chcon (manual method):"
echo "  Command:  chcon -Rt svirt_sandbox_file_t ${HOST_DATA_DIR}"
echo ""
echo "  OR use the :Z shorthand directly in the --volume flag (preferred):"
echo "  Command:  podman run --volume ${HOST_DATA_DIR}:/data:Z ..."
echo ""
echo "  The :Z option tells Podman to automatically run:"
echo "    chcon -Rt svirt_sandbox_file_t <host-path>"
echo "  before mounting the directory into the container."
echo ""

echo "[STEP 2] Demonstrate chcon manually and show context change:"
# Only run chcon if sestatus shows SELinux is enforcing/permissive
if command -v sestatus &>/dev/null && sestatus | grep -q "enabled"; then
    echo "  Before:"
    ls -lZd "${HOST_DATA_DIR}"
    chcon -Rt svirt_sandbox_file_t "${HOST_DATA_DIR}" 2>/dev/null || \
        echo "  [NOTE] chcon requires SELinux to be enabled; skipping in demo."
    echo "  After:"
    ls -lZd "${HOST_DATA_DIR}"
else
    echo "  [NOTE] SELinux is not enabled in this environment."
    echo "  On a live RHEL system, you would see the context change from:"
    echo "    user_home_t  →  svirt_sandbox_file_t"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " PART C – Explanation of :Z vs :z"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat <<'EXPLANATION'

  Option  | What it does
  --------+------------------------------------------------------------------
  :z      | Sets the SELinux label to a SHARED label (svirt_sandbox_file_t)
          | that ALL containers on the host can read. Appropriate for shared
          | read-only content (e.g., a config directory used by many pods).
          |
  :Z      | Sets the SELinux label to a PRIVATE label (svirt_sandbox_file_t
          | with a unique MCS pair like s0:c123,c456) that ONLY this specific
          | container can access. Appropriate for data that must be isolated
          | to one container — our use case (writes visit counts privately).
  --------+------------------------------------------------------------------

  Why does SELinux enforce this at all?
  ──────────────────────────────────────
  SELinux uses Mandatory Access Control (MAC). Even if a process has
  Unix DAC (file permission bits) to access a path, SELinux can still
  block it based on TYPE enforcement rules.

  Containers run with the 'container_t' process type. By default, a home
  directory has type 'user_home_t'. The SELinux policy has NO allow rule
  for: container_t → write → user_home_t.

  Applying :Z relabels the directory to 'svirt_sandbox_file_t', for which
  the policy DOES have an allow rule:
    allow container_t svirt_sandbox_file_t:dir { read write ... };

  Relevant SELinux commands for troubleshooting:
    sudo ausearch -m avc -ts recent          # view recent AVC denials
    sudo sealert -a /var/log/audit/audit.log # human-readable explanation
    ls -lZ <path>                            # show file SELinux context
    ps -eZ | grep podman                     # show process context

EXPLANATION

echo "[DONE] Task 4 – SELinux Integration complete."
