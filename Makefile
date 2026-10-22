DOCKER ?= docker
COMPOSE = $(DOCKER) compose --env-file srcs/.env -f srcs/docker-compose.yml
.DEFAULT_GOAL := up
.PHONY: all setup config build up down stop start restart logs ps test clean re
all: up
setup:
	python3 tools/setup.py
config:
	$(COMPOSE) config --quiet
build: config
	$(COMPOSE) build
up: config
	$(COMPOSE) up -d --build --wait --wait-timeout 240
down:
	$(COMPOSE) down
stop:
	$(COMPOSE) stop
start:
	$(COMPOSE) start
restart:
	$(COMPOSE) restart
logs:
	$(COMPOSE) logs --tail=100
ps:
	$(COMPOSE) ps
test:
	DOCKER=$(DOCKER) bash tests/integration.sh
clean: down
re: down up
