#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

rm -f PowerSpoons.spoon.zip
ditto -c -k --sequesterRsrc --keepParent PowerSpoons.spoon PowerSpoons.spoon.zip

echo "Created PowerSpoons.spoon.zip"
