.DEFAULT_GOAL := check

SHELL := bash
.SHELLFLAGS := -euo pipefail -c

DOCKER ?= docker
ACTION_IMAGE ?= nobl9-action:local
TEST_IMAGE ?= nobl9-action:test
BATS ?= bats

.PHONY: check lint lint-actions lint-shell lint-docker format test test-release test-release-docker build build-test

check: lint test-release-docker

lint: lint-actions lint-shell lint-docker

lint-actions:
	actionlint

lint-shell:
	shellcheck entrypoint.sh .github/scripts/*.sh tests/helpers/*
	shfmt -d -i 2 entrypoint.sh .github/scripts/*.sh tests/*.bats tests/helpers/*

lint-docker:
	hadolint --ignore DL3018 Dockerfile tests/Dockerfile

format:
	shfmt -w -i 2 entrypoint.sh .github/scripts/*.sh tests/*.bats tests/helpers/*

build:
	$(DOCKER) build --tag $(ACTION_IMAGE) .

build-test: build
	$(DOCKER) build --build-arg ACTION_IMAGE=$(ACTION_IMAGE) --tag $(TEST_IMAGE) tests

test-release:
	$(BATS) tests/release.bats

test-release-docker: build-test
	$(DOCKER) run --rm --entrypoint bats \
		--volume "$(CURDIR):/workspace:ro" --workdir /workspace \
		$(TEST_IMAGE) tests/release.bats

test: build-test
	$(DOCKER) run --rm \
		--env SLOCTL_CLIENT_ID --env SLOCTL_CLIENT_SECRET \
		--env SLOCTL_OKTA_ORG_URL --env SLOCTL_OKTA_AUTH_SERVER \
		$(TEST_IMAGE)
