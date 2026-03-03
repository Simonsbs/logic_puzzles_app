#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SERVICE_SRC="$ROOT_DIR/deploy/systemd/logic-admin-manager.service"
SERVICE_DST="/etc/systemd/system/logic-admin-manager.service"

if [[ ! -f "$ROOT_DIR/.env.admin_manager" ]]; then
  echo "Missing $ROOT_DIR/.env.admin_manager"
  echo "Copy .env.admin_manager.example and set real values first."
  exit 1
fi

sudo cp "$SERVICE_SRC" "$SERVICE_DST"
sudo systemctl daemon-reload
sudo systemctl enable --now logic-admin-manager.service
sudo systemctl restart logic-admin-manager.service

echo "Installed. Check status with: systemctl status logic-admin-manager.service"
