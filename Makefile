SHELL := /usr/bin/env bash

.DEFAULT_GOAL := help

.PHONY: help bootstrap dry-run test-shell test-bootstrap

help:
	@printf '%s\n' \
	  'make bootstrap PROFILE=laptop  Apply a profile to this Ubuntu machine (real changes).' \
	  'make dry-run PROFILE=laptop    Show bootstrap operations without applying them.' \
	  'make test-shell                Start a disposable Ubuntu test shell.' \
	  'make test-bootstrap PROFILE=laptop  Run bootstrap twice in Docker.'

bootstrap:
	@test -n "$(PROFILE)" || { printf '%s\n' 'PROFILE is required, for example: make bootstrap PROFILE=laptop' >&2; exit 2; }
	sudo --preserve-env=BOOTSTRAP_USER ./setup/bootstrap.sh "$(PROFILE)"

dry-run:
	@test -n "$(PROFILE)" || { printf '%s\n' 'PROFILE is required, for example: make dry-run PROFILE=laptop' >&2; exit 2; }
	./setup/bootstrap.sh --dry-run "$(PROFILE)"

test-shell:
	docker compose -f test/docker-compose.yml run --rm setup bash

test-bootstrap:
	@test -n "$(PROFILE)" || { printf '%s\n' 'PROFILE is required, for example: make test-bootstrap PROFILE=laptop' >&2; exit 2; }
	docker compose -f test/docker-compose.yml run --rm setup bash -lc 'BOOTSTRAP_USER=developer ./setup/bootstrap.sh "$(PROFILE)" && BOOTSTRAP_USER=developer ./setup/bootstrap.sh "$(PROFILE)" && ./test/verify-bootstrap.sh "$(PROFILE)" && ./test/verify-keykeeper-unlock.sh'
