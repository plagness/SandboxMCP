SHELL := /bin/bash
ENV_FILE ?= .env
ENABLE_VISUAL := $(shell if [ -f $(ENV_FILE) ]; then . $(ENV_FILE); echo $$ENABLE_VISUAL; else echo auto; fi)
ENABLE_VISUAL := $(strip $(ENABLE_VISUAL))
ENABLE_VISUAL_LOWER := $(shell echo "$(ENABLE_VISUAL)" | tr 'A-Z' 'a-z')

.PHONY: bootstrap compose-up compose-down compose-logs mcp-playwright mcp-docker mcp-telegram setup-systemd \
	visual-bootstrap visual-up visual-down visual-status

bootstrap:
	./scripts/bootstrap.sh

setup-systemd:
	./scripts/install-systemd.sh

compose-up:
	docker compose up -d

compose-down:
	docker compose down

compose-logs:
	docker compose logs -f

mcp-playwright:
	./scripts/run-playwright-mcp.sh

mcp-docker:
	./scripts/run-docker-mcp.sh

mcp-telegram:
	./scripts/run-telegram-mcp.sh

ifeq ($(ENABLE_VISUAL_LOWER),false)
visual-bootstrap:
	@echo "ENABLE_VISUAL=$(ENABLE_VISUAL_LOWER) — визуальное окружение отключено. Обновите .env для включения."

visual-up:
	@echo "ENABLE_VISUAL=$(ENABLE_VISUAL_LOWER) — визуальное окружение отключено. Обновите .env для включения."

visual-down:
	@echo "ENABLE_VISUAL=$(ENABLE_VISUAL_LOWER) — визуальное окружение отключено. Обновите .env для включения."

visual-status:
	@echo "ENABLE_VISUAL=$(ENABLE_VISUAL_LOWER) — визуальное окружение отключено. Обновите .env для включения."

else
visual-bootstrap:
	./scripts/install-visual.sh packages

visual-up:
	./scripts/install-visual.sh enable

visual-down:
	./scripts/install-visual.sh disable

visual-status:
	./scripts/install-visual.sh status

endif
