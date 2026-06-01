# Using Podman in place of Docker

We use **[Podman](https://podman.io/)** (via [Podman Desktop](https://podman-desktop.io/))
as our container engine. It runs the same OCI images as Docker, is daemonless,
runs containers rootless by default, and is free for any use — no per-seat
licensing to worry about as a team grows. This page gets it installed and makes
it a drop-in replacement for `docker`, including driving the VS Code Dev
Containers extension.

Running the devcontainer on Podman gives every developer a **consistent,
platform-agnostic development environment**: the same image, the same Node and
tooling, and the same MySQL/Redis service containers run identically on Windows,
macOS, and Linux. The container is the environment, so "works on my machine"
stops depending on what's installed on the host — everyone builds against the
same bytes regardless of platform.

---

## Before you start: remove Docker Desktop

If Docker Desktop is installed, **uninstall it before installing Podman.**
Running both engines on one machine causes conflicts — a clash over the `docker`
CLI name (and the alias in step 3 below), competing WSL distributions on
Windows, and confusion over which engine actually served a `docker` command.
A clean switch avoids all of it.

→ [How to uninstall Docker Desktop](UNINSTALL-DOCKER.md)

Come back here once it's removed.

> Never had Docker Desktop? Nothing to do — skip straight to step 1.

---

## 1. Install Podman Desktop

Download and install from **https://podman-desktop.io/downloads** (Windows,
macOS, Linux).

On first launch, Podman Desktop walks you through installing the Podman engine
itself if it isn't already present. Accept the prompts.

> **Windows / macOS run Podman in a Linux VM** (a "Podman machine") — Linux
> containers can't run natively on those kernels. Podman Desktop creates and
> starts this machine for you. On Linux there's no VM; Podman runs containers
> directly.

### Windows: use the WSL2 backend (not Hyper-V)

On Windows, Podman Desktop can back its machine with either **WSL2** or
**Hyper-V**. **Use WSL2.** It's lighter, doesn't require Windows Pro/Enterprise
(Hyper-V does), and is the backend the Dev Containers extension and our rootful
Docker-in-Docker setup are tested against.

1. **Enable WSL2 first** (admin PowerShell), then reboot:

   ```powershell
   wsl --install
   wsl --set-default-version 2
   wsl --version          # confirm WSL 2 is present
   ```

2. **Tell Podman to use WSL.** In Podman Desktop's onboarding / **Settings →
   Resources**, choose the **WSL** provider when creating the machine. For the
   CLI, set the provider before `podman machine init`:

   ```powershell
   $env:CONTAINERS_MACHINE_PROVIDER = "wsl"
   ```

   (or set `[machine] provider = "wsl"` in `containers.conf` to make it
   permanent).

3. **Already created a Hyper-V machine?** Remove it and recreate on WSL:

   ```powershell
   podman machine rm        # removes the existing machine
   $env:CONTAINERS_MACHINE_PROVIDER = "wsl"
   podman machine init
   ```

You can confirm the backend later with `podman machine inspect` — the `VMType`
should read `wsl`.

### Initialise the Podman machine (Windows / macOS)

If Podman Desktop didn't already do it, create and start the VM:

```bash
podman machine init
podman machine start
```

Give it enough resources for the devcontainer plus the MySQL and Redis service
containers — bump CPUs/memory if builds feel slow:

```bash
podman machine init --cpus 4 --memory 8192   # 8 GB; adjust to taste
```

Verify the engine is up — this should print **both** a Client and a Server
section:

```bash
podman version
```

### Install the Compose provider

This project is a Compose stack (app + mysql + redis), so Podman needs a Compose
provider. Use the **`podman compose`** subcommand. Install it straight from
Podman Desktop — it bundles the right binary for you:

1. Open **Podman Desktop → Settings (⚙) → Resources**.
2. Find the **Compose** card and click **Setup** / **Install**.
3. Podman Desktop downloads the `compose` binary and puts it on `PATH` for use
   as `podman compose` — nothing else to configure.

Verify it works:

