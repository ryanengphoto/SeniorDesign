#!/usr/bin/env bash
# Sync Official_SD_docs into Website/public/docs before build/deploy.
# Copies only when the source is missing at the destination or content differs.
#
# Exit 0 always (unless a required source is missing).
# Prints SYNCED=1 to stdout summary lines; sets docs_synced global via caller.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
PUBLIC_DOCS="$ROOT/public/docs"
SRC_DIR="$REPO/Docs/Official_SD_docs"

# source_relative_to_Official_SD_docs|dest_name_in_public/docs
DOC_MAP=(
  "D_and_C_SD1_v2.pdf|divide-and-conquer.pdf"
)

mkdir -p "$PUBLIC_DOCS"

synced=0
for entry in "${DOC_MAP[@]}"; do
  src_name="${entry%%|*}"
  dest_name="${entry##*|}"
  src="$SRC_DIR/$src_name"
  dest="$PUBLIC_DOCS/$dest_name"

  if [[ ! -f "$src" ]]; then
    echo "Missing source document: $src" >&2
    exit 1
  fi

  if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
    echo "  up to date: $dest_name"
    continue
  fi

  cp -f "$src" "$dest"
  echo "  updated: $dest_name  (from Docs/Official_SD_docs/$src_name)"
  synced=1
done

if [[ "$synced" -eq 0 ]]; then
  echo "  no document changes"
fi

# Signal to caller via exit code: 0 = unchanged, 2 = updated
if [[ "$synced" -eq 1 ]]; then
  exit 2
fi
exit 0
