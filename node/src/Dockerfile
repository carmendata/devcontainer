# syntax=docker/dockerfile:1.7
# NODE_VARIANT and PNPM_VERSION are set per build variant by CI from
# variants.json. The defaults below are only the fallback for a bare
# `docker build` with no --build-arg.
ARG NODE_VARIANT=24-bookworm-slim
FROM node:${NODE_VARIANT}

ARG PNPM_VERSION=10.33.0

ENV NODE_ENV=development \
    PNPM_HOME=/usr/local/share/pnpm \
    PATH=/usr/local/share/pnpm:$PATH

# --- system packages --------------------------------------------------------
# node:<v>-bookworm-slim is debian:bookworm-slim plus Node -- the smallest
# Debian base that still ships Node, so there is no separate Node install step
# and no NodeSource layer. The dev essentials below are added explicitly;
# MySQL and Redis run as service containers (see compose.yaml), so only their
# CLIs (default-mysql-client, redis-tools) are installed here.
#
# build-essential is intentionally NOT installed -- only `make`, for running
# Makefiles. A repo that compiles native npm addons (node-gyp) would also need
# gcc/g++/python3; add build-essential to this list if that ever comes up.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg \
        git openssh-client \
        jq make less iproute2 procps \
        sqlite3 redis-tools default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# --- GitHub CLI -------------------------------------------------------------
# gh is not in Debian's default repos; install from GitHub's apt repository.
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# --- pnpm via corepack (corepack ships with Node) ---------------------------
RUN corepack enable \
    && corepack prepare pnpm@${PNPM_VERSION} --activate \
    && node --version \
    && pnpm --version

# The devcontainer.metadata label is applied at build time by the CI workflow
# (see .github/workflows/build.yml) from src/devcontainer-metadata.json.

# Keep the container alive when run directly; compose overrides this per service.
CMD ["sleep", "infinity"]
