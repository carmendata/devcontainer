#!/usr/bin/env bash
#
# Build all three tiers locally -- the same source of truth CI uses:
#   devcontainer:base  (minimal prod base)  ->  devcontainer:dev  (dev tooling)
#   ->  devcontainer:<name>  for every variant in variants.json.
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
    echo "==> building ${name}  (node ${node}, pnpm ${pnpm})"
    "$builder" build \
        --build-arg "DEV_IMAGE=devcontainer:dev" \
        --build-arg "NODE_VERSION=${node}" \
        --build-arg "PNPM_VERSION=${pnpm}" \
        -t "devcontainer:${name}" \
        ./src
done

echo "==> done"
