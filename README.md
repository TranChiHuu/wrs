# wrs

Keep several Cloudflare `wrangler` OAuth logins and switch between them, like `gh auth switch`.

Wrangler holds only one OAuth login at a time. `wrs` saves each login as a named profile and swaps it into wrangler's config file on demand.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/TranChiHuu/wrs/main/wrs -o ~/.local/bin/wrs
chmod +x ~/.local/bin/wrs
```

Requires bash and `npx wrangler`. Written for macOS; on Linux set `WRS_WRANGLER_CONFIG` (see below).

## Usage

```bash
wrs save work        # save the current wrangler login as "work"
wrs login personal   # run `wrangler login` in the browser, save it as "personal"
wrs switch work      # or: wrs use work
wrs list             # * marks the active profile
wrs remove [-f] personal
```

## How it works

- Profiles are stored in `~/.config/wrs/profiles/<name>.toml` (mode 600). The active profile name is in `~/.config/wrs/active`.
- Wrangler refreshes the OAuth token and rewrites its config, and refresh tokens rotate. Before every `switch` or `login`, `wrs` copies wrangler's current config back into the active profile so the refreshed token is kept.
- `wrs` never runs `wrangler logout`, because logout revokes the token on Cloudflare's side and the saved profile would stop working.
- If `CLOUDFLARE_API_TOKEN` is set, wrangler uses it instead of the OAuth login.

## Environment

| Variable | Default |
|---|---|
| `WRS_WRANGLER_CONFIG` | `~/Library/Preferences/.wrangler/config/default.toml` |
| `WRS_HOME` | `~/.config/wrs` |

## Test

```bash
./test.sh
```

Runs in a temp directory with fake config files and a fake `npx`; it never touches your real login.
