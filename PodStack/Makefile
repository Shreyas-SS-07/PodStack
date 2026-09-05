# =============================================================================
# PodStack Makefile
# RH134 Ch 6, 14, 17 | RH124 Ch 16
# Standard Automation for RHEL Rootless Container Platform
# =============================================================================

.PHONY: all help user build run stop restart status verify stress reboot-check clean

SHELL := /bin/bash

all: help

help:
	@echo "=================================================================="
	@echo " PodStack Container Platform Automation"
	@echo "=================================================================="
	@echo "  make user          - [ROOT] Setup unprivileged service user (Task 1)"
	@echo "  make build         - [USER] Build custom UBI9 container image (Task 2)"
	@echo "  make run           - [USER] Deploy services with persistent volume (Task 3)"
	@echo "  make selinux       - [USER] Audit and apply SELinux :Z fix (Task 4)"
	@echo "  make systemd       - [USER] Install & enable systemd user units (Task 5)"
	@echo "  make firewall      - [ROOT] Open port 8080/tcp in firewalld (Task 6)"
	@echo "  make cgroups       - [USER] Run resource limit validation (Task 7)"
	@echo "  make multi         - [USER] Deploy full 3-service architecture"
	@echo "  make verify        - [USER] Run complete automated test suite"
	@echo "  make stress        - [USER] Run CPU/memory cgroup throttling test"
	@echo "  make status        - [USER] Display platform live status"
	@echo "  make clean         - [USER] Tear down containers and user units"

user:
	@echo "==> Setting up dedicated rootless user 'podstack'..."
	sudo bash scripts/01-setup-user.sh

build:
	@echo "==> Building custom image localhost/podstack-web:latest..."
	bash scripts/02-image-management.sh

run:
	@echo "==> Running container with host-mounted volume..."
	bash scripts/03-persistent-data.sh

selinux:
	@echo "==> Demonstrating SELinux denial and :Z resolution..."
	bash scripts/04-selinux-fix.sh

systemd:
	@echo "==> Configuring systemd user units and lingering..."
	bash scripts/05-boot-persistence.sh

firewall:
	@echo "==> Exposing service port in firewalld..."
	bash scripts/06-network-exposure.sh

cgroups:
	@echo "==> Enforcing memory & CPU resource limits..."
	bash scripts/07-resource-limits.sh

multi:
	@echo "==> Deploying 3-tier microservice architecture..."
	bash scripts/08-multi-service.sh

verify:
	@echo "==> Running full 7-task verification test suite..."
	bash scripts/verify-all.sh

stress:
	@echo "==> Executing cgroup throttling benchmark..."
	bash scripts/stress-test.sh

status:
	@./bin/podstack status

clean:
	@./bin/podstack clean
