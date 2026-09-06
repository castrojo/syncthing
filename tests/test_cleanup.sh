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
