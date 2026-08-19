#!/bin/zsh

# Toggle Recording Script for Alfred Workflow
# Dependency: sox (rec binary)

set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Default directory fallbacks if run outside Alfred
CACHE_DIR="${alfred_workflow_cache:-$HOME/Library/Caches/com.runningwithcrayons.Alfred/Workflow Data/transcribe}"
DATA_DIR="${alfred_workflow_data:-$HOME/Library/Application Support/Alfred/Workflow Data/transcribe}"

PID_FILE="$CACHE_DIR/record.pid"
CURRENT_FILE="$CACHE_DIR/current_recording.txt"
LOG_FILE="$CACHE_DIR/rec.log"

mkdir -p "$CACHE_DIR"
mkdir -p "$DATA_DIR/recordings"

if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        # Recording is running - send SIGINT to stop gracefully
        kill -2 "$PID"
        
        # Wait until process exits
        while kill -0 "$PID" 2>/dev/null; do
            sleep 0.05
        done
        
        rm -f "$PID_FILE"
        
        if [[ -f "$CURRENT_FILE" ]]; then
            AUDIO_PATH=$(cat "$CURRENT_FILE" | tr -d '\r\n')
            rm -f "$CURRENT_FILE"
            printf "%s" "$AUDIO_PATH"
        fi
        exit 0
    else
        # Stale PID file cleanup
        rm -f "$PID_FILE"
    fi
fi

# Start recording
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
AUDIO_PATH="$DATA_DIR/recordings/${TIMESTAMP}.wav"

printf "%s" "$AUDIO_PATH" > "$CURRENT_FILE"

nohup rec -r 16000 -c 1 -b 16 "$AUDIO_PATH" >"$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

# Output empty string when starting recording
exit 0
