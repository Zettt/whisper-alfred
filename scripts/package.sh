#!/bin/zsh

# Package Whisper Alfred workflow into Whisper Alfred.alfredworkflow at repository root
# Syncs VERSION and README.md into workflow/info.plist, validates plist/keys, and bundles workflow/ contents.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h}"
WORKFLOW_DIR="$ROOT_DIR/workflow"
VERSION_FILE="$ROOT_DIR/VERSION"
README_PATH="$ROOT_DIR/README.md"
PLIST_PATH="$WORKFLOW_DIR/info.plist"
ICON_PATH="$WORKFLOW_DIR/icon.png"
OUTPUT_WORKFLOW="$ROOT_DIR/Whisper Alfred.alfredworkflow"

if [[ -n "${1:-}" && "${1:-}" != --* ]]; then
	printf '%s\n' "$1" > "$VERSION_FILE"
fi

if [[ ! -f "$VERSION_FILE" ]]; then
	echo "Error: Missing $VERSION_FILE" >&2
	exit 1
fi

VERSION=$(tr -d '[:space:]' < "$VERSION_FILE")
if [[ -z "$VERSION" ]]; then
	echo "Error: Empty version in $VERSION_FILE" >&2
	exit 1
fi

if [[ ! -f "$README_PATH" ]]; then
	echo "Error: Missing $README_PATH" >&2
	exit 1
fi

if [[ ! -f "$PLIST_PATH" ]]; then
	echo "Error: Missing $PLIST_PATH" >&2
	exit 1
fi

if [[ ! -f "$ICON_PATH" ]]; then
	echo "Error: Missing $ICON_PATH" >&2
	exit 1
fi

python3 - "$PLIST_PATH" "$VERSION" "$README_PATH" <<'PY'
import pathlib, plistlib, sys

plist_path = pathlib.Path(sys.argv[1])
version = sys.argv[2]
readme_path = pathlib.Path(sys.argv[3])

with plist_path.open("rb") as f:
    plist = plistlib.load(f)

cfg = {item["variable"]: item for item in plist.get("userconfigurationconfig", [])}
dont_export = set(plist.get("variablesdontexport", []))

for key in ("MISTRAL_API_KEY", "GROQ_API_KEY"):
    default_val = cfg.get(key, {}).get("config", {}).get("default", "")
    if default_val != "":
        print(f"Error: {key} has a non-empty default in info.plist", file=sys.stderr)
        sys.exit(1)
    if key not in dont_export:
        print(f"Error: {key} is missing from variablesdontexport", file=sys.stderr)
        sys.exit(1)

plist["version"] = version
plist["readme"] = readme_path.read_text(encoding="utf-8")

with plist_path.open("wb") as f:
    plistlib.dump(plist, f, sort_keys=True)
PY

plutil -convert xml1 "$PLIST_PATH"
plutil -lint "$PLIST_PATH" >/dev/null

if grep -Eq "gsk_|uZ2C" "$PLIST_PATH"; then
	echo "Error: Detected potential API key prefix in info.plist" >&2
	exit 1
fi

if [[ -d "$WORKFLOW_DIR/history.alfredui/resources" ]]; then
	printf '[]\n' > "$WORKFLOW_DIR/history.alfredui/resources/history_data.json"
fi

chmod +x "$WORKFLOW_DIR/scripts/"*.sh(N) "$WORKFLOW_DIR/"*.alfredui/scripts/*.sh(N)

rm -f "$OUTPUT_WORKFLOW"
(cd "$WORKFLOW_DIR" && zip -q -r "$OUTPUT_WORKFLOW" info.plist icon.png scripts history.alfredui hud.alfredui -x "*.DS_Store")

echo "Packaged: $OUTPUT_WORKFLOW (v${VERSION})"
