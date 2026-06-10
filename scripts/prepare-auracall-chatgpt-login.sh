#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
bridge_root=$(CDPATH= cd "$script_dir/.." && pwd)
tmp_dir=$(mktemp -d)
apply=false
mcp_server=auracall

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

usage() {
  cat <<'EOF'
Usage:
  scripts/prepare-auracall-chatgpt-login.sh [--apply] [--server auracall|auracall-local]

Checks Aura-Call MCP agent_host_readiness for ChatGPT and prepares only the
safe next setup action:

- prune stale browser-state entries when requested;
- launch the managed login browser when requested;
- print the human/login handoff when provider guard pages require a human.

Without --apply this is a dry run and does not mutate browser state or launch
Chrome.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      apply=true
      shift
      ;;
    --server)
      if [ "$#" -lt 2 ]; then
        printf '%s\n' '--server requires auracall or auracall-local.' >&2
        exit 2
      fi
      mcp_server="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$mcp_server" in
  auracall|auracall-local) ;;
  *)
    printf '%s\n' '--server must be auracall or auracall-local.' >&2
    exit 2
    ;;
esac

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

call_mcp() {
  tool="$1"
  shift
  ./scripts/run-node22-npx.sh mcporter call "${mcp_server}.${tool}" "$@" \
    --config examples/mcporter.auracall.json
}

node_cmd=$(resolve_node)
readiness_json="$tmp_dir/readiness.json"

cd "$bridge_root"

call_mcp agent_host_readiness target:chatgpt >"$readiness_json"

state=$(json_value "$readiness_json" browser.state || printf 'unknown\n')
action=$(json_value "$readiness_json" agentDecision.action || printf 'inspect-diagnostics\n')
can_drive=$(json_value "$readiness_json" browser.agentDecision.canDriveBrowser || printf 'false\n')
command=$(json_value "$readiness_json" agentDecision.command || true)

printf 'chatgpt login prep: state=%s action=%s canDriveBrowser=%s server=%s\n' \
  "$state" "$action" "$can_drive" "$mcp_server"

case "$action" in
  proceed)
    printf 'Aura-Call reports ChatGPT browser driving is already allowed.\n'
    exit 0
    ;;
  prune-browser-state)
    if [ "$apply" != true ]; then
      printf 'dry-run: would call %s.browser_control action:prune-browser-state target:chatgpt\n' "$mcp_server"
      exit 0
    fi
    call_mcp browser_control action:prune-browser-state target:chatgpt >/dev/null
    printf 'pruned stale browser state. Re-run agent_host_readiness or this script for the next action.\n'
    exit 0
    ;;
  launch-login)
    if [ "$apply" != true ]; then
      printf 'dry-run: would call %s.browser_control action:launch-login target:chatgpt\n' "$mcp_server"
      printf 'dry-run: pass --apply to open the managed login browser.\n'
      exit 0
    fi
    call_mcp browser_control action:launch-login target:chatgpt >/dev/null
    printf 'launched managed ChatGPT login browser. Complete sign-in manually, then run scripts/prove-auracall-chatgpt-browser.sh.\n'
    exit 0
    ;;
  wait-for-human)
    printf 'human action required. Complete the provider gate in the managed browser.\n'
    if [ -n "$command" ]; then
      printf 'nextCommand=%s\n' "$command"
    fi
    exit 2
    ;;
  *)
    printf 'no safe automatic setup action for agentAction=%s.\n' "$action"
    if [ -n "$command" ]; then
      printf 'nextCommand=%s\n' "$command"
    fi
    exit 2
    ;;
esac
