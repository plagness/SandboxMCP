# SandboxMCP

Набор инструкций и вспомогательных файлов для подготовки тестовой площадки SandboxMCP на сервере VDS2 (`SANDBOX_DOMAIN`). Стек предназначен для удалённых UI/интеграционных тестов и вспомогательных сервисов агента Codex.

## Цели
- Виртуальный рабочий стол (Xvfb + Openbox + x11vnc + noVNC) под `root`.
- Инструменты для UI-тестов: Playwright (приоритетно) и CUA Computer Server для нативного Telegram Desktop.
- MCP-сервисы: Playwright MCP, Docker MCP, Telegram MCP (через SSH с VDS1), опционально CUA MCP.
- FastAPI-приложение (локально на 127.0.0.1:8100) с проксированием через Caddy.
- Reverse-proxy Caddy с автоматическим TLS на `${SANDBOX_DOMAIN}` (и опциональные поддомены).
- Документация и переменные окружения для быстрого ввода в строй.

## Структура
```
/root/sandboxmcp/
├─ docker-compose.yml        # единый compose для Caddy + FastAPI
├─ .env                      # заполненные переменные (рабочие значения)
├─ .env.example              # шаблон для быстрого старта
├─ caddy/
│  └─ Caddyfile              # маршрутизация, HTTPS, basic auth
├─ fastapi-app/
│  ├─ Dockerfile             # python:3.12-slim + uvicorn
│  ├─ requirements.txt
│  └─ app/main.py            # FastAPI с health-эндпоинтом
├─ policy/
│  └─ decision.yaml          # выбор инструментов (Playwright/CUA/Trigger.dev)
└─ telegram-mcp/             # репозиторий telegram-mcp (+ .venv)
```

## Системные сервисы
- `xvfb.service`, `openbox.service`, `x11vnc.service`, `novnc.service` — обеспечивают графическую среду и доступ через noVNC (работают нативно, вне контейнеров).
- `cua-computer.service` — CUA Computer Server с ENV `DISPLAY=:1` (нативный сервис).

## Быстрый чеклист развёртывания
1. **SSH**: настроить обмен ключами между VDS1 и VDS2 (`/root/.ssh/config`).
2. **Переменные**: `cp .env.example .env`, заполнить домены, хэш пароля, TELEGRAM_* и прочие поля.
3. **Базовые пакеты**: `apt update` и установка Xorg, noVNC, Python, Node.js, Docker, браузеров, Telegram Desktop.
4. **Сервисы**: разместить unit-файлы в `/etc/systemd/system/`, выполнить `systemctl daemon-reload` и `systemctl enable --now ...`.
5. **Caddy + FastAPI**: проверить `caddy/Caddyfile`, затем из `/root/sandboxmcp` выполнить `docker compose up -d` (поднимет FastAPI-контейнер и Caddy с TLS).
6. **CUA Computer Server**: `pipx install cua-computer-server` → `systemctl enable --now cua-computer`, проверить `curl http://127.0.0.1:8000/health` (ожидаем 200, иначе смотреть логи `journalctl -u cua-computer`).
7. **Playwright**: `npm i -g @playwright/test @playwright/mcp`, затем `npx playwright install-deps && npx playwright install`.
8. **Telegram Desktop**: поставить через snap (`snap install telegram-desktop`), выполнить первичную авторизацию под `DISPLAY=:1`.
9. **Telegram MCP**: `python -m venv /root/sandboxmcp/telegram-mcp/.venv && pip install -r requirements.txt`, переменные TELEGRAM_* подтягиваются из корневого `.env`.
10. **Trigger.dev**: `npm i -g pnpm`, подключать SDK в TypeScript-проектах при необходимости.
11. **Проверки**:
    - `https://${SANDBOX_DOMAIN}` — ответ `OK` с валидным SSL.
    - `curl http://127.0.0.1:8000/health` и `curl http://127.0.0.1:8100/health`.
    - `ssh sandbox npx @playwright/mcp@latest --help`.
    - `ssh sandbox docker-mcp --help` и `docker ps`.
    - `ssh sandbox bash -lc ". /root/sandboxmcp/telegram-mcp/.venv/bin/activate && set -a && source /root/sandboxmcp/.env && set +a && python /root/sandboxmcp/telegram-mcp/main.py --help"`.
    - Подтвердить запуск Telegram Desktop под `DISPLAY=:1` (через локальный noVNC или проксирование домена).

## Переменные окружения
- `.env.example` — шаблон. Скопируйте его в `.env` и заполните.
- `.env` — единый источник значений для compose, Caddy, FastAPI, CUA и Telegram MCP. Отдельных `.env` в подпроектах не требуется. Для экспорта значений в текущую сессию используйте `set -a && source ./.env && set +a`.
- Для basic-auth используйте `caddy hash-password --plaintext 'пароль'` и вставьте хэш в `BASIC_AUTH_PASS`.
- Для опциональных поддоменов (`NOVNC_DOMAIN`, `API_DOMAIN`) убедитесь, что в DNS есть записи; иначе оставьте пустыми (ACME не будет пробовать выпускать сертификат).

## Следующие шаги
- Доработать `policy/decision.yaml` (подключение к FastAPI, выдача контекста агенту).
- Подготовить плейбуки/скрипты для автоматизации шагов из чеклиста.
- Согласовать хранение чувствительных секретов (OpenAI, Telegram) в защищённых vault'ах.
- Настроить мониторинг состояния systemd-сервисов и алерты.
