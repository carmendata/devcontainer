# Adding your SSH key to GitHub

GitHub needs the **public** half of your key before it will accept SSH
connections. This is a one-time step per key. If you don't have a key yet, start
with [Creating an SSH key](SSH-KEY.md).

> You only ever upload the **`.pub`** (public) file. Never paste your private
> key (`id_ed25519`, no extension) anywhere.

---

## 1. Copy your public key

Copy the entire contents of `id_ed25519.pub` to your clipboard.

**Windows (PowerShell):**

```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | Set-Clipboard
```

**macOS:**

```bash
pbcopy < ~/.ssh/id_ed25519.pub
```

**Linux:**

```bash
# needs xclip (sudo apt install xclip), or just cat and copy by hand
xclip -selection clipboard < ~/.ssh/id_ed25519.pub
# or:
cat ~/.ssh/id_ed25519.pub
```

The value looks like one line:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... you@example.com
```

Copy **all** of it, from `ssh-ed25519` through the trailing comment.

---

## 2. Add it on GitHub

1. Go to **https://github.com/settings/ssh/new**
   (or: profile photo → **Settings** → **SSH and GPG keys** → **New SSH key**).
2. **Title** — a name that identifies the machine, e.g. `Work laptop (Windows)`.
   This is how you'll recognise which key to revoke later.
3. **Key type** — leave as **Authentication Key**.
4. **Key** — paste the public key you copied.
5. Click **Add SSH key** (confirm your password if prompted).

---

## 3. Test it

From your **host** machine (the agent doesn't need to be set up yet for this
test — ssh will read the key file directly):

```bash
ssh -T git@github.com
```

The first time, you'll be asked to trust GitHub's host key — type `yes`. A
success looks like:

```
Hi <your-username>! You've successfully authenticated, but GitHub does not
provide shell access.
```

That "does not provide shell access" line is **normal and expected** — GitHub
never gives you a shell; seeing your username means the key works.

---

## Troubleshooting

- **`Permission denied (publickey)`** — GitHub didn't accept the key. Most
  common causes: you pasted the **private** key or only part of the public key;
  the key isn't actually added to *this* GitHub account; or ssh is offering a
  different key. Re-check step 2, and confirm the fingerprint matches:

  ```bash
  ssh-keygen -lf ~/.ssh/id_ed25519.pub
  ```

  Compare that `SHA256:...` fingerprint to the one shown under your key at
  **https://github.com/settings/keys**.
- **It asks for a passphrase every time** — expected if you set one. Set up the
  [ssh-agent](SSH-AGENT.md) so you unlock the key once per session instead of on
  every git command.

---

## Next step

[Set up ssh-agent forwarding](SSH-AGENT.md) so the key is available inside the
devcontainer without copying it in.
