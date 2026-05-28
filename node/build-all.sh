#!/usr/bin/env bash
#
# Build every tier and image locally -- the same source of truth CI uses:
#   devcontainer:base  (minimal prod base)  ->  devcontainer:dev  (dev tooling)
# then, for every variant in variants.json, both targets of node/src/Dockerfile:
#   production:<name>    the lean prod runtime base (base + node, non-root)
#   devcontainer:<name>  the devcontainer image (dev + node + pnpm)
#
# Requires jq and a container builder (docker or podman -- whichever has a
# working engine; force one with DOCKER=podman).
#
set -euo pipefail

cd "$(dirname "$0")"

# Container engine: honour $DOCKER, else pick whichever engine actually
# responds -- a CLI may be installed with its daemon/VM stopped, so probe
# `<engine> version` rather than just checking PATH.
engine_ok() { "$1" version >/dev/null 2>&1; }
if [ -n "${DOCKER:-}" ]; then
    builder="$DOCKER"
elif engine_ok docker; then
    builder=docker
elif engine_ok podman; then
    builder=podman
else
    echo "error: no working docker or podman engine found" >&2
    exit 1
fi

echo "==> building base  (devcontainer:base)"
"$builder" build -t devcontainer:base ../base/src

echo "==> building dev  (devcontainer:dev)"
"$builder" build \
    --build-arg "BASE_IMAGE=devcontainer:base" \
    -t devcontainer:dev \
    ../dev/src

jq -c '.variants[]' variants.json | while read -r variant; do
    name=$(jq -r '.name' <<<"$variant")
    node=$(jq -r '.node' <<<"$variant")
    pnpm=$(jq -r '.pnpm' <<<"$variant")
    echo "==> building ${name} production  (production:${name}, node ${node})"
    "$builder" build --target prod \
        --build-arg "BASE_IMAGE=devcontainer:base" \
        --build-arg "NODE_VERSION=${node}" \
        -t "production:${name}" \
        ./src
    echo "==> building ${name} devcontainer  (devcontainer:${name}, pnpm ${pnpm})"
    "$builder" build --target dev \
        --build-arg "BASE_IMAGE=devcontainer:base" \
        --build-arg "DEV_IMAGE=devcontainer:dev" \
        --build-arg "NODE_VERSION=${node}" \
        --build-arg "PNPM_VERSION=${pnpm}" \
        -t "devcontainer:${name}" \
        ./src
done

echo "==> done"
