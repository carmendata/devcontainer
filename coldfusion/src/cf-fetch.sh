#!/usr/bin/env bash
#
# Fetch a production ColdFusion 2021 install tree from an S3-compatible backup
# and normalise it to /opt/coldfusion2021. Run only inside the throwaway
# `cf-fetch` build stage (see src/Dockerfile), with the presigned URL provided
# as a BuildKit secret so it never enters an image layer or the build cache.
#
# Why a presigned URL rather than access keys: it is provider-agnostic (works
# for any S3-compatible store -- MinIO, R2, B2, Wasabi, AWS), time-limited, and
# needs no cloud CLI in the build. Generate one with your provider's tooling,
# e.g.  aws s3 presign s3://<bucket>/<key> --expires-in 3600
#       mc share download --expire 1h <alias>/<bucket>/<key>
# and write it (URL only) to coldfusion/cf_backup_url.txt.
#
# The archive must be a tar (.tar/.tar.gz/.tgz/.tar.xz/.tar.zst -- GNU tar
# autodetects compression). Any of these top-level layouts is accepted:
#   coldfusion2021/cfusion/...        (tar -C /opt coldfusion2021)
#   opt/coldfusion2021/cfusion/...    (tar with a leading opt/)
#   cfusion/...  jre/...              (tar -C /opt/coldfusion2021 .)
set -euo pipefail

secret=/run/secrets/cf_backup_url
[ -f "$secret" ] || {
    echo "ERROR: build secret 'cf_backup_url' is not mounted." >&2
    echo "       Pass --secret id=cf_backup_url,src=<file with a presigned URL>," >&2
    echo "       or use coldfusion/compose.yaml which wires it from cf_backup_url.txt." >&2
    exit 1
}
url="$(tr -d '\r\n' < "$secret")"
[ -n "$url" ] || { echo "ERROR: the cf_backup_url secret file is empty." >&2; exit 1; }

dest=/opt/coldfusion2021
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "==> downloading ColdFusion 2021 backup (presigned URL)"
curl -fSL --retry 3 --retry-delay 2 "$url" -o "$tmp/cf-backup.tar"

echo "==> extracting"
mkdir -p "$tmp/x"
tar -xf "$tmp/cf-backup.tar" -C "$tmp/x" --no-same-owner

# Locate the install root regardless of how the archive was packed.
if   [ -d "$tmp/x/coldfusion2021/cfusion" ];     then src="$tmp/x/coldfusion2021"
elif [ -d "$tmp/x/opt/coldfusion2021/cfusion" ]; then src="$tmp/x/opt/coldfusion2021"
elif [ -d "$tmp/x/cfusion" ];                    then src="$tmp/x"
else
    echo "ERROR: no 'cfusion/' directory found in the archive. Extracted top level:" >&2
    ls -la "$tmp/x" >&2
    exit 1
fi

echo "==> installing to $dest"
mkdir -p "$dest"
cp -a "$src/." "$dest/"

[ -f "$dest/cfusion/bin/coldfusion" ] || {
    echo "ERROR: $dest/cfusion/bin/coldfusion missing after extract -- archive layout unexpected." >&2
    exit 1
}
chmod +x "$dest/cfusion/bin/coldfusion" 2>/dev/null || true
echo "==> ColdFusion 2021 tree ready at $dest"
