SHELL := /bin/bash

.PHONY: bootstrap compose-up compose-down compose-logs mcp-playwright mcp-docker mcp-telegram setup-systemd

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
