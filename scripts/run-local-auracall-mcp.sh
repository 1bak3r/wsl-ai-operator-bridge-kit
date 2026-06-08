#!/usr/bin/env sh
set -eu

if [ -z "${NODE:-}" ]; then
  for dir in "$HOME"/.nvm/versions/node/v*/bin; do
    [ -x "$dir/node" ] && NODE="$dir/node"
  done
fi

repo_root="${AURACALL_REPO:-$(pwd)}"

if [ ! -f "$repo_root/dist/bin/auracall-mcp.js" ]; then
  echo "Could not find dist/bin/auracall-mcp.js under: $repo_root" >&2
  echo "Run from an Aura-Call checkout after pnpm run build, or set AURACALL_REPO." >&2
  exit 2
fi

exec "${NODE:-node}" "$repo_root/dist/bin/auracall-mcp.js" "$@"
