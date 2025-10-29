#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${REPO_ROOT}/telegram-mcp"
VENV_DIR="${APP_DIR}/.venv"

export PATH="${HOME}/.local/bin:${PATH}"

if [[ ! -d "${VENV_DIR}" ]]; then
  echo "[sandboxmcp] telegram-mcp venv missing, bootstrapping..."
  "${REPO_ROOT}/scripts/setup-telegram-mcp.sh"
fi

if [[ -f "${REPO_ROOT}/.env" ]]; then
  set -a
  source "${REPO_ROOT}/.env"
  set +a
fi

for var in TELEGRAM_API_ID TELEGRAM_API_HASH TELEGRAM_SESSION_STRING; do
  if [[ -z "${!var:-}" ]]; then
    echo "[sandboxmcp] ${var} не задан. Добавьте значение в .env перед запуском telegram-mcp." >&2
    exit 1
  fi
done

source "${VENV_DIR}/bin/activate"
exec python "${APP_DIR}/main.py" "$@"
