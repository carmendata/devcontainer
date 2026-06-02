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
# FROM base plus the temporary fetch tools (curl/gnupg/xz, discarded with this
# stage), so building the production image does not pull in the dev tier.
# Installed from the official nodejs.org tarball into /opt/node. Integrity is
# established by GPG-verifying SHASUMS256.txt against the Node release keys
# (https://github.com/nodejs/node#release-keys), then checking the tarball's
# sha256 against that verified manifest -- the same chain the official node
# image uses, so a tampered tarball OR checksum file is rejected.
FROM ${BASE_IMAGE} AS node-build
# Required, no default -- the version lives only in node/variants.json (DRY).
ARG NODE_VERSION
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl xz-utils gnupg dirmngr \
    && rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    [ -n "${NODE_VERSION}" ] || { echo "ERROR: build-arg NODE_VERSION is required -- see node/variants.json" >&2; exit 1; }; \
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
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt.asc"; \
    export GNUPGHOME="$(mktemp -d)"; \
    for key in \
        5BE8A3F6C8A5C01D106C0AD820B1A390B168D356 \
        DD792F5973C6DE52C432CBDAC77ABFA00DDBF2B7 \
        CC68F5A3106FF448322E48ED27F5E38D5B0A215F \
        8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
        890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4 \
        C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
        108F52B48DB57BB0CC439B2997B01419BD92F80A \
        A363A499291CBBC940DD62E41F10027AF002F8B0 \
    ; do \
        gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" \
        || gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
    done; \
    gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME"; \
    grep " ${tarball}\$" SHASUMS256.txt | sha256sum -c -; \
    tar -xJf "${tarball}" -C /opt/node --strip-components=1 --no-same-owner; \
    rm "${tarball}" SHASUMS256.txt SHASUMS256.txt.asc

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
# Required, no defaults -- these live only in node/variants.json (DRY).
ARG PNPM_VERSION
# Rolling image tag for THIS variant (e.g. node22), baked into the reference
# compose.yaml below so a repo's CI copy respects the image it actually runs.
ARG VARIANT_TAG
COPY --from=node-build /opt/node/ /usr/local/
ENV NODE_ENV=development \
    PNPM_HOME=/usr/local/share/pnpm \
    PATH=/usr/local/share/pnpm:$PATH
# pnpm via corepack (corepack ships inside the Node tarball).
RUN [ -n "${PNPM_VERSION}" ] || { echo "ERROR: build-arg PNPM_VERSION is required -- see node/variants.json" >&2; exit 1; } \
    && corepack enable \
    && corepack prepare pnpm@${PNPM_VERSION} --activate \
    && node --version \
    && pnpm --version

# --- baked reference config -------------------------------------------------
# The canonical devcontainer.json + compose.yaml that downstream repos copy into
# their .devcontainer/. Baked here (dev target only -- never in prod) so an
# in-container CI tool can diff/copy the repo's files against the current
# standard. Reference only -- not consumed by the devcontainer runtime.
# Requires the build context to be node/ (not node/src) so examples/ is in scope.
COPY examples/devcontainer.json examples/compose.yaml /usr/local/share/devcontainer/
# Pin the baked compose's app image tag to THIS variant, so a repo running e.g.
# :node22 has CI copy in a :node22 reference (not the example's default). This is
# why the per-repo Node major needs no .env -- the copy matches the running image.
RUN [ -n "${VARIANT_TAG}" ] || { echo "ERROR: build-arg VARIANT_TAG is required (the variant name, e.g. node22)" >&2; exit 1; } \
    && sed -i -E "s|(ghcr\.io/carmendata/devcontainer:)[A-Za-z0-9._-]+|\1${VARIANT_TAG}|" \
        /usr/local/share/devcontainer/compose.yaml

# Keep the container alive when run directly; compose overrides this per service.
CMD ["sleep", "infinity"]
