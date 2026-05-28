# syntax=docker/dockerfile:1.7
# One Node version, two images built from this file via --target:
#
#   target `prod` -- base + Node only: a lean PRODUCTION runtime base that runs
#       as a non-root user. Downstream app repos do
#       `FROM ghcr.io/<owner>/production:node<major>`, copy in their built app,
#       and set their own CMD. No dev tooling, no docker engine.
#
#   target `dev` (default) -- the devcontainer image: the dev tooling tier
#       (dev/src) + the same Node + pnpm.
#
# Node is downloaded and integrity-checked once in the node-build stage and
# copied into both, so the two images carry byte-identical Node.
ARG BASE_IMAGE=ghcr.io/carmendata/devcontainer:base
ARG DEV_IMAGE=ghcr.io/carmendata/devcontainer:dev

# --- node-build: fetch + verify Node once -----------------------------------
# FROM base plus the temporary fetch tools (curl/xz, discarded with this stage),
# so building the production image does not pull in the dev tier. Installed from
# the official nodejs.org tarball into /opt/node and integrity-checked against
# SHASUMS256.txt; both fetched over TLS from nodejs.org.
FROM ${BASE_IMAGE} AS node-build
ARG NODE_VERSION=24.16.0
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl xz-utils \
    && rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    dpkg_arch="$(dpkg --print-architecture)"; \
    case "$dpkg_arch" in \
        amd64) node_arch='x64' ;; \
        arm64) node_arch='arm64' ;; \
        *) echo "unsupported architecture: $dpkg_arch" >&2; exit 1 ;; \
    esac; \
    tarball="node-v${NODE_VERSION}-linux-${node_arch}.tar.xz"; \
    mkdir -p /opt/node; \
    cd /tmp; \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/${tarball}"; \
    curl -fsSL  "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" \
        | grep " ${tarball}\$" | sha256sum -c -; \
    tar -xJf "${tarball}" -C /opt/node --strip-components=1 --no-same-owner; \
    rm "${tarball}"

# --- prod: production runtime base (base + Node, non-root) -------------------
FROM ${BASE_IMAGE} AS prod
COPY --from=node-build /opt/node/ /usr/local/
ENV NODE_ENV=production
# Run as a non-root user in production. uid/gid 1000 matches the convention of
# the official node image.
RUN groupadd --gid 1000 node \
    && useradd --uid 1000 --gid node --create-home --shell /bin/bash node \
    && node --version \
    && npm --version
USER node
CMD ["node"]

# --- dev: devcontainer image (dev tooling + Node + pnpm) --------------------
FROM ${DEV_IMAGE} AS dev
ARG PNPM_VERSION=10.33.0
COPY --from=node-build /opt/node/ /usr/local/
ENV NODE_ENV=development \
    PNPM_HOME=/usr/local/share/pnpm \
    PATH=/usr/local/share/pnpm:$PATH
# pnpm via corepack (corepack ships inside the Node tarball).
RUN corepack enable \
    && corepack prepare pnpm@${PNPM_VERSION} --activate \
    && node --version \
    && pnpm --version

# The devcontainer.metadata label is applied at build time by the CI workflow
# (see .github/workflows/build.yml) from src/devcontainer-metadata.json.

# Keep the container alive when run directly; compose overrides this per service.
CMD ["sleep", "infinity"]
