#!/usr/bin/env sh
set -eu

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

