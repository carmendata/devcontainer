# SSH agent forwarding for the devcontainer

Git operations inside the devcontainer (push, pull, clone over SSH) need your
SSH key. The **secure** way to provide it is **ssh-agent forwarding**: your key
stays on your host machine, and VS Code forwards the *agent* — not the key file
— into the container. The container can authenticate but can never read or copy
your private key.

The container bind-mounts no host files, so this agent forwarding — not a mounted
`~/.ssh` — is how your key reaches it. Set it up once and it survives reboots.

---

## Windows (PowerShell, run as Administrator)

```powershell
# 1. Make the ssh-agent service start automatically on every boot
Get-Service ssh-agent | Set-Service -StartupType Automatic

# 2. Start it now (no reboot needed for the first time)
Start-Service ssh-agent

# 3. Add your key. Adjust the filename if yours isn't id_ed25519.
ssh-add $env:USERPROFILE\.ssh\id_ed25519

# 4. Confirm the key is loaded
ssh-add -l
```

You should only ever need to do this **once per machine**. The Windows
ssh-agent stores added keys in the registry (encrypted to your Windows account),
so after a reboot the service auto-starts and reloads the key for you — you do
**not** re-run `ssh-add`. Verify any time by opening a normal (non-admin)
terminal and running `ssh-add -l`; your key should already be listed.

> Steps 1 and 2 require an **Administrator** PowerShell. Step 3 can be run from
> a normal terminal, but it's fine to do it all in the admin window.

---

## macOS

```bash
# Add the key to the agent and persist it in the Keychain
ssh-add --apple-use-keychain ~/.ssh/id_ed25519

# Confirm
ssh-add -l
```

To have it re-add automatically after a reboot/login, add this to
`~/.ssh/config`:

```
Host *
  AddKeysToAgent yes
  UseKeychain yes
```

## Linux

The agent is usually started by your desktop session. If `ssh-add -l` says
"Could not open a connection to your authentication agent", start one:

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Add `AddKeysToAgent yes` under `Host *` in `~/.ssh/config` so the key is loaded
on first use each session. (Unlike Windows, the Linux/macOS agent is in-memory,
so keys are re-added per login session rather than persisted in a registry.)

---

## Using it with the devcontainer

1. Make sure `ssh-add -l` on your **host** lists your key (see above).
2. **Restart VS Code** so it picks up the running agent.
3. Reopen the project in the container ("Reopen in Container" /
   "Rebuild and Reopen in Container").

VS Code automatically forwards the host agent into the container — there is
nothing to configure in `devcontainer.json`.

### Verify it works inside the container

Open a terminal **inside the devcontainer** and run:

```bash
# The forwarded agent should list the same key as your host
ssh-add -l

# End-to-end check against GitHub (expects a "Hi <user>!" greeting)
ssh -T git@github.com
```

If `ssh-add -l` shows your key, forwarding is working and git over SSH will use
it — with no private key present in the container.

---

## Troubleshooting

- **`ssh-add -l` inside the container says "Could not open a connection"** —
  the host agent wasn't running when VS Code started. Confirm `ssh-add -l` works
  on the host, then fully restart VS Code (not just reload the window).
- **`ssh -T git@github.com` says "Permission denied (publickey)"** — the agent
  is forwarded but that key isn't registered with GitHub. Add the matching
  public key to your GitHub account (Settings → SSH and GPG keys).
- **Host key verification prompt / `known_hosts`** — agent forwarding carries
  your *key*, not your `known_hosts` file. The first connection to a host will
  ask you to confirm its fingerprint; that's expected and not a key problem.
- **Windows: key not loaded after reboot** — check the service is actually
  Automatic with `Get-Service ssh-agent | Select Status,StartType`. If it shows
  `Manual`/`Disabled`, re-run step 1 as Administrator.

---

## Why this is preferred over mounting `~/.ssh`

With agent forwarding, your private key never enters the container's filesystem.
Code running in the container (dependencies, postinstall scripts, the in-
container Docker engine) can ask the agent to *sign* authentication challenges
but cannot read, copy, or exfiltrate the key itself. A bind-mount — even a
read-only one — puts the key bytes inside the container where any process
running there can read them. Forwarding is the smaller attack surface.
