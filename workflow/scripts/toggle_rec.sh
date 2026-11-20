#!/bin/zsh

# Toggle Recording Script for Alfred Workflow
# Dependency: ffmpeg CLI (Homebrew: brew install ffmpeg)

set -e

if [[ -z "${FFMPEG_BIN:-}" ]]; then
    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
fi
FFMPEG_CMD="${FFMPEG_BIN:-ffmpeg}"

# Default directory fallbacks if run outside Alfred
CACHE_DIR="${alfred_workflow_cache:-$HOME/Library/Caches/com.runningwithcrayons.Alfred/Workflow Data/com.zettt.whisper-alfred}"
DATA_DIR="${alfred_workflow_data:-$HOME/Library/Application Support/Alfred/Workflow Data/com.zettt.whisper-alfred}"

PID_FILE="$CACHE_DIR/record.pid"
CURRENT_FILE="$CACHE_DIR/current_recording.txt"
LOG_FILE="$CACHE_DIR/recording.log"
STATUS_FILE="$CACHE_DIR/status.txt"
START_FILE="$CACHE_DIR/record_start.txt"

mkdir -p "$CACHE_DIR"
mkdir -p "$DATA_DIR/recordings"

ACTION="${1:-}"
if [[ "${ACTION:l}" == "cancel" || "${ACTION:l}" == "abort" ]]; then
    if [[ -f "$PID_FILE" ]]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill -2 "$PID" 2>/dev/null || true
            wait_count=0
            while kill -0 "$PID" 2>/dev/null && (( wait_count < 20 )); do
                sleep 0.05
                wait_count=$((wait_count + 1))
            done
            if kill -0 "$PID" 2>/dev/null; then
                kill -9 "$PID" 2>/dev/null || true
            fi
        fi
        rm -f "$PID_FILE"
    fi
    if [[ -f "$CURRENT_FILE" ]]; then
        AUDIO_PATH=$(cat "$CURRENT_FILE" | tr -d '\r\n')
        if [[ -n "$AUDIO_PATH" && -f "$AUDIO_PATH" ]]; then
            rm -f "$AUDIO_PATH"
        fi
        rm -f "$CURRENT_FILE"
    fi
    rm -f "$STATUS_FILE" "$START_FILE"
    exit 0
fi

if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        # Recording is running - send SIGINT to stop gracefully
        kill -2 "$PID" 2>/dev/null || true
        
        # Wait until process exits
        while kill -0 "$PID" 2>/dev/null; do
            sleep 0.05
        done
        
        rm -f "$PID_FILE" "$START_FILE"
        echo "transcribing" > "$STATUS_FILE"
        
        if [[ -f "$CURRENT_FILE" ]]; then
            AUDIO_PATH=$(cat "$CURRENT_FILE" | tr -d '\r\n')
            rm -f "$CURRENT_FILE"
            printf "%s" "$AUDIO_PATH"
        fi
        exit 0
    else
        # Stale PID cleanup
        rm -f "$PID_FILE" "$START_FILE" "$STATUS_FILE"
    fi
fi

# Start recording with queue buffer to prevent AVFoundation drops
AUDIO_FORMAT="${AUDIO_FORMAT:-m4a}"
AUDIO_FORMAT="${AUDIO_FORMAT:l}"
MAX_DURATION="${MAX_RECORDING_DURATION:-600}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
AUDIO_PATH="$DATA_DIR/recordings/${TIMESTAMP}.${AUDIO_FORMAT}"

if [[ "$AUDIO_FORMAT" == "wav" ]]; then
    CODEC_ARGS=(-c:a pcm_s16le)
else
    CODEC_ARGS=(-c:a aac -b:a 64k)
fi

if [[ "$MAX_DURATION" =~ ^[1-9][0-9]*$ ]]; then
    DURATION_ARGS=(-t "$MAX_DURATION")
else
    DURATION_ARGS=()
fi

printf "%s" "$AUDIO_PATH" > "$CURRENT_FILE"
date +%s > "$START_FILE"
echo "recording" > "$STATUS_FILE"

# Detach stdin/stdout/stderr completely so Alfred subshell pipe closes instantly
nohup "$FFMPEG_CMD" -hide_banner -loglevel error -y "${DURATION_ARGS[@]}" -thread_queue_size 1024 -f avfoundation -i ":default" -ar 16000 -ac 1 "${CODEC_ARGS[@]}" "$AUDIO_PATH" >"$LOG_FILE" 2>&1 </dev/null &
disown $! 2>/dev/null || true
echo $! > "$PID_FILE"

# Output empty string when starting recording
exit 0
