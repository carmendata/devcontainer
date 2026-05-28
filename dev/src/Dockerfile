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
ARG BASE_IMAGE=ghcr.io/carmendata/devcontainer:base
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
        jq make less iproute2 procps iptables \
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

# --- Docker engine + buildx (Docker-in-Docker for CI release builds) --------
# Baked in only for CI/release jobs that build images: such a job runs the image
# with --privileged and calls `start-dockerd` (see start-dockerd) before its
# `docker buildx build` steps. Devcontainers never start this daemon -- their
# mysql/redis siblings run on the *host* daemon via the stack compose file, so
# dockerd here stays stopped and no --privileged is needed for dev use.
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

# Keep the container alive when run directly; compose overrides this per service.
CMD ["sleep", "infinity"]
