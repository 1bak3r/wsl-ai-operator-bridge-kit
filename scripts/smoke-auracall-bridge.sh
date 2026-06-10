#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
bridge_root=$(CDPATH= cd "$script_dir/.." && pwd)
tmp_dir=$(mktemp -d)

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

cd "$bridge_root"

run_capture() {
  label="$1"
  shift
  output="$tmp_dir/$label.out"
  printf 'checking %s... ' "$label"
  if "$@" >"$output" 2>&1; then
    printf 'ok\n'
    return
  fi
  printf 'failed\n' >&2
  cat "$output" >&2
  exit 1
}

require_output() {
  label="$1"
  pattern="$2"
  description="$3"
  output="$tmp_dir/$label.out"
  if grep -Fq "$pattern" "$output"; then
    return
  fi
  printf '%s did not contain expected %s: %s\n' "$label" "$description" "$pattern" >&2
  cat "$output" >&2
  exit 1
}

run_capture powershell ./scripts/wsl-powershell-chat.sh Get-Location
require_output powershell '"type":"ready"' 'ready JSON line'
require_output powershell '"ok":true' 'successful command result'

run_capture installed-list \
  ./scripts/run-node22-npx.sh mcporter list auracall --config examples/mcporter.auracall.json
require_output installed-list 'function agent_host_readiness' 'installed agent_host_readiness tool'

run_capture installed-readiness \
  ./scripts/run-node22-npx.sh mcporter call auracall.agent_host_readiness target:chatgpt --config examples/mcporter.auracall.json
require_output installed-readiness '"object": "agent_host_readiness"' 'installed readiness object'
require_output installed-readiness '"mcpRuntimeRunnerRegistered": true' 'installed MCP runtime runner'
require_output installed-readiness '"windowsPowerShell": {' 'installed Windows PowerShell bridge block'

run_capture local-list \
  ./scripts/run-node22-npx.sh mcporter list auracall-local --config examples/mcporter.auracall.json
require_output local-list 'function agent_host_readiness' 'local agent_host_readiness tool'

run_capture local-readiness \
  ./scripts/run-node22-npx.sh mcporter call auracall-local.agent_host_readiness target:chatgpt --config examples/mcporter.auracall.json
require_output local-readiness '"object": "agent_host_readiness"' 'local readiness object'
require_output local-readiness '"mcpRuntimeRunnerRegistered": true' 'local MCP runtime runner'
require_output local-readiness '"windowsPowerShell": {' 'local Windows PowerShell bridge block'

printf 'auracall bridge smoke: pass\n'
