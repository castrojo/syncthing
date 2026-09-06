# Syncthing for Project Bluefin

A declarative, rootless, zero-maintenance Syncthing deployment designed specifically for [Project Bluefin](https://projectbluefin.io/) and Fedora Atomic desktops.

## Architecture

Syncthing runs as a declarative rootless user service via Podman Quadlet with pure peer-to-peer (P2P) synchronization:

```
  ┌──────────────────────────────┐                   ┌──────────────────────────────┐
  │      Bluefin Desktop A       │                   │      Bluefin Desktop B       │
  │  - Rootless Podman Quadlet   │                   │  - Rootless Podman Quadlet   │
  │  - Mounts ~/Sync & state     │◄─────────────────►│  - Mounts ~/Sync & state     │
  │  - Desktop App Launcher      │   (Direct P2P:    │  - Desktop App Launcher      │
  │  - podman-auto-update.timer  │   LAN / Tailscale)│  - podman-auto-update.timer  │
  └──────────────────────────────┘                   └──────────────────────────────┘
```

- **Pure Peer-to-Peer:** Devices discover and sync directly with each other over local network broadcast (UDP 21027), global discovery, and Tailscale mesh networks. No centralized servers or cluster hubs required.
- **Rootless & Secure:** Runs strictly in user session namespace (`UserNS=keep-id`, `User=%U`, `Group=%G`) with all Linux capabilities dropped (`DropCapability=ALL`) and `NoNewPrivileges=true`.
- **Hardened Web GUI:** The management Web GUI is bound strictly to loopback (`127.0.0.1:8384`), preventing exposure across the network.
- **Automated Container Updates:** Tracks `ghcr.io/syncthing/syncthing:2` from GitHub Container Registry with `AutoUpdate=registry`, automatically updated via Podman's `podman-auto-update.timer`.

---

## Shipped System Files

This repository packages declarative system files directly into the Bluefin OS image:

- `system_files/usr/share/containers/systemd/users/syncthing.container`
  Installed system-wide to `/usr/share/containers/systemd/users/syncthing.container`. Quadlet automatically generates a user-level systemd service (`syncthing.service`) for every user.
- `system_files/usr/share/applications/syncthing.desktop`
  Installed system-wide to `/usr/share/applications/syncthing.desktop`. Integrates Syncthing into desktop application menus with quick actions to start/stop the service and launch the Web GUI.

---

## Usage

### Managing the Service

Users can manage Syncthing either via the desktop application menu or via `systemctl`:

- **Start Syncthing:**
  - Desktop: Right-click the **Syncthing** application icon and choose **Start Syncthing**, or
  - CLI:
    ```bash
    systemctl --user start syncthing
    ```
- **Stop Syncthing:**
  - Desktop: Right-click the **Syncthing** application icon and choose **Stop Syncthing**, or
  - CLI:
    ```bash
    systemctl --user stop syncthing
    ```
- **Enable on Login (Optional):**
  To automatically start Syncthing when logging into your desktop session:
  ```bash
  systemctl --user enable syncthing
  ```

### Accessing the Web GUI

Click the **Syncthing** application launcher or navigate in any browser to:
[http://127.0.0.1:8384/](http://127.0.0.1:8384/)

---

## Storage & Paths

The container isolates configuration/state from user sync data:

| Purpose | Host Path | Container Path |
|---|---|---|
| Configuration & Database | `%S/syncthing` (`~/.local/state/syncthing`) | `/var/syncthing` |
| Sync Folder | `%h/Sync` (`~/Sync`) | `/var/syncthing/Sync` |

SELinux relabeling (`:Z`) is automatically applied to both mounts to ensure access in SELinux-enforcing environments.

---

## Automated Updates

Updates are handled natively by Podman without external daemons:

1. The Quadlet unit specifies `AutoUpdate=registry` against `ghcr.io/syncthing/syncthing:2`.
2. Enable the standard user auto-update timer if not already active:
   ```bash
   systemctl --user enable --now podman-auto-update.timer
   ```
3. When new container image tags are published to `ghcr.io/syncthing/syncthing:2`, `podman auto-update` pulls the latest layer and restarts `syncthing.service` automatically.

---

## Verification & Testing

Validation test suites are provided under `tests/`:

- `tests/test_quadlet_syntax.sh`: Validates Quadlet configuration directives and security constraints.
- `tests/test_desktop_entry.sh`: Validates desktop launcher actions and URL definitions.
- `tests/test_cleanup.sh`: Validates removal of obsolete manifests and scripts.

Run all tests:
```bash
bash tests/test_quadlet_syntax.sh
bash tests/test_desktop_entry.sh
bash tests/test_cleanup.sh
```
