#!/bin/zsh

# Audio & Metadata Sidecar Retention Pruner for Alfred Workflow
# Deletes old audio recordings (.wav) and metadata sidecars (.json) based on RETENTION_DAYS variable

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

DATA_DIR="${alfred_workflow_data:-$HOME/Library/Application Support/Alfred/Workflow Data/transcribe}"
RECORDINGS_DIR="$DATA_DIR/recordings"

if [[ ! -d "$RECORDINGS_DIR" ]]; then
	exit 0
fi

DAYS="${RETENTION_DAYS:-7}"

# Delete WAV audio files and JSON sidecar files older than RETENTION_DAYS
find "$RECORDINGS_DIR" -type f \( -name "*.wav" -o -name "*.json" \) -mtime +${DAYS} -delete 2>/dev/null || true
