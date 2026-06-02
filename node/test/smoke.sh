#!/usr/bin/env bash
#
# Smoke test for the devcontainer Compose stack.
#
# For each variant in variants.json it builds the app image, brings the stack
# up (app + mysql + redis), asserts every component responds, and tears down.
# Run it before pushing image changes.
#
# Usage:
#   ./test/smoke.sh            test every variant in variants.json
#   ./test/smoke.sh node24     test a single variant by name
#
# Uses docker or podman -- whichever has a working engine; force one with
# DOCKER=podman.
#
set -euo pipefail
cd "$(dirname "$0")/.."

# Container engine: honour $DOCKER, else pick whichever engine actually
# responds -- a CLI may be installed with its daemon/VM stopped, so probe
# `<engine> version` rather than just checking PATH.
engine_ok() { "$1" version >/dev/null 2>&1; }
if [ -z "${DOCKER:-}" ]; then
    if engine_ok docker; then
        DOCKER=docker
    elif engine_ok podman; then
        DOCKER=podman
    else
        echo "error: no working docker or podman engine found" >&2
        exit 1
    fi
fi
# `</dev/null` keeps compose from consuming stdin -- without it, compose
# swallows the variant list the `while read` loop iterates, so only the first
# variant would ever run.
compose() { "$DOCKER" compose "$@" </dev/null; }

trap 'compose down -v >/dev/null 2>&1 || true' EXIT

# Variants build FROM the dev tier, which builds FROM the base tier. Build both
# once up front and point the stack at the local dev image (the compose default
# is the published dev image).
echo "--> building base image (devcontainer:base)"
"$DOCKER" build -t devcontainer:base ../base/src
echo "--> building dev image (devcontainer:dev)"
"$DOCKER" build --build-arg BASE_IMAGE=devcontainer:base -t devcontainer:dev ../dev/src
export BASE_IMAGE=devcontainer:base DEV_IMAGE=devcontainer:dev

# Select variants to test: all of them, or one by name.
if [ "$#" -gt 0 ]; then
    variants=$(jq -c --arg n "$1" '.variants[] | select(.name == $n)' variants.json)
    [ -n "$variants" ] || { echo "no variant named '$1' in variants.json"; exit 1; }
else
    variants=$(jq -c '.variants[]' variants.json)
fi

overall=0
failed=0

assert() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  ok    $label"
    else
        echo "  FAIL  $label"
        failed=1
    fi
}

while read -r v; do
    name=$(jq -r '.name' <<<"$v")
    node=$(jq -r '.node' <<<"$v")
    pnpm=$(jq -r '.pnpm' <<<"$v")
    major=${node%%.*}                       # 24.16.0 -> 24

    echo
    echo "=== variant: ${name}  (node ${node}, pnpm ${pnpm}) ==="
    export NODE_VERSION="$node" PNPM_VERSION="$pnpm" VARIANT_TAG="$name"
    failed=0

    echo "--> build + start stack"
    if ! compose up -d --build; then
        echo "  FAIL  stack failed to build or start"
        compose down -v >/dev/null 2>&1 || true
        overall=1
        continue
    fi

    echo "--> wait for services"
    for _ in $(seq 1 30); do
        if compose exec -T app mysql -h mysql -u root -e 'SELECT 1' >/dev/null 2>&1 \
           && compose exec -T app redis-cli -h redis ping >/dev/null 2>&1; then
            break
        fi
        sleep 2
    done

    echo "--> assertions"
    assert "node present"    compose exec -T app node --version
    assert "pnpm present"    compose exec -T app pnpm --version
    assert "git present"     compose exec -T app git --version
    assert "make present"    compose exec -T app make --version
    assert "mysql client"    compose exec -T app mysql --version
    assert "redis client"    compose exec -T app redis-cli --version
    assert "redis reachable" compose exec -T app redis-cli -h redis ping
    assert "mysql reachable" compose exec -T app mysql -h mysql -u root -e 'SELECT VERSION();'

    # The Node major in the running container must match the variant.
    got=$(compose exec -T app node -p 'process.versions.node.split(".")[0]' 2>/dev/null | tr -d '\r' || true)
    if [ "$got" = "$major" ]; then
        echo "  ok    node major is ${major}"
    else
        echo "  FAIL  node major: expected ${major}, got ${got:-unknown}"
        failed=1
    fi

    compose down -v >/dev/null 2>&1 || true

    # Production image (target prod): base + Node, non-root, no dev tooling.
    echo "--> build + check production image"
    if "$DOCKER" build --target prod \
            --build-arg "BASE_IMAGE=devcontainer:base" \
            --build-arg "NODE_VERSION=${node}" \
            -t "production:${name}" ./src >/dev/null 2>&1; then
        prod_major=$("$DOCKER" run --rm "production:${name}" node -p 'process.versions.node.split(".")[0]' 2>/dev/null | tr -d '\r' || true)
        [ "$prod_major" = "$major" ] \
            && echo "  ok    prod node major is ${major}" \
            || { echo "  FAIL  prod node major: expected ${major}, got ${prod_major:-unknown}"; failed=1; }

        prod_uid=$("$DOCKER" run --rm "production:${name}" id -u 2>/dev/null | tr -d '\r' || true)
        [ "$prod_uid" = "1000" ] \
            && echo "  ok    prod runs as non-root (uid 1000)" \
            || { echo "  FAIL  prod uid: expected 1000, got ${prod_uid:-unknown}"; failed=1; }

        if "$DOCKER" run --rm "production:${name}" sh -c 'command -v docker' >/dev/null 2>&1; then
            echo "  FAIL  prod unexpectedly ships the docker cli"; failed=1
        else
            echo "  ok    prod has no docker cli"
        fi
    else
        echo "  FAIL  production image failed to build"
        failed=1
    fi

    if [ "$failed" -eq 0 ]; then
        echo "--> ${name} PASSED"
    else
        echo "--> ${name} FAILED"
        overall=1
    fi
done <<<"$variants"

echo
if [ "$overall" -eq 0 ]; then
    echo "All smoke tests passed."
else
    echo "Smoke tests FAILED."
    exit 1
fi
