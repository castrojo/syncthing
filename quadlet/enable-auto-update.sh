#!/usr/bin/env bash
set -euo pipefail

echo "==> Enabling rootless podman-auto-update timer for background container updates..."
systemctl --user daemon-reload
systemctl --user enable --now podman-auto-update.timer

echo "==> Current podman timer status:"
systemctl --user list-timers podman-auto-update.timer
