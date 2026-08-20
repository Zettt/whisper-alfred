#!/bin/zsh

# Audio & Metadata Sidecar Retention Pruner for Alfred Workflow
# Supports arguments ($1):
#   (empty) / prune -> Purges ALL recordings & sidecars immediately
#   recordings / wav -> Deletes only .wav audio files, keeping JSON sidecars
#   archive          -> Moves recordings & sidecars to $DATA_DIR/archive/
#   auto / retention -> Background retention check (deletes files older than RETENTION_DAYS)
#   N (number)       -> Prunes files older than N days

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
	"recordings" | "wav" | "audio")
		find "$RECORDINGS_DIR" -type f -name "*.wav" -delete 2>/dev/null || true
		printf "Deleted all audio (.wav) files. JSON sidecars preserved."
		;;
	"archive")
		mkdir -p "$ARCHIVE_DIR"
		find "$RECORDINGS_DIR" -type f \( -name "*.wav" -o -name "*.json" \) -exec mv {} "$ARCHIVE_DIR/" \; 2>/dev/null || true
		printf "Archived all recordings to %s" "$ARCHIVE_DIR"
		;;
	"auto" | "retention")
		DAYS="${RETENTION_DAYS:-7}"
		find "$RECORDINGS_DIR" -type f \( -name "*.wav" -o -name "*.json" \) -mtime +${DAYS} -delete 2>/dev/null || true
		printf "Pruned recordings older than %s days." "$DAYS"
		;;
	*)
		if [[ "$ARG" =~ ^[0-9]+$ ]]; then
			find "$RECORDINGS_DIR" -type f \( -name "*.wav" -o -name "*.json" \) -mtime +${ARG} -delete 2>/dev/null || true
			printf "Pruned recordings older than %s days." "$ARG"
		else
			find "$RECORDINGS_DIR" -type f \( -name "*.wav" -o -name "*.json" \) -delete 2>/dev/null || true
			printf "Purged all audio recordings and JSON sidecars."
		fi
		;;
esac
