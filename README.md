# devcontainer

A devcontainer setup, initially for Node.js projects: Node 22 and Node 24 (LTS) + pnpm `app` images, run alongside MySQL 8 and Redis 7 service containers via Docker Compose. Designed to be referenced from a small `.devcontainer/` directory in every downstream repo so updates land everywhere without per-repo changes.

All Node-stack code lives under [`node/`](node/); the repo is laid out so other stacks — a `go/` or `python/` directory — can be added alongside it later.

## Using the image

The devcontainer is a Compose stack of three containers — your dev environment (`app`) plus `mysql` and `redis` — so a downstream repo needs two files. Copy both from [`node/examples/`](node/examples/) into a `.devcontainer/` directory at your repo root:

- `.devcontainer/devcontainer.json`
- `.devcontainer/compose.yaml`

`devcontainer.json` is just:

```jsonc
{
  "name": "my-project Development",
  "dockerComposeFile": "compose.yaml",
  "service": "app",
  "workspaceFolder": "/workspace"
}
```

`compose.yaml` pulls the published `app` image — set its tag to the Node major you want, `node22` or `node24` (see [Tagging](#tagging)) — and defines the `mysql` and `redis` services. The `app` image still carries its own VS Code extension list, settings, mount config, and post-attach hook via an embedded `devcontainer.metadata` label — the Dev Containers extension reads that label and merges it with `devcontainer.json`, so anything genuinely repo-specific composes with the image defaults rather than replacing them. Repo-specific infrastructure (an extra service, a different mount) goes in your copy of `compose.yaml`.

## What's in it

The repo publishes several `app` image **variants** — each a Node major paired with a pnpm version — defined in [`node/variants.json`](node/variants.json):

| Variant tag | Node.js  | pnpm    |
|-------------|----------|---------|
| `node22`    | 22 (LTS) | 10.33.0 |
| `node24`    | 24 (LTS) | 10.33.0 |

Every variant shares the same base: `debian:bookworm-slim` via the official `node:<major>-bookworm-slim` image, with pnpm enabled through corepack.

Plus the `redis-cli` and `mysql` client CLIs for use from the dev shell. The `mysql` client is Debian's MariaDB-flavoured `default-mysql-client` — there is no `arm64` Oracle MySQL client package — and it connects to the `mysql` service normally.

The `app` image is deliberately lean: a `node:<major>-bookworm-slim` base and no C/C++ toolchain. `make` is included, but `build-essential` is not. A repo whose npm dependencies compile native addons (`node-gyp`) needs `gcc`/`g++`/`python3` — add `build-essential` back to `node/src/Dockerfile`, or install the toolchain in that repo's own setup.

Companion service containers, from official upstream images:

| Service | Image       | Reachable from the devcontainer at |
|---------|-------------|------------------------------------|
| MySQL   | `mysql:8.0` | host `mysql`, port 3306            |
| Redis   | `redis:7.4` | host `redis`, port 6379            |

Connect to them by **service name** — e.g. `mysql -h mysql -u root` or `redis-cli -h redis`. The MySQL root user has no password (`MYSQL_ALLOW_EMPTY_PASSWORD`) — this is a dev sandbox, not a production database. Redis runs with persistence disabled. MySQL data lives in a named volume (`mysql-data`), so it survives a container restart but `docker compose down -v` wipes it; Redis is fully ephemeral. The example `compose.yaml` does not publish the database ports to the host — add a `ports:` mapping if you need host-side access.

## Architecture

The `app` image builds natively for both **`arm64` and `amd64`** — no emulation. This is the payoff of running MySQL and Redis as service containers rather than installing them into the image: MySQL's Debian apt repo ships no `arm64` packages (which previously forced an amd64-only image and broke Redis under QEMU emulation on Apple Silicon), but the official `mysql` and `redis` container images are multi-arch. Every container — `app`, `mysql`, `redis` — now runs native on whatever host it lands on.

## Tagging

All variants publish to a single package — **`ghcr.io/<owner>/devcontainer`** — with the variant in the **tag**, not the image name. This keeps the package stack-agnostic: today `devcontainer:node22` and `devcontainer:node24`, with room to add `devcontainer:go`, `devcontainer:python`, and so on later.

The variants and the tags they publish are defined in [`node/variants.json`](node/variants.json). For each variant, CI publishes:

- its **rolling tag(s)** — e.g. `node22`, `node24` — tracking the latest build of that variant; **the recommended pin for most repos**
- an **immutable tag** `<variant-name>-<git-sha>` — e.g. `node24-a1b2c3d` — for pinning a repo to a known-good build

There is deliberately **no `latest` tag**: across multiple stacks sharing one package it would be ambiguous, so every consumer picks an explicit variant tag. Pin the tag matching your project; if a build breaks something, switch that repo to the matching `<name>-<sha>` tag and roll forward at your own pace.

## Updating

The Node images rebuild on every push to `main` that touches `node/`, weekly on Monday 04:00 UTC to pick up base-image and OS security updates, and on demand via `workflow_dispatch` — see [`.github/workflows/build-node.yml`](.github/workflows/build-node.yml). To change something everyone gets — a new extension, an extra system package, a Node or pnpm version — edit the relevant file and push to `main`.

- `node/variants.json` — the Node/pnpm build variants and the tags each publishes
- `node/src/Dockerfile` — the `app` image: base image, system packages, pnpm
- `node/src/devcontainer-metadata.json` — extensions, settings, mounts, lifecycle hooks
- `node/examples/compose.yaml` — the service definitions downstream repos copy

To add a build variant — a new Node major, or a second pnpm version for an existing one — add an object to `node/variants.json` with a unique `name`, the `node` base-image suffix (e.g. `24-bookworm-slim`), a `pnpm` version, and the rolling `tags` to publish. For example, a second pnpm line for Node 24: `{ "name": "node24-pnpm9", "node": "24-bookworm-slim", "pnpm": "9.15.0", "tags": ["node24-pnpm9"] }`. CI picks it up on the next push — no workflow change needed.

Two caveats on how changes propagate. Changes to `devcontainer-metadata.json` don't rebuild the image layers — the JSON is excluded from the Docker build context via `node/src/.dockerignore` and applied as a label at build time; pushing a metadata-only change still produces a new image but is cheap. And changes to `node/examples/compose.yaml` (e.g. a new MySQL version) reach a downstream repo only when it re-copies the file — unlike the `app` image, which is pulled automatically on the next container rebuild.

## Image visibility

GHCR packages default to private. After the first successful build, go to the package's settings on GitHub and either set it to public (recommended for an internal-only org-wide devcontainer) or grant pull access to the orgs and teams that need it. Otherwise downstream `docker pull` fails with auth errors that aren't always obvious from the VS Code side.

## Building locally

Everything for the Node stack lives under [`node/`](node/) — work from there:

```bash
cd node
docker compose build              # build the app image (default variant)
docker compose up -d --wait       # start app + mysql + redis
```

`--wait` blocks until every healthcheck passes. Poke at the stack:

```bash
docker compose exec app bash
# inside the container:
node --version
pnpm --version
redis-cli -h redis ping
mysql -h mysql -u root -e "SELECT VERSION();"
```

Tear down with `docker compose down -v` (the `-v` also drops the MySQL volume).

`docker compose build` uses the default variant; build another with `NODE_VARIANT=22-bookworm-slim docker compose build`. To build every variant at once, run [`node/build-all.sh`](node/build-all.sh); to smoke-test the full stack for every variant, run [`node/test/smoke.sh`](node/test/smoke.sh) (or pass one variant name, e.g. `./test/smoke.sh node24`). `podman compose` works in place of `docker compose`; `build-all.sh` and `test/smoke.sh` auto-detect a working docker or podman engine (force one with `DOCKER=podman`).

## Why a custom image rather than features

Devcontainer features are modular but they run setup logic at container creation time, and a stack of five features can add minutes to first-create. Baking the same outcome into a pre-built image trades modular composition for predictability — every developer hits identical bytes, container creation is fast, and the surface for "works on my machine" shrinks.

The trade-off goes the other way once teams need genuinely different stacks. At that point add more variants, or split into a separate stack directory. Don't try to make one image cover every project.

## Layout

```
.
├── .github/workflows/
│   └── build-node.yml               multi-arch matrix build + push to GHCR
├── node/                            the Node devcontainer stack
│   ├── variants.json                Node/pnpm build variants + their tags
│   ├── build-all.sh                 build every variant locally
│   ├── compose.yaml                 local build + test stack
│   ├── src/
│   │   ├── Dockerfile               the app image definition
│   │   ├── devcontainer-metadata.json   baked into the image as a label
│   │   └── .dockerignore
│   ├── examples/
│   │   ├── devcontainer.json        downstream .devcontainer/ template
│   │   └── compose.yaml             downstream service definitions
│   └── test/
│       └── smoke.sh                 stack smoke test
└── README.md
```

Further stacks would sit alongside `node/` — a `go/` or `python/` directory with its own `variants.json`, and a matching `.github/workflows/build-<stack>.yml`.
