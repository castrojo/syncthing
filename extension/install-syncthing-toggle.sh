#!/usr/bin/env bash
set -euo pipefail

UUID="syncthing-toggle@rehhouari.github.com"
EXT_DIR="${HOME}/.local/share/gnome-shell/extensions/${UUID}"
REPO_URL="https://github.com/rehhouari/gnome-shell-extension-syncthing-toggle.git"

echo "==> Setting up GNOME Quick Settings extension: ${UUID}..."
mkdir -p "${HOME}/.local/share/gnome-shell/extensions"

if [ -d "${EXT_DIR}" ]; then
  echo "Extension already present at ${EXT_DIR}, updating..."
  git -C "${EXT_DIR}" pull --ff-only || true
else
  echo "Cloning ${UUID}..."
  git clone --depth 1 "${REPO_URL}" "${EXT_DIR}"
fi

echo "==> Compiling schemas..."
if [ -d "${EXT_DIR}/schemas" ]; then
  glib-compile-schemas "${EXT_DIR}/schemas"
fi

echo "==> Configuring dconf preferences..."
# start-stop-only: true (don't disable unit when pausing)
# service-name: syncthing.service (bound to Quadlet user service)
# port: 8384
if command -v dconf >/dev/null 2>&1; then
  dconf write /org/gnome/shell/extensions/syncthing-toggle/service-name "'syncthing.service'"
  dconf write /org/gnome/shell/extensions/syncthing-toggle/start-stop-only true
  dconf write /org/gnome/shell/extensions/syncthing-toggle/port 8384
fi

echo "==> Enabling extension..."
if command -v gnome-extensions >/dev/null 2>&1; then
  gnome-extensions enable "${UUID}" || true
  echo "Extension enabled. (Note: On Wayland/GNOME, a logout/login or Alt+F2 'r' on X11 loads newly installed extensions into the shell session)."
fi

echo "==> Done. Quick Settings toggle ready."
