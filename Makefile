# Drive the image pipeline. Save work with `git push`; use these targets to
# trigger and watch the GitHub Actions workflows that build and push the
# base -> dev -> node image tiers and the services mirrors to GHCR.
#
#   make deploy                                  full build: build.yml (base -> dev -> node, services in parallel)
#   make deploy TARGET=node [VARIANT=node24]     node.yml: rebuild NodeJS variants on the current base/dev
#   make deploy TARGET=services [SERVICE=mysql]  services.yml: publish service mirrors only
#
# TARGET selects the workflow (unset = build.yml); base and dev have no TARGET,
# because base.yml/dev.yml are call-only and are rebuilt only by the full build.
# runs/logs/watch follow the same TARGET. A node or services run nested inside a
# full build appears under build.yml, so `make runs TARGET=services` lists
# standalone services runs only.
#
# Builds are NOT triggered by `git push` -- no workflow has a push trigger, so
# pushing only saves work. Use `make deploy` to build on demand. Requires the
# GitHub CLI (`gh`) authenticated against this repo. Note: dispatching against a
# branch only works once that workflow file (build.yml, node.yml or
# services.yml) exists on the default branch.

TARGET  ?=
SERVICE ?= all
VARIANT ?= all
REF     ?= $(shell git rev-parse --abbrev-ref HEAD)

ifeq ($(TARGET),)
WORKFLOW       := build.yml
TRIGGER_INPUTS :=
else ifeq ($(TARGET),node)
WORKFLOW       := node.yml
TRIGGER_INPUTS := -f variant=$(VARIANT)
else ifeq ($(TARGET),services)
WORKFLOW       := services.yml
TRIGGER_INPUTS := -f service=$(SERVICE)
else
$(error TARGET=$(TARGET) is not valid: leave TARGET unset for the full build (build.yml), or use TARGET=node or TARGET=services. base and dev are rebuilt only by the full build)
endif

# Catch a selector given without its TARGET, which would otherwise run the
# full build and ignore it.
ifneq ($(SERVICE),all)
ifneq ($(TARGET),services)
$(error SERVICE=$(SERVICE) needs TARGET=services)
endif
endif
ifneq ($(VARIANT),all)
ifneq ($(TARGET),node)
$(error VARIANT=$(VARIANT) needs TARGET=node)
endif
endif

# Resolve the most recent run of WORKFLOW on the current ref to a run id.
latest_run = gh run list --workflow $(WORKFLOW) --branch $(REF) --limit 1 --json databaseId --jq '.[0].databaseId'

.DEFAULT_GOAL := help

.PHONY: help
help: ## List available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Variables (deploy/trigger/watch/runs/logs):"
	@echo "  TARGET=          unset = full build (build.yml); node (node.yml); services (services.yml)"
	@echo "  VARIANT=all      with TARGET=node: one variant from node/variants.json, e.g. node24"
	@echo "  SERVICE=all      with TARGET=services: one service from services/variants.json, e.g. mysql"

.PHONY: deploy
deploy: trigger watch ## Trigger the selected workflow (default: full build) on the current branch and watch it

.PHONY: trigger
trigger: ## Trigger the selected workflow on the current branch (no waiting)
	gh workflow run $(WORKFLOW) --ref $(REF) $(TRIGGER_INPUTS)
	@echo "triggered $(WORKFLOW) on $(REF) $(TRIGGER_INPUTS)"

.PHONY: watch
watch: ## Watch the latest run of the selected workflow on this branch
	@echo "waiting for the run to register..."
	@sleep 5
	@id=$$($(latest_run)); \
		[ -n "$$id" ] || { echo "no run found for $(WORKFLOW) on $(REF)"; exit 1; }; \
		gh run watch "$$id" --exit-status

.PHONY: services
services: ## Show the currently pinned service image versions (services/variants.json)
	@jq -r '.services[] | "  \(.name): sources=\(.sources | join(", ")) tags=\(.tags | join(", "))"' services/variants.json

.PHONY: bump-services
bump-services: ## How to bump a frozen service image (mysql/redis/...) to a new version
	@echo "Service images are version-pinned + frozen -- bumps are deliberate:"
	@echo "  1. make services            # see the current pins"
	@echo "  2. edit services/variants.json: set the new exact patch in sources[]"
	@echo "     and the matching exact tag in tags[] (keep the stable alias, e.g. 8.0)"
	@echo "  3. commit on a branch, open a PR -- the version change is reviewed in git"
	@echo "  4. make deploy TARGET=services SERVICE=<name>   # publish that mirror only"

.PHONY: runs
runs: ## List recent runs of the selected workflow
	gh run list --workflow $(WORKFLOW) --limit 10

.PHONY: logs
logs: ## Show the log of the latest run of the selected workflow on this branch (use after a failure)
	@id=$$($(latest_run)); \
		[ -n "$$id" ] || { echo "no run found for $(WORKFLOW) on $(REF)"; exit 1; }; \
		gh run view "$$id" --log
