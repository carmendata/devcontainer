# GitHub token (`GITHUB_AUTH_TOKEN`)

The devcontainer reads a `GITHUB_AUTH_TOKEN` environment variable from your host
and forwards it into the container (via `remoteEnv` in `devcontainer.json`). This
is the **one credential you set up manually** — your SSH key and Git config are
forwarded automatically; this token is not.

It's used for the things SSH and your Git config don't cover:

- **Installing private `@carmendata` npm packages** from GitHub Packages. The
  image bakes an `~/.npmrc`
  (`//npm.pkg.github.com/:_authToken=${GITHUB_AUTH_TOKEN}`) that expands the
  token at install time, so `pnpm install` of a `@carmendata/*` dependency
  authenticates with it. Without the token, those installs 401.
- **The `gh` CLI.** The container also maps the same value to `GH_TOKEN`, which
  `gh` uses — including the `postCreateCommand` that runs `gh release download`
  to pull the private CI bundle into the container.

(Your [SSH key](SSH-KEY.md) handles git clone/push over SSH; this token handles
GitHub Packages and the `gh`/API access. You need both.)

This is a **one-time** setup per machine.

---

## 1. Create a classic Personal Access Token

Use a **classic** token (not fine-grained).

1. Go to **https://github.com/settings/tokens** → **Generate new token** →
   **Generate new token (classic)**.
2. **Note** — a name you'll recognise, e.g. `devcontainer – <machine>`.
3. **Expiration** — set one (e.g. 90 days) and renew rather than using "no
   expiration".
4. **Scopes** — tick **at a minimum**:

   | Scope | Why |
   |-------|-----|
   | `repo` | `gh release download` of the private CI bundle (`postCreateCommand`) |
   | `write:packages` | install `@carmendata` npm packages (implies `read:packages`); publish if you release packages |

5. **Generate token** and copy it now — GitHub shows it only once.

> Treat the token like a password. A classic token with these scopes can write
> to your packages and read your repos, so don't paste it into a repo, chat, or
> shared drive.

---

## 2. Set it as `GITHUB_AUTH_TOKEN` on the host

It must be set in the environment **VS Code inherits**, so the devcontainer can
forward it in. Set it persistently, then fully restart VS Code.

**Windows (PowerShell):**

```powershell
setx GITHUB_AUTH_TOKEN "ghp_yourtokenhere"
```

Or the PowerShell-native equivalent — writes to the **same** place (the User
environment, `HKCU\Environment`) and avoids `setx`'s 1024-character truncation:

```powershell
[Environment]::SetEnvironmentVariable('GITHUB_AUTH_TOKEN', 'ghp_yourtokenhere', 'User')
```

Both persist the variable to your **User** environment for **future** sessions
only — close and reopen your terminal (and **fully quit and restart VS Code**,
not just reload the window) so it's picked up. Verify in a new terminal:

```powershell
echo $env:GITHUB_AUTH_TOKEN
```

> Stored in the user environment (registry) in plain text. That's the same trust
> level as your other host credentials; rely on the token's expiry and scopes to
> bound the risk.

**macOS / Linux** — add to `~/.zshrc` or `~/.bashrc`:

```bash
export GITHUB_AUTH_TOKEN="ghp_yourtokenhere"
```

Then `source ~/.zshrc` (or open a new terminal) and **restart VS Code from that
shell** so it inherits the variable. Verify:

```bash
echo "$GITHUB_AUTH_TOKEN"
```

---

## 3. Verify it works

From a terminal **inside the devcontainer** (after *Reopen in Container*):

```bash
# the variable should be present
echo "$GITHUB_AUTH_TOKEN" | head -c 4   # prints "ghp_" (not the whole token)

# the GitHub Packages registry accepts the token (uses the baked ~/.npmrc)
npm whoami --registry=https://npm.pkg.github.com   # prints your GitHub username

# gh is authenticated via GH_TOKEN
gh auth status
```

`npm whoami` printing your username confirms the token and its `*:packages`
scope work; a clean `gh auth status` confirms the `gh`/CI side.

---

## 4. Renewing the token when it expires

A classic PAT stops working on its expiry date — `@carmendata` installs start
returning `401` and `gh` calls fail. GitHub emails you shortly before this
happens. To refresh it:

1. Go to **https://github.com/settings/tokens** and click the existing token
   (the one you named `devcontainer – <machine>`).
2. Click **Regenerate token**, pick a new expiration, and **Generate** — this
   keeps the same name and scopes and issues a **new value**. Copy it now;
   GitHub shows it only once. (Creating a brand-new token instead works just as
   well — you don't have to reuse the old one.)
3. **Update `GITHUB_AUTH_TOKEN` on the host with the new value** — re-run the
   same command from [step 2](#2-set-it-as-github_auth_token-on-the-host); it
   overwrites the old value:

   ```powershell
   # Windows
   setx GITHUB_AUTH_TOKEN 'ghp_newtokenhere'
   ```

   ```bash
   # macOS / Linux: replace the value in the export line in ~/.zshrc or ~/.bashrc,
   # then re-source it (or open a new terminal)
   ```

4. **Fully quit and restart VS Code** so it forwards the new value, then
   **Rebuild Container** (the old token is baked into the running container's
   environment until it's recreated).
5. Confirm with the [verify steps](#3-verify-it-works) above.

> Nothing on GitHub's side needs re-authorising and your SSH key is unaffected —
> only the token value changes, so renewal is just "new value → update env var →
> restart VS Code".

---

## Troubleshooting

- **`GITHUB_AUTH_TOKEN` is empty inside the container** — VS Code was started
  before the variable existed, or from a shell that didn't have it. Fully quit
  VS Code and relaunch from a terminal where `echo $GITHUB_AUTH_TOKEN` prints the
  value.
- **`401 Unauthorized` installing a `@carmendata` package** — the token is
  missing `read:packages`/`write:packages`, isn't set in the container (check
  `echo "$GITHUB_AUTH_TOKEN"`), or **has expired** — if it's past the expiry
  date, [renew it](#4-renewing-the-token-when-it-expires).
- **`postCreateCommand` fails on `gh release download`** — the token is missing
  `repo` scope or your account doesn't have access to the private CI repo.
- **`gh` not authenticated** — run `gh auth status`; if needed,
  `gh auth login` and choose to use the token.
