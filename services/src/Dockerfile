# syntax=docker/dockerfile:1.7
# Mirror tier: re-publish a pinned upstream service image (mysql, redis, ...) to
# GHCR so the egress-sandboxed matterhorn hosts (and production) can pull it from
# ghcr.io's stable Fastly IPs instead of docker.io's churning multi-CDN backend.
#
# Vanilla passthrough -- no config baked in; that is supplied at deploy time via
# compose/swarm. Pinning FROM_IMAGE by tag keeps it current via the weekly
# rebuild; pin by @sha256 digest as well if you want an immutable upstream.
ARG FROM_IMAGE
FROM ${FROM_IMAGE}
