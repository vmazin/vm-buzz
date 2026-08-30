#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_URL="https://github.com/block/buzz.git"
REQUESTED_REF=""
CHECK_ONLY=false

usage() {
  cat <<'EOF'
Usage: update-upstream.sh [--ref desktop-vX.Y.Z] [--check-only]

Fetch upstream and rebase the current customization branch onto the selected
stable Buzz Desktop release. The worktree must be clean.
EOF
}

while (($#)); do
  case "$1" in
    --ref)
      REQUESTED_REF="${2:?--ref requires a value}"
      shift 2
      ;;
    --check-only)
      CHECK_ONLY=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$(git -C "$ROOT_DIR" remote get-url upstream 2>/dev/null || true)" != "$UPSTREAM_URL" ]]; then
  echo "Remote 'upstream' must be $UPSTREAM_URL" >&2
  exit 1
fi

git -C "$ROOT_DIR" fetch --tags --prune upstream

if [[ -z "$REQUESTED_REF" ]]; then
  REQUESTED_REF="$({
    git -C "$ROOT_DIR" tag --list 'desktop-v*' |
      grep -E '^desktop-v[0-9]+\.[0-9]+\.[0-9]+$' |
      sort -V |
      tail -n 1
  })"
fi

if [[ ! "$REQUESTED_REF" =~ ^desktop-v[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
   ! git -C "$ROOT_DIR" rev-parse --verify --quiet "refs/tags/$REQUESTED_REF^{commit}" >/dev/null; then
  echo "Unknown stable Desktop tag: $REQUESTED_REF" >&2
  exit 2
fi

printf 'current_branch=%s\n' "$(git -C "$ROOT_DIR" branch --show-current)"
printf 'current_commit=%s\n' "$(git -C "$ROOT_DIR" rev-parse HEAD)"
printf 'selected_upstream_ref=%s\n' "$REQUESTED_REF"
printf 'selected_upstream_commit=%s\n' \
  "$(git -C "$ROOT_DIR" rev-parse "refs/tags/$REQUESTED_REF^{commit}")"

if [[ "$CHECK_ONLY" == true ]]; then
  exit 0
fi

if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
  echo "Refusing to rebase a dirty vm-buzz worktree" >&2
  exit 1
fi

branch="$(git -C "$ROOT_DIR" branch --show-current)"
if [[ -z "$branch" || "$branch" == "main" || "$branch" == "master" ]]; then
  echo "Refusing to rebase protected or detached branch: ${branch:-detached}" >&2
  exit 1
fi

git -C "$ROOT_DIR" rebase "$REQUESTED_REF"
"$ROOT_DIR/scripts/verify-vm-buzz-customizations.sh"