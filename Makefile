DOCKER ?= docker
COMPOSE = $(DOCKER) compose --env-file srcs/.env -f srcs/docker-compose.yml
.DEFAULT_GOAL := up
.PHONY: all setup config build up down stop start restart logs ps test clean re preflight check
all: up
setup:
	python3 srcs/tools/setup.py
config:
	$(COMPOSE) config --quiet
preflight: config
	python3 srcs/tools/check_storage.py $(DOCKER)
build: preflight
	$(COMPOSE) build
up: preflight
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
check: config
	python3 -B srcs/tests/test_storage.py
test:
	DOCKER=$(DOCKER) bash srcs/tests/integration.sh
clean: down
re: down up
