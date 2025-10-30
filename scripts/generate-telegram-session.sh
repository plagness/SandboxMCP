#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"
VENV_DIR="${REPO_ROOT}/telegram-mcp/.venv"
PYTHON_BIN="${VENV_DIR}/bin/python"
PIP_BIN="${VENV_DIR}/bin/pip"

if [[ ! -d "${VENV_DIR}" ]]; then
  echo "[tg-session] Telegram MCP venv не найден. Запускаю setup..." >&2
  "${REPO_ROOT}/scripts/setup-telegram-mcp.sh"
fi

if [[ ! -x "${PYTHON_BIN}" ]]; then
  echo "[tg-session] Не удалось найти python в ${VENV_DIR}." >&2
  exit 1
fi

# Убедимся, что установлен telethon.
if ! "${PIP_BIN}" show telethon >/dev/null 2>&1; then
  echo "[tg-session] Устанавливаю telethon в .venv..." >&2
  "${PIP_BIN}" install --upgrade telethon >/dev/null
fi

API_ID_FROM_ENV=""
API_HASH_FROM_ENV=""
if [[ -f "${ENV_FILE}" ]]; then
  API_ID_FROM_ENV=$(grep '^TELEGRAM_API_ID=' "${ENV_FILE}" | head -n1 | cut -d'=' -f2- || true)
  API_HASH_FROM_ENV=$(grep '^TELEGRAM_API_HASH=' "${ENV_FILE}" | head -n1 | cut -d'=' -f2- || true)
fi

read -rp "Введите TELEGRAM_API_ID [${API_ID_FROM_ENV:-enter manually}]: " INPUT_API_ID
API_ID="${INPUT_API_ID:-${API_ID_FROM_ENV}}"
if [[ -z "${API_ID}" ]]; then
  echo "[tg-session] TELEGRAM_API_ID обязателен." >&2
  exit 1
fi

read -rp "Введите TELEGRAM_API_HASH [${API_HASH_FROM_ENV:-enter manually}]: " INPUT_API_HASH
API_HASH="${INPUT_API_HASH:-${API_HASH_FROM_ENV}}"
if [[ -z "${API_HASH}" ]]; then
  echo "[tg-session] TELEGRAM_API_HASH обязателен." >&2
  exit 1
fi

SESSION_STRING=$("${PYTHON_BIN}" - <<PY
from telethon.sync import TelegramClient
from telethon.sessions import StringSession

api_id = int(${API_ID})
api_hash = "${API_HASH}"

with TelegramClient(StringSession(), api_id, api_hash) as client:
    print(client.session.save())
PY
)

if [[ -z "${SESSION_STRING}" ]]; then
  echo "[tg-session] Не удалось получить строку сессии." >&2
  exit 1
fi

cat <<INFO

----
Добавьте в .env:
TELEGRAM_API_ID=${API_ID}
TELEGRAM_API_HASH=${API_HASH}
TELEGRAM_SESSION_NAME=telegram_session
TELEGRAM_SESSION_STRING=${SESSION_STRING}
----

Обратите внимание: TELEGRAM_SESSION_STRING содержит доступ к аккаунту — храните как секрет и не коммитьте.
INFO

read -rp "Записать значения в ${ENV_FILE}? [y/N]: " answer
case "${answer}" in
  [yY][eE][sS]|[yY])
    cp "${ENV_FILE}" "${ENV_FILE}.bak.$(date +%s)"
    # Удаляем предыдущие строки, если есть
    grep -v '^TELEGRAM_API_ID=' "${ENV_FILE}" | \
    grep -v '^TELEGRAM_API_HASH=' | \
    grep -v '^TELEGRAM_SESSION_NAME=' | \
    grep -v '^TELEGRAM_SESSION_STRING=' > "${ENV_FILE}.tmp"
    mv "${ENV_FILE}.tmp" "${ENV_FILE}"
    {
      echo "TELEGRAM_API_ID=${API_ID}"
      echo "TELEGRAM_API_HASH=${API_HASH}"
      echo "TELEGRAM_SESSION_NAME=telegram_session"
      echo "TELEGRAM_SESSION_STRING=${SESSION_STRING}"
    } >> "${ENV_FILE}"
    chmod 600 "${ENV_FILE}"
    echo "[tg-session] Значения добавлены в ${ENV_FILE} (резервная копия сохранена)."
    ;;
  *)
    echo "[tg-session] Значения не записаны. Добавьте вручную."
    ;;
 esac
