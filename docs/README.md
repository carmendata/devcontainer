# Developer setup guide

Everything you need to do **once on your machine** before opening a project in
the devcontainer. Work through the prerequisites below in order; each links to a
detail page where the steps need more than a line.

For what the devcontainer *is* and how the images are built, see the
[project README](../README.md). This guide is just the per-developer setup.

---

## Prerequisites

### 1. VS Code + Dev Containers extension

- Install [VS Code](https://code.visualstudio.com/).
- Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
  (`ms-vscode-remote.remote-containers`).

### 2. A container engine — Podman Desktop (recommended)

We use **[Podman Desktop](https://podman-desktop.io/)**: it's free for any use
(no per-seat licensing), daemonless, and runs the same OCI images. A few extra
settings make it a drop-in replacement for Docker and let the Dev Containers
extension drive it.

→ [Install and configure Podman](PODMAN.md)

Confirm it's working: `podman version` should print both a Client and a
Server/engine section without errors.

> **Already on Docker Desktop?** It still works with the extension, but it isn't
> our recommendation — Docker Desktop's licensing terms for larger organisations
> are why we default to Podman. If you're switching, **remove Docker Desktop
> first** ([uninstall guide](UNINSTALL-DOCKER.md)) to avoid `docker`/WSL
> conflicts, then follow the [Podman page](PODMAN.md).

### 3. An SSH key

You need an SSH key pair to push and pull from GitHub inside the container.

- **Don't have one yet?** → [Create an SSH key](SSH-KEY.md)
- **Already have one** (`ssh-add -l` or a file at `~/.ssh/id_ed25519`)? Skip to
  the next step.

### 4. Add the key to your GitHub account

A key only works once GitHub knows its public half.

→ [Add your SSH key to GitHub](GITHUB-SSH-KEY.md)

### 5. Make the key available to the container — use the ssh-agent

The **recommended, secure** way to give the container access to your key is
ssh-agent forwarding: your private key stays on the host and is never copied
into the container.

→ [Set up ssh-agent forwarding](SSH-AGENT.md)

> **Why the agent, not a mount?** The image *can* bind-mount your host `~/.ssh`
> into the container, but that puts your private key bytes where any process or
> extension in the container can read them. Agent forwarding avoids that — see
> the [security note in the README](../README.md#what-the-two-files-do) and the
> rationale at the bottom of the [ssh-agent page](SSH-AGENT.md).

---

## Then: open a project in the container

Once the above is done, in any repo that has a `.devcontainer/` directory:

1. Open the repo folder in VS Code.
2. Click **Reopen in Container** when prompted (or run **Dev Containers: Reopen
   in Container** from the Command Palette, `F1`).
3. The first open pulls images and takes a minute or two; later opens are
   near-instant.

Verify SSH works from a terminal **inside the container**:

```bash
ssh-add -l            # should list your key (forwarded from the host)
ssh -T git@github.com # should greet you by username
```

Setting up a repo's `.devcontainer/` config in the first place is covered in the
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
