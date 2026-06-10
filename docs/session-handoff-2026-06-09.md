# Session Handoff - 2026-06-09

## State Snapshot

- Aura-Call repo: `/home/bak3r/codex-research/corpora/repos/auracall`
- Aura-Call branch: `codex/agentic-browser-runtime-bridge`
- Aura-Call commit: `6947697e Add agentic browser runtime bridge`
- Bridge-kit repo: `/home/bak3r/codex-research/corpora/repos/wsl-ai-operator-bridge-kit`
- Bridge-kit branch: `main`
- Bridge-kit pushed commit: `8621655 Add safe Aura-Call MCP browser control`
- Agent-browser repo: `/home/bak3r/codex-research/corpora/repos/agent-browser`
- Both Aura-Call and bridge-kit worktrees were clean when this handoff was written.

## What Was Completed

- Installed and used `agent-browser` for read-only browser/CDP inspection.
- Fixed Aura-Call MCP startup/runtime paths for WSL Node 22.
- Fixed bridge-kit `run-node22-npx.sh` so `auracall-local` MCP checks work
  from the bridge-kit root without manually exporting `AURACALL_BRIDGE_KIT` or
  `AURACALL_REPO` when the local Aura-Call checkout is present.
- Added MCP tools and smokes for:
  - `agent_host_readiness`
  - `browser_readiness`
  - `browser_control`
  - `runtime_control`
  - `windows_powershell_probe`
  - `response_read`
- Added WSL-to-Windows PowerShell bridge scripts:
  - `scripts/wsl-powershell-chat.sh`
  - `scripts/windows-powershell-chat.ps1`
- Fixed the WSL wrapper to resolve Windows PowerShell by absolute Windows
  mount path when `powershell.exe` is not on the WSL PATH.
- Added bounded local-action MCP proof, including a WSL-to-Windows PowerShell action path.
- Added composite read-only MCP agent-host preflight covering MCP runtime-runner
  registration, the WSL-to-Windows PowerShell bridge, and browser readiness.
- Added browser readiness states and agent decisions for managed browser work.
- Added safe MCP browser setup controls:
  - `prune-browser-state`
  - `launch-login`
- Regenerated and pushed the Aura-Call implementation patch artifact:
  - `patches/auracall-agentic-browser-runtime-bridge.patch`
- Verified that patch applies cleanly to Aura-Call `origin/main`.

## Safety Boundary

Aura-Call was not taught to bypass, solve, or click through Cloudflare, CAPTCHA, Turnstile, Google account auth, or ChatGPT account-auth gates.

Current compliant behavior is:

- detect guard/account-auth pages;
- report a structured readiness state;
- return `agentDecision.canDriveBrowser = false`;
- recommend a human-in-the-loop login/manual-clear step;
- resume only after the managed browser is clear and identity/readiness checks pass.

The safe next command for ChatGPT is:

```bash
auracall login --target chatgpt --wait-for-manual-clear auto
```

## Latest Verified Browser State

The installed MCP agent-host-readiness smoke currently reports the MCP runtime
runner and WSL-to-Windows PowerShell bridge are healthy, while browser driving
is still disabled because there is no live managed ChatGPT browser:

```text
agent_host_readiness target=chatgpt ok=false browserState=no-live-managed-browser runtimeRunner=true windowsPowerShell=true agentAction=launch-login canDriveBrowser=false
```

The bridge-kit JSONL PowerShell chat wrapper now also works directly:

```bash
./scripts/wsl-powershell-chat.sh Get-Location
```

It returned `ok=true` and Windows PowerShell `5.1.26100.8521` after falling
back to the absolute Windows PowerShell path.

The bridge-kit no-env local MCP path also works from the bridge-kit root:

```bash
./scripts/run-node22-npx.sh mcporter list auracall-local --config examples/mcporter.auracall.json
./scripts/run-node22-npx.sh mcporter call auracall-local.agent_host_readiness target:chatgpt --config examples/mcporter.auracall.json
```

The installed MCP browser-readiness smoke currently reports no live managed ChatGPT browser:

```text
browser_readiness target=chatgpt mode=local ok=false state=no-live-managed-browser severity=warning requiresHuman=false agentAction=launch-login canDriveBrowser=false
agentCommand=auracall login --target chatgpt --wait-for-manual-clear auto
recommendedAction=Run "auracall login --target chatgpt" or start a browser-backed run, then rerun "auracall doctor --target chatgpt".
```

The installed MCP browser-control smoke currently proves the safe prune/readiness path:

```text
browser_control target=chatgpt action=prune-browser-state ok=true performed=true state=no-live-managed-browser agentAction=launch-login
```

## Validation Already Run

From the Aura-Call repo with Node 22 on PATH:

```bash
pnpm vitest run tests/mcp.browserControl.test.ts tests/mcp.browserReadiness.test.ts --maxWorkers 1
pnpm run typecheck
pnpm run build
pnpm run install:user-runtime
pnpm run smoke:mcp-agent-host-readiness
pnpm run smoke:mcp-browser-control
pnpm run smoke:mcp-browser-readiness
../wsl-ai-operator-bridge-kit/scripts/wsl-powershell-chat.sh Get-Location
../wsl-ai-operator-bridge-kit/scripts/run-node22-npx.sh mcporter list auracall-local --config ../wsl-ai-operator-bridge-kit/examples/mcporter.auracall.json
```

The bridge-kit patch artifact was also verified with:

```bash
git worktree add --detach /tmp/auracall-patch-check-6947697e origin/main
git -C /tmp/auracall-patch-check-6947697e am /home/bak3r/codex-research/corpora/repos/wsl-ai-operator-bridge-kit/patches/auracall-agentic-browser-runtime-bridge.patch
git worktree remove /tmp/auracall-patch-check-6947697e
```

## Remaining Work

The original Aura-Call goal is not complete yet. The remaining proof is a real browser-backed ChatGPT prompt run after a human signs into ChatGPT in the managed browser and readiness becomes `ready`.

Useful next steps:

1. Run the safe login/manual-clear command above.
2. Complete ChatGPT sign-in manually in the managed browser.
3. Rerun:

```bash
pnpm run smoke:mcp-browser-readiness
auracall doctor --target chatgpt --json
```

4. Once readiness is `ready`, run a real browser prompt proof:

```bash
auracall --chatgpt \
  --browser-model-strategy ignore \
  --prompt "Read the attached package.json and reply with exactly: AURACALL_BROWSER_OK" \
  --file package.json \
  --slug auracall-browser-ok \
  --timeout 180 \
  --force \
  --no-notify
```

## Notes For The Next Goal

- Do not automate provider guard pages or account-auth gates.
- Use `agent_host_readiness` as the first MCP preflight when a downstream agent
  needs one call for runtime runner, PowerShell bridge, and browser gate state.
- Use `browser_readiness` before any browser-backed provider work.
- Use `browser_control action=prune-browser-state` only for dead local registry entries.
- Use `browser_control action=launch-login` only to open the managed browser for human login.
- Use `windows_powershell_probe` for constrained Windows host diagnostics from WSL.
- Use `runtime_control` for existing bounded runtime/local-action flows, not arbitrary host execution.
