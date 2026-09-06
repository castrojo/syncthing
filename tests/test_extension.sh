#!/usr/bin/env bash
set -euo pipefail

EXT_DIR="system_files/usr/share/gnome-shell/extensions/syncthing-toggle@rehhouari.github.com"

if [[ ! -d "$EXT_DIR" ]]; then
  echo "FAIL: $EXT_DIR does not exist"
  exit 1
fi

if [[ ! -f "$EXT_DIR/metadata.json" ]]; then
  echo "FAIL: $EXT_DIR/metadata.json missing"
  exit 1
fi

grep -q "syncthing-toggle@rehhouari.github.com" "$EXT_DIR/metadata.json" || {
  echo "FAIL: Unexpected extension UUID"
  exit 1
}

echo "PASS: GNOME extension package verified."
