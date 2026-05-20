#!/usr/bin/env bash
#
# Build every image variant declared in variants.json locally -- the same
# source of truth CI uses. Each is tagged devcontainer:<name>.
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

jq -c '.variants[]' variants.json | while read -r variant; do
    name=$(jq -r '.name' <<<"$variant")
    node=$(jq -r '.node' <<<"$variant")
    pnpm=$(jq -r '.pnpm' <<<"$variant")
    echo "==> building ${name}  (node:${node}, pnpm ${pnpm})"
    "$builder" build \
        --build-arg "NODE_VARIANT=${node}" \
        --build-arg "PNPM_VERSION=${pnpm}" \
        -t "devcontainer:${name}" \
        ./src
done

echo "==> done"
