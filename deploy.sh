#!/usr/bin/env bash
set -euo pipefail

SERVER="192.168.5.118"
REMOTE_DIR="~/docker/media-shelf"
EXCLUDES=(
  --exclude='.git'
  --exclude='.env'
  --exclude='node_modules'
  --exclude='__pycache__'
  --exclude='.venv'
  --exclude='*.pyc'
)

echo "==> Pushing to GitHub..."
git push origin main

echo ""
echo "==> Syncing files to server..."
rsync -avz --delete "${EXCLUDES[@]}" ./ "${SERVER}:${REMOTE_DIR}/"

echo ""
echo "==> Rebuilding containers on server..."
ssh "${SERVER}" "cd ${REMOTE_DIR} && docker compose up -d --build"

echo ""
echo "==> Deploy complete!"
