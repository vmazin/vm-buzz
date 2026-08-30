#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINATION="${1:-}"
MARKER=".vm-buzz-build-tree"

command -v rsync >/dev/null || {
  echo "rsync is required" >&2
  exit 1
}
command -v powershell.exe >/dev/null || {
  echo "powershell.exe is required" >&2
  exit 1
}
command -v wslpath >/dev/null || {
  echo "wslpath is required" >&2
  exit 1
}

if [[ -z "$DESTINATION" ]]; then
  local_app_data="$(powershell.exe -NoProfile -Command \
    '[Environment]::GetFolderPath("LocalApplicationData")' | tr -d '\r')"
  DESTINATION="$(wslpath -u "${local_app_data}\\vm-buzz\\build\\current")"
fi

case "$DESTINATION" in
  /mnt/?/*) ;;
  *)
    echo "Destination must be a Windows-mounted path under /mnt/<drive>: $DESTINATION" >&2
    exit 2
    ;;
esac

if [[ -d "$DESTINATION" && -n "$(find "$DESTINATION" -mindepth 1 -maxdepth 1 -print -quit)" &&
      ! -f "$DESTINATION/$MARKER" ]]; then
  echo "Refusing to replace an unmarked destination: $DESTINATION" >&2
  exit 1
fi

mkdir -p "$DESTINATION"
rsync -a --delete \
  --exclude '.git/' \
  --exclude 'target/' \
  --exclude 'node_modules/' \
  --exclude 'dist/' \
  --exclude '.cache/' \
  "$ROOT_DIR/" "$DESTINATION/"
touch "$DESTINATION/$MARKER"

printf 'windows_source_wsl=%s\n' "$DESTINATION"
printf 'windows_source=%s\n' "$(wslpath -w "$DESTINATION")"