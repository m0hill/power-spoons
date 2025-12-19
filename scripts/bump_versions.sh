#!/usr/bin/env bash
set -euo pipefail

MODE="--staged"
for arg in "$@"; do
	case "$arg" in
		--staged|--all)
			MODE="$arg"
			;;
		*)
			echo "Usage: $0 [--staged|--all]"
			exit 1
			;;
	esac
done

if ! command -v git >/dev/null 2>&1; then
	echo "git not found"
	exit 1
fi

if [ "$MODE" = "--staged" ]; then
	FILES=$(git diff --name-only --cached)
else
	FILES=$(git diff --name-only)
fi

if [ -z "$FILES" ]; then
	exit 0
fi

python3 - <<PY
import json
import re
from datetime import datetime, timezone
from pathlib import Path

files = """${FILES}""".splitlines()
changed = set()
for path in files:
    parts = path.split("/")
    if len(parts) >= 2 and parts[0] == "packages":
        changed.add(parts[1])

root = Path(".")
manifest_path = root / "manifest.json"
manifest = json.loads(manifest_path.read_text())
if not changed:
    raise SystemExit(0)

version = datetime.now(timezone.utc).strftime("%Y.%m.%d.%H%M")

updated_any = False
for pkg in manifest.get("packages", []):
    if pkg.get("id") in changed:
        pkg["version"] = version
        updated_any = True

if updated_any:
    manifest["version"] = version

manifest_path.write_text(json.dumps(manifest, indent=2) + "\\n")

if "manager" in changed:
    manager_path = root / "packages" / "manager" / "init.lua"
    text = manager_path.read_text()
    new_version = version
    text_new, count = re.subn(
        r'local MANAGER_VERSION = "([^"]+)"',
        f'local MANAGER_VERSION = "{new_version}"',
        text,
        count=1,
    )
    if count == 0:
        raise SystemExit("MANAGER_VERSION string not found")
    manager_path.write_text(text_new)
PY

echo "Bumped versions for: $FILES"
