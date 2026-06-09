# WSL AI Operator Bridge Kit

Small utilities for AI-agent development on a Windows host with WSL Ubuntu.

This repo packages the reusable pieces from local Aura-Call/Codex work:

- a JSONL bridge from WSL to Windows PowerShell;
- Node 22-aware wrappers for MCP/`npx` tools from WSL;
- an example MCPorter config for installed and local Aura-Call MCP servers;
- an exported Aura-Call patch with the local browser/MCP/runtime improvements;
- notes for pairing Aura-Call with `agent-browser` and Windows Chrome from WSL.

The goal is to make local agent tooling more reliable without exposing a broad
PowerShell command server or depending on whichever `node` binary happens to be
first on the distro PATH.

## Requirements

- Windows with WSL Ubuntu.
- Windows PowerShell available as `powershell.exe`.
- Node 22 installed in WSL, preferably under NVM:

```bash
export PATH="$HOME/.nvm/versions/node/v22.22.3/bin:$PATH"
```

- Optional but useful:
  - Aura-Call installed as `~/.local/bin/auracall` and `~/.local/bin/auracall-mcp`;
  - MCPorter for MCP smoke tests;
  - `agent-browser` cloned and installed for direct browser automation work.

## Install Agent Browser

From WSL:

```bash
cd ~/codex-research/corpora/repos
git clone https://github.com/CochranResearchGroup/agent-browser.git
cd agent-browser
export PATH="$HOME/.nvm/versions/node/v22.22.3/bin:$PATH"
pnpm install
node bin/agent-browser.js --help
```

The install downloads the native `agent-browser-linux-x64` binary. If no local
Linux Chrome is installed, the postinstall warning is expected. Use CDP/provider
mode, an explicit executable path, or run:

```bash
node bin/agent-browser.js install --with-deps
```

when you want `agent-browser` to manage Linux browser binaries.

## WSL To Windows PowerShell

One-shot command:

```bash
./scripts/wsl-powershell-chat.sh Get-Location
```

Stateful JSONL session:

```bash
printf '%s\n' 'Set-Location C:\Windows' 'Get-Location' ':quit' \
  | ./scripts/wsl-powershell-chat.sh
```

Each command returns one compact JSON result with:

- `ok`
- `command`
- `cwd`
- `exitCode`
- `durationMs`
- `stdout`
- `stderr`

This bridge is intentionally local over stdio. It is useful for diagnostics and
bounded host actions, but it is not a network service and should not be treated
as a general remote execution API.

## Node-Aware MCP Launchers

Some WSL installs still put distro Node 18 first on PATH. These wrappers prefer
the latest NVM Node before falling back to plain `node`.

Run MCPorter through the user Node runtime:

```bash
./scripts/run-node22-npx.sh mcporter list auracall --config examples/mcporter.auracall.json
```

Run a local built Aura-Call MCP server from an Aura-Call checkout:

```bash
cd /path/to/auracall
/path/to/wsl-ai-operator-bridge-kit/scripts/run-local-auracall-mcp.sh
```

## MCPorter Example

`examples/mcporter.auracall.json` defines two useful server entries:

- `auracall`: installed user runtime via `~/.local/bin/auracall-mcp`;
- `auracall-local`: a local Aura-Call checkout via `dist/bin/auracall-mcp.js`.

Typical smoke checks:

```bash
./scripts/run-node22-npx.sh mcporter list auracall --config examples/mcporter.auracall.json
./scripts/run-node22-npx.sh mcporter call auracall.browser_control action:prune-browser-state target:chatgpt --config examples/mcporter.auracall.json
./scripts/run-node22-npx.sh mcporter call auracall.browser_readiness target:chatgpt mode:local --config examples/mcporter.auracall.json
./scripts/run-node22-npx.sh mcporter call auracall.windows_powershell_probe probe:get_location --config examples/mcporter.auracall.json
```

## Aura-Call Implementation Patch

The local Aura-Call checkout could not be pushed to `ecochran76/auracall`
because GitHub rejected the `1bak3r` credentials for that repository. The
implementation is preserved here as:

```text
patches/auracall-agentic-browser-runtime-bridge.patch
```

Apply it from a clean Aura-Call checkout with:

```bash
git am /path/to/wsl-ai-operator-bridge-kit/patches/auracall-agentic-browser-runtime-bridge.patch
```

The patch contains the browser readiness gates, ChatGPT blocking-state
classification, human-clear waiting for Cloudflare/CAPTCHA/account gates, MCP
browser-readiness, runtime-control, and response-read tools, an explicit
`agentDecision` for browser-driving go/no-go decisions, safe MCP
`browser_control` actions for pruning stale browser state and launching the
managed login browser, WSL-to-Windows PowerShell probe support, planned bounded
local-action execution, same-session MCP smoke checks for browser readiness,
browser control, runtime control, local actions, and Windows PowerShell
probing, local install/runtime fixes, focused tests, and machine-local handoff
docs.

## Current Aura-Call Notes

See [docs/auracall-local-handoff.md](docs/auracall-local-handoff.md) for the
machine-local state that motivated this kit, including the MCP runtime-control
and Windows PowerShell probe proofs and the remaining ChatGPT browser
manual-clear / identity-verification blocker.

The most useful current readiness gate is:

```bash
auracall doctor --target chatgpt --local-only --prune-browser-state
pnpm run smoke:mcp-browser-control
pnpm run smoke:mcp-browser-readiness
auracall setup --target chatgpt --skip-login --skip-verify --wait-for-identity auto --json
```

The first command clears stale local CDP registry entries without launching a
browser. The MCP `browser_control` smoke proves an agent can call the same
safe prune/readiness path through stdio. The setup command waits for the live
ChatGPT provider session to match the expected Aura-Call runtime identity, and
fails fast if the managed browser is already on a manual-clear page such as
ChatGPT `Just a moment...`. None of these paths solve, click, or bypass
Cloudflare/CAPTCHA/account-auth gates; they detect those gates and hold for a
human.
