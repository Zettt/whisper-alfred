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

(trap 'exit 0' INT; while true; do sleep 0.05; done) &
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

# Test 8: Transcribe error handling and async sidecar creation with jq
TRANS_AUDIO="$alfred_workflow_data/recordings/test_trans.m4a"
touch "$TRANS_AUDIO"
TRANS_OUT=$(TRANSCRIPTION_PROVIDER="local" LOCAL_TRANSCRIPTION_ENDPOINT="http://127.0.0.1:59999" ./scripts/transcribe.sh "$TRANS_AUDIO")
if [[ "$TRANS_OUT" =~ "Could not connect to local server" ]]; then
    echo "[PASS] Transcribe script (jq) handles offline endpoint gracefully"
else
    echo "[FAIL] Transcribe script (jq) error handling failed: '$TRANS_OUT'"
    exit 1
fi
sleep 0.1
if [[ -f "${TRANS_AUDIO%.*}.json" ]]; then
    echo "[PASS] Transcribe script (jq) wrote sidecar JSON asynchronously"
else
    echo "[FAIL] Transcribe sidecar JSON was not created"
    exit 1
fi
rm -f "$TRANS_AUDIO" "${TRANS_AUDIO%.*}".json

# Test 9: Transcribe error handling and async sidecar with plutil fallback (FORCE_PLUTIL=1)
TRANS_AUDIO_PLUTIL="$alfred_workflow_data/recordings/test_trans_plutil.m4a"
touch "$TRANS_AUDIO_PLUTIL"
TRANS_OUT_PLUTIL=$(FORCE_PLUTIL=1 TRANSCRIPTION_PROVIDER="local" LOCAL_TRANSCRIPTION_ENDPOINT="http://127.0.0.1:59999" ./scripts/transcribe.sh "$TRANS_AUDIO_PLUTIL")
if [[ "$TRANS_OUT_PLUTIL" =~ "Could not connect to local server" ]]; then
    echo "[PASS] Transcribe script (plutil fallback) handles offline endpoint gracefully"
else
    echo "[FAIL] Transcribe script (plutil fallback) error handling failed: '$TRANS_OUT_PLUTIL'"
    exit 1
fi
sleep 0.1
if [[ -f "${TRANS_AUDIO_PLUTIL%.*}.json" ]]; then
    echo "[PASS] Transcribe script (plutil fallback) wrote sidecar JSON asynchronously"
else
    echo "[FAIL] Transcribe plutil sidecar JSON was not created"
    exit 1
fi
rm -f "$TRANS_AUDIO_PLUTIL" "${TRANS_AUDIO_PLUTIL%.*}".json

# Test 10: Polish script with plutil fallback
POLISH_PLUTIL_OUT=$(FORCE_PLUTIL=1 ENABLE_CLEANUP="false" ./scripts/polish.sh "Hello plutil world test")
if [[ "$POLISH_PLUTIL_OUT" == "Hello plutil world test" ]]; then
    echo "[PASS] Polish script (plutil fallback) passes through input correctly"
else
    echo "[FAIL] Polish plutil output unexpected: '$POLISH_PLUTIL_OUT'"
    exit 1
fi

# Test 11: Cross-provider transcription model mismatch fallback
MOCK_TRANS_AUDIO="$alfred_workflow_data/recordings/test_model_fallback.m4a"
touch "$MOCK_TRANS_AUDIO"
# Testing that Groq with voxtral-mini-latest doesn't crash before validation (requires GROQ_API_KEY)
# If GROQ_API_KEY is empty, it exits 1 with expected message
GROQ_KEY_ERR=$(TRANSCRIPTION_PROVIDER="groq" GROQ_API_KEY="" TRANSCRIPTION_MODEL="voxtral-mini-latest" ./scripts/transcribe.sh "$MOCK_TRANS_AUDIO" 2>&1 || true)
if [[ "$GROQ_KEY_ERR" =~ "GROQ_API_KEY environment variable is not set" ]]; then
    echo "[PASS] Groq provider validates API key presence"
else
    echo "[FAIL] Groq provider API key check failed: '$GROQ_KEY_ERR'"
    exit 1
fi
rm -f "$MOCK_TRANS_AUDIO"

# Test 12: Detailed API error parsing in transcribe script
MOCK_ERR_RESP='{"error":{"message":"The model does not exist","type":"invalid_request_error","code":"model_not_found"}}'
PARSE_OUT=$(zsh -c '
    eval "$(sed -n "/parse_json_transcription() {/,/^}/p" ./scripts/transcribe.sh)"
    eval "$(sed -n "/trim() {/,/^}/p" ./scripts/transcribe.sh)"
    parse_json_transcription '"'$MOCK_ERR_RESP'"'
')
if [[ "$PARSE_OUT" =~ "The model does not exist" ]]; then
    echo "[PASS] parse_json_transcription correctly extracts detailed error message"
else
    echo "[FAIL] Detailed error extraction failed: '$PARSE_OUT'"
    exit 1
fi

# Test 13: plutil fallback for detailed API error parsing
PARSE_OUT_PLUTIL=$(FORCE_PLUTIL=1 zsh -c '
    eval "$(sed -n "/parse_json_transcription() {/,/^}/p" ./scripts/transcribe.sh)"
    eval "$(sed -n "/trim() {/,/^}/p" ./scripts/transcribe.sh)"
    parse_json_transcription '"'$MOCK_ERR_RESP'"'
')
if [[ "$PARSE_OUT_PLUTIL" =~ "The model does not exist" ]]; then
    echo "[PASS] parse_json_transcription (plutil fallback) correctly extracts detailed error message"
else
    echo "[FAIL] Detailed error extraction (plutil fallback) failed: '$PARSE_OUT_PLUTIL'"
    exit 1
fi

echo "=== All Tests Passed Successfully ==="
