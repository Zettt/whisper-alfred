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
CACHE_DIR="${alfred_workflow_cache:-$HOME/Library/Caches/com.runningwithcrayons.Alfred/Workflow Data/transcribe}"
mkdir -p "$CACHE_DIR"

TEXT=""
MODEL=""
ENDPOINT=""

case "$PROVIDER" in
mistral)
	if [[ -z "$MISTRAL_API_KEY" ]]; then
		echo "Error: MISTRAL_API_KEY environment variable is not set." >&2
		exit 1
	fi

	MODEL="${TRANSCRIPTION_MODEL:-voxtral-mini-latest}"

	RESPONSE=$(curl -s --location 'https://api.mistral.ai/v1/audio/transcriptions' \
		--header "Authorization: Bearer $MISTRAL_API_KEY" \
		--form "file=@$AUDIO_FILE" \
		--form "model=\"$MODEL\"")

	TEXT=$(osascript -l JavaScript -e '
            function run(argv) {
                try {
                    var resp = JSON.parse(argv[0]);
                    if (resp.error) {
                        return "[Whisper Alfred Error: Mistral API error]";
                    }
                    if (resp.text) {
                        return resp.text.trim();
                    }
                    return "";
                } catch(e) {
                    return "";
                }
            }
        ' "$RESPONSE")
	;;

groq)
	if [[ -z "$GROQ_API_KEY" ]]; then
		echo "Error: GROQ_API_KEY environment variable is not set." >&2
		exit 1
	fi

	MODEL="${TRANSCRIPTION_MODEL:-whisper-large-v3-turbo}"

	RESPONSE=$(curl -s https://api.groq.com/openai/v1/audio/transcriptions \
		-H "Authorization: Bearer $GROQ_API_KEY" \
		-F "file=@$AUDIO_FILE" \
		-F "model=$MODEL" \
		-F "response_format=json")

	TEXT=$(osascript -l JavaScript -e '
            function run(argv) {
                try {
                    var resp = JSON.parse(argv[0]);
                    if (resp.error) {
                        return "[Whisper Alfred Error: Groq API error]";
                    }
                    if (resp.text) {
                        return resp.text.trim();
                    }
                    return "";
                } catch(e) {
                    return "";
                }
            }
        ' "$RESPONSE")
	;;

local | parakeet)
	ENDPOINT="${LOCAL_TRANSCRIPTION_ENDPOINT:-${LOCAL_ENDPOINT:-${PARAKEET_ENDPOINT:-http://127.0.0.1:8080/v1/audio/transcriptions}}}"
	MODEL="${TRANSCRIPTION_MODEL:-local}"

	# Connect with 2-second timeout to handle unstarted local server gracefully
	RESPONSE=$(curl -s --connect-timeout 2 "$ENDPOINT" \
		-F "file=@$AUDIO_FILE" \
		-F "model=$MODEL" 2>/dev/null || echo '{"error":"LOCAL_SERVER_OFFLINE"}')

	TEXT=$(osascript -l JavaScript -e '
            function run(argv) {
                try {
                    var resp = JSON.parse(argv[0]);
                    if (resp.error) {
                        if (resp.error === "LOCAL_SERVER_OFFLINE") {
                            return "[Whisper Alfred Error: Could not connect to local server on " + argv[1] + ". Please verify your local server is running.]";
                        }
                        return "[Whisper Alfred Error: Local server error]";
                    }
                    if (resp.text) {
                        return resp.text.trim();
                    }
                    return "";
                } catch(e) {
                    return "";
                }
            }
        ' "$RESPONSE" "$ENDPOINT")
	;;

*)
	echo "Error: Unknown provider '$PROVIDER'" >&2
	exit 1
	;;
esac

# Create matching JSON sidecar file alongside .wav
JSON_FILE="${AUDIO_FILE%.wav}.json"
TIMESTAMP_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

osascript -l JavaScript -e '
    function run(argv) {
        var fs = $.NSFileManager.defaultManager;
        var data = {
            timestamp: argv[0],
            audio_file: argv[1],
            transcription: {
                provider: argv[2],
                model: argv[3],
                raw_text: argv[4]
            },
            cleanup: {
                enabled: false,
                provider: null,
                model: null,
                polished_text: null
            }
        };
        var str = $.NSString.stringWithString(JSON.stringify(data, null, 2));
        str.writeToFileAtomicallyEncodingError(argv[5], true, $.NSUTF8StringEncoding, null);
    }
' "$TIMESTAMP_ISO" "$AUDIO_FILE" "$PROVIDER" "$MODEL" "$TEXT" "$JSON_FILE" 2>/dev/null || true

# Store active JSON sidecar pointer in cache for polish script
echo "$JSON_FILE" > "$CACHE_DIR/latest_sidecar.txt"

printf "%s" "$TEXT"
