# SandboxMCP

**Текущая версия:** `1.0.0` (см. [CHANGELOG.md](CHANGELOG.md)). Используем схему `x.y.z`: `x` — крупные стабильные релизы, `y` — минорные рабочие обновления, `z` — фиксы и тестирование.

Набор инструкций и вспомогательных файлов для подготовки тестовой площадки SandboxMCP на сервере VDS2 (`SANDBOX_DOMAIN`). Стек предназначен для удалённых UI/интеграционных тестов и вспомогательных сервисов агента Codex.

## Цели
- Виртуальный рабочий стол (Xvfb + Openbox + x11vnc + noVNC) под `root`.
- Инструменты для UI-тестов: Playwright (приоритетно) и CUA Computer Server для нативного Telegram Desktop.
- MCP-сервисы: Playwright MCP, Docker MCP, Telegram MCP (через SSH с VDS1), опционально CUA MCP.
- FastAPI-приложение (локально на 127.0.0.1:8100) с проксированием через Caddy.
- Reverse-proxy Caddy с автоматическим TLS на `${SANDBOX_DOMAIN}` (по умолчанию примерный домен `sandbox.example.com`, легко переключается на прод-домен через `.env`).
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
- `systemctl is-active xvfb xfce x11vnc novnc cua-computer` → все `active`

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
- `xvfb@.service`, `xfce@.service`, `x11vnc@.service`, `novnc@.service` — обеспечивают видеовывод и noVNC (работают нативно, вне контейнеров).
- `cua-computer.service` — CUA Computer Server с ENV `DISPLAY=:1` (нативный сервис).
Файлы unit'ов лежат в `systemd/`, установка и запуск выполняются скриптом `make setup-systemd` (`scripts/install-systemd.sh`).

## MCP-сервисы
- `./scripts/run-playwright-mcp.sh` — запускает Playwright MCP (`npx @playwright/mcp@latest`), подхватывает `.env`.
- `./scripts/run-docker-mcp.sh` — CLI для Docker MCP (пакет `docker-mcp`, установлен через pipx).
- `./scripts/run-telegram-mcp.sh` — активирует venv `telegram-mcp/.venv`, экспортирует TELEGRAM_* из `.env` и стартует MCP.
- `make tg-session` — интерактивный генератор TELEGRAM_SESSION_STRING (через Telethon), при желании обновляет `.env` (создаёт резервную копию).
Эти скрипты связаны с целями `make mcp-*`/`make tg-session` и пригодны для вызова по SSH с VDS1.

## FastAPI-эндпоинты
- `GET /health` — базовый healthcheck самого FastAPI.
- `GET /cua/health` — проверка доступности CUA Computer Server (возвращает HTTP-статус и тело ответа).
- `GET /policy` — отдаёт YAML с правилами выбора инструментов (читается из `policy/decision.yaml` или из файла, указанного в `POLICY_FILE`).

## Визуальное окружение (опционально)
В `.env` появилась переменная `ENABLE_VISUAL` (`auto|true|false`). По умолчанию `auto`: окружение разворачивается только по запросу.

1. Настройте `.env`:
   ```bash
   ENABLE_VISUAL=true            # или оставьте auto и вызовите команды вручную
   DISPLAY_NUM=:1
   NOVNC_LISTEN=127.0.0.1
   NOVNC_PORT=6080
   VNC_PORT=5901
   QT_OPENGL=software
   LIBGL_ALWAYS_SOFTWARE=1
   CHROMIUM_FLAGS="--disable-gpu --no-sandbox --disable-dev-shm-usage"
   ```
2. Выполните (от root):
   ```bash
   make visual-bootstrap    # ставит Xvfb/XFCE/noVNC, шрифты и браузеры (идемпотентно)
   make visual-up           # выкладывает unit-файлы и запускает xvfb@1, xfce@1, x11vnc@1, novnc@1
   make visual-status       # проверка статусов
   ```
   Для остановки используйте `make visual-down`.
3. Проверки:
   ```bash
   systemctl is-active xvfb@1 xfce@1 x11vnc@1 novnc@1
   ```
   Все сервисы должны быть `active`. Повторные вызовы команд безопасны — сценарий идемпотентен.

### Подключение и запуск приложений
- Туннель с macOS/Linux:
  ```bash
  ssh -N \
    -L 127.0.0.1:${NOVNC_PORT}:127.0.0.1:${NOVNC_PORT} \
    -L 127.0.0.1:${VNC_PORT}:127.0.0.1:${VNC_PORT} \
    root@sandbox.example.com
  ```
  Затем откройте `http://127.0.0.1:${NOVNC_PORT}/vnc.html` (логин/пароль задаются в `.env`).
- После подключения загрузится XFCE-панель и рабочий стол; терминал можно запустить через меню приложений (`Alt+F2` → `xfce4-terminal`).
- Telegram Desktop:
  ```bash
  DISPLAY=${DISPLAY_NUM} QT_OPENGL=${QT_OPENGL} \
  LIBGL_ALWAYS_SOFTWARE=${LIBGL_ALWAYS_SOFTWARE} telegram-desktop &
  ```
- Chromium без GPU:
  ```bash
  DISPLAY=${DISPLAY_NUM} LIBGL_ALWAYS_SOFTWARE=${LIBGL_ALWAYS_SOFTWARE} \
  chromium ${CHROMIUM_FLAGS} &
  ```

