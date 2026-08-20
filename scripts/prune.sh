#!/bin/zsh

# Audio & Metadata Sidecar Retention Pruner for Alfred Workflow
# Deletes old audio recordings (.wav) and metadata sidecars (.json) based on RETENTION_DAYS variable
# Supports optional keyword arguments ($1):
#   (empty)    -> Prunes files older than RETENTION_DAYS (default: 7)
#   0 / force  -> Force deletes ALL recordings & sidecars immediately
#   N (number) -> Prunes files older than N days

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

DATA_DIR="${alfred_workflow_data:-$HOME/Library/Application Support/Alfred/Workflow Data/transcribe}"
RECORDINGS_DIR="$DATA_DIR/recordings"

if [[ ! -d "$RECORDINGS_DIR" ]]; then
	exit 0
fi

ARG=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d '\r\n' | xargs)

if [[ "$ARG" == "force" || "$ARG" == "all" || "$ARG" == "0" ]]; then
	find "$RECORDINGS_DIR" -type f \( -name "*.wav" -o -name "*.json" \) -delete 2>/dev/null || true
	printf "Purged all audio recordings and JSON sidecars."
else
	if [[ "$ARG" =~ ^[0-9]+$ ]]; then
		DAYS="$ARG"
	else
		DAYS="${RETENTION_DAYS:-7}"
	fi

	find "$RECORDINGS_DIR" -type f \( -name "*.wav" -o -name "*.json" \) -mtime +${DAYS} -delete 2>/dev/null || true
	printf "Pruned recordings older than %s days." "$DAYS"
fi
