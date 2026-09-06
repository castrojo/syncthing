# Bluefin P2P Syncthing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Syncthing in Project Bluefin as a rootless, declarative Podman Quadlet user unit with pure P2P discovery, automatic upstream updates via GHCR :2, and a native desktop entry, removing all Kubernetes resources and wrapper scripts.

**Architecture:** A declarative rootless Quadlet container unit placed in `/usr/share/containers/systemd/users/syncthing.container` paired with a `.desktop` entry. Uses host networking for native LAN broadcast discovery (UDP 21027) and Tailscale connectivity, strictly binds GUI to loopback (127.0.0.1:8384), maps host UID dynamically via `User=%U`, `Group=%G`, and `UserNS=keep-id`, mounts `%S/syncthing` for state and `%h/Sync` for user data, and tracks `ghcr.io/syncthing/syncthing:2` with `AutoUpdate=registry`.

**Tech Stack:** Podman Quadlet, systemd user manager, GitHub Container Registry (`ghcr.io`), XDG Desktop Entry, SELinux (`:Z`).

**Spec:** Self-contained in this plan and verified against Bluefin/Podman/Syncthing specifications.

## Global Constraints

- Image: `ghcr.io/syncthing/syncthing:2` with `AutoUpdate=registry`
- GUI Address: Must strictly enforce `Environment=STGUIADDRESS=127.0.0.1:8384`
- Network: `Network=host`
- Ownership & Identity: `User=%U`, `Group=%G`, `UserNS=keep-id`
- State & Data Paths: State in `%S/syncthing:/var/syncthing:Z`, user data in `%h/Sync:/var/syncthing/Sync:Z`
- No Kubernetes files, no onboarding shell scripts, no git-cloning scripts, no RPM packaging
- All files placed in `system_files/` following Bluefin packaging structure plus top-level `README.md`

---

### Task 1: Create Declarative Quadlet Container Unit

**Files:**
- Create: `system_files/usr/share/containers/systemd/users/syncthing.container`
- Test: `tests/test_quadlet_syntax.sh`

**Interfaces:**
- Produces: `/usr/share/containers/systemd/users/syncthing.container`

- [ ] **Step 1: Write validation test for Quadlet unit**

Create `tests/test_quadlet_syntax.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

QUADLET_FILE="system_files/usr/share/containers/systemd/users/syncthing.container"

if [[ ! -f "$QUADLET_FILE" ]]; then
  echo "FAIL: $QUADLET_FILE does not exist"
  exit 1
fi

grep -q "Image=ghcr.io/syncthing/syncthing:2" "$QUADLET_FILE" || { echo "FAIL: Missing Image"; exit 1; }
grep -q "AutoUpdate=registry" "$QUADLET_FILE" || { echo "FAIL: Missing AutoUpdate=registry"; exit 1; }
grep -q "Environment=STGUIADDRESS=127.0.0.1:8384" "$QUADLET_FILE" || { echo "FAIL: Missing loopback GUI binding"; exit 1; }
grep -q "User=%U" "$QUADLET_FILE" || { echo "FAIL: Missing User=%U"; exit 1; }
grep -q "Group=%G" "$QUADLET_FILE" || { echo "FAIL: Missing Group=%G"; exit 1; }
grep -q "UserNS=keep-id" "$QUADLET_FILE" || { echo "FAIL: Missing UserNS=keep-id"; exit 1; }
grep -q "Network=host" "$QUADLET_FILE" || { echo "FAIL: Missing Network=host"; exit 1; }
grep -q "Volume=%S/syncthing:/var/syncthing:Z" "$QUADLET_FILE" || { echo "FAIL: Missing state volume"; exit 1; }
grep -q "Volume=%h/Sync:/var/syncthing/Sync:Z" "$QUADLET_FILE" || { echo "FAIL: Missing Sync volume"; exit 1; }

echo "PASS: Quadlet unit validated successfully."
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_quadlet_syntax.sh`
Expected: FAIL

- [ ] **Step 3: Implement `syncthing.container`**

Write `system_files/usr/share/containers/systemd/users/syncthing.container`:
```ini
[Unit]
Description=Syncthing peer-to-peer file synchronization
Documentation=man:syncthing(1) https://docs.syncthing.net/
Wants=network-online.target
After=network-online.target

StartLimitIntervalSec=10min
StartLimitBurst=5

[Container]
Image=ghcr.io/syncthing/syncthing:2
AutoUpdate=registry

# Dynamic user/group mapping for rootless container
User=%U
Group=%G
UserNS=keep-id

# Environment & security hardening
Environment=HOME=/var/syncthing
Environment=STHOMEDIR=/var/syncthing
Environment=STGUIADDRESS=127.0.0.1:8384
Environment=STNOUPGRADE=1
Environment=STNORESTART=1

# State and dedicated user sync volume
Volume=%S/syncthing:/var/syncthing:Z
Volume=%h/Sync:/var/syncthing/Sync:Z

# Network configuration: host network for LAN broadcast and Tailscale mesh
Network=host

Notify=healthy
NoNewPrivileges=true
DropCapability=ALL
StopTimeout=45

[Service]
Restart=on-failure
RestartSec=15s
TimeoutStartSec=300
TimeoutStopSec=60s
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_quadlet_syntax.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add system_files/usr/share/containers/systemd/users/syncthing.container tests/test_quadlet_syntax.sh
git commit -m "feat: add declarative syncthing quadlet unit tracking ghcr:2"
```

