#!/bin/zsh

# Test suite for Whisper Alfred workflow scripts

set -e

echo "=== Running Workflow Verification Tests ==="

export alfred_workflow_cache="/tmp/alfred_transcribe_test_cache"
export alfred_workflow_data="/tmp/alfred_transcribe_test_data"

rm -rf "$alfred_workflow_cache" "$alfred_workflow_data"
mkdir -p "$alfred_workflow_cache" "$alfred_workflow_data"

# Test 1: Polish fallback when cleanup disabled
OUTPUT=$(ENABLE_CLEANUP="false" ./scripts/polish.sh "Hello um world test")
if [[ "$OUTPUT" == "Hello um world test" ]]; then
    echo "[PASS] Polish script correctly passes through input when ENABLE_CLEANUP=false"
else
    echo "[FAIL] Polish output unexpected: '$OUTPUT'"
    exit 1
fi

# Test 2: Toggle start/stop recording process tracking (simulated PID)
PID_FILE="$alfred_workflow_cache/record.pid"
CURRENT_FILE="$alfred_workflow_cache/current_recording.txt"
MOCK_WAV="$alfred_workflow_data/recordings/mock_sample.wav"

mkdir -p "$alfred_workflow_data/recordings"
touch "$MOCK_WAV"

sleep 10 &
MOCK_PID=$!

echo "$MOCK_PID" > "$PID_FILE"
echo "$MOCK_WAV" > "$CURRENT_FILE"

STOP_OUTPUT=$(./scripts/toggle_rec.sh)

if [[ "$STOP_OUTPUT" == "$MOCK_WAV" ]]; then
    echo "[PASS] Toggle controller correctly returns recorded WAV path on stop"
else
    echo "[FAIL] Toggle output expected '$MOCK_WAV', got '$STOP_OUTPUT'"
    exit 1
fi

if kill -0 "$MOCK_PID" 2>/dev/null; then
    echo "[FAIL] Mock process was not terminated"
    kill -9 "$MOCK_PID" 2>/dev/null || true
    exit 1
else
    echo "[PASS] Toggle controller cleanly terminated process state"
fi

# Test 3: Audio Pruner Test
OLD_WAV="$alfred_workflow_data/recordings/old_sample.wav"
touch -t 202001010000 "$OLD_WAV"

RETENTION_DAYS=1 ./scripts/prune.sh

if [[ ! -f "$OLD_WAV" ]]; then
    echo "[PASS] Pruner script deleted expired audio recording"
else
    echo "[FAIL] Pruner failed to remove expired audio recording"
    exit 1
fi

echo "=== All Tests Passed Successfully ==="
