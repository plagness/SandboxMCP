#!/usr/bin/env bash
set -euo pipefail

INSTANCE="${1:-1}"
ENV_FILE="/etc/sandboxmcp/visual.env"
if [[ -f "${ENV_FILE}" ]]; then
  source "${ENV_FILE}"
fi

DISPLAY_NUM=":${INSTANCE}"
export DISPLAY="${DISPLAY_NUM}"
export QT_OPENGL="${QT_OPENGL:-software}"
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"

exec /usr/bin/startxfce4
