#!/bin/zsh

# Minimal Isolated Prototype for Audio Capture & Transcription

set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

ACTION="${1:-toggle}"

CACHE_DIR="/tmp/alfred_transcribe_proto"
PID_FILE="$CACHE_DIR/record.pid"
AUDIO_FILE="$CACHE_DIR/latest_recording.wav"
LOG_FILE="$CACHE_DIR/sox.log"

mkdir -p "$CACHE_DIR"

case "$ACTION" in
    start)
        if [[ -f "$PID_FILE" ]] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
            echo "Recording is already active."
            exit 0
        fi
        
        echo "Starting isolated prototype recording..."
        nohup sox -q -d -c 1 "$AUDIO_FILE" rate 16000 >"$LOG_FILE" 2>&1 &
        echo $! > "$PID_FILE"
        echo "Recording started (PID $(cat $PID_FILE)). Output: $AUDIO_FILE"
        ;;

    stop)
        if [[ ! -f "$PID_FILE" ]]; then
            echo "No active recording found."
            exit 1
        fi

        PID=$(cat "$PID_FILE")
        echo "Stopping recording (PID $PID)..."
        kill -2 "$PID" 2>/dev/null || true
        
        while kill -0 "$PID" 2>/dev/null; do
            sleep 0.05
        done
        rm -f "$PID_FILE"

        echo "Recording stopped."
        if [[ -f "$AUDIO_FILE" ]]; then
            SIZE=$(wc -c < "$AUDIO_FILE" | tr -d ' ')
            echo "Recorded File: $AUDIO_FILE ($SIZE bytes)"
            
            if [[ -z "$MISTRAL_API_KEY" ]]; then
                echo "Warning: MISTRAL_API_KEY is not set in environment."
                exit 0
            fi

            echo "Sending to Mistral AI API..."
            RESPONSE=$(curl -s --location 'https://api.mistral.ai/v1/audio/transcriptions' \
              --header "Authorization: Bearer $MISTRAL_API_KEY" \
              --form "file=@$AUDIO_FILE" \
              --form 'model="voxtral-mini-latest"')
              
            echo "API Response: $RESPONSE"
        fi
        ;;

    toggle)
        if [[ -f "$PID_FILE" ]] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
            $0 stop
        else
            $0 start
        fi
        ;;

    *)
        echo "Usage: $0 {start|stop|toggle}"
        exit 1
        ;;
esac
