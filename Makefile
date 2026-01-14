SHELL := /usr/bin/env bash

.PHONY: help install status logs restart stop ps

help:
	@echo "Targets:"
	@echo "  make install  - install user unit + enable linger"
	@echo "  make status   - systemd status"
	@echo "  make logs     - follow logs"
	@echo "  make restart  - restart service"
	@echo "  make stop     - stop service"
	@echo "  make ps       - podman ps summary"

install:
	chmod +x scripts/install-user-service.sh
	scripts/install-user-service.sh

status:
	systemctl --user --no-pager status cf-ddns.service || true

logs:
	journalctl --user -u cf-ddns -f

restart:
	systemctl --user restart cf-ddns.service

stop:
	systemctl --user stop cf-ddns.service

ps:
	podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
