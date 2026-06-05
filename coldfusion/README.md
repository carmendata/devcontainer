# ColdFusion 2021 devcontainer (POC)

A devcontainer for ongoing local development of **existing (legacy) Adobe
ColdFusion 2021** projects. It layers a known-good **production** CF 2021 install
onto the shared [`dev`](../dev/) tier — exactly like the [`node/`](../node/)
stack layers Node — and runs it next to a MySQL 8 service container.

> **Status: proof of concept.** This has **not** been validated against a live
> backup or an amd64 build host. Treat the steps below as the intended flow and
> expect to tune two things on first real build: the runtime libraries in
> [`src/Dockerfile`](src/Dockerfile) (if CF logs missing `.so` files) and the CF
> install path / archive layout in [`src/cf-fetch.sh`](src/cf-fetch.sh). CI
> publishing to GHCR and a `variants.json` are deliberately **deferred** to a
> later phase.

## Why copy a production install instead of running the installer

CF 2021 is proprietary, **amd64-only**, and its installer does not support
Debian trixie (the base OS of these images). Rather than fight the silent
installer and licensing, this bakes the **whole standalone install tree** from a
production backup —`/opt/coldfusion2021` (`cfusion/` + the bundled `jre/`)— onto
the dev tier at the *same path*, so the baked start script, `jvm.config`, and
`JAVA_HOME` all resolve unchanged. The result is a deterministic build and a CF
runtime identical to production.

On Apple Silicon the CF container runs under **amd64 emulation** (MySQL stays
native — it's a separate, multi-arch service container).

## Prerequisites

- The same prerequisites as the [Node stack](../README.md#using-the-image):
  VS Code, the Dev Containers extension, and a container engine.
- A **tar** of your production `/opt/coldfusion2021` tree in an S3-compatible
  bucket (MinIO, Cloudflare R2, Backblaze B2, Wasabi, AWS S3, …). Any of these
  archive layouts is accepted (see [`src/cf-fetch.sh`](src/cf-fetch.sh)):

  ```
  coldfusion2021/cfusion/...        # tar -C /opt coldfusion2021
  opt/coldfusion2021/cfusion/...    # tar with a leading opt/
  cfusion/...  jre/...              # tar -C /opt/coldfusion2021 .
  ```

## Build

The CF tree is fetched at build time from a **presigned URL** passed as a
BuildKit secret — so the URL and the licensed CF bits never enter an image layer
or the build cache. Generate a short-lived presigned URL with your provider's
tooling and drop it (URL only) into `cf_backup_url.txt`:

```bash
cd coldfusion

# pick the one for your provider:
aws s3 presign s3://<bucket>/<key> --expires-in 3600   > cf_backup_url.txt   # AWS / generic
mc  share download --expire 1h <alias>/<bucket>/<key>  > cf_backup_url.txt   # MinIO (use the URL it prints)

docker compose build        # fetches the tree + tags devcontainer:coldfusion2021
```

`cf_backup_url.txt` is **gitignored** — it is a credential. `BASE_IMAGE` /
`DEV_IMAGE` default to the published tiers, so you don't need to build `base`/
`dev` yourself.

Equivalent raw `buildx` (compose just wraps this):

```bash
docker buildx build --target dev \
  --secret id=cf_backup_url,src=./cf_backup_url.txt \
  -f src/Dockerfile -t devcontainer:coldfusion2021 .
```

## Run it as a devcontainer

In your **legacy CF project** repo, copy the two files from
[`examples/`](examples/) into a `.devcontainer/` directory:

- `.devcontainer/devcontainer.json`
- `.devcontainer/compose.yaml`

They reference the locally built `devcontainer:coldfusion2021` image (POC; this
becomes a pulled GHCR tag once CI lands). Then **Reopen in Container** in VS
Code. Your repo mounts at `/workspace`.

Inside the container:

```bash
cfstart                         # start CF + tail its logs (cfstop to stop)
# CF Administrator:  http://localhost:8500/CFIDE/administrator/
mysql -h mysql -u root          # the MySQL service (passwordless dev root)
```

### Where your app is served

`postStartCommand` symlinks your repo into CF's webroot at
`http://localhost:8500/app/`, leaving the baked **CFIDE** (CF Administrator)
working at the web root. A legacy app that must live at `/` instead can point
Tomcat's `docBase` at `/workspace` in
`/opt/coldfusion2021/cfusion/runtime/conf/server.xml` (you then lose the
in-container CFIDE unless you also copy it under `/workspace`). Tune this to how
the app expects to be mounted.

### Datasources

Datasources baked into the backup point at the *production* DB. For local work,
either re-point them at the `mysql` service (host `mysql`, port 3306) in the CF
Administrator, or add new ones. The MySQL JDBC driver must be on CF's classpath —
recent CF 2021 updates bundle it; if not, drop the connector jar into
`/opt/coldfusion2021/cfusion/lib`.

## Files

```
coldfusion/
├── compose.yaml              local build + test stack (builds app + mysql; wires the build secret)
├── .dockerignore             build context is coldfusion/; keep it lean, exclude the credential
├── src/
│   ├── Dockerfile            multi-stage: cf-fetch (download/extract) -> dev (dev tier + CF + jre)
│   ├── cf-fetch.sh           fetch + normalise the prod CF tree from the presigned S3 URL
│   ├── cfstart / cfstop      start/stop the standalone CF server in the dev shell
│   └── (cf_backup_url.txt)   YOU create this — gitignored presigned URL; never committed
├── examples/                 the config a downstream legacy repo copies into .devcontainer/
│   ├── devcontainer.json     CF devcontainer config (CFML extension, ports, webroot symlink)
│   └── compose.yaml          service definitions (app + mysql)
└── README.md
```

## Deferred to a later phase

- Publishing `devcontainer:coldfusion2021` to GHCR via a `coldfusion` job in
  [`.github/workflows/build.yml`](../.github/workflows/build.yml) — including how
  to inject the backup secret in CI (a GitHub Actions secret feeding
  `--secret id=cf_backup_url`).
- A `variants.json` / `build-all.sh` / `smoke.sh` for the stack, matching
  `node/`.
- Deciding whether the CF tree belongs baked into the image (current approach,
  self-contained) or bind-mounted at runtime (faster iteration, not portable).
