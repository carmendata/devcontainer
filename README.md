# devcontainer

A devcontainer setup, initially for Node.js projects: Node 22 and Node 24 (LTS) + pnpm `app` images, run alongside MySQL 8 and Redis 7 service containers via Docker Compose. Designed to be referenced from a small `.devcontainer/` directory in every downstream repo so updates land everywhere without per-repo changes.

Images are built in tiers from a minimal [`base/`](base/) (`debian:trixie-slim` + org-wide essentials), through a [`dev/`](dev/) tier adding the dev/CI tooling and the Docker engine, up to the language images. Each language ships **two** images from one source: the **devcontainer** image (`dev` tier + language + dev conveniences) and a lean, non-root **production** runtime base (`base` + language only) — see [Production images](#production-images). All Node-stack code lives under [`node/`](node/); the repo is laid out so other stacks — a `go/` or `python/` directory — can be added alongside it later, each reusing the same `base`/`dev` tiers.

## Using the image

The devcontainer is a Compose stack of three containers — your dev environment (`app`) plus `mysql` and `redis`. To set one up in a project from VS Code:

**1. Install the prerequisites** — [VS Code](https://code.visualstudio.com/), the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) (`ms-vscode-remote.remote-containers`), and a container engine: Docker Desktop, or Podman (point the extension at it by setting `dev.containers.dockerPath` to `podman` in VS Code settings).

**2. Add the config** — copy both files from [`node/examples/`](node/examples/) into a `.devcontainer/` directory at the root of your repo:

- `.devcontainer/devcontainer.json`
- `.devcontainer/compose.yaml`

Copy these rather than using VS Code's *Dev Containers: Add Dev Container Configuration Files* command — that scaffolds VS Code's own generic templates, not this image.

**3. Choose the Node version** — in `.devcontainer/compose.yaml`, set the `app` service's image tag to the Node major you want, `node22` or `node24` (see [Tagging](#tagging)).

**4. Reopen in the container** — open the repo folder in VS Code. It detects `.devcontainer/` and offers a **Reopen in Container** notification; click it, or run **Dev Containers: Reopen in Container** from the Command Palette (`F1`). VS Code pulls the `app`, `mysql`, and `redis` images, starts the stack, and attaches a shell in the `app` container. The first open takes a minute or two while images download; later opens are near-instant.

After changing the `.devcontainer/` config — or to pick up a newer published image — run **Dev Containers: Rebuild Container**.

> **Image vs. template.** VS Code's *New Dev Container…* command lists devcontainer *templates* — a separate kind of published artifact — not plain images. This project publishes container *images* (referenced by `devcontainer.json`), so always use the copy-the-files flow above. Once `.devcontainer/` is committed to a repo, every entry point — *Reopen in Container*, *Open Folder in Container*, *Clone Repository in Container Volume*, Codespaces — picks it up automatically, with no per-developer setup.

### What the two files do

`devcontainer.json` is minimal:

```jsonc
{
  "name": "my-project Development",
  "dockerComposeFile": "compose.yaml",
  "service": "app",
  "workspaceFolder": "/workspace"
}
```

`compose.yaml` pulls the published `app` image and defines the `mysql` and `redis` services. The `app` image carries its own VS Code extension list, settings, mount config, and post-attach hook via an embedded `devcontainer.metadata` label — the Dev Containers extension reads that label and merges it with `devcontainer.json`, so anything genuinely repo-specific composes with the image defaults rather than replacing them. Repo-specific infrastructure (an extra service, a different mount) goes in your copy of `compose.yaml`.

> **Security note — SSH keys.** The image's metadata bind-mounts your host `~/.ssh` into the container (at `/root/.ssh-host`, and the container runs as `root`). This is convenient for git-over-SSH, but it means any code or VS Code extension running inside the devcontainer can read your private keys. If that exposure matters for your threat model, prefer **SSH agent forwarding** (don't mount the key material), or make the mount read-only — edit the `mounts` entry in `node/src/devcontainer-metadata.json`. The production image is unaffected (no such mount, runs non-root).

## What's in it

The repo publishes several `app` image **variants** — each a Node major paired with a pnpm version — defined in [`node/variants.json`](node/variants.json):

| Variant tag | Node.js  | pnpm    |
|-------------|----------|---------|
| `node22`    | 22 (LTS) | 10.33.0 |
| `node24`    | 24 (LTS) | 10.33.0 |

Every variant is built in three tiers: the minimal `base` (`debian:trixie-slim` + org-wide essentials), the `dev` tier on top (the common dev tooling below), and finally the variant, which adds only Node — installed from the official nodejs.org tarball into `/usr/local` — with pnpm enabled through corepack.

The `dev` tier carries the stack-agnostic tooling shared by every variant: `git`, `gh` (GitHub CLI), `jq`, `make`, `curl`, `ssh`, plus the `redis-cli` and `mysql` client CLIs for use from the dev shell. The `mysql` client is Debian's MariaDB-flavoured `default-mysql-client` — there is no `arm64` Oracle MySQL client package — and it connects to the `mysql` service normally. None of this ships in the `base` tier, so `base` stays lean enough to use as a production base too.

The `dev` tier also bakes in the **Docker engine + buildx**, so a CI/release job can run the image and build images itself (see [Building images from CI](#building-images-from-ci)). This is dormant in the devcontainer — the daemon is never started there.

The images are deliberately lean: no C/C++ toolchain. `make` is included, but `build-essential` is not. A repo whose npm dependencies compile native addons (`node-gyp`) needs `gcc`/`g++`/`python3` — add `build-essential` to `node/src/Dockerfile`, or install the toolchain in that repo's own setup.

### Building images from CI

The `dev` tier bundles the Docker engine, `docker buildx`, and a `start-dockerd` helper so a CI/release pipeline can build and push images from inside this container (Docker-in-Docker), with versions pinned for reproducibility. It is opt-in and used only by CI:

```sh
# the container must be started privileged (privileged: true / --privileged)
start-dockerd
docker buildx build --platform linux/amd64,linux/arm64 -t <image> --push .
```

`start-dockerd` launches `dockerd` and blocks until it is ready, and **fails fast** if the container isn't privileged (it checks for `CAP_SYS_ADMIN` rather than timing out). Grant privilege with `privileged: true` on the service in your `.devcontainer/compose.yaml` (or the release profile), e.g.:

```yaml
services:
  app:
    image: ghcr.io/<owner>/devcontainer:node24
    privileged: true        # required for in-container dockerd (DinD)
```

The daemon never starts on its own — `CMD` stays `sleep infinity` — so a container left unprivileged simply never runs it. Docker versions are pinned in [`dev/src/Dockerfile`](dev/src/Dockerfile); bump them deliberately.

Companion service containers, from official upstream images:

| Service | Image       | Reachable from the devcontainer at |
|---------|-------------|------------------------------------|
| MySQL   | `mysql:8.0` | host `mysql`, port 3306            |
| Redis   | `redis:7.4` | host `redis`, port 6379            |

Connect to them by **service name** — e.g. `mysql -h mysql -u root` or `redis-cli -h redis`. The MySQL root user has no password (`MYSQL_ALLOW_EMPTY_PASSWORD`) — this is a dev sandbox, not a production database. Redis runs with persistence disabled. MySQL data lives in a named volume (`mysql-data`), so it survives a container restart but `docker compose down -v` wipes it; Redis is fully ephemeral. The example `compose.yaml` does not publish the database ports to the host — add a `ports:` mapping if you need host-side access.

## Architecture

The `app` image builds natively for both **`arm64` and `amd64`** — no emulation. This is the payoff of running MySQL and Redis as service containers rather than installing them into the image: MySQL's Debian apt repo ships no `arm64` packages (which previously forced an amd64-only image and broke Redis under QEMU emulation on Apple Silicon), but the official `mysql` and `redis` container images are multi-arch. Every container — `app`, `mysql`, `redis` — now runs native on whatever host it lands on.

**Shared tiers.** The `base` (`debian:trixie-slim` + essentials) and `dev` (base + tooling + docker) tiers are each built and pushed once, and every variant is layered on top of that exact `dev` image. So the heavy lower tiers are stored once in GHCR and pulled once onto a machine — pulling `node24` after `node22` (or a future `go` image) fetches only that variant's thin Node/runtime layer, not the tiers beneath. This is why Node is installed from the nodejs.org tarball in the variant rather than starting from the official `node:<major>-slim` image: a per-major Node base image would sit *below* the shared tooling and defeat that deduplication.

## Production images

Alongside each devcontainer image, CI publishes a matching **production runtime base** to `ghcr.io/<owner>/production`. It is built from the same [`node/src/Dockerfile`](node/src/Dockerfile) (the `prod` build target) and carries **byte-identical Node** — the Node tarball is fetched and verified once in a shared `node-build` stage and copied into both images. The difference is what sits underneath: the production image is just `base` + Node, so it has **none** of the dev/CI tooling — no docker engine, no `gh`, no `git`/`make`/db clients — and it runs as a **non-root** `node` user (uid/gid 1000) with `NODE_ENV=production`.

Consume it from a downstream app's own Dockerfile:

```dockerfile
FROM ghcr.io/<owner>/production:node24
WORKDIR /app
COPY --chown=node:node . .
# (switch to USER root first if you need to install OS packages, then back)
CMD ["node", "server.js"]
```

Pin `production:node24` (rolling) or `production:node24-<sha>` (immutable), exactly like the devcontainer tags below. Keeping the production base in lock-step with the devcontainer's Node version is the point: developers and production run the same runtime.

## Tagging

Two packages, with the tier/variant in the **tag**, not the image name:

- **`ghcr.io/<owner>/devcontainer`** — the devcontainer images and their build tiers: `devcontainer:base`, `devcontainer:dev`, and the variants `devcontainer:node22` / `devcontainer:node24` (room for `:go`, `:python`, … later).
- **`ghcr.io/<owner>/production`** — the lean production runtime bases: `production:node22` / `production:node24` (see [Production images](#production-images)).

Both keep the package stack-agnostic. Most repos pin a language variant tag.

The variants and the tags they publish are defined in [`node/variants.json`](node/variants.json). For each variant, CI publishes:

- its **rolling tag(s)** — e.g. `node22`, `node24` — tracking the latest build of that variant; **the recommended pin for most repos**
- an **immutable tag** `<variant-name>-<git-sha>` — e.g. `node24-a1b2c3d` — for pinning a repo to a known-good build

There is deliberately **no `latest` tag**: across multiple stacks sharing one package it would be ambiguous, so every consumer picks an explicit variant tag. Pin the tag matching your project; if a build breaks something, switch that repo to the matching `<name>-<sha>` tag and roll forward at your own pace.

## Updating

Builds are **not** triggered by `git push` — pushing only saves work. The workflow runs on demand via `workflow_dispatch` (driven by `make deploy`, below) and weekly on Monday 04:00 UTC to pick up base-image and OS security updates — see [`.github/workflows/build.yml`](.github/workflows/build.yml). It builds the tiers in order — `base`, then `dev`, then each variant (both its production and devcontainer images).

The [`Makefile`](Makefile) drives the pipeline (it wraps the GitHub CLI, so `gh` must be authenticated):

```bash
make deploy   # trigger build.yml on the current branch and watch it
make runs     # list recent workflow runs
make logs     # show the latest run's log (after a failure)
```

To change something everyone gets — a new extension, an extra system package, a Node or pnpm version — edit the relevant file and push to `main`.

- `base/src/Dockerfile` — the minimal prod-capable base (`debian:trixie-slim` + essentials)
- `dev/src/Dockerfile` — the dev/CI tier: common system packages, `gh`, the pinned Docker engine/buildx
- `dev/src/start-dockerd` — the opt-in Docker-in-Docker daemon launcher for CI
- `node/variants.json` — the Node/pnpm build variants and the tags each publishes
- `node/src/Dockerfile` — multi-stage: the `prod` target (production runtime base) and the `dev` target (devcontainer image), sharing one Node install
- `node/src/devcontainer-metadata.json` — extensions, settings, mounts, lifecycle hooks
- `node/examples/compose.yaml` — the service definitions downstream repos copy

To add a build variant — a new Node major, or a second pnpm version for an existing one — add an object to `node/variants.json` with a unique `name`, the full `node` version (e.g. `24.16.0`), a `pnpm` version, and the rolling `tags` to publish. For example, a second pnpm line for Node 24: `{ "name": "node24-pnpm9", "node": "24.16.0", "pnpm": "9.15.0", "tags": ["node24-pnpm9"] }`. CI picks it up on the next push — no workflow change needed.

Two caveats on how changes propagate. Changes to `devcontainer-metadata.json` don't rebuild the image layers — the JSON is excluded from the Docker build context via `node/src/.dockerignore` and applied as a label at build time; pushing a metadata-only change still produces a new image but is cheap. And changes to `node/examples/compose.yaml` (e.g. a new MySQL version) reach a downstream repo only when it re-copies the file — unlike the `app` image, which is pulled automatically on the next container rebuild.

## Image visibility

GHCR packages default to private. After the first successful build there are **two** packages — `devcontainer` and `production` — and each must be made visible independently: go to the package's settings on GitHub and either set it to public (recommended for an internal-only org-wide image) or grant pull access to the orgs and teams that need it. Otherwise downstream `docker pull` fails with auth errors that aren't always obvious from the VS Code side.

## Building locally

Everything for the Node stack lives under [`node/`](node/) — work from there:

```bash
cd node
docker compose build              # build the app image (default variant)
docker compose up -d --wait       # start app + mysql + redis
```

By default `docker compose build` layers the app on the **published** `base` and `dev` images (`ghcr.io/<owner>/devcontainer:{base,dev}`), so it works without building the lower tiers yourself. To test local changes to `base/` or `dev/`, build the whole chain with [`node/build-all.sh`](node/build-all.sh) — it builds `devcontainer:base` → `devcontainer:dev` → then both targets of every variant (`production:<name>` and `devcontainer:<name>`) — or build the tiers and pass `BASE_IMAGE=devcontainer:base DEV_IMAGE=devcontainer:dev docker compose build`.

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

`docker compose build` uses the default variant; build another with `NODE_VERSION=22.22.3 docker compose build`. To build every variant at once, run [`node/build-all.sh`](node/build-all.sh); to smoke-test the full stack for every variant, run [`node/test/smoke.sh`](node/test/smoke.sh) (or pass one variant name, e.g. `./test/smoke.sh node24`). `podman compose` works in place of `docker compose`; `build-all.sh` and `test/smoke.sh` auto-detect a working docker or podman engine (force one with `DOCKER=podman`).

## Why a custom image rather than features

Devcontainer features are modular but they run setup logic at container creation time, and a stack of five features can add minutes to first-create. Baking the same outcome into a pre-built image trades modular composition for predictability — every developer hits identical bytes, container creation is fast, and the surface for "works on my machine" shrinks.

The trade-off goes the other way once teams need genuinely different stacks. At that point add more variants, or split into a separate stack directory. Don't try to make one image cover every project.

## Layout

```
.
├── Makefile                         trigger/watch the build workflow (gh wrapper)
├── .github/workflows/
│   └── build.yml                    multi-arch base -> dev -> variant build + push to GHCR
├── base/                            tier 1: minimal prod-capable base (all stacks)
│   └── src/
│       └── Dockerfile               debian:trixie-slim + org-wide essentials
├── dev/                             tier 2: dev/CI tooling (all stacks)
│   └── src/
│       ├── Dockerfile               base + git/gh/jq/make/db clients + docker engine
│       └── start-dockerd            opt-in Docker-in-Docker launcher for CI
├── node/                            tier 3: the Node devcontainer stack
│   ├── variants.json                Node/pnpm build variants + their tags
│   ├── build-all.sh                 build base + dev + every variant locally
│   ├── compose.yaml                 local build + test stack
│   ├── src/
│   │   ├── Dockerfile               multi-stage: prod (runtime base) + dev (devcontainer)
│   │   ├── devcontainer-metadata.json   baked into the dev image as a label
│   │   └── .dockerignore
│   ├── examples/
│   │   ├── devcontainer.json        downstream .devcontainer/ template
│   │   └── compose.yaml             downstream service definitions
│   └── test/
│       └── smoke.sh                 stack smoke test
└── README.md
```

Further stacks would sit alongside `node/` — a `go/` or `python/` directory with its own `variants.json` — each layered on the shared `base/` + `dev/` tiers and added as a job in `.github/workflows/build.yml`.
