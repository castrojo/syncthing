# Syncthing Cloud-Native Multi-Device Sync

A zero-touch, automated Syncthing deployment across computers using:
1. **Cluster Introducer Hub** (Kubernetes / k3s) as the 24/7 permanent anchor.
2. **Podman Quadlets** on Linux / Bluefin desktops with rootless `keep-id` (UID 1000) and specific folder mounts.
3. **Automated Container Updates** via `AutoUpdate=registry` and `podman-auto-update.timer`.
4. **Modern GNOME Quick Settings Toggle** (`syncthing-toggle`) matching macOS Control Center slickness (no legacy systray).

---

## Architecture Overview

```
                        ┌──────────────────────────────────────────────┐
                        │      Kubernetes / k3s Cluster Hub            │
                        │      - Syncthing Introducer (24/7)           │
                        │      - Auto-Accepts shared folders           │
                        │      - Connects all client nodes             │
                        └──────────────────────┬───────────────────────┘
                                               │ (Introducer link)
                     ┌─────────────────────────┴────────────────────────┐
                     ▼                                                  ▼
      ┌──────────────────────────────┐                   ┌──────────────────────────────┐
      │     Workstation / Laptop     │                   │       Secondary Laptop       │
      │  - Rootless Podman Quadlet   │                   │  - Rootless Podman Quadlet   │
      │  - Mounts ~/Documents, ~/src │◄─────────────────►│  - Mounts ~/Documents, ~/src │
      │  - GNOME Quick Settings Pill │   (Direct peer    │  - GNOME Quick Settings Pill │
      │  - Daily Auto-Update Timer   │     transfer)     │  - Daily Auto-Update Timer   │
      └──────────────────────────────┘                   └──────────────────────────────┘
```

---

## 1. Deploy Cluster Introducer (k8s / k3s)

Run on your cluster:
```bash
kubectl apply -k k8s/
```

Retrieve the Cluster Introducer's Device ID:
```bash
kubectl exec -n syncthing syncthing-introducer-0 -- syncthing cli show system | jq -r .myID
```

*(Note: In the Cluster Web GUI, ensure your designated shared folders have **Auto-Accept** enabled).*

---

## 2. Onboard a Desktop / Laptop (Bluefin / Linux)

Run the single-command onboarding script on each computer:

```bash
./onboard-client.sh --cluster-id "<CLUSTER_DEVICE_ID>" --folders "Documents,src"
```

### What this does automatically:
1. Generates `~/.config/containers/systemd/syncthing.container` with:
   - Rootless UID mapping (`UserNS=keep-id`).
   - Specific folder volume mounts (`~/Documents`, `~/src`).
   - Automated registry updates (`AutoUpdate=registry`).
   - Host networking for high-speed LAN & Tailscale mesh transfer.
2. Enables and starts the user systemd service: `systemctl --user enable --now syncthing.service`.
3. Activates background container auto-updates via `systemctl --user enable --now podman-auto-update.timer`.
4. Pairs the computer with the Cluster Introducer via Syncthing REST API / CLI (`introducer=true`).
5. Installs and activates the modern **GNOME Quick Settings Toggle** (`syncthing-toggle`).
6. Displays the local Device ID to approve once on the cluster.

---

## 3. Modern GNOME Quick Settings Toggle

No legacy systray. The extension adds a native toggle pill inside GNOME's Quick Settings menu (top right):
- **Click pill**: Starts/stops `syncthing.service`.
- **Click arrow**: Displays status and one-click **Open Web GUI** (`http://127.0.0.1:8384`).

To manually install or re-configure:
```bash
./extension/install-syncthing-toggle.sh
```

---

## 4. Automated Container Updates

- **Desktops**: Configured with `AutoUpdate=registry`. The systemd user timer `podman-auto-update.timer` runs daily, checks registry image digests, pulls updates, and restarts the container safely.
- **Cluster**: StatefulSet configured with `imagePullPolicy: Always` and Keel/Watchtower annotations for automated rolling image updates.

---

## Directory Structure

```
syncthing/
├── k8s/                         # Kubernetes Introducer manifests
│   ├── namespace.yaml
│   ├── pvc.yaml
│   ├── service.yaml
│   ├── statefulset.yaml
│   └── kustomization.yaml
├── quadlet/                     # Quadlet client assets
│   ├── syncthing.container.template
│   └── enable-auto-update.sh
├── extension/                   # GNOME Quick Settings extension helper
│   └── install-syncthing-toggle.sh
├── onboard-client.sh            # Main client onboarding CLI
└── README.md
```
