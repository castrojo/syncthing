#!/usr/bin/env bash
set -euo pipefail

QUADLET_FILE="system_files/etc/containers/systemd/users/syncthing.container"

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
grep -q "WantedBy=default.target" "$QUADLET_FILE" || { echo "FAIL: Missing WantedBy=default.target"; exit 1; }

echo "PASS: Quadlet unit validated successfully."
