# Drive the image pipeline. Save work with `git push`; use these targets to
# trigger and watch the GitHub Actions workflow that builds and pushes the
# base -> dev -> node image tiers to GHCR.
#
# Pushing to `main` already auto-runs the workflow; these targets are for
# building a feature branch on demand, or re-running to pick up a refreshed
# base image. Requires the GitHub CLI (`gh`) authenticated against this repo.
# Note: dispatching against a branch only works once build.yml exists on the
# default branch.

WORKFLOW := build.yml
REF      ?= $(shell git rev-parse --abbrev-ref HEAD)

# Resolve the most recent run of WORKFLOW on the current ref to a run id.
latest_run = gh run list --workflow $(WORKFLOW) --branch $(REF) --limit 1 --json databaseId --jq '.[0].databaseId'

.DEFAULT_GOAL := help

.PHONY: help
help: ## List available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

.PHONY: deploy
deploy: trigger watch ## Trigger the build workflow on the current branch and watch it

.PHONY: trigger
trigger: ## Trigger the build workflow on the current branch (no waiting)
	gh workflow run $(WORKFLOW) --ref $(REF)
	@echo "triggered $(WORKFLOW) on $(REF)"

.PHONY: watch
watch: ## Watch the latest run of the build workflow on this branch
	@echo "waiting for the run to register..."
	@sleep 5
	@id=$$($(latest_run)); \
		[ -n "$$id" ] || { echo "no run found for $(WORKFLOW) on $(REF)"; exit 1; }; \
		gh run watch "$$id" --exit-status

.PHONY: runs
runs: ## List recent runs of the build workflow
	gh run list --workflow $(WORKFLOW) --limit 10

.PHONY: logs
logs: ## Show the log of the latest run on this branch (use after a failure)
	@id=$$($(latest_run)); \
		[ -n "$$id" ] || { echo "no run found for $(WORKFLOW) on $(REF)"; exit 1; }; \
		gh run view "$$id" --log
