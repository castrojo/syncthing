#!/usr/bin/env bash
# ==============================================================================
# onboard-client.sh — Zero-Touch Syncthing Quadlet Onboarding for Desktops
# ==============================================================================
# Deploys rootless Podman Quadlet, maps specific sync folders, connects to
# the central Cluster Introducer with auto-accept, activates automated updates,
# and installs the modern GNOME Quick Settings toggle.
# ==============================================================================
set -euo pipefail

CLUSTER_ID=""
CLUSTER_ADDR="dynamic"
FOLDERS="Documents,src"
SKIP_GUI=false
DRY_RUN=false

usage() {
  cat <<EOF
Usage: $(basename "$0") --cluster-id <DEVICE_ID> [options]

Required:
  -c, --cluster-id <ID>       Device ID of the central Cluster Introducer

Options:
  -f, --folders <list>        Comma-separated list of folders under \$HOME to sync
                              (default: "Documents,src")
  -a, --cluster-addr <addr>   Address for cluster (default: "dynamic", or "tcp://ip:22000")
  --skip-gui                  Do not install the GNOME Quick Settings extension
  --dry-run                   Print actions without modifying files or systemd
  -h, --help                  Show this help message
EOF
  exit 1
}

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--cluster-id)
      CLUSTER_ID="$2"
      shift 2
      ;;
    -f|--folders)
      FOLDERS="$2"
      shift 2
      ;;
    -a|--cluster-addr)
      CLUSTER_ADDR="$2"
      shift 2
      ;;
    --skip-gui)
      SKIP_GUI=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

if [ -z "$CLUSTER_ID" ]; then
  echo "Error: --cluster-id is required." >&2
  usage
fi

echo "=========================================================="
echo " Syncthing Client Onboarding (Podman Quadlet + Cluster Hub)"
echo "=========================================================="
echo "Cluster Introducer ID : ${CLUSTER_ID}"
echo "Cluster Address       : ${CLUSTER_ADDR}"
echo "Designated Folders    : ${FOLDERS}"
echo "=========================================================="

QUADLET_DIR="${HOME}/.config/containers/systemd"
CONFIG_DIR="${HOME}/.local/share/syncthing-quadlet/config"
QUADLET_FILE="${QUADLET_DIR}/syncthing.container"

# Build volume lines
IFS=',' read -ra FOLDER_ARRAY <<< "$FOLDERS"
VOLUME_LINES=""
for rel_path in "${FOLDER_ARRAY[@]}"; do
  # Trim leading/trailing whitespace
  rel_path="$(echo "$rel_path" | xargs)"
  [ -z "$rel_path" ] && continue

  abs_path="${HOME}/${rel_path}"
  if [ "$DRY_RUN" = false ]; then
    mkdir -p "$abs_path"
  fi
  # Mount host directory into container at /var/syncthing/<rel_path>
  # Quadlet expands %h to user home directory
  VOLUME_LINES="${VOLUME_LINES}Volume=%h/${rel_path}:/var/syncthing/${rel_path}:Z"$'\n'
done

# Render Quadlet file
QUADLET_CONTENT="[Unit]
Description=Syncthing Continuous File Synchronization (Rootless)
Documentation=man:syncthing(1) https://docs.syncthing.net/
After=network-online.target
Wants=network-online.target

[Container]
Image=docker.io/syncthing/syncthing:latest
AutoUpdate=registry
ContainerName=syncthing
UserNS=keep-id
Environment=STNORESTART=1
Environment=STNOUPGRADE=1

# Configuration & TLS identity persistence
Volume=%h/.local/share/syncthing-quadlet/config:/var/syncthing/config:Z

# Designated specific sync folders
${VOLUME_LINES}
# Host networking for maximum performance, LAN broadcast, and Tailscale support
Network=host

[Service]
Restart=on-failure
RestartSec=10
TimeoutStartSec=300

[Install]
WantedBy=default.target
"

if [ "$DRY_RUN" = true ]; then
  echo "[DRY-RUN] Would write to ${QUADLET_FILE}:"
  echo "$QUADLET_CONTENT"
  exit 0
fi

