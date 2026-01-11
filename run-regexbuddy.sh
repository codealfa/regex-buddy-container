#!/usr/bin/env bash
set -euo pipefail

# Go to the repo folder (this script's directory)
cd "$(dirname "$(readlink -f "$0")")"

# Export IDs for compose
export MY_UID="$(id -u)"
export MY_GID="$(id -g)"

# Optional: safest X11 permission grant for local user (NOT "xhost +")
# Only needed if you are NOT using XAUTHORITY mount successfully.
if command -v xhost >/dev/null 2>&1; then
  xhost +SI:localuser:"$USER" >/dev/null 2>&1 || true
fi

# Start the container (foreground)
exec docker compose up
