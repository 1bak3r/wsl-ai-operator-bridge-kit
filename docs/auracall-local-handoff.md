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

## Published Artifact

The local Aura-Call implementation was committed on branch
`codex/agentic-browser-runtime-bridge` as:

```text
7557d53b Add agentic browser runtime bridge
```

Pushing that branch to `ecochran76/auracall` was denied by GitHub for the
`1bak3r` credentials, so the exact commit is preserved in this repo as:

```text
patches/auracall-agentic-browser-runtime-bridge.patch
```

The patch was verified with `git am` against Aura-Call `origin/main`.

Latest validation on the committed branch:

```text
pnpm vitest run tests/mcp.runtimeControl.test.ts tests/mcp.windowsPowerShellProbe.test.ts tests/browser/browserTools.test.ts tests/browser/profileDoctor.test.ts --maxWorkers 1
pnpm run typecheck
pnpm run build
pnpm run smoke:mcp-runtime-control
```

All four checks passed.

## Current Browser Readiness Blocker

The installed Aura-Call doctor now exposes a first-class readiness verdict. The
current local ChatGPT browser state is:

```text
readiness: not-ok (login-required; blocked)
activeManagedInstance: live windows-loopback managed Chrome
chromeGoogleAccount: Bakermaun@gmail.com
expectedChatgptIdentity: Bakermaun@gmail.com
selectedUrl: https://chatgpt.com/api/auth/error
selectedTitle: Just a moment...
blockingState: account-auth
```

Aura-Call can discover managed Windows Chrome state from WSL through
`windows-loopback`, and MCP can inspect the Windows host through the PowerShell
probe. Browser prompt automation still needs ChatGPT sign-in completed in the
managed browser, the live ChatGPT provider session verified, and then a
successful real ChatGPT prompt proof.

A low-risk CDP reload/focus attempt against the current tab did not clear the
page: before and after were both `https://chatgpt.com/`, title
`Just a moment...`, with zero visible composer or form controls.
After relaunching through `auracall login --target chatgpt`, the selected tab
advanced to `https://chatgpt.com/auth/login`; doctor now classifies that as
`login-required`.

A credential-free CDP click on `Continue with Google` then landed at
`https://chatgpt.com/api/auth/error`, title `Just a moment...`, with no visible
controls. Doctor still classifies the page as `login-required` with
`blockingState.kind=account-auth`.

Doctor readiness now reports failed/missing browser-tools probes as
`browser-probe-error` before falling back to identity state. That avoids a
weaker `identity-unverified` diagnosis when concurrent setup/doctor probes
contend for the managed browser operation lock.

`auracall doctor --target chatgpt --json --save-snapshot` now writes a
browser-tools snapshot even when selector diagnosis is skipped. The latest
local proof wrote a snapshot with `reason=login-required`,
`url=https://chatgpt.com/api/auth/error`, `title=Just a moment...`, and
`blockingState.kind=account-auth`.

Blocking pages such as ChatGPT `/api/auth/error`, Cloudflare, CAPTCHA, Google
account auth, or other human-verification pages should appear in
`auracall doctor --target chatgpt --json` as `login-required` or
`manual-clear-required`. A provider root tab titled `Just a moment...` is now
classified as a Cloudflare-style manual-clear page even if the body text omits
the literal Cloudflare label. If the top-level URL is `https://chatgpt.com/`
after the challenge is cleared but identity-smoke still reports
`chatgpt_identity_not_detected`, the readiness state becomes
`identity-unverified`.

For unattended setup handoffs, use the bounded identity wait so setup fails
closed instead of verifying against an unconfirmed provider account. It also
fails fast when the managed browser is already on a manual-clear page:

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
