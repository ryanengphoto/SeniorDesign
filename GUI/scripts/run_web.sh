#!/usr/bin/env bash
# Launch Flutter mock console on web-server and open a browser when possible.
set -euo pipefail

HOST="${1:-127.0.0.1}"
PORT="${2:-7357}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/app"
FLUTTER="${FLUTTER:-$HOME/flutter/bin/flutter}"
URL="http://${HOST}:${PORT}"

export PATH="$HOME/flutter/bin:$HOME/.local/bin:${PATH:-}"

if [[ ! -x "$FLUTTER" ]]; then
  echo "ERROR: Flutter not found at $FLUTTER" >&2
  echo "  Install: git clone https://github.com/flutter/flutter.git -b stable ~/flutter" >&2
  exit 1
fi

"$FLUTTER" config --enable-web >/dev/null

# Prefer Windows Chrome/Edge from WSL when present.
if [[ -z "${CHROME_EXECUTABLE:-}" ]]; then
  for candidate in \
    "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" \
    "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"; do
    if [[ -x "$candidate" ]]; then
      export CHROME_EXECUTABLE="$candidate"
      break
    fi
  done
fi

open_browser() {
  local target="$1"
  if [[ -n "${CHROME_EXECUTABLE:-}" && -x "${CHROME_EXECUTABLE}" ]]; then
    "$CHROME_EXECUTABLE" --new-window "$target" >/dev/null 2>&1 &
    return
  fi
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$target" >/dev/null 2>&1 &
    return
  fi
  echo "Open $target in your browser."
}

# Free the port if a previous run is stuck.
fuser -k "${PORT}/tcp" 2>/dev/null || true

echo "Starting mock operator console at $URL"
echo "(Simulated hub data — MOCK mode. Ctrl+C to stop.)"

# Open browser shortly after the server is likely up.
(
  for _ in $(seq 1 60); do
    if curl -sf "$URL" >/dev/null 2>&1; then
      open_browser "$URL"
      exit 0
    fi
    sleep 0.5
  done
) &

cd "$APP"
exec "$FLUTTER" run -d web-server \
  --web-hostname="$HOST" \
  --web-port="$PORT"
