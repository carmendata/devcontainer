# Creating an SSH key

You need an SSH key pair to authenticate with GitHub from inside the
devcontainer. This is a **one-time** setup per machine. If you already have a
key you're happy to use, skip to [adding it to GitHub](GITHUB-SSH-KEY.md).

We use the **Ed25519** key type — modern, short, and secure. (Only use RSA if
you must talk to a legacy host that doesn't support Ed25519, in which case use
`ssh-keygen -t rsa -b 4096` instead.)

---

## Do you already have a key?

Check before creating a new one — a second key just adds confusion.

**Windows (PowerShell):**

```powershell
Get-ChildItem $env:USERPROFILE\.ssh\*.pub
```

**macOS / Linux:**

```bash
ls -l ~/.ssh/*.pub
```

If you see `id_ed25519.pub` (or similar), you already have a key — skip to
[Add your SSH key to GitHub](GITHUB-SSH-KEY.md).

---

## Generate a key

The command is the same on all platforms (Windows has OpenSSH built in; on
Windows run it in **PowerShell**).

```bash
ssh-keygen -t ed25519 -C "you@example.com"
```

- `-t ed25519` — the key type.
- `-C "you@example.com"` — a label/comment so you can recognise the key later.
  Use your work email; it has no effect on security.

You'll be prompted three times:

1. **File location** — press **Enter** to accept the default
   (`~/.ssh/id_ed25519` on macOS/Linux, `C:\Users\<you>\.ssh\id_ed25519` on
   Windows). Only change this if you're deliberately managing multiple keys.
2. **Passphrase** — **strongly recommended.** A passphrase encrypts the private
   key on disk, so a stolen key file is useless without it. You won't have to
   type it on every git operation — the ssh-agent unlocks it once per session
   (see [SSH-AGENT.md](SSH-AGENT.md)).
3. **Confirm passphrase** — type it again.

This produces **two** files:

| File | What it is | Share it? |
|------|-----------|-----------|
| `id_ed25519` | **private** key | **Never.** Treat it like a password. |
| `id_ed25519.pub` | **public** key | Yes — this is what you give to GitHub. |

---

## Next steps

1. [Add the public key to your GitHub account](GITHUB-SSH-KEY.md)
2. [Load the key into the ssh-agent so the container can use it](SSH-AGENT.md)

---

## Notes

- **Keep the private key.** If you lose `id_ed25519` you simply generate a new
  pair and re-add the public key to GitHub — no data is lost, but you'll have to
  redo those two steps.
- **One key per machine is fine.** You can use the same key from multiple
  computers, but generating a separate key per machine is cleaner: if one
  machine is lost you revoke just that key in GitHub.
- **Back up safely, or don't bother.** A private key is easy to regenerate, so
  most people don't back it up. If you do, store it somewhere encrypted — never
  in a repo, chat, or shared drive.
