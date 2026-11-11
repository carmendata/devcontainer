#!/usr/bin/env bash
# Validate node/variants.json and emit the build matrix, optionally narrowed to
# one variant. Shared by node.yml's load-matrix job and build.yml's early
# validate-variants job, so a malformed file fails before anything is published.
#
# Usage: load-variants.sh [VARIANT] [FILE]
#   VARIANT  a variant name from FILE, or "all" (default: all)
#   FILE     path to the variants file (default: node/variants.json)
# Writes `variants=<json array>` to $GITHUB_OUTPUT when set, otherwise to stdout.
# Fails if FILE is empty, has duplicate name/tag values, or VARIANT is unknown.
set -euo pipefail

VARIANT="${1:-all}"
FILE="${2:-node/variants.json}"

jq -e '
  (.variants | length > 0)
  and ((.variants | map(.name) | length) == (.variants | map(.name) | unique | length))
  and ((.variants | map(.tags[]) | length) == (.variants | map(.tags[]) | unique | length))
' "$FILE" > /dev/null \
  || { echo "::error::$FILE is empty or has duplicate name/tag values"; exit 1; }
variants=$(jq -c --arg v "$VARIANT" '.variants | if $v == "all" then . else map(select(.name == $v)) end' "$FILE")
[ "$(echo "$variants" | jq 'length')" -gt 0 ] \
  || { echo "::error::variant '$VARIANT' is not in $FILE (use a variant name or 'all')"; exit 1; }
echo "variants=$variants" >> "${GITHUB_OUTPUT:-/dev/stdout}"