---

### Task 2: Create Desktop Launcher Entry

**Files:**
- Create: `system_files/usr/share/applications/syncthing.desktop`
- Test: `tests/test_desktop_entry.sh`

**Interfaces:**
- Produces: `/usr/share/applications/syncthing.desktop`

- [ ] **Step 1: Write validation test for Desktop entry**

Create `tests/test_desktop_entry.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

DESKTOP_FILE="system_files/usr/share/applications/syncthing.desktop"

if [[ ! -f "$DESKTOP_FILE" ]]; then
  echo "FAIL: $DESKTOP_FILE does not exist"
  exit 1
fi

grep -q "Exec=xdg-open http://127.0.0.1:8384/" "$DESKTOP_FILE" || { echo "FAIL: Missing Exec loopback url"; exit 1; }
grep -q "Exec=systemctl --user start --no-block syncthing.service" "$DESKTOP_FILE" || { echo "FAIL: Missing start action"; exit 1; }
grep -q "Exec=systemctl --user stop syncthing.service" "$DESKTOP_FILE" || { echo "FAIL: Missing stop action"; exit 1; }

echo "PASS: Desktop entry validated successfully."
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_desktop_entry.sh`
Expected: FAIL

- [ ] **Step 3: Implement `syncthing.desktop`**

Write `system_files/usr/share/applications/syncthing.desktop`:
```ini
[Desktop Entry]
Name=Syncthing
Comment=Peer-to-peer file synchronization
Exec=xdg-open http://127.0.0.1:8384/
Icon=folder-sync
Terminal=false
Type=Application
Categories=Network;FileTransfer;
Actions=Start;Stop;

[Desktop Action Start]
Name=Start Syncthing
Exec=systemctl --user start --no-block syncthing.service

[Desktop Action Stop]
Name=Stop Syncthing
Exec=systemctl --user stop syncthing.service
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_desktop_entry.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add system_files/usr/share/applications/syncthing.desktop tests/test_desktop_entry.sh
git commit -m "feat: add syncthing desktop launcher with start/stop actions"
```

---

### Task 3: Remove Deprecated Scripts, Kubernetes Manifests, and Update Documentation

**Files:**
- Delete: `k8s/`
- Delete: `onboard-client.sh`
- Delete: `quadlet/`
- Delete: `extension/`
- Modify: `README.md`
- Test: `tests/test_cleanup.sh`

**Interfaces:**
- Produces: Clean tree with only declarative system files, tests, and updated `README.md`

- [ ] **Step 1: Write cleanup validation test**

Create `tests/test_cleanup.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

for obsolete in k8s onboard-client.sh quadlet extension; do
  if [[ -e "$obsolete" ]]; then
    echo "FAIL: $obsolete still exists"
    exit 1
  fi
done

grep -q "Kubernetes" README.md && { echo "FAIL: README still references Kubernetes"; exit 1; }
grep -q "onboard-client.sh" README.md && { echo "FAIL: README still references onboard-client.sh"; exit 1; }
grep -q "ghcr.io/syncthing/syncthing:2" README.md || { echo "FAIL: README missing ghcr reference"; exit 1; }

echo "PASS: Cleanup verified."
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_cleanup.sh`
Expected: FAIL

- [ ] **Step 3: Remove obsolete files and rewrite `README.md`**

Remove:
```bash
git rm -rf k8s onboard-client.sh quadlet extension
```

Update `README.md` to document:
- Pure P2P architecture (no k8s, no scripts)
- Shipping in Bluefin under `system_files/` (`/usr/share/containers/systemd/users/syncthing.container` and `/usr/share/applications/syncthing.desktop`)
- Native P2P discovery over LAN (UDP 21027) and Tailscale
- Auto-updates via Podman `podman-auto-update.timer` tracking `ghcr.io/syncthing/syncthing:2`
- How users start/stop via desktop launcher or `systemctl --user start syncthing`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_cleanup.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add README.md tests/test_cleanup.sh
git commit -m "refactor: remove legacy k8s, scripts, and update docs for bluefin p2p quadlet"
```
