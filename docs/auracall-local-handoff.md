# Aura-Call Local Handoff

This note records the local Aura-Call state that produced this bridge kit.

## Verified Locally

- Installed user runtime:
  - `~/.auracall/user-runtime`
  - `~/.local/bin/auracall`
  - `~/.local/bin/auracall-mcp`
- MCP tools added or verified:
  - `browser_control`
  - `browser_readiness`
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
- Same-session MCP planned local-action execution works:
  - seed a direct runtime run whose bundle includes one step-owned bounded shell
    `localActionRequests[]` entry;
  - claim and drain the run through installed `~/.local/bin/auracall-mcp`;
  - the stored local-action result is `executed` with
    `stdout=AURACALL_LOCAL_ACTION_OK`.
- The same installed local-action smoke can execute the WSL-to-Windows
  PowerShell JSONL bridge as the bounded action:
  - `pnpm run smoke:mcp-local-action -- --windows-powershell-bridge`
  - the stored local-action result is `executed` with
    `powershellStdout=AURACALL_WINDOWS_POWERSHELL_OK`.
- WSL can call Windows PowerShell through the JSONL bridge and preserve a
  stateful PowerShell working directory across commands.
- The installed MCP `windows_powershell_probe` tool now has a same-session
  smoke check that starts `~/.local/bin/auracall-mcp`, lists the tool, calls
  `probe=get_location`, and can optionally verify a live Chrome DevTools port.
- The installed MCP `browser_readiness` tool now has a same-session smoke check
  that starts `~/.local/bin/auracall-mcp`, lists the tool, calls
  `browser_readiness`, and validates the structured readiness state returned
  from the same `auracall.browser-doctor` contract as `auracall doctor --json`.
- The installed MCP `browser_control` tool now has a same-session smoke check
  that starts `~/.local/bin/auracall-mcp`, lists the tool, calls
  `browser_control action=prune-browser-state`, and validates the structured
  action/readiness result. The tool only prunes dead browser-state entries or
  opens the managed login browser; it does not type, click, solve, or bypass
  Cloudflare/CAPTCHA/account-auth gates.

## Published Artifact

The local Aura-Call implementation was committed on branch
`codex/agentic-browser-runtime-bridge` as:

```text
3c44075a Add agentic browser runtime bridge
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
pnpm vitest run tests/cli/browserSetup.test.ts tests/browser/profileDoctor.test.ts tests/browser/browserTools.test.ts --maxWorkers 1
pnpm run typecheck
pnpm run build
pnpm run smoke:mcp-runtime-control
pnpm run smoke:mcp-local-action
pnpm run smoke:mcp-local-action -- --windows-powershell-bridge
pnpm run smoke:mcp-browser-control
pnpm run smoke:mcp-browser-readiness
pnpm run smoke:mcp-windows-powershell-probe
pnpm run smoke:mcp-windows-powershell-probe -- --devtools-port 55855
```

All listed checks passed.

An earlier live PowerShell probe smoke returned Windows PowerShell
`5.1.26100.8521` and verified the managed Chrome DevTools endpoint on port
`55855` as `Chrome/148.0.7778.218`.

The latest installed browser-readiness MCP smoke returned:

```text
browser_readiness target=chatgpt mode=local ok=false state=no-live-managed-browser severity=warning requiresHuman=false agentAction=launch-login canDriveBrowser=false
agentCommand=auracall login --target chatgpt --wait-for-manual-clear auto
recommendedAction=Run "auracall login --target chatgpt" or start a browser-backed run, then rerun "auracall doctor --target chatgpt".
```

The latest installed browser-control MCP smoke returned:

```text
browser_control target=chatgpt action=prune-browser-state ok=true performed=true state=no-live-managed-browser agentAction=launch-login
```

## Current Browser Readiness Blocker

The installed Aura-Call doctor now exposes a first-class readiness verdict. The
latest local ChatGPT browser state is:

```text
readiness: not-ok (no-live-managed-browser; warning)
activeManagedInstance: none
staleManagedEntry: none after pruning one windows-loopback port 55855 dead-process entry
chromeGoogleAccount: Bakermaun@gmail.com
expectedChatgptIdentity: Bakermaun@gmail.com
recommendedAction: auracall login --target chatgpt, then rerun doctor
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

Aura-Call now supports a human-clear wait path:

```bash
auracall login --target chatgpt --wait-for-manual-clear auto
auracall setup --target chatgpt --wait-for-manual-clear auto --wait-for-identity auto --skip-verify
```

This does not solve Cloudflare, CAPTCHA, or account-auth challenges. It opens
the managed browser, observes readiness, and resumes once a human clears the
gate. A short installed test with `--wait-for-manual-clear 8` relaunched
Windows Chrome, Cloudflare cleared without automation, and Agent Browser
confirmed the page was a logged-out ChatGPT landing page with `Log in`, `Sign
up for free`, and a guest textbox. Identity smoke still fails with
`chatgpt_identity_not_detected`.

The logged-out ChatGPT landing page is now classified as `account-auth`. A
short installed test with `auracall login --target chatgpt
--wait-for-manual-clear 3` waited for human sign-in and timed out with
`Provider account chooser or sign-in gate detected` instead of treating the
guest page as ready.

Doctor readiness now reports failed/missing browser-tools probes as
`browser-probe-error` before falling back to identity state. That avoids a
weaker `identity-unverified` diagnosis when concurrent setup/doctor probes
contend for the managed browser operation lock.

When the managed browser has been closed but `browser-state.json` still carries
the old CDP entry, readiness reports `no-live-managed-browser` with a
prune-first `recommendedAction`:

```bash
auracall doctor --target chatgpt --local-only --prune-browser-state
auracall login --target chatgpt --wait-for-manual-clear auto
```

The prune command was run locally and removed one stale `dead-process` entry
for `windows-loopback:55855`. The machine is now ready for the relaunch/login
step, but ChatGPT provider sign-in still requires a human in the managed
browser.

`auracall doctor --target chatgpt --json --save-snapshot` now writes a
browser-tools snapshot even when selector diagnosis is skipped. The latest
local proof wrote a snapshot with `reason=login-required`,
`url=https://chatgpt.com/`, `title=ChatGPT`, and
`blockingState.kind=account-auth`.

Blocking pages such as ChatGPT `/api/auth/error`, Cloudflare, CAPTCHA, Google
account auth, or other human-verification pages should appear in
`auracall doctor --target chatgpt --json` as `login-required` or
`manual-clear-required`. A provider root tab titled `Just a moment...` is now
classified as a Cloudflare-style manual-clear page even if the body text omits
the literal Cloudflare label. A logged-out ChatGPT root page with `Log in` and
`Sign up` controls is classified as `login-required` so the human-clear waiter
can hold until sign-in is completed.

For unattended setup handoffs, use the bounded identity wait so setup fails
closed instead of verifying against an unconfirmed provider account. Add the
manual-clear wait only when a human is present to clear visible provider gates:

```bash
auracall setup --target chatgpt --skip-login --skip-verify --wait-for-identity auto --json
auracall setup --target chatgpt --wait-for-manual-clear auto --wait-for-identity auto --skip-verify
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
