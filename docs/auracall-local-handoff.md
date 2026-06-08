# Aura-Call Local Handoff

This note records the local Aura-Call state that produced this bridge kit.

## Verified Locally

- Installed user runtime:
  - `~/.auracall/user-runtime`
  - `~/.local/bin/auracall`
  - `~/.local/bin/auracall-mcp`
- MCP tools added or verified:
  - `response_read`
  - `runtime_control`
  - `windows_powershell_probe`
- MCP client startup from WSL works when Node 22 is forced through an NVM-aware
  launcher.
- Same-session MCP runtime control works:
  - seed a direct runtime run;
  - call `runtime_control action:claim-local-run`;
  - call `runtime_control action:drain-run` on the same MCP stdio connection;
  - read `run_status`;
  - the stored bundle ends `succeeded` with a released
    `runner:mcp-runtime-control:<pid>` lease.
- WSL can call Windows PowerShell through the JSONL bridge and preserve a
  stateful PowerShell working directory across commands.

## Current Browser Readiness Blocker

The installed Aura-Call doctor now exposes a first-class readiness verdict. The
current local ChatGPT browser state is:

```text
readiness: not-ok (identity-unverified; blocked)
activeManagedInstance: live windows-loopback managed Chrome
chromeGoogleAccount: Bakermaun@gmail.com
expectedChatgptIdentity: Bakermaun@gmail.com
```

Aura-Call can discover managed Windows Chrome state from WSL through
`windows-loopback`, and MCP can inspect the Windows host through the PowerShell
probe. Browser prompt automation still needs the live ChatGPT provider session
verified in the managed browser, then a successful real ChatGPT prompt proof.

Blocking pages such as ChatGPT `/api/auth/error`, Cloudflare, CAPTCHA, Google
account auth, or other human-verification pages should appear in
`auracall doctor --target chatgpt --json` as `login-required` or
`manual-clear-required`. If the top-level URL is `https://chatgpt.com/` but
identity-smoke still reports `chatgpt_identity_not_detected`, the current
readiness state is `identity-unverified`.

For unattended setup handoffs, use the bounded identity wait so setup fails
closed instead of verifying against an unconfirmed provider account:

```bash
auracall setup --target chatgpt --skip-login --skip-verify --wait-for-identity auto --json
```

## Useful Retest Commands

```bash
export PATH="$HOME/.nvm/versions/node/v22.22.3/bin:$PATH"

auracall --chatgpt \
  --browser-model-strategy ignore \
  --prompt "Read the attached package.json and reply with exactly: AURACALL_BROWSER_OK" \
  --file package.json \
  --slug auracall-browser-ok \
  --timeout 180 \
  --force \
  --no-notify

./scripts/run-node22-npx.sh mcporter call auracall.sessions limit:5 --config examples/mcporter.auracall.json
./scripts/run-node22-npx.sh mcporter call auracall.response_read id:<session-id> --config examples/mcporter.auracall.json
```
