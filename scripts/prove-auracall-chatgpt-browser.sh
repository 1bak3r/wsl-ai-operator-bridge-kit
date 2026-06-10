#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
bridge_root=$(CDPATH= cd "$script_dir/.." && pwd)
tmp_dir=$(mktemp -d)

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

resolve_node() {
  if [ -n "${NODE:-}" ]; then
    printf '%s\n' "$NODE"
    return
  fi
  for dir in "$HOME"/.nvm/versions/node/v*/bin; do
    if [ -x "$dir/node" ]; then
      node_bin="$dir/node"
    fi
  done
  if [ -n "${node_bin:-}" ]; then
    printf '%s\n' "$node_bin"
    return
  fi
  if command -v node >/dev/null 2>&1; then
    command -v node
    return
  fi
  printf '%s\n' node
}

resolve_auracall_repo() {
  if [ -n "${AURACALL_REPO:-}" ] && [ -f "$AURACALL_REPO/package.json" ]; then
    printf '%s\n' "$AURACALL_REPO"
    return
  fi
  for candidate in \
    "$bridge_root/../auracall" \
    "$HOME/codex-research/corpora/repos/auracall"
  do
    if [ -f "$candidate/package.json" ]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  printf 'Could not find Aura-Call checkout. Set AURACALL_REPO.\n' >&2
  exit 2
}

json_value() {
  file="$1"
  expr="$2"
  "$node_cmd" -e '
const fs = require("fs");
const file = process.argv[1];
const expr = process.argv[2];
const data = JSON.parse(fs.readFileSync(file, "utf8"));
const value = expr.split(".").reduce((current, key) => current == null ? undefined : current[key], data);
if (value === undefined || value === null) process.exit(3);
if (typeof value === "string") console.log(value);
else console.log(JSON.stringify(value));
' "$file" "$expr"
}

node_cmd=$(resolve_node)
auracall_repo=$(resolve_auracall_repo)
readiness_json="$tmp_dir/agent-host-readiness.json"
proof_output="$tmp_dir/browser-proof.out"
proof_expected="AURACALL_BROWSER_OK"

cd "$bridge_root"

./scripts/run-node22-npx.sh mcporter call auracall.agent_host_readiness target:chatgpt \
  --config examples/mcporter.auracall.json >"$readiness_json"

can_drive=$(json_value "$readiness_json" browser.agentDecision.canDriveBrowser || printf 'false\n')
state=$(json_value "$readiness_json" browser.state || printf 'unknown\n')
action=$(json_value "$readiness_json" agentDecision.action || printf 'inspect-diagnostics\n')
command=$(json_value "$readiness_json" agentDecision.command || true)

if [ "$can_drive" != "true" ]; then
  printf 'auracall browser proof: not ready\n'
  printf 'state=%s\n' "$state"
  printf 'agentAction=%s\n' "$action"
  if [ -n "$command" ]; then
    printf 'nextCommand=%s\n' "$command"
  fi
  printf 'This script did not launch browser work because readiness did not allow browser driving.\n'
  exit 2
fi

cd "$auracall_repo"

"$HOME/.local/bin/auracall" --chatgpt \
  --browser-model-strategy ignore \
  --prompt "Read the attached package.json and reply with exactly: ${proof_expected}" \
  --file package.json \
  --slug auracall-browser-ok \
  --timeout "${AURACALL_BROWSER_PROOF_TIMEOUT:-180}" \
  --force \
  --no-notify >"$proof_output" 2>&1

if grep -Fq "$proof_expected" "$proof_output"; then
  printf 'auracall browser proof: pass\n'
  printf 'expected=%s\n' "$proof_expected"
  exit 0
fi

printf 'auracall browser proof: failed\n' >&2
cat "$proof_output" >&2
exit 1
