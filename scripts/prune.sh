#!/bin/zsh

# Audio & Metadata Sidecar Retention Pruner for Alfred Workflow
# Supports arguments ($1):
#   (empty) / auto / text -> Retention check (deletes files older than RETENTION_DAYS, default: 7)
#   force / all / purge / 0 -> Purges ALL recordings & sidecars immediately
#   recordings / wav / m4a  -> Deletes only audio files, keeping JSON sidecars
#   archive                 -> Moves recordings & sidecars to $DATA_DIR/archive/
#   N (number)              -> Prunes files older than N days

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

DATA_DIR="${alfred_workflow_data:-$HOME/Library/Application Support/Alfred/Workflow Data/transcribe}"
RECORDINGS_DIR="$DATA_DIR/recordings"
ARCHIVE_DIR="$DATA_DIR/archive"

if [[ ! -d "$RECORDINGS_DIR" ]]; then
	exit 0
fi

RAW_ARG=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d '\r\n' | xargs)
ARG="${RAW_ARG#prune}"
ARG=$(echo "$ARG" | xargs)

case "$ARG" in
	"force" | "all" | "purge" | "0")
		find "$RECORDINGS_DIR" -type f \( -name "*.m4a" -o -name "*.wav" -o -name "*.mp4" -o -name "*.aac" -o -name "*.json" \) -delete 2>/dev/null || true
		printf "Purged all audio recordings and JSON sidecars."
		;;
	"recordings" | "wav" | "m4a" | "audio")
		find "$RECORDINGS_DIR" -type f \( -name "*.m4a" -o -name "*.wav" -o -name "*.mp4" -o -name "*.aac" \) -delete 2>/dev/null || true
		printf "Deleted all audio files. JSON sidecars preserved."
		;;
	"archive")
		mkdir -p "$ARCHIVE_DIR"
		find "$RECORDINGS_DIR" -type f \( -name "*.m4a" -o -name "*.wav" -o -name "*.mp4" -o -name "*.aac" -o -name "*.json" \) -exec mv {} "$ARCHIVE_DIR/" \; 2>/dev/null || true
		printf "Archived all recordings to %s" "$ARCHIVE_DIR"
		;;
	*)
		if [[ "$ARG" =~ ^[0-9]+$ ]]; then
			DAYS="$ARG"
		else
			DAYS="${RETENTION_DAYS:-7}"
		fi
		find "$RECORDINGS_DIR" -type f \( -name "*.m4a" -o -name "*.wav" -o -name "*.mp4" -o -name "*.aac" -o -name "*.json" \) -mtime +${DAYS} -delete 2>/dev/null || true
		printf "Pruned recordings older than %s days." "$DAYS"
		;;
esac
