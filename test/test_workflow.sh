#!/bin/zsh

# Test suite for Whisper Alfred workflow scripts

set -e

echo "=== Running Workflow Verification Tests ==="

export alfred_workflow_cache="/tmp/alfred_transcribe_test_cache"
export alfred_workflow_data="/tmp/alfred_transcribe_test_data"

rm -rf "$alfred_workflow_cache" "$alfred_workflow_data"
mkdir -p "$alfred_workflow_cache" "$alfred_workflow_data/recordings"

# Test 1: Polish fallback when cleanup disabled
OUTPUT=$(ENABLE_CLEANUP="false" ./workflow/scripts/polish.sh "Hello um world test")
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

STOP_OUTPUT=$(./workflow/scripts/toggle_rec.sh)

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
RETENTION_DAYS=7 ./workflow/scripts/prune.sh "This is a transcribed voice note from workflow" > /dev/null

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

./workflow/scripts/prune.sh "force" > /dev/null

if [[ ! -f "$SAMPLE_M4A" && ! -f "$SAMPLE_JSON" ]]; then
    echo "[PASS] Pruner 'force' argument purged all recordings"
else
    echo "[FAIL] Pruner 'force' full purge failed"
    exit 1
fi

# Test 5: Audio Pruner Test - 'recordings' / 'wav' / 'm4a' sub-argument
touch "$SAMPLE_M4A" "$SAMPLE_JSON"

./workflow/scripts/prune.sh "recordings" > /dev/null

if [[ ! -f "$SAMPLE_M4A" && -f "$SAMPLE_JSON" ]]; then
    echo "[PASS] Pruner 'recordings' argument deleted .m4a and preserved .json sidecar"
else
    echo "[FAIL] Pruner 'recordings' mode failed"
    exit 1
fi
rm -f "$SAMPLE_JSON"

# Test 6: Audio Pruner Test - 'archive' sub-argument
touch "$SAMPLE_M4A" "$SAMPLE_JSON"

./workflow/scripts/prune.sh "archive" > /dev/null

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

./workflow/scripts/prune.sh "2" > /dev/null

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
TRANS_OUT=$(TRANSCRIPTION_PROVIDER="local" LOCAL_TRANSCRIPTION_ENDPOINT="http://127.0.0.1:59999" ./workflow/scripts/transcribe.sh "$TRANS_AUDIO")
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
TRANS_OUT_PLUTIL=$(FORCE_PLUTIL=1 TRANSCRIPTION_PROVIDER="local" LOCAL_TRANSCRIPTION_ENDPOINT="http://127.0.0.1:59999" ./workflow/scripts/transcribe.sh "$TRANS_AUDIO_PLUTIL")
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
POLISH_PLUTIL_OUT=$(FORCE_PLUTIL=1 ENABLE_CLEANUP="false" ./workflow/scripts/polish.sh "Hello plutil world test")
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
GROQ_KEY_ERR=$(TRANSCRIPTION_PROVIDER="groq" GROQ_API_KEY="" TRANSCRIPTION_MODEL="voxtral-mini-latest" ./workflow/scripts/transcribe.sh "$MOCK_TRANS_AUDIO" 2>&1 || true)
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
    eval "$(sed -n "/parse_json_transcription() {/,/^}/p" ./workflow/scripts/transcribe.sh)"
    eval "$(sed -n "/trim() {/,/^}/p" ./workflow/scripts/transcribe.sh)"
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
    eval "$(sed -n "/parse_json_transcription() {/,/^}/p" ./workflow/scripts/transcribe.sh)"
    eval "$(sed -n "/trim() {/,/^}/p" ./workflow/scripts/transcribe.sh)"
    parse_json_transcription '"'$MOCK_ERR_RESP'"'
')
if [[ "$PARSE_OUT_PLUTIL" =~ "The model does not exist" ]]; then
    echo "[PASS] parse_json_transcription (plutil fallback) correctly extracts detailed error message"
else
    echo "[FAIL] Detailed error extraction (plutil fallback) failed: '$PARSE_OUT_PLUTIL'"
    exit 1
fi