# Write Quadlet
mkdir -p "$QUADLET_DIR"
mkdir -p "$CONFIG_DIR"
echo "$QUADLET_CONTENT" > "$QUADLET_FILE"
echo "==> Created Quadlet unit at ${QUADLET_FILE}"

# Reload systemd generator and start container
echo "==> Reloading systemd user daemon and starting syncthing..."
systemctl --user daemon-reload
systemctl --user enable --now syncthing.service

# Enable automated container updates
echo "==> Enabling podman-auto-update timer for background updates..."
systemctl --user enable --now podman-auto-update.timer

# Wait for Syncthing to initialize config.xml (up to 15s)
echo "==> Waiting for Syncthing to generate local configuration..."
CONFIG_XML="${CONFIG_DIR}/config.xml"
COUNT=0
while [ ! -f "$CONFIG_XML" ] && [ $COUNT -lt 15 ]; do
  sleep 1
  COUNT=$((COUNT + 1))
done

if [ -f "$CONFIG_XML" ]; then
  echo "==> Found ${CONFIG_XML}."
  # Retrieve local API key
  API_KEY=$(grep -oPm1 "(?<=<apikey>)[^<]+" "$CONFIG_XML" || true)

  # Check if cluster device is already present
  if ! grep -q "$CLUSTER_ID" "$CONFIG_XML"; then
    echo "==> Pairing with Cluster Introducer (${CLUSTER_ID})..."
    
    # Try configuring via REST API if curl & API key are available
    PAIRED=false
    if [ -n "$API_KEY" ]; then
      DEVICE_PAYLOAD=$(cat <<JSON
{
  "deviceID": "${CLUSTER_ID}",
  "name": "cluster-introducer",
  "addresses": ["${CLUSTER_ADDR}"],
  "introducer": true,
  "autoAcceptFolders": true,
  "paused": false
}
JSON
)
      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
        -H "X-API-Key: ${API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$DEVICE_PAYLOAD" \
        "http://127.0.0.1:8384/rest/config/devices/${CLUSTER_ID}" || echo "000")

      if [ "$HTTP_CODE" = "200" ]; then
        echo "==> Successfully added Cluster Introducer via REST API."
        PAIRED=true
      fi
    fi

    # Fallback to podman exec syncthing cli if API PUT was not completed
    if [ "$PAIRED" = false ]; then
      echo "==> Configuring Introducer via container CLI..."
      podman exec syncthing syncthing cli config devices add \
        --device-id "${CLUSTER_ID}" \
        --name "cluster-introducer" \
        --introducer || true
    fi
  else
    echo "==> Cluster Introducer is already configured in config.xml."
  fi

  # Display local device ID for cluster approval
  LOCAL_DEVICE_ID=$(podman exec syncthing syncthing cli show system 2>/dev/null | grep -oPm1 '(?<="myID": ")[^"]+' || true)
  if [ -z "$LOCAL_DEVICE_ID" ]; then
    LOCAL_DEVICE_ID=$(grep -oPm1 "(?<=<device id=\")[^\"]+" "$CONFIG_XML" | head -n1 || echo "unknown")
  fi

  echo ""
  echo "----------------------------------------------------------"
  echo " This Computer's Device ID:"
  echo "   ${LOCAL_DEVICE_ID}"
  echo ""
  echo " Add or accept this Device ID on your Cluster Introducer."
  echo " Because the Cluster is set as Introducer, all shared"
  echo " folders and peer links will sync automatically!"
  echo "----------------------------------------------------------"
fi

# Optional GUI extension setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$SKIP_GUI" = false ] && command -v gnome-shell >/dev/null 2>&1; then
  echo ""
  echo "==> Setting up GNOME Quick Settings toggle extension..."
  if [ -f "${SCRIPT_DIR}/extension/install-syncthing-toggle.sh" ]; then
    "${SCRIPT_DIR}/extension/install-syncthing-toggle.sh" || echo "Note: Extension setup completed with notice."
  fi
fi

echo ""
echo "==> Onboarding complete!"
echo "    - Status   : systemctl --user status syncthing.service"
echo "    - Console  : xdg-open http://127.0.0.1:8384"
echo "    - Updates  : Auto-managed daily via podman-auto-update.timer"
