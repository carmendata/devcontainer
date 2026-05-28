# syntax=docker/dockerfile:1.7
# Tier 1 of 3: the shared foundation, kept minimal so it is usable for
# PRODUCTION as well as dev. Production images (in other repos) do
# `FROM ghcr.io/<owner>/devcontainer:base` and add only their app + runtime;
# devcontainers add the dev tooling (tier 2, dev/src/Dockerfile) and a language
# (tier 3, node/src/Dockerfile) on top.
#
# Keep this lean: only org-wide essentials that a production container also
# wants belong here. Dev/CI tooling (git, gh, docker, jq, make, db clients)
# lives in the dev tier so it never ships to production. Building and pushing
# this once means its layers are stored once and shared by every tier above.
FROM debian:trixie-slim

# ca-certificates: TLS trust store, needed by anything making HTTPS calls in
# prod or dev. Add further org-wide prod essentials here (e.g. tzdata, locales).
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Keep the container alive when run directly; compose overrides this per service.
CMD ["sleep", "infinity"]
