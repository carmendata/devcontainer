# syntax=docker/dockerfile:1.7
# Tier 2 of 3: dev/CI tooling, layered on the minimal prod base (tier 1,
# base/src/Dockerfile). This is everything a devcontainer or CI job wants but
# that should NOT ship to production -- git, gh, jq, make, the db client CLIs,
# and the Docker engine. Language runtimes go in tier 3 on top of this
# (node/src/Dockerfile, and later go/python).
#
# Built and pushed once, so these layers are stored once and shared by every
# language variant above. BASE_IMAGE is the prod base this extends; CI pins it
# to the immutable base-<sha> built in the same run.
ARG BASE_IMAGE=ghcr.io/carmendata/base:latest
FROM ${BASE_IMAGE}

# --- system packages --------------------------------------------------------
# Stack-agnostic dev essentials. MySQL and Redis run as service containers (see
# the per-stack compose files), so only their CLIs are installed here.
# xz-utils unpacks the Node tarball in the language tier; iptables is required
# by dockerd at runtime. build-essential is intentionally NOT installed -- a
# language tier whose stack compiles native code adds gcc/g++/python3 itself.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl gnupg xz-utils \
        git openssh-client \
        jq make less vim iproute2 procps iptables \
        sqlite3 redis-tools default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# --- shell + mysql client defaults ------------------------------------------
# Bake the shared interactive shell config (branch-aware prompt) and the mysql
# client config so `mysql`/`mysqladmin` reach the compose 'mysql' service with
# no per-repo .devcontainer files. .my.cnf is 0600 by convention for a client
# config that may later hold credentials.
COPY --chmod=0644 bashrc /root/.bashrc
COPY --chmod=0644 bash_profile /root/.bash_profile
COPY --chmod=0600 my.cnf /root/.my.cnf

# --- git-subtree ------------------------------------------------------------
# Debian's git package does not put `git-subtree` on PATH, but the repo
# bootstrap (init.dev.sh) relies on `git subtree add/pull` to vendor .ci/.
# Fetch the subtree script pinned to the installed git version (not master, to
# avoid drift against the installed git's internals) and drop it on PATH.
RUN GIT_VERSION="$(git --version | awk '{print $3}')" \
    && curl -fsSL "https://raw.githubusercontent.com/git/git/v${GIT_VERSION}/contrib/subtree/git-subtree.sh" \
        -o /usr/local/bin/git-subtree \
    && chmod 0755 /usr/local/bin/git-subtree

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

# --- Docker engine + buildx (Docker-in-Docker for release image builds) -----
# Baked in so a container that needs to build release images can run its own
# Docker daemon. That requires the container to be started with --privileged
# (set `privileged: true` on the service); then call `start-dockerd` (see
# start-dockerd) before the `docker buildx build` steps. The daemon is never
# started automatically -- CMD stays `sleep infinity` and start-dockerd is
# invoked explicitly -- so a container left unprivileged simply never runs it.
#
# Versions are pinned for reproducible release builds; bump deliberately rather
# than letting them float. Verify the strings exist for both amd64 and arm64 in
# Docker's apt repo before bumping:
#   https://download.docker.com/linux/debian/dists/trixie/stable/
ARG DOCKER_VERSION=5:29.5.2-1~debian.13~trixie
ARG CONTAINERD_VERSION=2.2.4-1~debian.13~trixie
ARG BUILDX_VERSION=0.34.1-1~debian.13~trixie
RUN curl -fsSL https://download.docker.com/linux/debian/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod go+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian trixie stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        docker-ce=${DOCKER_VERSION} \
        docker-ce-cli=${DOCKER_VERSION} \
        containerd.io=${CONTAINERD_VERSION} \
        docker-buildx-plugin=${BUILDX_VERSION} \
    && rm -rf /var/lib/apt/lists/*
COPY --chmod=0755 start-dockerd /usr/local/bin/start-dockerd

# --- clone-in-volume mountpoint ---------------------------------------------
# VS Code's "Clone Repository in Container Volume" mounts a named volume at
# /workspaces and clones into /workspaces/<repo>. Pre-create the mountpoint so
# the runtime never has to mkdir it: under rootless Podman in the macOS VM that
# runtime mkdir fails with "mkdir /workspaces: operation not permitted" (EPERM).
# With the dir already present the volume just mounts over it. Harmless to the
# "Reopen in Container" flow, which uses /workspace (singular) via the bind mount.
RUN mkdir -p /workspaces

# Keep the container alive when run directly; compose overrides this per service.
CMD ["sleep", "infinity"]
