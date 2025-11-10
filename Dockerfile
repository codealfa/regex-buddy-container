# Dockerfile
ARG UBUNTU_TAG=24.04
FROM ubuntu:${UBUNTU_TAG}

ENV DEBIAN_FRONTEND=noninteractive \
    WINEDEBUG=-all \
    WINEPREFIX=/data/.wine
    # If you prefer 32-bit prefix: add WINEARCH=win32

# WineHQ repo + Wine + winetricks + gosu
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates gnupg2 wget software-properties-common cabextract xz-utils \
      dbus-x11 pulseaudio \
 && install -d -m 0755 /etc/apt/keyrings \
 && wget -O- https://dl.winehq.org/wine-builds/winehq.key | gpg --dearmor > /etc/apt/keyrings/winehq-archive.gpg \
 && chmod 0644 /etc/apt/keyrings/winehq-archive.gpg \
 && printf "Types: deb\nURIs: https://dl.winehq.org/wine-builds/ubuntu\nSuites: noble\nComponents: main\nSigned-By: /etc/apt/keyrings/winehq-archive.gpg\n" \
    > /etc/apt/sources.list.d/winehq.sources \
 && apt-get update \
 && apt-get install -y --no-install-recommends winehq-stable winetricks gosu \
 && rm -rf /var/lib/apt/lists/*

# Optional: bake an installer for build-time installs (not required if installing at runtime)
# (No chown — we’re root here and /tmp is fine)
COPY installers/RegexBuddy4Setup.exe /opt/installer/RegexBuddy4Setup.exe

# PulseAudio env (Wayland/PipeWire’s Pulse shim works fine too)
ENV PULSE_SERVER=unix:${XDG_RUNTIME_DIR}/pulse/native

# Entrypoint handles first-run install + auto-discovery of EXE
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# No CMD here — entrypoint will locate the EXE (or run installer) and exec it.
