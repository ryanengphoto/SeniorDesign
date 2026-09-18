#!/usr/bin/env bash
# Deploy Website/dist to the EECS Maverick group account home (web root).
#
# Credentials: Website/.env (gitignored). See .env.example.
# Live URL: https://maverick.eecs.ucf.edu/seniordesign/fa2026sp2027/g19/
#
# Always syncs Docs/Official_SD_docs → public/docs before deploy.
# If documents changed, rebuilds even without --build (so dist/ gets the new PDF).
#
# Usage:
#   ./deploy-maverick.sh          # sync docs; rebuild if docs changed; upload
#   ./deploy-maverick.sh --build  # sync docs; always rebuild; upload

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$ROOT/dist"
ENV_FILE="$ROOT/.env"
VENV="$ROOT/.venv-deploy"
SYNC_DOCS="$ROOT/scripts/sync_docs.sh"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

HOST="${MAVERICK_HOST:-maverick.eecs.ucf.edu}"
USER="${MAVERICK_USER:-fa26sp27g19}"
REMOTE_DIR="${MAVERICK_DIR:-.}"
PASS="${MAVERICK_PASS:-}"
LIVE_URL="https://maverick.eecs.ucf.edu/seniordesign/fa2026sp2027/g19/"

BUILD=0
for arg in "$@"; do
  case "$arg" in
    --build|-b) BUILD=1 ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

echo "==> Syncing documents from Docs/Official_SD_docs ..."
DOCS_CHANGED=0
set +e
bash "$SYNC_DOCS"
sync_status=$?
set -e
if [[ "$sync_status" -eq 2 ]]; then
  DOCS_CHANGED=1
elif [[ "$sync_status" -ne 0 ]]; then
  exit "$sync_status"
fi

if [[ "$BUILD" -eq 1 || "$DOCS_CHANGED" -eq 1 ]]; then
  if [[ "$DOCS_CHANGED" -eq 1 && "$BUILD" -eq 0 ]]; then
    echo "==> Documents changed — rebuilding so dist/ includes them..."
  else
    echo "==> Building site..."
  fi
  (cd "$ROOT" && npm run build)
fi

if [[ ! -d "$DIST" ]]; then
  echo "Missing $DIST — run with --build or: npm run build" >&2
  exit 1
fi

# Guard: public PDF must match what we are about to upload from dist/
if [[ -f "$ROOT/public/docs/divide-and-conquer.pdf" ]]; then
  if [[ ! -f "$DIST/docs/divide-and-conquer.pdf" ]] \
    || ! cmp -s "$ROOT/public/docs/divide-and-conquer.pdf" "$DIST/docs/divide-and-conquer.pdf"; then
    echo "==> dist/docs PDF out of date — rebuilding..."
    (cd "$ROOT" && npm run build)
  fi
fi

REMOTE="${USER}@${HOST}:${REMOTE_DIR}/"
echo "==> Deploying $DIST/ -> $REMOTE"

deploy_sftp() {
  if [[ ! -x "$VENV/bin/python" ]]; then
    echo "==> Creating local deploy venv (paramiko)..."
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q paramiko
  fi
  "$VENV/bin/python" "$ROOT/scripts/sftp_deploy.py"
}

# Prefer SFTP helper when deploying to home "." — safer than rsync --delete on $HOME.
if [[ -n "$PASS" ]]; then
  if [[ "$REMOTE_DIR" == "." || "$REMOTE_DIR" == "./" || "$REMOTE_DIR" == "" ]]; then
    echo "(Deploying to account home — using Python SFTP, site files only)"
    deploy_sftp
  elif command -v sshpass >/dev/null 2>&1; then
    export SSHPASS="$PASS"
    rsync -avz --delete -e "sshpass -e ssh -o StrictHostKeyChecking=accept-new" \
      "$DIST"/ "$REMOTE"
  else
    echo "(sshpass not found — using Python SFTP via .venv-deploy)"
    deploy_sftp
  fi
else
  echo "(No MAVERICK_PASS in env/.env — SSH will prompt for the password.)"
  if [[ "$REMOTE_DIR" == "." || "$REMOTE_DIR" == "./" || "$REMOTE_DIR" == "" ]]; then
    echo "Password required for home-directory deploy (set MAVERICK_PASS in .env)." >&2
    exit 1
  fi
  rsync -avz --delete -e "ssh -o StrictHostKeyChecking=accept-new" \
    "$DIST"/ "$REMOTE"
fi

echo "==> Done."
echo "    Live URL: $LIVE_URL"
