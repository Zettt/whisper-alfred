#!/bin/zsh

# Audio Retention Pruner for Alfred Workflow
# Purges recorded WAV files older than RETENTION_DAYS

DATA_DIR="${alfred_workflow_data:-$HOME/Library/Application Support/Alfred/Workflow Data/transcribe}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

if [[ -d "$DATA_DIR/recordings" && "$RETENTION_DAYS" -gt 0 ]]; then
    find "$DATA_DIR/recordings" -name "*.wav" -type f -mtime +"$RETENTION_DAYS" -delete 2>/dev/null || true
fi
