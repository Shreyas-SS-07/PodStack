#!/usr/bin/env bash
# =============================================================================
# Automated GitHub Push Script for PodStack
# Usage: ./push_to_github.sh <YOUR_GITHUB_USERNAME>
# =============================================================================

set -e

if [ -z "${1:-}" ]; then
    echo "Usage: ./push_to_github.sh <YOUR_GITHUB_USERNAME>"
    echo "Example: ./push_to_github.sh john-doe"
    exit 1
fi

GITHUB_USER="$1"
REPO_URL="https://github.com/${GITHUB_USER}/PodStack.git"

echo "=================================================================="
echo " Pushing PodStack to GitHub: ${REPO_URL}"
echo "=================================================================="

# Initialize git if needed
if [ ! -d ".git" ]; then
    git init
    git branch -M main
fi

git add .
git commit -m "feat: complete PodStack enterprise container platform capstone" || true
git remote remove origin 2>/dev/null || true
git remote add origin "${REPO_URL}"

echo "Pushing to main branch..."
git push -u origin main

echo ""
echo "=================================================================="
echo " ✅ PUSH SUCCESSFUL!"
echo " Visit your live repository at: https://github.com/${GITHUB_USER}/PodStack"
echo "=================================================================="
