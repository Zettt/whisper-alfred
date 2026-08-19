#!/bin/zsh

# Synchronous Audio Recording Test via FFmpeg AVFoundation (-nostdin)

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

TEST_WAV="/tmp/direct_test.wav"
LOG_FILE="/tmp/ffmpeg_full.log"

rm -f "$TEST_WAV" "$LOG_FILE"

# Run ffmpeg with explicit input device "none:0"
ffmpeg -nostdin -y -f avfoundation -i "none:0" -ar 16000 -ac 1 -t 4 "$TEST_WAV" >"$LOG_FILE" 2>&1
EXIT_CODE=$?

if [[ -f "$TEST_WAV" ]]; then
    SIZE=$(wc -c < "$TEST_WAV" | tr -d ' ')
    echo "COMPLETED (Exit $EXIT_CODE): Recorded $SIZE bytes to $TEST_WAV"
else
    LOG_TAIL=$(tail -n 3 "$LOG_FILE" | tr '\n' ' ')
    echo "FAILED (Exit $EXIT_CODE): $LOG_TAIL"
fi
