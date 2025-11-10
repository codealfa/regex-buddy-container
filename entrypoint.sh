#!/usr/bin/env bash
set -euo pipefail

# optional UID/GID drop (only if you pass MY_UID/MY_GID; otherwise runs as current user)
if command -v gosu >/dev/null 2>&1 && [ -n "${MY_UID:-}" ] && [ -n "${MY_GID:-}" ]; then
  mkdir -p /data
  chown -R "${MY_UID}:${MY_GID}" /data
fi

export WINEDLLOVERRIDES="mscoree,mshtml="   # avoid Gecko/Mono prompts
mkdir -p "${WINEPREFIX:-/data/.wine}"

# initialize prefix (optional)
winecfg -v win10 || true

find_exe() {
  for base in "/data/.wine/drive_c/Program Files" "/data/.wine/drive_c/Program Files (x86)"; do
    [ -d "$base" ] || continue
    f="$(find "$base"/Just* -maxdepth 4 -type f -iname 'RegexBuddy*.exe' 2>/dev/null | head -n1 || true)"
    [ -n "$f" ] && { printf '%s\n' "$f"; return 0; }
  done
  return 1
}

exe_path="$(find_exe || true)"

if [ -z "${exe_path}" ]; then
  inst="$(ls -1 /opt/installer/*.exe 2>/dev/null | sort -V | tail -n1 || true)"
  if [ -n "$inst" ]; then
    echo "Running installer interactively: $inst"
    # GUI install, no silent flags for this diagnostic pass
    wine "$inst" || true

    # After installer exits, re-scan for the EXE
    exe_path="$(find_exe || true)"
  fi
fi

if [ -z "${exe_path}" ]; then
  echo "RegexBuddy EXE not found after install attempt."
  echo "Dumping possible locations:"
  find "/data/.wine/drive_c/Program Files" "/data/.wine/drive_c/Program Files (x86)" -maxdepth 4 -iname 'RegexBuddy*.exe' 2>/dev/null || true
  # keep container open so you can inspect
  exec bash
fi

echo "Launching: $exe_path"
exec wine "$exe_path"

# Manual override supported via APP_EXE env (Windows path)
if [ -n "${APP_EXE:-}" ]; then
  p="/data/.wine/drive_c/${APP_EXE#C:\\}"
  p="${p//\\//}"
  [ -f "$p" ] && exe_path="$p"
fi

if [ -z "${exe_path}" ]; then
  echo "RegexBuddy EXE not found. Put the installer in ./installers/ and restart."
  exit 1
fi

echo "Launching: $exe_path"
exec wine "$exe_path"
