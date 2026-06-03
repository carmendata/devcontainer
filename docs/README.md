# Getting started

A one-time, per-machine setup to develop inside the devcontainer. Each step is a
quick summary with a link to its detail page — work through them top to bottom.

For what the devcontainer *is* and how the images are built, see the
[project README](../README.md). This guide is just the per-developer setup.

---

## What you'll set up

The container bind-mounts no host files, so it gets what it needs from you three
different ways:

1. **SSH key + agent forwarding** — your key stays on the host; VS Code forwards
   the *agent* in (steps 3–5).
2. **Git identity forwarding** — VS Code copies your host Git config in
   automatically; you just set it on the host (step 6).
3. **`GITHUB_AUTH_TOKEN`** — the one credential you set *manually*: a host env var
   forwarded in for private npm packages and `gh` (step 7).

---

## Setup steps

### 1. Install VS Code + the Dev Containers extension

[VS Code](https://code.visualstudio.com/) plus the
[Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
(`ms-vscode-remote.remote-containers`).

### 2. Install Podman and point VS Code at it

We use Podman Desktop (free, no per-seat licensing). Install it, add the WSL2
backend on Windows, and set `dev.containers.dockerPath` to `podman`.

→ [PODMAN.md](PODMAN.md) · switching from Docker Desktop? [UNINSTALL-DOCKER.md](UNINSTALL-DOCKER.md) first

### 3. Create an SSH key

You need an Ed25519 key pair to reach GitHub from inside the container. Already
have one (`ssh-add -l`, or `~/.ssh/id_ed25519` exists)? Skip ahead.

→ [SSH-KEY.md](SSH-KEY.md)

### 4. Add the key to GitHub

The key only works once GitHub has its public half.

→ [GITHUB-SSH-KEY.md](GITHUB-SSH-KEY.md)

### 5. Set up ssh-agent forwarding

Run the ssh-agent with your key loaded; VS Code forwards the agent into the
container so your private key never enters it.

→ [SSH-AGENT.md](SSH-AGENT.md)

### 6. Install Git and set your identity

Install Git on the host and set `user.name` / `user.email` — VS Code forwards
your Git config into the container automatically.

→ [GIT-IDENTITY.md](GIT-IDENTITY.md)

### 7. Set `GITHUB_AUTH_TOKEN`

Create a classic PAT (scopes `repo`, `write:packages`) and export it on the host
as `GITHUB_AUTH_TOKEN`, for private `@carmendata` packages and `gh`.

→ [GITHUB-TOKEN.md](GITHUB-TOKEN.md)

---

## Open a project

Once setup is done, for any repo with a `.devcontainer/` directory:

- **Fresh start (recommended)** — let VS Code clone the repo into an isolated,
  faster volume-backed workspace; you never clone to your host.
  → [CLONE-IN-VOLUME.md](CLONE-IN-VOLUME.md)
- **Existing checkout** — open the folder and run **Dev Containers: Reopen in
  Container** (`F1`) to bind-mount your host checkout at `/workspace`.

First open pulls images (a minute or two); later opens are near-instant. Sanity
check from a terminal **inside the container**:

```bash
ssh-add -l            # lists your key (forwarded from the host)
ssh -T git@github.com # greets you by username
```

Adding `.devcontainer/` config to a repo in the first place is covered in the
[project README → Using the image](../README.md#using-the-image).

---

## Detail pages

| Page | What it covers |
|------|----------------|
| [PODMAN.md](PODMAN.md) | Installing Podman Desktop and using it in place of Docker |
| [UNINSTALL-DOCKER.md](UNINSTALL-DOCKER.md) | Removing Docker Desktop before switching to Podman |
| [SSH-KEY.md](SSH-KEY.md) | Generating an SSH key pair on Windows / macOS / Linux |
| [GITHUB-SSH-KEY.md](GITHUB-SSH-KEY.md) | Adding the public key to your GitHub account |
| [SSH-AGENT.md](SSH-AGENT.md) | Running the ssh-agent and forwarding it into the container |
| [GIT-IDENTITY.md](GIT-IDENTITY.md) | Installing Git and setting your commit identity |
| [GITHUB-TOKEN.md](GITHUB-TOKEN.md) | Creating a classic PAT and setting `GITHUB_AUTH_TOKEN` |
| [CLONE-IN-VOLUME.md](CLONE-IN-VOLUME.md) | Working on a repo via "Clone Repository in Container Volume" |
