#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "This script must be run as root." >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT_SOURCE="${REPO_ROOT}/systemd"
UNIT_TARGET="/etc/systemd/system"

UNITS=(
  xvfb.service
  openbox.service
  x11vnc.service
  novnc.service
  cua-computer.service
)

for unit in "${UNITS[@]}"; do
  install -m 0644 "${UNIT_SOURCE}/${unit}" "${UNIT_TARGET}/${unit}"
done

systemctl daemon-reload
systemctl enable --now xvfb.service openbox.service x11vnc.service novnc.service cua-computer.service

echo "[sandboxmcp] Systemd units installed and started."
