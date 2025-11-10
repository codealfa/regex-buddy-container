#!/usr/bin/env bash
set -euo pipefail

# --- Root phase: fix /data ownership, then re-exec as target user ----------
if [[ -z "${AS_USER:-}" ]]; then
  UID_T=${MY_UID:-1000}
  GID_T=${MY_GID:-1000}

  # Ensure /data exists and is owned by target uid:gid
  mkdir -p /data
  # Only chown when mismatched (fast on subsequent starts)
  OWN="$(stat -c '%u:%g' /data || echo '')"
  if [[ "${OWN}" != "${UID_T}:${GID_T}" ]]; then
    echo "Fixing ownership of /data to ${UID_T}:${GID_T} ..."
    chown -R "${UID_T}:${GID_T}" /data
  fi

  # Re-exec this script as the target user (mark with AS_USER to avoid recursion)
  exec gosu "${UID_T}:${GID_T}" env AS_USER=1 "$0" "$@"
fi

# --- User phase: install-if-needed and launch RegexBuddy --------------------

# Defaults (can be overridden via compose env)
export WINEPREFIX="${WINEPREFIX:-/data/.wine}"
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree,mshtml=}"   # avoid Gecko/Mono prompts
# If you want to force 64-bit (default) or 32-bit prefix, set WINEARCH in compose:
# export WINEARCH="${WINEARCH:-win64}"

mkdir -p "${WINEPREFIX}"

# Initialize prefix to Windows 10 (non-fatal if wine popups occur)
winecfg -v win10 || true

find_exe() {
  # Search both Program Files dirs for any RegexBuddy*.exe
  for base in \
    "${WINEPREFIX}/drive_c/Program Files" \
    "${WINEPREFIX}/drive_c/Program Files (x86)"; do
    [[ -d "${base}" ]] || continue
    local f
    f="$(find "${base}"/Just* -maxdepth 4 -type f -iname 'RegexBuddy*.exe' 2>/dev/null | head -n1 || true)"
    if [[ -n "${f:-}" ]]; then
      printf '%s\n' "$f"
      return 0
    fi
  done
  return 1
}

exe_path="$(find_exe || true)"

# Install if not already present (use newest *.exe in /opt/installer)
if [[ -z "${exe_path}" ]]; then
  inst="$(ls -1 /opt/installer/*.exe 2>/dev/null | sort -V | tail -n1 || true)"
  if [[ -n "${inst}" ]]; then
    echo "Running installer: ${inst}"
    # Optional niceties; comment out if you want absolutely minimal first-run
    # winetricks -q corefonts fontsmooth=rgb || true

    # Inno Setup silent flags (common for Just Great Software installers)
    # Use interactive install instead by removing flags if you prefer.
    wine "${inst}" /VERYSILENT /SP- /NORESTART /SUPPRESSMSGBOXES /LOG=C:\\install.log || true

    # Re-scan for installed executable
    exe_path="$(find_exe || true)"
  fi
fi

# Allow explicit override via Windows-style APP_EXE path (e.g. C:\Program Files\...\RegexBuddy64.exe)
if [[ -n "${APP_EXE:-}" ]]; then
  p="${WINEPREFIX}/drive_c/${APP_EXE#C:\\}"
  p="${p//\\//}"
  if [[ -f "${p}" ]]; then
    exe_path="${p}"
  fi
fi

if [[ -z "${exe_path}" ]]; then
  echo "RegexBuddy EXE not found after install attempt."
  echo "Hint: ensure an installer exists under ./installers (mounted to /opt/installer)."
  echo "Searched under 'Program Files' and 'Program Files (x86)'. Dropping to shell for inspection..."
  exec bash
fi

# If an instance is already running (e.g., installer auto-launched), don't start another.
already_pid="$(pgrep -f 'RegexBuddy.*\.exe' || true)"
if [[ -n "${already_pid}" ]]; then
  echo "RegexBuddy is already running (pid ${already_pid}); not launching a second instance."
  # keep the container alive while the GUI process runs
  exec tail --pid="${already_pid}" -f /dev/null
fi

echo "Launching: ${exe_path}"
exec wine "${exe_path}"
