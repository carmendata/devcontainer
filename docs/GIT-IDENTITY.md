# Install Git and set your identity

The VS Code Dev Containers extension **forwards your Git config** into the
container automatically (`dev.containers.copyGitConfig`, on by default), and
shares your Git credentials via its credential helper / your forwarded
[SSH agent](SSH-AGENT.md) — nothing is bind-mounted. But it can only forward what
exists on the host, and Git **refuses to clone or commit** without a `user.name`
and `user.email`, so install Git on the host and set them there first.

---

## 1. Install Git on the host

- **Windows** — [Git for Windows](https://git-scm.com/download/win) (this also
  gives you the `git` command in PowerShell).
- **macOS** — `git` ships with the Xcode Command Line Tools (`xcode-select
  --install`), or `brew install git`.
- **Linux** — `sudo apt install git` (Debian/Ubuntu) or your distro's package.

---

## 2. Set your identity

Run these on **every** platform; `git config` writes `~/.gitconfig` in the
correct location and format for you:

```bash
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"
```

> **Don't hand-edit the file with Notepad on Windows.** Notepad silently saves as
> `.gitconfig.txt`, so the real `.gitconfig` never gets created and nothing is
> passed into the container. Use the `git config` commands above — that's why
> installing Git first matters.

---

## 3. Verify

```bash
git config --global user.name
git config --global user.email
```

Both should print the values you set. They'll be forwarded into the container the
next time you open it, so commits inside the container are attributed to you.
