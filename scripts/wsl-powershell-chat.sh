#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
ps_script="$script_dir/windows-powershell-chat.ps1"
if command -v wslpath >/dev/null 2>&1; then
  ps_script=$(wslpath -w "$ps_script")
fi

powershell_bin="${WSL_BRIDGE_WINDOWS_POWERSHELL:-powershell.exe}"

if [ "$#" -gt 0 ]; then
  {
    printf '%s\n' "$*"
    printf ':quit\n'
  } | "$powershell_bin" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$ps_script"
else
  "$powershell_bin" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$ps_script"
fi