# Test 14: Toggle recording codec selection (m4a vs wav) and max duration cap
MOCK_BIN="$alfred_workflow_cache/mock_bin"
FFMPEG_ARGS_FILE="$alfred_workflow_cache/ffmpeg_args.txt"
mkdir -p "$MOCK_BIN"
cat <<'EOF' > "$MOCK_BIN/ffmpeg"
#!/bin/zsh
printf '%s\n' "$*" > "${MOCK_FFMPEG_ARGS_FILE}"
trap 'exit 0' INT TERM
while true; do sleep 0.1; done
EOF
chmod +x "$MOCK_BIN/ffmpeg"

rm -f "$PID_FILE" "$CURRENT_FILE" "$FFMPEG_ARGS_FILE"
MOCK_FFMPEG_ARGS_FILE="$FFMPEG_ARGS_FILE" FFMPEG_BIN="$MOCK_BIN/ffmpeg" AUDIO_FORMAT="m4a" MAX_RECORDING_DURATION="600" ./workflow/scripts/toggle_rec.sh >/dev/null
for _ in {1..40}; do [[ -s "$FFMPEG_ARGS_FILE" ]] && break; sleep 0.05; done
M4A_ARGS=$(cat "$FFMPEG_ARGS_FILE" 2>/dev/null || true)
if [[ -f "$PID_FILE" ]]; then
    kill -9 "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE" "$CURRENT_FILE"
fi
if [[ "$M4A_ARGS" == *"-c:a aac -b:a 64k"* && "$M4A_ARGS" == *"-t 600"* && "$M4A_ARGS" == *".m4a"* ]]; then
    echo "[PASS] Toggle recording passes AAC codec and max duration for m4a format"
else
    echo "[FAIL] M4A ffmpeg args unexpected: '$M4A_ARGS'"
    exit 1
fi

rm -f "$FFMPEG_ARGS_FILE"
MOCK_FFMPEG_ARGS_FILE="$FFMPEG_ARGS_FILE" FFMPEG_BIN="$MOCK_BIN/ffmpeg" AUDIO_FORMAT="wav" MAX_RECORDING_DURATION="120" ./workflow/scripts/toggle_rec.sh >/dev/null
for _ in {1..40}; do [[ -s "$FFMPEG_ARGS_FILE" ]] && break; sleep 0.05; done
WAV_ARGS=$(cat "$FFMPEG_ARGS_FILE" 2>/dev/null || true)
if [[ -f "$PID_FILE" ]]; then
    kill -9 "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE" "$CURRENT_FILE"
fi
if [[ "$WAV_ARGS" == *"-c:a pcm_s16le"* && "$WAV_ARGS" == *"-t 120"* && "$WAV_ARGS" == *".wav"* && "$WAV_ARGS" != *"-c:a aac"* ]]; then
    echo "[PASS] Toggle recording passes PCM codec and max duration for wav format"
else
    echo "[FAIL] WAV ffmpeg args unexpected: '$WAV_ARGS'"
    exit 1
