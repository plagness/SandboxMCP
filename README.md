# SandboxMCP

Набор инструкций и вспомогательных файлов для подготовки тестовой площадки SandboxMCP на сервере VDS2 (`SANDBOX_DOMAIN`). Стек предназначен для удалённых UI/интеграционных тестов и вспомогательных сервисов агента Codex.

## Цели
- Виртуальный рабочий стол (Xvfb + Openbox + x11vnc + noVNC) под `root`.
- Инструменты для UI-тестов: Playwright (приоритетно) и CUA Computer Server для нативного Telegram Desktop.
- MCP-сервисы: Playwright MCP, Docker MCP, Telegram MCP (через SSH с VDS1), опционально CUA MCP.
- FastAPI-приложение (локально на 127.0.0.1:8100) с проксированием через Caddy.
- Reverse-proxy Caddy с автоматическим TLS на `${SANDBOX_DOMAIN}` (по умолчанию `sandbox.localhost`, легко переключается на прод-домен через `.env`).
- Документация и переменные окружения для быстрого ввода в строй.

## Быстрый старт
Все команды ниже выполняются от имени `root` (или через `sudo`).

```bash
cd /root/sandboxmcp
cp .env.example .env          # заполните email, домены, хэш пароля и TELEGRAM_* по необходимости
make bootstrap                # ставим apt-пакеты, pipx, npm-инструменты, браузеры
make setup-systemd            # разворачиваем Xvfb/Openbox/noVNC/CUA через systemd
make compose-up               # поднимаем Caddy + FastAPI
```

Проверки после запуска:
- `curl http://127.0.0.1:8100/health` → `{"ok": true}`
- `curl http://127.0.0.1:8100/cua/health` → `{"up": true, ...}` (даже при `status: 404` сервис отвечает)
- `curl http://127.0.0.1:8100/policy` → JSON со значениями из `.env`
- `docker compose ps` → оба контейнера `Up`
- `systemctl is-active xvfb openbox x11vnc novnc cua-computer` → все `active`

Доступные команды Makefile:
- `make compose-down` — остановить контейнеры
- `make compose-logs` — посмотреть логи Caddy/FastAPI
- `make mcp-playwright|mcp-docker|mcp-telegram` — запустить соответствующий MCP-сервер (подхватывают `.env`).

## Структура
```
/root/sandboxmcp/
├─ Makefile                 # удобные цели (bootstrap, compose-up, mcp-*)
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
├─ scripts/                  # bootstrap, systemd, запуск MCP
│  ├─ bootstrap.sh
│  ├─ install-systemd.sh
│  ├─ run-*.sh
│  └─ setup-telegram-mcp.sh
├─ systemd/                  # unit-файлы для Xvfb/Openbox/noVNC/CUA
└─ telegram-mcp/             # репозиторий telegram-mcp (+ .venv)
```

## Системные сервисы
- `xvfb.service`, `openbox.service`, `x11vnc.service`, `novnc.service` — обеспечивают графическую среду и доступ через noVNC (работают нативно, вне контейнеров).
- `cua-computer.service` — CUA Computer Server с ENV `DISPLAY=:1` (нативный сервис).
Файлы unit'ов лежат в `systemd/`, установка и запуск выполняются скриптом `make setup-systemd` (`scripts/install-systemd.sh`).

## MCP-сервисы
- `./scripts/run-playwright-mcp.sh` — запускает Playwright MCP (`npx @playwright/mcp@latest`), подхватывает `.env`.
- `./scripts/run-docker-mcp.sh` — CLI для Docker MCP (пакет `docker-mcp`, установлен через pipx).
- `./scripts/run-telegram-mcp.sh` — активирует venv `telegram-mcp/.venv`, экспортирует TELEGRAM_* из `.env` и стартует MCP.
Эти скрипты связаны с целями `make mcp-*` и пригодны для вызова по SSH с VDS1.

## FastAPI-эндпоинты
- `GET /health` — базовый healthcheck самого FastAPI.
- `GET /cua/health` — проверка доступности CUA Computer Server (возвращает HTTP-статус и тело ответа).
- `GET /policy` — отдаёт YAML с правилами выбора инструментов (читается из `policy/decision.yaml` или из файла, указанного в `POLICY_FILE`).

## Чеклист развёртывания на новый сервер
1. **SSH**: Настроить обмен ключами между VDS1 ↔ VDS2 (`/root/.ssh/config`).
2. **Переменные**: `cp .env.example .env`, заполнить email, домены (или оставить `.localhost` для теста), задать `BASIC_AUTH_PASS` (хэш `caddy hash-password`), TELEGRAM_*.
3. **Зависимости**: `make bootstrap` (apt-пакеты, pipx-клиенты, npm-инструменты, Playwright-браузеры, venv для telegram-mcp).
4. **Графическая среда**: `make setup-systemd` (устанавливает unit-файлы из `systemd/`, запускает Xvfb/Openbox/x11vnc/noVNC/CUA).
5. **Контейнеры**: `make compose-up` — поднимаем FastAPI + Caddy. Для остановки `make compose-down`.
6. **Первичный вход в Telegram**: выполнить `DISPLAY=:1 telegram-desktop` через noVNC, авторизоваться и подтвердить устройства.
7. **Проверки**:
   - `curl http://127.0.0.1:8100/health`
   - `curl http://127.0.0.1:8100/cua/health`
   - `docker compose ps`
   - `systemctl is-active xvfb openbox x11vnc novnc cua-computer`
   - `./scripts/run-playwright-mcp.sh --help`, `./scripts/run-docker-mcp.sh --help`, `./scripts/run-telegram-mcp.sh --help`
   - Для прод-домена: `curl -k https://${SANDBOX_DOMAIN}/health`

- `.env.example` — шаблон. Скопируйте его в `.env` и заполните (по умолчанию использует `.localhost` домены, что даёт самоподписанный сертификат без обращения к ACME).
- `.env` — единый источник значений для compose, Caddy, FastAPI, CUA и Telegram MCP. Для экспорта значений в текущую сессию используйте `set -a && source ./.env && set +a`.
- `BASIC_AUTH_PASS` — ожидает bcrypt-хэш (`caddy hash-password --plaintext 'пароль'`).
- Для боевого домена пропишите `SANDBOX_DOMAIN`/`NOVNC_DOMAIN`/`API_DOMAIN` в DNS и обновите `.env`.
- `COMPUTER_SERVER_HOST` по умолчанию `host.docker.internal`, чтобы контейнер FastAPI мог достучаться до CUA, слушающего на хосте.
- `POLICY_FILE` указывает путь внутри контейнера (`/app/policy/decision.yaml`), файл из хоста монтируется в контейнер автоматически.

## Следующие шаги
- Доработать `policy/decision.yaml` (подключение к FastAPI, выдача контекста агенту).
- Подготовить плейбуки/скрипты для автоматизации шагов из чеклиста.
- Согласовать хранение чувствительных секретов (OpenAI, Telegram) в защищённых vault'ах.
- Настроить мониторинг состояния systemd-сервисов и алерты.
