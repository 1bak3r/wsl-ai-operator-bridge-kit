#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
bridge_root=$(CDPATH= cd "$script_dir/.." && pwd)

if [ -z "${AURACALL_BRIDGE_KIT:-}" ]; then
  export AURACALL_BRIDGE_KIT="$bridge_root"
fi

if [ -z "${AURACALL_REPO:-}" ]; then
  for candidate in \
    "$bridge_root/../auracall" \
    "$HOME/codex-research/corpora/repos/auracall"
  do
    if [ -f "$candidate/dist/bin/auracall-mcp.js" ]; then
      export AURACALL_REPO="$candidate"
      break
    fi
  done
fi

if [ -z "${NODE:-}" ]; then
  for dir in "$HOME"/.nvm/versions/node/v*/bin; do
    if [ -x "$dir/node" ]; then
      NODE="$dir/node"
      NODE_BIN="$dir"
    fi
  done
else
  NODE_BIN=$(dirname "$NODE")
fi

if [ "$#" -eq 0 ]; then
  echo "usage: run-node22-npx.sh <package-or-bin> [args...]" >&2
  exit 2
fi

if [ -n "${NODE_BIN:-}" ] && [ -f "$NODE_BIN/../lib/node_modules/npm/bin/npx-cli.js" ]; then
  export PATH="$NODE_BIN:$PATH"
  exec "$NODE" "$NODE_BIN/../lib/node_modules/npm/bin/npx-cli.js" -y "$@"
fi

exec npx -y "$@"
