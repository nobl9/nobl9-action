.DEFAULT_GOAL := check

SHELL := bash
.SHELLFLAGS := -euo pipefail -c

DOCKER ?= docker
ACTION_IMAGE ?= nobl9-action:local
TEST_IMAGE ?= nobl9-action:test

.PHONY: check lint lint-actions lint-shell lint-docker format test build build-test

check: lint build-test

lint: lint-actions lint-shell lint-docker

lint-actions:
	actionlint

lint-shell:
	shellcheck entrypoint.sh
	shfmt -d -i 2 entrypoint.sh tests/e2e.bats

lint-docker:
	hadolint --ignore DL3018 Dockerfile tests/Dockerfile

format:
	shfmt -w -i 2 entrypoint.sh tests/e2e.bats

build:
	$(DOCKER) build --tag $(ACTION_IMAGE) .

build-test: build
	$(DOCKER) build --build-arg ACTION_IMAGE=$(ACTION_IMAGE) --tag $(TEST_IMAGE) tests

test: build-test
	$(DOCKER) run --rm \
		--env SLOCTL_CLIENT_ID --env SLOCTL_CLIENT_SECRET \
		--env SLOCTL_OKTA_ORG_URL --env SLOCTL_OKTA_AUTH_SERVER \
		$(TEST_IMAGE)
