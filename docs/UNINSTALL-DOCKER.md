# Uninstalling Docker Desktop

Do this **before** installing Podman (see [PODMAN.md](PODMAN.md)). Running Docker
Desktop and Podman side by side causes conflicts over the `docker` CLI name, WSL
distributions on Windows, and which engine actually handled a command. A clean
switch is the least painful path.

> **Back up anything you need first.** Uninstalling removes Docker Desktop's VM
> and, depending on options, its images, containers, and named volumes. If you
> have data in a Docker volume you still want, copy it out before you start.
> (The devcontainer's MySQL/Redis data is throwaway, so for this project there's
> normally nothing to save.)

Pick your platform:

- [Windows](#windows)
- [macOS](#macos)
- [Linux](#linux)

---

## Windows

1. **Quit Docker Desktop** — right-click the whale icon in the system tray →
   **Quit Docker Desktop**.
2. **Uninstall the app** — **Settings → Apps → Installed apps**, find **Docker
   Desktop**, click **⋯ → Uninstall**. (Or **Control Panel → Programs and
   Features → Docker Desktop → Uninstall**.)
3. **Restart** when prompted.
4. **Remove leftover data**.
   Delete these folders if they remain:

   ```powershell
   Remove-Item -Recurse -Force "$env:APPDATA\Docker" -ErrorAction SilentlyContinue
   Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Docker" -ErrorAction SilentlyContinue
   Remove-Item -Recurse -Force "$env:USERPROFILE\.docker" -ErrorAction SilentlyContinue
   ```

5. **Remove Docker's WSL distributions** so they don't clash with Podman's:

   ```powershell
   wsl --list --verbose
   # if you see docker-desktop (and/or docker-desktop-data), remove them:
   wsl --unregister docker-desktop
   wsl --unregister docker-desktop-data
   ```

   > Only unregister the `docker-desktop*` distros. Leave any other WSL distros
   > (Ubuntu, etc.) alone.

---

## macOS

1. **Quit Docker Desktop** — whale icon in the menu bar → **Quit Docker
   Desktop**.
2. **Use the built-in uninstaller** (cleanest) — open Docker Desktop and from
   the **bug/troubleshoot** menu choose **Uninstall**, *or* run:

   ```bash
   /Applications/Docker.app/Contents/MacOS/uninstall
   ```

3. **Delete the app:**

   ```bash
   rm -rf /Applications/Docker.app
   ```

4. **Remove leftover data** (optional, for a clean switch):

   ```bash
   rm -rf ~/Library/Containers/com.docker.docker
   rm -rf ~/Library/Application\ Support/Docker\ Desktop
   rm -rf ~/Library/Group\ Containers/group.com.docker
   rm -rf ~/.docker
   ```

---

## Linux

Docker Desktop for Linux is a separate package from the `docker` engine (`docker-ce`).
This removes **Docker Desktop**; if you installed the engine directly instead,
remove the `docker-ce`/`docker.io` packages your distro uses.

**Debian / Ubuntu:**

```bash
# Docker Desktop (the .deb app)
sudo apt remove docker-desktop

# clean up per-user config
rm -rf ~/.docker/desktop
```

**Fedora / RHEL:**

```bash
sudo dnf remove docker-desktop
rm -rf ~/.docker/desktop
```

If you instead ran the plain engine, remove it with your package manager, e.g.
`sudo apt remove docker-ce docker-ce-cli containerd.io docker-compose-plugin`.

---

## Confirm it's gone

A fresh terminal should no longer find a Docker Desktop engine:

```bash
docker version
```

You want this to **fail** with "command not found" or "cannot connect to the
Docker daemon" — that confirms Docker Desktop is no longer serving the `docker`
command. (Once you alias `docker` → `podman` in [step 3 of the Podman
guide](PODMAN.md#3-make-docker-mean-podman-optional-but-convenient), `docker`
will resolve to Podman instead.)

---

## Next step

[Install and configure Podman](PODMAN.md).
