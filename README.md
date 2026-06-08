# WSL AI Operator Bridge Kit

Small utilities for AI-agent development on a Windows host with WSL Ubuntu.

This repo packages the reusable pieces from local Aura-Call/Codex work:

- a JSONL bridge from WSL to Windows PowerShell;
- Node 22-aware wrappers for MCP/`npx` tools from WSL;
- an example MCPorter config for installed and local Aura-Call MCP servers;
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
./scripts/run-node22-npx.sh mcporter call auracall.windows_powershell_probe probe:get_location --config examples/mcporter.auracall.json
```

## Current Aura-Call Notes

See [docs/auracall-local-handoff.md](docs/auracall-local-handoff.md) for the
machine-local state that motivated this kit, including the MCP runtime-control
proof and the remaining ChatGPT browser identity-verification blocker.

The most useful current readiness gate is:

```bash
auracall setup --target chatgpt --skip-login --skip-verify --wait-for-identity auto --json
```

It waits for the live ChatGPT provider session to match the expected Aura-Call
runtime identity, then fails closed if the managed browser still needs manual
sign-in or challenge clearance.
