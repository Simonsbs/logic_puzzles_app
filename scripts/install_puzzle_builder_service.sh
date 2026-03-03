#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SERVICE_SRC="$ROOT_DIR/deploy/systemd/logic-puzzle-builder.service"
TIMER_SRC="$ROOT_DIR/deploy/systemd/logic-puzzle-builder.timer"
SERVICE_DST="/etc/systemd/system/logic-puzzle-builder.service"
TIMER_DST="/etc/systemd/system/logic-puzzle-builder.timer"

if [[ ! -f "$ROOT_DIR/.env.puzzle_builder" ]]; then
  echo "Missing $ROOT_DIR/.env.puzzle_builder"
  echo "Copy .env.puzzle_builder.example and set real values first."
  exit 1
fi

sudo cp "$SERVICE_SRC" "$SERVICE_DST"
sudo cp "$TIMER_SRC" "$TIMER_DST"
sudo systemctl daemon-reload
sudo systemctl enable --now logic-puzzle-builder.timer
sudo systemctl restart logic-puzzle-builder.timer

echo "Installed. Check status with: systemctl status logic-puzzle-builder.timer"
echo "Manual run: $ROOT_DIR/scripts/run_puzzle_builder.sh --days 1"
