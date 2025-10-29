#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "${EUID}" -ne 0 ]]; then
  echo "This script must be run as root (it installs system packages)." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "[sandboxmcp] Installing base apt packages..."
apt-get update
apt-get install -y \
  xorg xvfb x11vnc openbox novnc websockify \
  python3 python3-pip python3-venv python3-tk \
  git curl docker.io nodejs npm \
  firefox-esr fonts-liberation \
  pipx snapd libgtk-3-0 libnss3 libasound2 \
  wget gnupg

if ! command -v chromium-browser >/dev/null 2>&1 && ! command -v chromium >/dev/null 2>&1; then
  if command -v snap >/dev/null 2>&1; then
    echo "[sandboxmcp] Installing Chromium via snap..."
    snap install chromium --classic || true
  else
    echo "[sandboxmcp] snap not available; install Chromium manually if требуется." >&2
  fi
fi

if ! command -v telegram-desktop >/dev/null 2>&1; then
  if command -v snap >/dev/null 2>&1; then
    echo "[sandboxmcp] Installing Telegram Desktop via snap..."
    snap install telegram-desktop || true
  else
    echo "[sandboxmcp] snap not available; install Telegram Desktop manually." >&2
  fi
fi

echo "[sandboxmcp] Ensuring pipx path..."
pipx ensurepath
export PATH="${HOME}/.local/bin:${PATH}"

echo "[sandboxmcp] Installing pipx applications..."
pipx install --force cua-computer-server
pipx install --force docker-mcp

echo "[sandboxmcp] Installing Node.js global tooling..."
npm install -g @playwright/test @playwright/mcp pnpm

echo "[sandboxmcp] Installing Playwright browsers and dependencies..."
npx --yes playwright install-deps
npx --yes playwright install

echo "[sandboxmcp] Bootstrapping telegram-mcp virtual environment..."
"${REPO_ROOT}/scripts/setup-telegram-mcp.sh"

echo "[sandboxmcp] Bootstrap complete."