fi
rm -rf "$MOCK_BIN" "$FFMPEG_ARGS_FILE" "$alfred_workflow_data/recordings"/*.m4a(N) "$alfred_workflow_data/recordings"/*.wav(N)

# Test 15: Recording cancel/abort mode
CANCEL_M4A="$alfred_workflow_data/recordings/cancel_sample.m4a"
touch "$CANCEL_M4A"
(trap 'exit 0' INT TERM; while true; do sleep 0.05; done) &
CANCEL_PID=$!
echo "$CANCEL_PID" > "$PID_FILE"
echo "$CANCEL_M4A" > "$CURRENT_FILE"

CANCEL_OUT=$(./workflow/scripts/toggle_rec.sh cancel)
if [[ -z "$CANCEL_OUT" ]] && ! kill -0 "$CANCEL_PID" 2>/dev/null && [[ ! -f "$PID_FILE" && ! -f "$CURRENT_FILE" && ! -f "$CANCEL_M4A" ]]; then
    echo "[PASS] Toggle recording cancel stops process, cleans state, and removes partial audio"
else
    echo "[FAIL] Toggle recording cancel failed (out='$CANCEL_OUT')"
    kill -9 "$CANCEL_PID" 2>/dev/null || true
    exit 1
fi

# Test 16: Count-based retention (MAX_RECORDINGS and MIN_KEEP_RECORDINGS)
for i in 1 2 3 4; do
    touch -t "20260101010${i}" "$alfred_workflow_data/recordings/rec_${i}.m4a" "$alfred_workflow_data/recordings/rec_${i}.json"
done
MAX_RECORDINGS=2 RETENTION_DAYS=3650 ./workflow/scripts/prune.sh >/dev/null
if [[ ! -f "$alfred_workflow_data/recordings/rec_1.m4a" && ! -f "$alfred_workflow_data/recordings/rec_1.json" && ! -f "$alfred_workflow_data/recordings/rec_2.m4a" && ! -f "$alfred_workflow_data/recordings/rec_2.json" && -f "$alfred_workflow_data/recordings/rec_3.m4a" && -f "$alfred_workflow_data/recordings/rec_4.m4a" && -f "$alfred_workflow_data/recordings/rec_4.json" ]]; then
    echo "[PASS] Pruner MAX_RECORDINGS retains only the N newest recording/sidecar pairs"
else
    echo "[FAIL] Pruner MAX_RECORDINGS retention failed"
    exit 1
fi
rm -f "$alfred_workflow_data/recordings"/rec_*(N)

touch -t 202001010000 "$alfred_workflow_data/recordings/old_keep_1.m4a" "$alfred_workflow_data/recordings/old_keep_1.json"
touch -t 202001020000 "$alfred_workflow_data/recordings/old_keep_2.m4a" "$alfred_workflow_data/recordings/old_keep_2.json"
MIN_KEEP_RECORDINGS=2 RETENTION_DAYS=7 ./workflow/scripts/prune.sh >/dev/null
if [[ -f "$alfred_workflow_data/recordings/old_keep_1.m4a" && -f "$alfred_workflow_data/recordings/old_keep_1.json" && -f "$alfred_workflow_data/recordings/old_keep_2.m4a" && -f "$alfred_workflow_data/recordings/old_keep_2.json" ]]; then
    echo "[PASS] Pruner MIN_KEEP_RECORDINGS preserves minimum recent recordings despite age"
else
    echo "[FAIL] Pruner MIN_KEEP_RECORDINGS preservation failed"
    exit 1
fi
rm -f "$alfred_workflow_data/recordings"/old_keep_*(N)

# Test 17: Synchronous sidecar creation in transcribe.sh
SYNC_AUDIO="$alfred_workflow_data/recordings/test_sync_sidecar.m4a"
touch "$SYNC_AUDIO"
TRANSCRIPTION_PROVIDER="local" LOCAL_TRANSCRIPTION_ENDPOINT="http://127.0.0.1:59999" ./workflow/scripts/transcribe.sh "$SYNC_AUDIO" >/dev/null
if [[ -f "${SYNC_AUDIO%.*}.json" ]] && jq empty "${SYNC_AUDIO%.*}.json" >/dev/null 2>&1; then
    echo "[PASS] Transcribe script creates valid sidecar JSON synchronously before exiting"
else
    echo "[FAIL] Synchronous sidecar JSON missing or invalid"
    exit 1
fi
rm -f "$SYNC_AUDIO" "${SYNC_AUDIO%.*}.json"

# Test 18: Polish script error bypass
ERR_SIDECAR="$alfred_workflow_data/recordings/err_sidecar.json"
cat <<'EOF' > "$ERR_SIDECAR"
{
  "timestamp": "2026-11-20T00:00:00Z",
  "audio_file": "err.m4a",
  "transcription": {"provider": "local", "model": "local", "raw_text": "[Whisper Alfred Error: Could not connect to local server]"},
  "cleanup": {"enabled": false, "provider": null, "model": null, "polished_text": null}
}
EOF
echo "$ERR_SIDECAR" > "$alfred_workflow_cache/latest_sidecar.txt"
ERR_POLISH_OUT=$(ENABLE_CLEANUP="true" CLEANUP_PROVIDER="local" LOCAL_CLEANUP_ENDPOINT="http://127.0.0.1:59999" ./workflow/scripts/polish.sh "[Whisper Alfred Error: Could not connect to local server]")
ERR_CLEANUP_ENABLED=$(jq -r '.cleanup.enabled' "$ERR_SIDECAR")
if [[ "$ERR_POLISH_OUT" == "[Whisper Alfred Error: Could not connect to local server]" && "$ERR_CLEANUP_ENABLED" == "false" ]]; then
    echo "[PASS] Polish script bypasses LLM cleanup for error strings"
else
    echo "[FAIL] Polish script error bypass failed: out='$ERR_POLISH_OUT' enabled='$ERR_CLEANUP_ENABLED'"
    exit 1
fi
rm -f "$ERR_SIDECAR"

# Test 19: Missing API key formatted error message
KEY_AUDIO="$alfred_workflow_data/recordings/test_missing_key.m4a"
touch "$KEY_AUDIO"
MISTRAL_KEY_OUT=$(TRANSCRIPTION_PROVIDER="mistral" MISTRAL_API_KEY="" ./workflow/scripts/transcribe.sh "$KEY_AUDIO" 2>&1 || true)
if [[ "$MISTRAL_KEY_OUT" == *"[Whisper Alfred Error: MISTRAL_API_KEY environment variable is not set.]"* ]]; then
    echo "[PASS] Transcribe script emits formatted error on missing API key"
else
    echo "[FAIL] Missing API key output unexpected: '$MISTRAL_KEY_OUT'"
    exit 1
fi
rm -f "$KEY_AUDIO"

# Test 20: info.plist audit and external script delegation
if [[ -f "./workflow/info.plist" ]] && plutil -lint ./workflow/info.plist >/dev/null 2>&1; then
    if python3 -c '
import plistlib, sys
with open("./workflow/info.plist", "rb") as f:
    plist = plistlib.load(f)
cfg_list = plist.get("userconfigurationconfig", [])
cfg = {item["variable"]: item for item in cfg_list}
cfg_vars = [item["variable"] for item in cfg_list]
for item in cfg_list:
    label = item["label"]
    assert len(label) <= 22, f"Label too long ({len(label)}): {label}"
cleanup_idx = cfg_vars.index("ENABLE_CLEANUP")
assert cfg_vars[cleanup_idx:cleanup_idx+4] == ["ENABLE_CLEANUP", "CLEANUP_PROVIDER", "CLEANUP_MODEL", "CLEANUP_SYSTEM_PROMPT"], f"Unexpected cleanup order: {cfg_vars}"
assert cfg_vars[-2:] == ["RETENTION_DAYS", "MAX_RECORDINGS"], f"Retention settings not at bottom: {cfg_vars}"
for key in ["MISTRAL_API_KEY", "GROQ_API_KEY"]:
    assert cfg[key]["config"]["default"] == "", f"{key} default not empty"
    assert key in plist.get("variablesdontexport", []), f"{key} missing from variablesdontexport"
for key in ["PARAKEET_ENDPOINT", "AUDIO_FORMAT", "CLEANUP_SYSTEM_PROMPT", "MAX_RECORDING_DURATION", "MAX_RECORDINGS"]:
    assert key in cfg, f"Missing config key {key}"
scripts = [obj.get("config", {}).get("script", "") for obj in plist.get("objects", []) if obj.get("type") == "alfred.workflow.action.script"]
joined = "\n".join(scripts)
for target in ["./scripts/toggle_rec.sh", "./scripts/transcribe.sh", "./scripts/polish.sh", "./scripts/prune.sh", "./scripts/open_recordings.sh"]:
    assert target in joined, f"Missing external script call {target}"
assert "toggle_rec.sh cancel" in joined, "Missing cancel script call"
' && ! rg -q "gsk_|uZ2C" ./workflow/info.plist; then
        echo "[PASS] info.plist passes lint, security, config, and external script checks"
    else
        echo "[FAIL] info.plist structure or security check failed"
        exit 1
    fi
else
    echo "[FAIL] ./workflow/info.plist missing or failed plutil -lint"
    exit 1
fi

# Test 21: Script Filter for whisper prune (1D2)
touch "$alfred_workflow_data/recordings/pf_1.m4a" "$alfred_workflow_data/recordings/pf_2.m4a"
touch "$alfred_workflow_data/recordings/pf_1.json" "$alfred_workflow_data/recordings/pf_2.json"
PF_EMPTY=$(./workflow/scripts/prune_filter.sh "")
if printf '%s' "$PF_EMPTY" | jq -e '
    (.items | length >= 4) and
    ([.items[].arg] | index("auto") != null) and
    ([.items[].arg] | index("recordings") != null) and
    ([.items[].arg] | index("archive") != null) and
    ([.items[].arg] | index("force") != null)
' >/dev/null 2>&1; then
    echo "[PASS] Prune Script Filter outputs valid JSON options"
else
    echo "[FAIL] Prune Script Filter default output invalid: '$PF_EMPTY'"
    exit 1
fi

PF_NUM=$(./workflow/scripts/prune_filter.sh "14")
if printf '%s' "$PF_NUM" | jq -e '
    ([.items[].arg] | index("14") != null) and
    ([.items[].arg] | index("keep 14") != null)
' >/dev/null 2>&1; then
    echo "[PASS] Prune Script Filter emits dynamic day/keep options for numeric query"
else
    echo "[FAIL] Prune Script Filter numeric output invalid: '$PF_NUM'"
    exit 1
fi
rm -f "$alfred_workflow_data/recordings"/pf_*(N)

# Test 22: Transcript History UI & scripts (1A)
HIST_M4A_1="$alfred_workflow_data/recordings/hist_1.m4a"
HIST_JSON_1="$alfred_workflow_data/recordings/hist_1.json"
HIST_M4A_2="$alfred_workflow_data/recordings/hist_2.m4a"
HIST_JSON_2="$alfred_workflow_data/recordings/hist_2.json"
touch "$HIST_M4A_1" "$HIST_M4A_2"
cat <<EOF > "$HIST_JSON_1"
{
  "timestamp": "2026-11-20T06:00:00Z",
  "audio_file": "$HIST_M4A_1",
  "transcription": {"provider": "mistral", "model": "voxtral-mini-latest", "raw_text": "um hello world one"},
  "cleanup": {"enabled": true, "provider": "mistral", "model": "mistral-small-latest", "polished_text": "Hello world one."}
}
EOF
cat <<EOF > "$HIST_JSON_2"
{
  "timestamp": "2026-11-20T06:05:00Z",
  "audio_file": "$HIST_M4A_2",
  "transcription": {"provider": "groq", "model": "whisper-large-v3-turbo", "raw_text": "hello world two"},
  "cleanup": {"enabled": false, "provider": null, "model": null, "polished_text": null}
}
EOF
touch -t 202611200600 "$HIST_JSON_1"
touch -t 202611200605 "$HIST_JSON_2"

./workflow/scripts/history_prepare.sh >/dev/null
HIST_DATA_FILE="./workflow/history.alfredui/resources/history_data.json"
if [[ -f "$HIST_DATA_FILE" ]] && jq -e '
    (length == 2) and
    (.[0] | has("cellTitle.text") and has("cellSubtitle.text") and has("cellPolished.text") and has("cellRaw.text") and has("cellMeta.text") and has("cellAudio.text") and has("cellJson.text"))
' "$HIST_DATA_FILE" >/dev/null 2>&1; then
    echo "[PASS] history_prepare.sh builds valid history_data.json from sidecars"
else
    echo "[FAIL] history_prepare.sh output missing or malformed"
    exit 1
fi

DEL_OUT=$(./workflow/history.alfredui/scripts/history_action.sh delete "$HIST_JSON_1")
if [[ ! -f "$HIST_JSON_1" && ! -f "$HIST_M4A_1" ]] && jq -e 'length == 1' "$HIST_DATA_FILE" >/dev/null 2>&1 && printf '%s' "$DEL_OUT" | jq -e '.update.ids.historyList.data.src | length == 1' >/dev/null 2>&1; then
    echo "[PASS] history_action.sh delete removes files and emits UI update JSON"
else
    echo "[FAIL] history_action.sh delete failed: '$DEL_OUT'"
    exit 1
fi

if [[ -f "./workflow/history.alfredui/ui.json" ]] && jq -e '
    (.window.root.layout == "border") and
    (.. | objects | select(.id? == "historyList")) and
    ((.. | objects | select(has("copy")) | .copy) | has("src")) and
    ([.. | objects | select(has("finish")) | .finish | type == "object"] | all) and
    ([.. | strings | select(. == "./scripts/history_action.sh")] | length >= 1)
' ./workflow/history.alfredui/ui.json >/dev/null 2>&1; then
    echo "[PASS] history.alfredui/ui.json passes schema and action contract checks"
else
    echo "[FAIL] history.alfredui/ui.json invalid or missing required keys"
    exit 1
fi
rm -f "$HIST_M4A_2" "$HIST_JSON_2"
printf '[]\n' > "$HIST_DATA_FILE"

# Test 23: Floating HUD UI & pulse/action scripts (1B)
if [[ -f "./workflow/hud.alfredui/ui.json" ]] && jq -e '
    (.window.borderless == true) and
    (.window.resizeable == false) and
    (.window.size.height == 96) and
    (.window.minsize.height == 64) and
    (.window.maxsize.height == 64) and
    (.pulse.src == "./scripts/hud_pulse.sh") and
    (.. | objects | select(.id? == "statusLabel")) and
    (.. | objects | select(.id? == "timerLabel")) and
    (.. | objects | select(.id? == "stopBtn" and .shortcut? == "↩")) and
    (.. | objects | select(.id? == "cancelBtn" and .shortcut? == "⎋"))
' ./workflow/hud.alfredui/ui.json >/dev/null 2>&1; then
    echo "[PASS] hud.alfredui/ui.json passes layout and pulse configuration checks"
else
    echo "[FAIL] hud.alfredui/ui.json invalid or missing components"
    exit 1
fi

(trap 'exit 0' INT TERM; while true; do sleep 0.05; done) &
HUD_PID=$!
echo "$HUD_PID" > "$PID_FILE"
date +%s > "$alfred_workflow_cache/record_start.txt"
echo "recording" > "$alfred_workflow_cache/status.txt"

PULSE_REC=$(./workflow/hud.alfredui/scripts/hud_pulse.sh)
if printf '%s' "$PULSE_REC" | jq -e '.update.ids.statusLabel.text == "Recording..."' >/dev/null 2>&1; then
    echo "[PASS] hud_pulse.sh reports Recording... during active capture"
else
    echo "[FAIL] hud_pulse.sh recording output unexpected: '$PULSE_REC'"
    kill -9 "$HUD_PID" 2>/dev/null || true
    exit 1
fi

echo "transcribing" > "$alfred_workflow_cache/status.txt"
PULSE_TRANS=$(./workflow/hud.alfredui/scripts/hud_pulse.sh)
if printf '%s' "$PULSE_TRANS" | jq -e '.update.ids.statusLabel.text == "Transcribing..."' >/dev/null 2>&1; then
    echo "[PASS] hud_pulse.sh reports Transcribing... during transcription"
else
    echo "[FAIL] hud_pulse.sh transcribing output unexpected: '$PULSE_TRANS'"
    kill -9 "$HUD_PID" 2>/dev/null || true
    exit 1
fi

kill -9 "$HUD_PID" 2>/dev/null || true
rm -f "$PID_FILE" "$alfred_workflow_cache/record_start.txt" "$alfred_workflow_cache/status.txt"
PULSE_DONE=$(./workflow/hud.alfredui/scripts/hud_pulse.sh)
if printf '%s' "$PULSE_DONE" | jq -e '(.finish | type == "object") and (.pulse.interval == 0)' >/dev/null 2>&1; then
    echo "[PASS] hud_pulse.sh finishes and stops pulse when pipeline completes"
else
    echo "[FAIL] hud_pulse.sh finish output unexpected: '$PULSE_DONE'"
    exit 1
fi

HUD_CANCEL_M4A="$alfred_workflow_data/recordings/hud_cancel.m4a"
touch "$HUD_CANCEL_M4A"
(trap 'exit 0' INT TERM; while true; do sleep 0.05; done) &
HUD_CANCEL_PID=$!
echo "$HUD_CANCEL_PID" > "$PID_FILE"
echo "$HUD_CANCEL_M4A" > "$CURRENT_FILE"
echo "recording" > "$alfred_workflow_cache/status.txt"
HUD_CANCEL_OUT=$(./workflow/hud.alfredui/scripts/hud_action.sh cancel)
if ! kill -0 "$HUD_CANCEL_PID" 2>/dev/null && [[ ! -f "$HUD_CANCEL_M4A" ]] && printf '%s' "$HUD_CANCEL_OUT" | jq -e '(.finish | type == "object") and (.pulse.interval == 0)' >/dev/null 2>&1; then
    echo "[PASS] hud_action.sh cancel aborts recording and finishes HUD"
else
    echo "[FAIL] hud_action.sh cancel failed: '$HUD_CANCEL_OUT'"
    kill -9 "$HUD_CANCEL_PID" 2>/dev/null || true
    exit 1
fi

# Test 24: info.plist and packaged archive verification for 1A, 1B, and 1D2
./scripts/package.sh >/dev/null
EXPECTED_VERSION=$(tr -d '[:space:]' < ./VERSION)
if python3 -c '
import plistlib, sys
expected_ver = sys.argv[1]
with open("./workflow/info.plist", "rb") as f:
    p = plistlib.load(f)
objs = {o["uid"]: o for o in p.get("objects", [])}
conns = p.get("connections", {})

sf = [o for o in objs.values() if o.get("type") == "alfred.workflow.input.scriptfilter" and o.get("config", {}).get("keyword") == "whisper prune"]
assert len(sf) == 1 and "./scripts/prune_filter.sh" in sf[0]["config"].get("script", ""), "Missing whisper prune script filter"

hk = [o for o in objs.values() if o.get("type") == "alfred.workflow.input.keyword" and o.get("config", {}).get("keyword") == "whisper history"]
assert len(hk) == 1, "Missing whisper history keyword"
hist_prep = conns.get(hk[0]["uid"], [{}])[0].get("destinationuid")
assert "./scripts/history_prepare.sh" in objs[hist_prep]["config"].get("script", ""), "whisper history missing history_prepare.sh"
hist_ui = conns.get(hist_prep, [{}])[0].get("destinationuid")
assert objs[hist_ui]["type"] == "alfred.workflow.userinterface.alfredui", "Missing history Alfred UI object"
assert objs[hist_ui]["config"].get("path") == "history.alfredui" and objs[hist_ui]["config"].get("launchmode") == 0, "Invalid history Alfred UI config"

cond = objs["063BAF88-77A7-461D-ACCB-3FD40C2D4017"]
assert cond["config"].get("hideelse") is False, "Toggle conditional must expose else branch for HUD"
else_targets = [c["destinationuid"] for c in conns.get("063BAF88-77A7-461D-ACCB-3FD40C2D4017", []) if "sourceoutputuid" not in c]
assert len(else_targets) == 1, "Missing else branch from toggle conditional"
hud_ui = objs[else_targets[0]]
assert hud_ui["type"] == "alfred.workflow.userinterface.alfredui" and hud_ui["config"].get("path") == "hud.alfredui" and hud_ui["config"].get("launchmode") == 1, "Invalid HUD Alfred UI config"

ext = [o for o in objs.values() if o.get("type") == "alfred.workflow.trigger.external" and o.get("config", {}).get("triggerid") == "toggle_dictation"]
assert len(ext) == 1, "Missing toggle_dictation external trigger"
assert conns.get(ext[0]["uid"], [{}])[0].get("destinationuid") == "1818A83B-5F44-4E96-88C2-D3284F397B26", "External trigger not wired to toggle_rec.sh"
ver = p.get("version")
assert ver == expected_ver, f"Expected version {expected_ver}, got {ver}"
' "$EXPECTED_VERSION" && ARCHIVE_LIST=$(unzip -l "./Whisper Alfred.alfredworkflow") && python3 -c '
import sys
lines = sys.argv[1].splitlines()
in_body = False
names = set()
for line in lines:
    if line.strip().startswith("---------"):
        if not in_body:
            in_body = True
            continue
        break
    if in_body:
        parts = line.split(None, 3)
        if len(parts) == 4:
            names.add(parts[3])

for required in [
    "info.plist",
    "icon.png",
    "history.alfredui/ui.json",
    "history.alfredui/scripts/history_action.sh",
    "hud.alfredui/ui.json",
    "hud.alfredui/scripts/hud_pulse.sh",
    "hud.alfredui/scripts/hud_action.sh",
    "scripts/prune_filter.sh",
    "scripts/history_prepare.sh",
    "scripts/toggle_rec.sh",
    "scripts/transcribe.sh",
    "scripts/polish.sh",
    "scripts/prune.sh",
    "scripts/open_recordings.sh",
]:
    assert required in names, f"Missing {required} in packaged workflow"

for forbidden in [
    "scripts/history_action.sh",
    "scripts/hud_action.sh",
    "scripts/hud_pulse.sh",
    "scripts/package.sh",
]:
    assert forbidden not in names, f"Unexpected duplicate or packaging script {forbidden} in packaged workflow"
' "$ARCHIVE_LIST"; then
    echo "[PASS] info.plist and packaged workflow include 1A, 1B, and 1D2 assets"
else
    echo "[FAIL] info.plist or packaged workflow check failed for 1A/1B/1D2"
    exit 1
fi

echo "=== All Tests Passed Successfully ==="
