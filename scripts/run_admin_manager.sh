#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env.admin_manager"
VENV_DIR="$ROOT_DIR/.venv-admin-manager"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  echo "Copy .env.admin_manager.example and set real values first."
  exit 1
fi

if [[ ! -d "$VENV_DIR" ]]; then
  python3 -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"
pip install --disable-pip-version-check -q -r "$ROOT_DIR/admin_manager/requirements.txt"

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

python "$ROOT_DIR/admin_manager/app.py"
