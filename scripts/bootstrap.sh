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
  python3 python3-pip python3-venv python3-tk \
  git curl docker.io nodejs npm \
  fonts-liberation \
  pipx snapd libgtk-3-0 libnss3 libasound2 \
  wget gnupg

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
