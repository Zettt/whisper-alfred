#!/bin/zsh

# Audio Transcription Dispatcher for Alfred Workflow
# Supports Mistral AI (voxtral), Groq (whisper), and Local Server endpoints (Whisper.cpp / Faster-Whisper / Parakeet)

set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

AUDIO_FILE=$(echo "$1" | tr -d '\r\n')

if [[ -z "$AUDIO_FILE" || ! -f "$AUDIO_FILE" ]]; then
	exit 0
fi

PROVIDER="${TRANSCRIPTION_PROVIDER:-mistral}"
CACHE_DIR="${alfred_workflow_cache:-$HOME/Library/Caches/com.runningwithcrayons.Alfred/Workflow Data/com.zettt.whisper-alfred}"
STATUS_FILE="$CACHE_DIR/status.txt"
mkdir -p "$CACHE_DIR"
echo "transcribing" > "$STATUS_FILE"

TEXT=""
MODEL=""
ENDPOINT=""

trim() {
	local var="$*"
	var="${var#"${var%%[![:space:]]*}"}"
	var="${var%"${var##*[![:space:]]}"}"
	printf '%s' "$var"
}

parse_json_transcription() {
	local resp="$1"
	local endpoint="$2"
	local err text

	if command -v jq >/dev/null 2>&1 && [[ "${FORCE_PLUTIL:-0}" != "1" ]]; then
		err=$(printf "%s" "$resp" | jq -r 'if .error | type == "object" then .error.message // (.error | tostring) elif .error then (.error | tostring) else empty end' 2>/dev/null || true)
		if [[ -n "$err" ]]; then
			if [[ "$err" == "LOCAL_SERVER_OFFLINE" ]]; then
				printf "%s" "[Whisper Alfred Error: Could not connect to local server on ${endpoint}. Please verify your local server is running.]"
			else
				printf "%s" "[Whisper Alfred Error: API error - ${err}]"
			fi
			return
		fi
		text=$(printf "%s" "$resp" | jq -r '.text // empty' 2>/dev/null || true)
		trim "$text"
		return
	fi

	# Fallback to macOS plutil
	err=$(plutil -extract error.message raw -o - - <<< "$resp" 2>/dev/null || plutil -extract error raw -o - - <<< "$resp" 2>/dev/null || true)
	if [[ "$err" == "(null)" ]]; then
		err=""
	fi
	if [[ -n "$err" ]]; then
		if [[ "$err" == "LOCAL_SERVER_OFFLINE" ]]; then
			printf "%s" "[Whisper Alfred Error: Could not connect to local server on ${endpoint}. Please verify your local server is running.]"
		else
			printf "%s" "[Whisper Alfred Error: API error - ${err}]"
		fi
		return
	fi

	text=$(plutil -extract text raw -o - - <<< "$resp" 2>/dev/null || true)
	if [[ -n "$text" && "$text" != "(null)" ]]; then
		trim "$text"
	fi
}

escape_json_val() {
	if command -v jq >/dev/null 2>&1 && [[ "${FORCE_PLUTIL:-0}" != "1" ]]; then
		printf '%s' "$1" | jq -R -s '.'
	else
		local str="$1"
		str="${str//\\/\\\\}"
		str="${str//\"/\\\"}"
		str="${str//$'\n'/\\n}"
		str="${str//$'\r'/\\r}"
		str="${str//$'\t'/\\t}"
		printf '"%s"' "$str"
	fi
}

case "$PROVIDER" in
mistral)
	if [[ -z "$MISTRAL_API_KEY" ]]; then
		ERR_MSG="[Whisper Alfred Error: MISTRAL_API_KEY environment variable is not set.]"
		rm -f "$STATUS_FILE"
		printf "%s" "$ERR_MSG"
		echo "$ERR_MSG" >&2
		exit 1
	fi

	MODEL="${TRANSCRIPTION_MODEL:-voxtral-mini-latest}"
	if [[ "$MODEL" == "whisper-large-v3-turbo" || "$MODEL" == "whisper-large-v3" || "$MODEL" == "local" ]]; then
		MODEL="voxtral-mini-latest"
	fi

	RESPONSE=$(curl -s --location 'https://api.mistral.ai/v1/audio/transcriptions' \
		--header "Authorization: Bearer $MISTRAL_API_KEY" \
		--form "file=@$AUDIO_FILE" \
		--form "model=\"$MODEL\"" 2>/dev/null || echo '{"error":"Could not reach Mistral API"}')

	TEXT=$(parse_json_transcription "$RESPONSE")
	;;

