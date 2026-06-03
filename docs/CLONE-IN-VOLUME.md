# Working on a repo with "Clone Repository in Container Volume"

This is the recommended way to start work on a repo with VS Code. VS Code clones the repo
straight into an **isolated container volume** and opens the devcontainer on it. Do not
clone to your host disk and opening the folder.

Why use it:

- **Faster** — the working tree lives in the Podman machine's own filesystem.
- **Clean** — nothing is written to your host file tree; great for reviewing a
  PR or trying a branch without touching your machine.
- **Isolated** — each clone is its own volume, so projects don't interfere.

It uses the same devcontainer the repo already defines — you get Node, pnpm,
mysql, and redis exactly as "Reopen in Container" would.

---

## Prerequisites

Do the one-time host setup **first** — clone-in-volume relies on all of it:

- [ ] [Podman installed and VS Code pointed at it](PODMAN.md)
- [ ] [SSH key created](SSH-KEY.md) and [added to GitHub](GITHUB-SSH-KEY.md)
- [ ] [ssh-agent running with your key](SSH-AGENT.md) — **the clone authenticates
      through the forwarded agent**, so `ssh-add -l` must list your key on the
      host *before* you start
- [ ] [Git identity set on the host](GIT-IDENTITY.md)
- [ ] [`GITHUB_AUTH_TOKEN` set on the host](GITHUB-TOKEN.md) — needed by the
      container's post-create step and for private `@carmendata` packages

The target repo must contain a `.devcontainer/` directory (most of ours do). If
it doesn't, use the [project README](../README.md#using-the-image) to add one
first.

> **Restart VS Code** after setting up the agent/token so it forwards them into
> the clone.

---

## Clone and open

1. Open the Command Palette (`F1` / `Ctrl/Cmd+Shift+P`).
2. Run **Dev Containers: Clone Repository in Container Volume…**.
3. Enter the repo as an **SSH** URL so the forwarded agent authenticates the
   clone — e.g.:

   ```
   git@github.com:carmendata/<repo>.git
   ```

   (You can also pick from the GitHub list; if prompted for the protocol, choose
   **SSH**, not HTTPS — HTTPS would need a credential prompt the bootstrap step
   can't satisfy from the agent.)
4. Choose the branch if asked.

VS Code then, with no further input from you:

- creates a uniquely-named volume and clones the repo into it (in a short-lived
  **bootstrap container** running on the Podman machine — the
  `dev.containers.bootstrapImage` you set),
- reads the repo's `.devcontainer/`, pulls the `app`/`mysql`/`redis` images, and
  starts the stack,
- runs the `postCreateCommand` (which uses your token to fetch the CI bundle),
- attaches a shell in the `app` container with the repo at `/workspace`.

The first open takes a minute or two (image pull + post-create); reopening the
same volume later is near-instant.

---

## Verify

In a terminal **inside the container**:

```bash
pwd                       # /workspace
ls                        # your repo's files
ssh-add -l                # your key, forwarded from the host
git status                # clean tree on the branch you cloned
```

If `git status` works and `ssh-add -l` lists your key, the clone and auth are
wired up correctly.

---

## Day-to-day

- **Your code lives in the volume, not on your host.** Edit through this VS Code
  window as normal.
- **Commit and push regularly.** Uncommitted work exists only inside the volume
  — if you delete the container/volume, it's gone. Pushing over SSH uses the same
  forwarded agent, so `git push` just works.
- **Reopening later:** the volume persists after you close the window. To return
  to it, open the **Remote Explorer** (left sidebar) and find the repo under the
  Dev Containers / Dev Volumes view, then reopen it. **Don't run *Clone…* again**
  — that creates a second, separate copy.
- **After changing `.devcontainer/`** (or to pick up a newer published image),
  run **Dev Containers: Rebuild Container**.

---

## Managing the volumes

Each clone leaves a named volume behind. List them from a **host** terminal:

```bash
podman volume ls
```

To reclaim space from a clone you're done with, remove its container first (via
the Remote Explorer or `podman ps -a` / `podman rm`), then:

```bash
podman volume rm <volume-name>
```

> Removing the volume **deletes any work you didn't push.** Make sure the branch
> is pushed first.

---

## Troubleshooting

- **Clone fails with `Permission denied (publickey)`** — the agent wasn't
  forwarded, or your key isn't on GitHub. Confirm `ssh-add -l` lists your key on
  the **host**, restart VS Code, and make sure you used the **SSH** URL
  (`git@github.com:…`), not HTTPS. See [SSH-AGENT.md](SSH-AGENT.md).
- **Clone fails to start / bootstrap image error** — the `bootstrapImage` must be
  pullable by Podman and contain `git`. Check `dev.containers.bootstrapImage` in
  your VS Code settings and that you can `podman pull` it.
- **`postCreateCommand` fails on `gh release download`** — `GITHUB_AUTH_TOKEN`
  isn't forwarded or lacks `repo` scope. See [GITHUB-TOKEN.md](GITHUB-TOKEN.md).
- **`401` installing `@carmendata` packages** — same token, missing
  `read:packages`/`write:packages` or expired. See [GITHUB-TOKEN.md](GITHUB-TOKEN.md).
- **Can't find the volume to reopen** — it's listed in the Remote Explorer's Dev
  Containers/Volumes view and in `podman volume ls`; running *Clone…* again makes
  a duplicate rather than reusing it.
