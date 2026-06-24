# Drive the image pipeline. Save work with `git push`; use these targets to
# trigger and watch the GitHub Actions workflow that builds and pushes the
# base -> dev -> node image tiers to GHCR.
#
# Builds are NOT triggered by `git push` -- the workflow has no push trigger, so
# pushing only saves work. Use `make deploy` to build on demand (a weekly cron
# also rebuilds for security updates). Requires the GitHub CLI (`gh`)
# authenticated against this repo. Note: dispatching against a branch only works
# once build.yml exists on the default branch.

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
	@echo "  4. make deploy              # re-run build.yml to publish the new mirror"
	@echo "The weekly security cron does NOT touch service images by design."

.PHONY: runs
runs: ## List recent runs of the build workflow
	gh run list --workflow $(WORKFLOW) --limit 10

.PHONY: logs
logs: ## Show the log of the latest run on this branch (use after a failure)
	@id=$$($(latest_run)); \
		[ -n "$$id" ] || { echo "no run found for $(WORKFLOW) on $(REF)"; exit 1; }; \
		gh run view "$$id" --log