groq)
	if [[ -z "$GROQ_API_KEY" ]]; then
		ERR_MSG="[Whisper Alfred Error: GROQ_API_KEY environment variable is not set.]"
		rm -f "$STATUS_FILE"
		printf "%s" "$ERR_MSG"
		echo "$ERR_MSG" >&2
		exit 1
	fi

	MODEL="${TRANSCRIPTION_MODEL:-whisper-large-v3-turbo}"
	if [[ "$MODEL" == "voxtral-mini-latest" || "$MODEL" == "local" ]]; then
		MODEL="whisper-large-v3-turbo"
	fi

	RESPONSE=$(curl -s https://api.groq.com/openai/v1/audio/transcriptions \
		-H "Authorization: Bearer $GROQ_API_KEY" \
		-F "file=@$AUDIO_FILE" \
		-F "model=$MODEL" \
		-F "response_format=json" 2>/dev/null || echo '{"error":"Could not reach Groq API"}')

	TEXT=$(parse_json_transcription "$RESPONSE")
	;;

local | parakeet)
	ENDPOINT="${LOCAL_TRANSCRIPTION_ENDPOINT:-${LOCAL_ENDPOINT:-${PARAKEET_ENDPOINT:-http://127.0.0.1:8080/v1/audio/transcriptions}}}"
	MODEL="${TRANSCRIPTION_MODEL:-local}"
	if [[ "$MODEL" == "voxtral-mini-latest" || "$MODEL" == "whisper-large-v3-turbo" || "$MODEL" == "whisper-large-v3" ]]; then
		MODEL="local"
	fi

	# Connect with 2-second timeout to handle unstarted local server gracefully
	RESPONSE=$(curl -s --noproxy '*' --connect-timeout 2 "$ENDPOINT" \
		-F "file=@$AUDIO_FILE" \
		-F "model=$MODEL" 2>/dev/null || echo '{"error":"LOCAL_SERVER_OFFLINE"}')

	TEXT=$(parse_json_transcription "$RESPONSE" "$ENDPOINT")
	;;

*)
	ERR_MSG="[Whisper Alfred Error: Unknown provider '$PROVIDER']"
	rm -f "$STATUS_FILE"
	printf "%s" "$ERR_MSG"
	echo "$ERR_MSG" >&2
	exit 1
	;;
esac

# Sidecar metadata file path alongside audio file
JSON_FILE="${AUDIO_FILE%.*}.json"
JSON_TMP="${JSON_FILE}.tmp"
TIMESTAMP_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Synchronously write matching JSON sidecar file atomically before polish.sh runs
JSON_AUDIO=$(escape_json_val "$AUDIO_FILE")
JSON_PROV=$(escape_json_val "$PROVIDER")
JSON_MODEL=$(escape_json_val "$MODEL")
JSON_TEXT=$(escape_json_val "$TEXT")

cat <<EOF > "$JSON_TMP"
{
  "timestamp": "$TIMESTAMP_ISO",
  "audio_file": $JSON_AUDIO,
  "transcription": {
    "provider": $JSON_PROV,
    "model": $JSON_MODEL,
    "raw_text": $JSON_TEXT
  },
  "cleanup": {
    "enabled": false,
    "provider": null,
    "model": null,
    "polished_text": null
  }
}
EOF
mv "$JSON_TMP" "$JSON_FILE"

# Store active JSON sidecar pointer in cache for polish script
echo "$JSON_FILE" > "$CACHE_DIR/latest_sidecar.txt"

if [[ "$TEXT" == \[Whisper\ Alfred\ Error:* ]] || [[ "${ENABLE_CLEANUP:-false}" != "1" && "${ENABLE_CLEANUP:-false}" != "true" ]]; then
	rm -f "$STATUS_FILE"
else
	echo "polishing" > "$STATUS_FILE"
fi

# Output transcription to stdout for Alfred
printf "%s" "$TEXT"
