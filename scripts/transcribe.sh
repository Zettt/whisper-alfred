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

case "$PROVIDER" in
mistral)
	if [[ -z "$MISTRAL_API_KEY" ]]; then
		echo "Error: MISTRAL_API_KEY environment variable is not set." >&2
		exit 1
	fi

	RESPONSE=$(curl -s --location 'https://api.mistral.ai/v1/audio/transcriptions' \
		--header "Authorization: Bearer $MISTRAL_API_KEY" \
		--form "file=@$AUDIO_FILE" \
		--form 'model="voxtral-mini-latest"')

	TEXT=$(osascript -l JavaScript -e '
            function run(argv) {
                try {
                    var resp = JSON.parse(argv[0]);
                    if (resp.error) {
                        return "[Alfred Transcribe Error: Mistral API error]";
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

	printf "%s" "$TEXT"
	;;

groq)
	if [[ -z "$GROQ_API_KEY" ]]; then
		echo "Error: GROQ_API_KEY environment variable is not set." >&2
		exit 1
	fi

	RESPONSE=$(curl -s https://api.groq.com/openai/v1/audio/transcriptions \
		-H "Authorization: Bearer $GROQ_API_KEY" \
		-F "file=@$AUDIO_FILE" \
		-F "model=whisper-large-v3-turbo" \
		-F "response_format=json")

	TEXT=$(osascript -l JavaScript -e '
            function run(argv) {
                try {
                    var resp = JSON.parse(argv[0]);
                    if (resp.error) {
                        return "[Alfred Transcribe Error: Groq API error]";
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

	printf "%s" "$TEXT"
	;;

local | parakeet)
	ENDPOINT="${PARAKEET_ENDPOINT:-${LOCAL_ENDPOINT:-http://127.0.0.1:8080/v1/audio/transcriptions}}"

	# Connect with 2-second timeout to handle unstarted local server gracefully
	RESPONSE=$(curl -s --connect-timeout 2 "$ENDPOINT" \
		-F "file=@$AUDIO_FILE" \
		-F "model=local" 2>/dev/null || echo '{"error":"LOCAL_SERVER_OFFLINE"}')

	TEXT=$(osascript -l JavaScript -e '
            function run(argv) {
                try {
                    var resp = JSON.parse(argv[0]);
                    if (resp.error) {
                        if (resp.error === "LOCAL_SERVER_OFFLINE") {
                            return "[Alfred Transcribe Error: Could not connect to local server on " + argv[1] + ". Please verify your local server is running.]";
                        }
                        return "[Alfred Transcribe Error: Local server error]";
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

	printf "%s" "$TEXT"
	;;

*)
	echo "Error: Unknown provider '$PROVIDER'" >&2
	exit 1
	;;
esac
