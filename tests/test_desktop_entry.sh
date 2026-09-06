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
