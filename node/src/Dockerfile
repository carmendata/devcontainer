# syntax=docker/dockerfile:1.7
# Tier 3 of 3: the Node language layer, on top of the dev tooling tier (tier 2,
# dev/src/Dockerfile -> tier 1, base/src/Dockerfile). Only the Node runtime and
# pnpm live here, so this layer is thin and the base + dev tiers beneath are
# shared with every other variant.
#
# DEV_IMAGE is the dev tier this was built against. CI pins it to the immutable
# dev-<sha> tag built in the same run; the default is the rolling dev tag for a
# bare `docker build`.
ARG DEV_IMAGE=ghcr.io/carmendata/devcontainer:dev
FROM ${DEV_IMAGE}

# NODE_VERSION (full, e.g. 24.16.0) and PNPM_VERSION are set per variant by CI
# from node/variants.json. The defaults are only the fallback for a bare build.
ARG NODE_VERSION=24.16.0
ARG PNPM_VERSION=10.33.0

ENV NODE_ENV=development \
    PNPM_HOME=/usr/local/share/pnpm \
    PATH=/usr/local/share/pnpm:$PATH

# --- Node.js ----------------------------------------------------------------
# Installed from the official nodejs.org tarball (the same payload the official
# node image ships) into /usr/local, rather than via a node:<v>-slim base. That
# keeps Node *above* the shared base layer instead of baking a per-major Debian
# base underneath the dev tooling. The tarball is integrity-checked against
# SHASUMS256.txt; both are fetched over TLS from nodejs.org.
RUN set -eux; \
    dpkg_arch="$(dpkg --print-architecture)"; \
    case "$dpkg_arch" in \
        amd64) node_arch='x64' ;; \
        arm64) node_arch='arm64' ;; \
        *) echo "unsupported architecture: $dpkg_arch" >&2; exit 1 ;; \
    esac; \
    tarball="node-v${NODE_VERSION}-linux-${node_arch}.tar.xz"; \
    cd /tmp; \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/${tarball}"; \
    curl -fsSL  "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" \
        | grep " ${tarball}\$" | sha256sum -c -; \
    tar -xJf "${tarball}" -C /usr/local --strip-components=1 --no-same-owner; \
    rm "${tarball}"; \
    node --version; \
    npm --version

# --- pnpm via corepack (corepack ships with Node) ---------------------------
RUN corepack enable \
    && corepack prepare pnpm@${PNPM_VERSION} --activate \
    && pnpm --version

# The devcontainer.metadata label is applied at build time by the CI workflow
# (see .github/workflows/build.yml) from src/devcontainer-metadata.json.

# Keep the container alive when run directly; compose overrides this per service.
CMD ["sleep", "infinity"]
