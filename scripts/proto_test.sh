#!/bin/zsh

# Minimal Isolated Alfred Prototype Test Script using Native AVFoundation Recorder

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

TEST_WAV="/tmp/alfred_proto_test.wav"
PID_FILE="/tmp/alfred_proto.pid"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REC_BIN="$SCRIPT_DIR/rec_native"

if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    kill -2 "$PID" 2>/dev/null || true
    while kill -0 "$PID" 2>/dev/null; do sleep 0.05; done
    rm -f "$PID_FILE"
    
    SIZE=$(wc -c < "$TEST_WAV" 2>/dev/null | tr -d ' ')

    if [[ -z "$MISTRAL_API_KEY" ]]; then
        echo "Error: MISTRAL_API_KEY environment variable is missing in Alfred configuration."
        exit 1
    fi

    # Transcribe via Mistral AI
    RESPONSE=$(curl -s --location 'https://api.mistral.ai/v1/audio/transcriptions' \
      --header "Authorization: Bearer $MISTRAL_API_KEY" \
      --form "file=@$TEST_WAV" \
      --form 'model="voxtral-mini-latest"')

    TEXT=$(osascript -l JavaScript -e "
        try {
            var resp = $RESPONSE;
            if (resp.error) {
                'API Error: ' + JSON.stringify(resp.error);
            } else if (resp.text && resp.text.length > 0) {
                resp.text.trim();
            } else {
                'Raw Response: ' + JSON.stringify(resp);
            }
        } catch(e) {
            'Parsing Exception: ' + e.toString();
        }
    ")

    echo "$TEXT"
else
    rm -f "$TEST_WAV"
    nohup "$REC_BIN" "$TEST_WAV" >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
    echo "STARTED: Native AVFoundation recording..."
fi
