#!/bin/zsh

# Script Filter for whisper prune in Alfred 6
# Displays recording counts, disk usage, and actionable prune modes.

set -e

DATA_DIR="${alfred_workflow_data:-$HOME/Library/Application Support/Alfred/Workflow Data/com.zettt.whisper-alfred}"
RECORDINGS_DIR="$DATA_DIR/recordings"

AUDIO_COUNT=0
JSON_COUNT=0
TOTAL_SIZE="0B"

if [[ -d "$RECORDINGS_DIR" ]]; then
	audio_files=("$RECORDINGS_DIR"/*.(m4a|wav|mp4|aac)(N.))
	json_files=("$RECORDINGS_DIR"/*.json(N.))
	AUDIO_COUNT=${#audio_files[@]}
	JSON_COUNT=${#json_files[@]}
	TOTAL_SIZE=$(du -sh "$RECORDINGS_DIR" 2>/dev/null | awk '{print $1}')
	TOTAL_SIZE="${TOTAL_SIZE:-0B}"
fi

RETENTION="${RETENTION_DAYS:-7}"
QUERY=$(echo "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '\r\n' | xargs)

python3 - "$QUERY" "$AUDIO_COUNT" "$JSON_COUNT" "$TOTAL_SIZE" "$RETENTION" <<'PY'
import json, re, sys

query, audio_count, json_count, total_size, retention = sys.argv[1:6]
items = []

if re.fullmatch(r"[1-9][0-9]*", query):
    items.append({
        "uid": f"prune_days_{query}",
        "title": f"Prune Recordings Older Than {query} Days",
        "subtitle": f"Delete recordings and transcripts modified more than {query} days ago",
        "arg": query,
    })
    items.append({
        "uid": f"prune_keep_{query}",
        "title": f"Keep Latest {query} Recordings",
        "subtitle": f"Retain the {query} newest recordings and delete older entries",
        "arg": f"keep {query}",
    })

standard_items = [
    {
        "uid": "prune_auto",
        "title": f"Auto Retention Prune (> {retention} days)",
        "subtitle": f"Current storage: {audio_count} audio files, {json_count} transcripts ({total_size})",
        "arg": "auto",
    },
    {
        "uid": "prune_recordings",
        "title": "Delete Audio Files Only",
        "subtitle": f"Delete {audio_count} audio files and preserve {json_count} JSON transcripts",
        "arg": "recordings",
    },
    {
        "uid": "prune_keep_10",
        "title": "Keep Latest 10 Recordings",
        "subtitle": "Delete all recordings except the 10 most recent pairs",
        "arg": "keep 10",
    },
    {
        "uid": "prune_archive",
        "title": "Archive All Recordings",
        "subtitle": "Move all audio files and transcripts to archive folder",
        "arg": "archive",
    },
    {
        "uid": "prune_force",
        "title": "Purge All Recordings and Transcripts",
        "subtitle": f"Permanently delete all {audio_count} audio files and {json_count} transcripts",
        "arg": "force",
    },
]

if query and not re.fullmatch(r"[1-9][0-9]*", query):
    filtered = [
        item for item in standard_items
        if query in item["title"].lower() or query in item["subtitle"].lower() or query in item["arg"].lower()
    ]
    items.extend(filtered if filtered else standard_items)
else:
    items.extend(standard_items)

print(json.dumps({"items": items}))
PY