### Ресурсные ориентиры
- CPU: 1–2 vCPU достаточно; noVNC + Chromium/Telegram дают до ~80–120% одного ядра.
- RAM: базовый стек (Xvfb+XFCE+x11vnc+noVNC) ≈ 300–400 МБ; Telegram Desktop 300–800 МБ; Chromium 300–700 МБ.
- Диск: Playwright-браузеры и кэши Telegram занимают до 2–3 ГБ. Для чистки: `rm -rf ~/.local/share/TelegramDesktop/*` (после остановки Telegram).
- Сеть: доступ только через SSH-туннель (или Caddy c basic auth, если раскомментирован домен `NOVNC_DOMAIN`).

### Отсутствие GPU
Переменные `QT_OPENGL=software`, `LIBGL_ALWAYS_SOFTWARE=1`, `CHROMIUM_FLAGS` автоматически попадают в `/etc/sandboxmcp/visual.env` и экспортируются в unit-файлы. Благодаря этому Telegram Desktop и Chromium работают через Mesa/llvmpipe на CPU.

## Чеклист развёртывания на новый сервер
1. **SSH**: Настроить обмен ключами между VDS1 ↔ VDS2 (`/root/.ssh/config`).
2. **Переменные**: `cp .env.example .env`, заполнить email, домены (или оставить значения из шаблона, затем заменить на реальные), задать `BASIC_AUTH_PASS` (хэш `caddy hash-password`), TELEGRAM_*.
3. **Зависимости**: `make bootstrap` (apt-пакеты, pipx-клиенты, npm-инструменты, Playwright-браузеры, venv для telegram-mcp).
4. **Графическая среда**: `make setup-systemd` (устанавливает unit-файлы из `systemd/`, запускает Xvfb/XFCE/x11vnc/noVNC/CUA).
5. **Контейнеры**: `make compose-up` — поднимаем FastAPI + Caddy. Для остановки `make compose-down`.
6. **Первичный вход в Telegram**: выполнить `DISPLAY=:1 telegram-desktop` через noVNC, авторизоваться и подтвердить устройства.
7. **Проверки**:
   - `curl http://127.0.0.1:8100/health`
   - `curl http://127.0.0.1:8100/cua/health`
   - `docker compose ps`
   - `systemctl is-active xvfb xfce x11vnc novnc cua-computer`
   - `./scripts/run-playwright-mcp.sh --help`, `./scripts/run-docker-mcp.sh --help`, `./scripts/run-telegram-mcp.sh --help`
   - Для прод-домена: `curl -k https://${SANDBOX_DOMAIN}/health`

- `.env.example` — шаблон. Скопируйте его в `.env` и заполните (используются примерные доменные имена `sandbox.example.com`, их нужно заменить на реальные).
- `.env` — единый источник значений для compose, Caddy, FastAPI, CUA и Telegram MCP. Для экспорта значений в текущую сессию используйте `set -a && source ./.env && set +a`.
- `BASIC_AUTH_PASS` — ожидает bcrypt-хэш (`caddy hash-password --plaintext 'пароль'`).
- Для боевого домена пропишите `SANDBOX_DOMAIN`/`NOVNC_DOMAIN`/`API_DOMAIN` в DNS и обновите `.env`.
- `COMPUTER_SERVER_HOST` по умолчанию `host.docker.internal`, чтобы контейнер FastAPI мог достучаться до CUA, слушающего на хосте.
- `POLICY_FILE` указывает путь внутри контейнера (`/app/policy/decision.yaml`), файл из хоста монтируется в контейнер автоматически.

## Telegram MCP — заполнение `.env`
```
TELEGRAM_API_ID=12345678
TELEGRAM_API_HASH=abcd1234efgh5678ijkl9012mnop3456
TELEGRAM_SESSION_NAME=telegram_session
TELEGRAM_SESSION_STRING=1AQA...длинная_строка.../==
```

- `TELEGRAM_API_ID` — числовой ID приложения Telegram (https://my.telegram.org → API development tools → Create new application).
- `TELEGRAM_API_HASH` — секретный hash того же приложения (не токен бота!).
- `TELEGRAM_SESSION_NAME` — имя сессии (можно оставить `telegram_session`).
- `TELEGRAM_SESSION_STRING` — base64-строка с пользовательской авторизацией; заменяет `.session`-файл Telethon.

### Как получить TELEGRAM_SESSION_STRING
1. Убедитесь, что окружение готово (`make bootstrap` создаёт `telegram-mcp/.venv`).
2. Запустите `make tg-session` — скрипт запросит `API_ID`/`API_HASH`, пройдёт авторизацию в Telegram, выведет строку и предложит записать её в `.env` (создаст резервную копию).

Альтернативно вручную:
```bash
. /opt/telegram-mcp/.venv/bin/activate
python - <<'PY'
from telethon.sync import TelegramClient
from telethon.sessions import StringSession

api_id = int(input("API_ID: ").strip())
api_hash = input("API_HASH: ").strip()

with TelegramClient(StringSession(), api_id, api_hash) as client:
    print("\nTELEGRAM_SESSION_STRING=" + client.session.save())
PY
```
Скопируйте всё после `TELEGRAM_SESSION_STRING=` и вставьте в `.env`.

**Безопасность:** строка-сессия даёт полный доступ к аккаунту. Храните `.env` c правами `600`, не добавляйте в репозиторий. При `Revoke` в my.telegram.org значение станет недействительным. Боты авторизуются по отдельному токену и к этому блоку не относятся. Сервер без GPU работает нормально: Telethon взаимодействует только через API, визуал нужен лишь для ручного управления Telegram Desktop.

## Следующие шаги
- Доработать `policy/decision.yaml` (подключение к FastAPI, выдача контекста агенту).
- Подготовить плейбуки/скрипты для автоматизации шагов из чеклиста.
- Согласовать хранение чувствительных секретов (OpenAI, Telegram) в защищённых vault'ах.
- Настроить мониторинг состояния systemd-сервисов и алерты.
