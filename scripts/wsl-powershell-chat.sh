#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
ps_script="$script_dir/windows-powershell-chat.ps1"
if command -v wslpath >/dev/null 2>&1; then
  ps_script=$(wslpath -w "$ps_script")
fi

resolve_powershell_bin() {
  if [ -n "${WSL_BRIDGE_WINDOWS_POWERSHELL:-}" ]; then
    printf '%s\n' "$WSL_BRIDGE_WINDOWS_POWERSHELL"
    return
  fi
  if [ -n "${AURACALL_WINDOWS_POWERSHELL:-}" ]; then
    printf '%s\n' "$AURACALL_WINDOWS_POWERSHELL"
    return
  fi
  if [ -n "${AURACALL_WINDOWS_POWERSHELL_PATH:-}" ]; then
    printf '%s\n' "$AURACALL_WINDOWS_POWERSHELL_PATH"
    return
  fi
  for candidate in \
    /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe \
    /mnt/c/Program\ Files/PowerShell/7/pwsh.exe
  do
    if [ -x "$candidate" ]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  if command -v powershell.exe >/dev/null 2>&1; then
    command -v powershell.exe
    return
  fi
  printf '%s\n' powershell.exe
}

powershell_bin=$(resolve_powershell_bin)

if [ "$#" -gt 0 ]; then
  {
    printf '%s\n' "$*"
    printf ':quit\n'
  } | "$powershell_bin" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$ps_script"
else
  "$powershell_bin" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$ps_script"
fi
