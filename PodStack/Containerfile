# ─────────────────────────────────────────────────────────────────────────────
# Containerfile – PodStack Demo Web Application
# Task 2: Custom image built from a Containerfile
# Covers: RH134 Ch 6  – Building images with Podman
# ─────────────────────────────────────────────────────────────────────────────

# Use the official UBI 9 minimal base image (Red Hat Universal Base Image)
# UBI is free, redistributable, and ideal for RHEL-based environments.
FROM registry.access.redhat.com/ubi9/python-311:latest

# --------------------------------------------------------------------------- #
# Image metadata labels (OCI standard)
# --------------------------------------------------------------------------- #
LABEL maintainer="podstack-team"
LABEL description="PodStack Demo – Rootless container platform capstone"
LABEL version="1.0.0"
LABEL org.opencontainers.image.title="podstack-web"
LABEL org.opencontainers.image.description="Rootless Flask web service for PodStack capstone"

# --------------------------------------------------------------------------- #
# Application setup
# --------------------------------------------------------------------------- #

# Switch to root temporarily to install packages
USER root

# Install any OS-level packages if needed (none required for python311 UBI)
# Kept as an example of how you would add packages:
# RUN dnf install -y <package> && dnf clean all

# Create a dedicated non-root application user inside the container
# UID 1001 avoids conflicts with the host podstack user (UID 1000)
RUN useradd --uid 1001 --gid 0 --no-create-home --shell /sbin/nologin appuser

# Create the data directory that will be mounted as a persistent volume
RUN mkdir -p /data && chown 1001:0 /data && chmod 0770 /data

# Set working directory
WORKDIR /app

# Copy dependency manifest first (leverages Docker/Podman layer cache)
COPY app/requirements.txt ./requirements.txt

# Install Python dependencies as root before switching users
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy application source code
COPY app/app.py ./app.py

# Adjust ownership so appuser can read/exec
RUN chown -R 1001:0 /app && chmod -R g=u /app

# --------------------------------------------------------------------------- #
# Security: drop root, run as non-privileged appuser
# --------------------------------------------------------------------------- #
USER 1001

# --------------------------------------------------------------------------- #
# Runtime configuration
# --------------------------------------------------------------------------- #

# Document which port the application listens on
EXPOSE 8080

# Persistent data volume mount point
VOLUME ["/data"]

# Health-check: Podman/Kubernetes will poll /health every 30 s
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

# Start the application with Gunicorn (production-grade WSGI server)
# --workers 2  → 2 worker processes (appropriate for a single-core VM)
# --bind       → listen on all interfaces, port 8080
# --access-logfile - → log to stdout so Podman/journald captures it
CMD ["gunicorn", "--workers", "2", "--bind", "0.0.0.0:8080", \
     "--access-logfile", "-", "--error-logfile", "-", "app:app"]
