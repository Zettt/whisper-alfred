#!/bin/zsh

# Test suite for Whisper Alfred workflow scripts

set -e

echo "=== Running Workflow Verification Tests ==="

export alfred_workflow_cache="/tmp/alfred_transcribe_test_cache"
export alfred_workflow_data="/tmp/alfred_transcribe_test_data"

rm -rf "$alfred_workflow_cache" "$alfred_workflow_data"
mkdir -p "$alfred_workflow_cache" "$alfred_workflow_data/recordings"

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
MOCK_M4A="$alfred_workflow_data/recordings/mock_sample.m4a"

touch "$MOCK_M4A"

sleep 10 &
MOCK_PID=$!

echo "$MOCK_PID" > "$PID_FILE"
echo "$MOCK_M4A" > "$CURRENT_FILE"

STOP_OUTPUT=$(./scripts/toggle_rec.sh)

if [[ "$STOP_OUTPUT" == "$MOCK_M4A" ]]; then
    echo "[PASS] Toggle controller correctly returns recorded M4A path on stop"
else
    echo "[FAIL] Toggle output expected '$MOCK_M4A', got '$STOP_OUTPUT'"
    exit 1
fi

if kill -0 "$MOCK_PID" 2>/dev/null; then
    echo "[FAIL] Mock process was not terminated"
    kill -9 "$MOCK_PID" 2>/dev/null || true
    exit 1
else
    echo "[PASS] Toggle controller cleanly terminated process state"
fi

# Test 3: Audio Pruner Test - Default Retention Prune (empty arg & upstream transcript string)
RECENT_M4A="$alfred_workflow_data/recordings/recent_sample.m4a"
RECENT_JSON="$alfred_workflow_data/recordings/recent_sample.json"
OLD_M4A="$alfred_workflow_data/recordings/old_sample.m4a"
OLD_JSON="$alfred_workflow_data/recordings/old_sample.json"

touch "$RECENT_M4A" "$RECENT_JSON"
touch -t 202001010000 "$OLD_M4A" "$OLD_JSON"

# Simulating workflow completion where upstream transcribed text is piped as $1
RETENTION_DAYS=7 ./scripts/prune.sh "This is a transcribed voice note from workflow" > /dev/null

if [[ -f "$RECENT_M4A" && -f "$RECENT_JSON" && ! -f "$OLD_M4A" && ! -f "$OLD_JSON" ]]; then
    echo "[PASS] Pruner default/upstream argument executed retention pruning without deleting recent recordings"
else
    echo "[FAIL] Pruner default retention behavior failed"
    exit 1
fi
rm -f "$RECENT_M4A" "$RECENT_JSON"

# Test 4: Audio Pruner Test - Explicit Full Purge ('force' / 'all' / 'purge')
SAMPLE_M4A="$alfred_workflow_data/recordings/sample.m4a"
SAMPLE_JSON="$alfred_workflow_data/recordings/sample.json"
touch "$SAMPLE_M4A" "$SAMPLE_JSON"

./scripts/prune.sh "force" > /dev/null

if [[ ! -f "$SAMPLE_M4A" && ! -f "$SAMPLE_JSON" ]]; then
    echo "[PASS] Pruner 'force' argument purged all recordings"
else
    echo "[FAIL] Pruner 'force' full purge failed"
    exit 1
fi

# Test 5: Audio Pruner Test - 'recordings' / 'wav' / 'm4a' sub-argument
touch "$SAMPLE_M4A" "$SAMPLE_JSON"

./scripts/prune.sh "recordings" > /dev/null

if [[ ! -f "$SAMPLE_M4A" && -f "$SAMPLE_JSON" ]]; then
    echo "[PASS] Pruner 'recordings' argument deleted .m4a and preserved .json sidecar"
else
    echo "[FAIL] Pruner 'recordings' mode failed"
    exit 1
fi
rm -f "$SAMPLE_JSON"

# Test 6: Audio Pruner Test - 'archive' sub-argument
touch "$SAMPLE_M4A" "$SAMPLE_JSON"

./scripts/prune.sh "archive" > /dev/null

if [[ ! -f "$SAMPLE_M4A" && ! -f "$SAMPLE_JSON" && -f "$alfred_workflow_data/archive/sample.m4a" && -f "$alfred_workflow_data/archive/sample.json" ]]; then
    echo "[PASS] Pruner 'archive' argument successfully moved files to archive directory"
else
    echo "[FAIL] Pruner 'archive' mode failed"
    exit 1
fi
rm -rf "$alfred_workflow_data/archive"

# Test 7: Audio Pruner Test - Numeric days argument
EXPIRED_M4A="$alfred_workflow_data/recordings/expired_sample.m4a"
FRESH_M4A="$alfred_workflow_data/recordings/fresh_sample.m4a"
touch -t 202001010000 "$EXPIRED_M4A"
touch "$FRESH_M4A"

./scripts/prune.sh "2" > /dev/null

if [[ ! -f "$EXPIRED_M4A" && -f "$FRESH_M4A" ]]; then
    echo "[PASS] Pruner numeric argument pruned files older than specified days"
else
    echo "[FAIL] Pruner numeric days mode failed"
    exit 1
fi
rm -f "$FRESH_M4A"

echo "=== All Tests Passed Successfully ==="