```bash
podman compose version
```

---

## 2. Point VS Code Dev Containers at Podman

The Dev Containers extension shells out to a `docker`-compatible CLI. Tell it to
use `podman` instead.

In VS Code: **Settings** (`Ctrl/Cmd+,`) → search **Dev › Containers: Docker
Path** → set it to:

```
podman
```

Or add to your `settings.json` directly:

```jsonc
{
  "dev.containers.dockerPath": "podman",
  "dev.containers.dockerComposePath": "podman compose",
  "dev.containers.bootstrapImage": "ghcr.io/carmendata/devcontainer:node24",
}
```

Restart VS Code after changing these so the extension picks them up.

---

## 3. Make `docker` mean `podman` (optional but convenient)

The Podman CLI is command-line compatible with Docker, so the simplest path is
to alias `docker` → `podman`. Then every `docker ...` command in this repo's
README and scripts just works.

**macOS / Linux** — add to `~/.bashrc` or `~/.zshrc`:

```bash
alias docker=podman
```

**Windows (PowerShell)** — add to your profile (`notepad $PROFILE`):

```powershell
Set-Alias docker podman
```

> If `notepad $PROFILE` returns "The system cannot find the path specified" then use `New-Item -ItemType File -Path $PROFILE -Force` to create it then `notepad $PROFILE` again.

> Use `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` to allow the profile script to execute and set the alias.

The repo's own scripts don't need the alias — `node/build-all.sh` and
`node/test/smoke.sh` already auto-detect a working `docker` *or* `podman`
engine, and you can force one with `DOCKER=podman ./test/smoke.sh`.


---

## 4. Verify end to end

```bash
podman version                       # Client + Server both shown
podman run --rm hello-world          # pulls and runs a tiny image
podman machine list                  # (Win/macOS) machine is "Currently running"
```

Then open a repo with a `.devcontainer/` directory and **Reopen in Container** —
VS Code should build/pull and attach exactly as it would under Docker.

---

## Notes & gotchas

- **Running CI image builds in the devcontainer needs a rootful machine.** This
  image can run its own Docker engine *inside* the devcontainer for CI/release
  image builds (Docker-in-Docker — see the
  [project README](../README.md#building-images-from-ci)). The devcontainer
  service is started with `privileged: true`, and `start-dockerd` launches a real
  `dockerd` inside it. Rootless Podman can't host that nested daemon — even a
  privileged *rootless* container runs inside your user namespace without the
  full `CAP_SYS_ADMIN` access `dockerd` needs — so run the Podman **machine**
  itself rootful:

  ```bash
  podman machine stop
  podman machine set --rootful
  podman machine start
  ```

  Or create it that way up front:

  ```bash
  podman machine init --rootful
  ```

  Check or revert the mode any time:

  ```bash
  podman machine inspect --format '{{.Rootful}}'   # true / false
  podman machine set --rootful=false               # back to rootless
  ```

  After switching, Podman's default connection points at the rootful socket, so
  the VS Code Dev Containers extension (`dev.containers.dockerPath: podman`) and
  `start-dockerd` inside the container both work with no further config — restart
  VS Code so it reconnects. If you only ever pull and run the devcontainer (no
  in-container image builds), rootless is fine and you can skip this.
- **Bind-mount permissions.** Rootless Podman maps your host user into the
  container via user namespaces. Files created in the mounted `/workspace`
  generally come back owned by you on the host — often *nicer* than Docker's
  root-owned files, but if you hit an ownership mismatch it's the userns mapping,
  not a bug in the image.
- **Port forwarding.** Rootless Podman can't bind host ports below 1024 without
  extra config. The devcontainer doesn't need privileged ports (MySQL/Redis are
  reached by service name, not published to the host), so this rarely bites.
- **First pull is slower.** Podman fetches images into its own local store the
  first time; subsequent runs are cached just like Docker.

---

## Next step

Back to the [setup guide](README.md) — continue with your
[SSH key](SSH-KEY.md) if you haven't set one up yet.
