# syntax=docker/dockerfile:1.7
# Tier 3 (POC): an Adobe ColdFusion 2021 devcontainer, layered on the shared dev
# tier (dev/src/Dockerfile) exactly like the node/ stack.
#
# ColdFusion 2021 is proprietary, amd64-only, and not supported on Debian trixie
# by its installer -- so rather than run the Adobe installer, this bakes a known-
# good *production* CF 2021 install (Linux x64, standalone / built-in server)
# straight onto the dev tier. The install tree is fetched at build time from an
# S3-compatible backup via a PRESIGNED URL passed as a BuildKit secret, so the
# URL and the licensed CF bits never land in an image layer or the build cache.
#
# Build (compose wires the secret for you -- see coldfusion/compose.yaml):
#   printf '%s' "<presigned-s3-url>" > coldfusion/cf_backup_url.txt
#   cd coldfusion && docker compose build
# Or directly with buildx:
#   docker buildx build --target dev \
#     --secret id=cf_backup_url,src=./cf_backup_url.txt \
#     -f src/Dockerfile -t devcontainer:coldfusion2021 .
#
# NOTE: this is a POC. It has not been validated against a live backup or an
# amd64 build host -- expect to tune the runtime libs below and CF_HOME once you
# run it against your real backup. There is no production target here (unlike
# node/): a CF devcontainer is for legacy app development, not a runtime base.
ARG BASE_IMAGE=ghcr.io/carmendata/devcontainer:base
ARG DEV_IMAGE=ghcr.io/carmendata/devcontainer:dev

# --- cf-fetch: download + unpack the prod CF 2021 tree (throwaway stage) ------
# FROM base plus curl only; everything here is discarded, so the download tools
# and the secret never reach the final image. The extracted tree is handed to
# the dev stage with a single COPY --from.
FROM ${BASE_IMAGE} AS cf-fetch
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY src/cf-fetch.sh /usr/local/bin/cf-fetch.sh
# The secret is a file containing ONLY a presigned S3 URL to a tar of the prod
# /opt/coldfusion2021 tree. cf-fetch.sh downloads, extracts, and normalises it
# to /opt/coldfusion2021 (see that script for the accepted archive layouts).
RUN --mount=type=secret,id=cf_backup_url \
    /usr/local/bin/cf-fetch.sh

# --- dev: the devcontainer image (dev tooling + CF 2021 standalone) -----------
FROM ${DEV_IMAGE} AS dev

# Runtime libraries the bundled CF JRE / headless AWT (CFImage, charting, PDF,
# font rendering) expect but which the lean base does not carry. If CF logs show
# missing .so files on first start, add them here. fontconfig + the X libs cover
# the common java.awt.headless cases.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        fontconfig libfreetype6 libxext6 libxi6 libxrender1 libxtst6 \
    && rm -rf /var/lib/apt/lists/*

ENV CF_HOME=/opt/coldfusion2021 \
    CF_PORT=8500

# The whole standalone install (cfusion/ + the bundled jre/), copied to the SAME
# path it had in production so the baked start script, jvm.config and JAVA_HOME
# all resolve unchanged.
COPY --from=cf-fetch /opt/coldfusion2021/ /opt/coldfusion2021/

# Start/stop helpers for the dev shell (the server is NOT started automatically;
# CMD stays sleep infinity so VS Code attaches to a shell, like the node stack).
COPY --chmod=0755 src/cfstart src/cfstop /usr/local/bin/

# Baked reference config (parity with node/): the canonical devcontainer.json +
# compose.yaml a downstream legacy repo copies into its .devcontainer/. Reference
# only -- not consumed by the runtime. Requires the build context to be
# coldfusion/ (not coldfusion/src) so examples/ is in scope.
COPY examples/devcontainer.json examples/compose.yaml /usr/local/share/devcontainer/

# CF's built-in (Tomcat) web server; CF Administrator at /CFIDE/administrator/.
EXPOSE 8500

# Keep the container alive when run directly; compose overrides this per service.
CMD ["sleep", "infinity"]
