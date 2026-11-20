#!/bin/zsh

# Action handler for history.alfredui (play audio, delete entry, refresh list)

set -e

SCRIPT_DIR="${0:A:h}"
UI_DIR="${SCRIPT_DIR:h}"
ROOT_DIR="${UI_DIR:h}"

CACHE_DIR="${alfred_workflow_cache:-$HOME/Library/Caches/com.runningwithcrayons.Alfred/Workflow Data/com.zettt.whisper-alfred}"
DATA_DIR="${alfred_workflow_data:-$HOME/Library/Application Support/Alfred/Workflow Data/com.zettt.whisper-alfred}"
HIST_DATA_FILE="${HISTORY_DATA_FILE:-$UI_DIR/resources/history_data.json}"
AFPLAY_PID_FILE="$CACHE_DIR/afplay.pid"

mkdir -p "$CACHE_DIR"

ACTION="${1:-}"
TARGET="${2:-}"

emit_list_update() {
	python3 - "$HIST_DATA_FILE" <<'PY'
import json, os, sys

data_file = sys.argv[1]
entries = []
if os.path.isfile(data_file):
    with open(data_file, "r", encoding="utf-8") as f:
        entries = json.load(f)

first = entries[0] if entries else {}
payload = {
    "update": {
        "ids": {
            "historyList": {
                "data": {
                    "type": "basic",
                    "src": entries,
                }
            },
            "polishedArea": {"text": first.get("cellPolished.text", "")},
            "rawArea": {"text": first.get("cellRaw.text", "")},
            "metaLabel": {"text": first.get("cellMeta.text", "No recordings found")},
        }
    }
}
print(json.dumps(payload, ensure_ascii=False))
PY
}

case "$ACTION" in
play)
	if [[ -f "$AFPLAY_PID_FILE" ]]; then
		OLD_PID=$(cat "$AFPLAY_PID_FILE" 2>/dev/null || true)
		if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
			kill "$OLD_PID" 2>/dev/null || true
		fi
		rm -f "$AFPLAY_PID_FILE"
	fi
	if [[ -n "$TARGET" && -f "$TARGET" ]]; then
		nohup afplay "$TARGET" >/dev/null 2>&1 </dev/null &
		disown $! 2>/dev/null || true
		echo $! > "$AFPLAY_PID_FILE"
	fi
	printf "{}"
	;;

delete)
	if [[ -n "$TARGET" && -f "$TARGET" ]]; then
		AUDIO_FROM_JSON=$(python3 -c '
import json, sys
try:
    with open(sys.argv[1], "r", encoding="utf-8") as f:
        print(json.load(f).get("audio_file") or "")
except Exception:
    pass
' "$TARGET" 2>/dev/null || true)
		if [[ -n "$AUDIO_FROM_JSON" && -f "$AUDIO_FROM_JSON" ]]; then
			rm -f "$AUDIO_FROM_JSON"
		fi
		for ext in m4a wav mp4 aac; do
			rm -f "${TARGET%.*}.${ext}" 2>/dev/null || true
		done
		rm -f "$TARGET"
	fi
	HISTORY_DATA_FILE="$HIST_DATA_FILE" "$ROOT_DIR/scripts/history_prepare.sh"
	emit_list_update
	;;

refresh)
	HISTORY_DATA_FILE="$HIST_DATA_FILE" "$ROOT_DIR/scripts/history_prepare.sh"
	emit_list_update
	;;

*)
	printf "{}"
	;;
esac
