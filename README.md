# RegexBuddy in Docker (Wine + Ubuntu 24.04)

This project builds a self-contained Docker environment for running **RegexBuddy 4 (Windows edition)** on Linux using **Wine** inside an **Ubuntu 24.04** base image.

It provides a reproducible, GUI-capable setup with persistent state and automatic installation handling — meaning the first run installs RegexBuddy, and every subsequent run launches it instantly.

---

## 🧩 Features

- ✅ Based on `ubuntu:24.04` with WineHQ stable build  
- ✅ Supports 64-bit RegexBuddy installer  
- ✅ GUI access through native X11 forwarding  
- ✅ Audio support via PulseAudio  
- ✅ Persistent Wine prefix stored in a Docker volume (`/data/.wine`)  
- ✅ Automatic installer detection and one-time setup  
- ✅ Host UID/GID mapping for clean permissions  
- ✅ Optional runtime reinstallation — just drop a new `.exe` installer into `./installers/`

---

## 🏗️ Prerequisites

Make sure the following are available on your Linux host:

- Docker and Docker Compose v2+
- An X11 environment (e.g., GNOME, KDE, XFCE)
- X11 socket exposed at `/tmp/.X11-unix`
- Access to your current X session’s authorization (usually via `~/.Xauthority`)
- (Optional) PulseAudio or PipeWire for sound

---

## 📦 Repository Layout

```
.
├── Dockerfile
├── docker-compose.yml
├── entrypoint.sh
├── installers/
│   └── RegexBuddy4Setup.exe   ← drop your installer here
└── README.md
```

---

## 🚀 Building and Running

### 1. Export your user and group IDs

Docker needs to know which user should own files created inside the container:

```bash
export MY_UID=$(id -u)
export MY_GID=$(id -g)
```

(You can also put these in a `.env` file if you prefer.)

---

### 2. Build and start the container

```bash
docker compose up --build
```

- On **first launch**, Wine will initialize a prefix and run your installer (`RegexBuddy*.exe`) interactively.
- On **subsequent runs**, it detects the installed app and launches it immediately.

---

### 3. Rebuilding or upgrading

To rebuild with a new installer or Wine version:

1. Drop the new `.exe` installer into `./installers/`
2. Rebuild:
   ```bash
   docker compose build --no-cache
   docker compose up
   ```
3. The entrypoint will automatically install the new version if it doesn’t detect an existing one.

---

## 💾 Data Persistence

The Wine prefix and installed RegexBuddy files live inside the Docker named volume:

```
regex-buddy-container_appdata:/data
```

This persists across rebuilds and restarts.  
To start fresh (e.g., clean reinstall):

```bash
docker compose down
docker volume rm regex-buddy-container_appdata
docker compose up --build
```

---

## 🧰 Useful Commands

Inspect the volume contents:
```bash
docker run --rm -it -v regex-buddy-container_appdata:/data ubuntu ls -lah /data
```

Fix ownership if you ever see a “Permission denied” error:
```bash
docker run --rm -v regex-buddy-container_appdata:/data alpine sh -c "chown -R $(id -u):$(id -g) /data"
```

Enter the running container:
```bash
docker exec -it regex-buddy-container-regexbuddy-1 bash
```

---

## ⚙️ Environment Variables

| Variable | Description | Default |
|-----------|--------------|----------|
| `MY_UID` | Host user ID (for file ownership) | 1000 |
| `MY_GID` | Host group ID (for file ownership) | 1000 |
| `DISPLAY` | X11 display to use | inherited |
| `XAUTHORITY` | Path to `.Xauthority` file | `/tmp/.Xauthority` |
| `WINEPREFIX` | Wine prefix directory | `/data/.wine` |
| `WINEARCH` | Architecture (win64 or win32) | `win64` |
| `APP_EXE` | Override executable path if needed | auto-detected |

---

## 🧭 Troubleshooting

### ❌ `Permission denied` creating `/data/.wine`
The volume was created as root. Fix ownership:
```bash
docker run --rm -v regex-buddy-container_appdata:/data alpine sh -c "chown -R $(id -u):$(id -g) /data"
```

---

### ❌ GUI doesn’t appear
Make sure your user has X access:
```bash
xhost +si:localuser:$USER
```
Then restart the container.

If you’re using Wayland, ensure Xwayland is running (`echo $XDG_SESSION_TYPE` should report `x11` or `wayland` with Xwayland support).

---

### ❌ Audio not working
Ensure the PulseAudio socket is mounted correctly in `docker-compose.yml`:
```yaml
- ${XDG_RUNTIME_DIR}/pulse/native:${XDG_RUNTIME_DIR}/pulse/native
```

---

### ❌ Installer fails or exits immediately
Try launching it interactively:
```bash
docker compose run regexbuddy bash
wine /opt/installer/RegexBuddy4Setup.exe
```
If that works manually, the installer may require user input or a newer Wine version.

---

### ❌ “RegexBuddy EXE not found” message
The installer didn’t complete successfully.  
Run the container interactively (`docker compose run regexbuddy bash`), reinstall manually, and verify:
```bash
ls "/data/.wine/drive_c/Program Files/Just Great Software"*
```
Once it’s installed, restart normally.

---

## 🖥️ Desktop Launcher (Recommended)

This repository includes a desktop launcher template that lets you start RegexBuddy with a single click — without manually exporting environment variables or running Docker commands.

### What the launcher does

When launched, it:

- Exports the required environment variables:
  - `MY_UID`
  - `MY_GID`
- Grants safe X11 access using:
  ```
  xhost +SI:localuser:$USER
  ```
- Runs `docker compose up` from the project directory in the foreground, showing logs in a terminal window

---

### 1️⃣ Install the launcher

Copy the template launcher to your local applications directory:

```
cp regexbuddy-docker.desktop.dist ~/.local/share/applications/regexbuddy-docker.desktop
```

---

### 2️⃣ Edit the launcher path

Open the copied launcher file:

```
nano ~/.local/share/applications/regexbuddy-docker.desktop
```

Update the `Exec=` line to point to your local checkout **and explicitly launch a terminal emulator** (recommended for GNOME):

```
Exec=gnome-terminal -- bash -lc '/absolute/path/to/regex-buddy-container/run-regexbuddy.sh'
```

Example:

```
Exec=gnome-terminal -- bash -lc '/home/jchoptim/regex-buddy-container/run-regexbuddy.sh'
```

Make sure the launcher also contains:

```
Terminal=false
```

> **Why this is needed**  
> On GNOME, `Terminal=true` is unreliable for GUI applications. Explicitly launching `gnome-terminal` guarantees a visible logs window.

---

### 3️⃣ Ensure the launch script is executable

```
chmod +x run-regexbuddy.sh
```

---

### 4️⃣ Launch RegexBuddy

- Open your desktop environment’s application launcher
- Search for **“RegexBuddy (Docker)”**
- Click to launch

A terminal window will open showing Docker and Wine logs, and the RegexBuddy GUI will appear separately.

Closing the terminal window will stop the container and close the application.

---

### 🛑 Stopping the application

If the terminal is still open, simply close it.

Otherwise, you can stop everything manually with:

```
cd /path/to/regex-buddy-container
docker compose down
```

---

## 🧹 Cleanup

Remove everything (container + volume + image):

```bash
docker compose down --rmi all -v
```

---

## 🧠 Notes

- The container runs Wine as your host user for correct file permissions.
- The first install creates a persistent Wine environment under `/data/.wine`.
- Subsequent launches reuse it, so settings and license files persist.
- If you update your installer, just drop the new `.exe` in `installers/` and restart.

---

## 📜 License

MIT — use and modify freely.
