#!/bin/zsh

# Audio Transcription Dispatcher for Alfred Workflow
# Supports Mistral AI (voxtral), Groq (whisper), and local Parakeet endpoints

set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

AUDIO_FILE=$(echo "$1" | tr -d '\r\n')

if [[ -z "$AUDIO_FILE" ]]; then
    exit 0
fi

if [[ ! -f "$AUDIO_FILE" ]]; then
    echo "Error: Audio file does not exist at path: '$AUDIO_FILE'" >&2
    exit 1
fi

# Check file size (WAV files under 4000 bytes contain negligible audio data)
FILE_SIZE=$(wc -c < "$AUDIO_FILE" | tr -d ' ')
if [[ "$FILE_SIZE" -lt 4000 ]]; then
    echo "Error: Audio recording is empty or too short ($FILE_SIZE bytes)." >&2
    exit 1
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
          
        RESULT=$(osascript -l JavaScript -e "
            try {
                var resp = $RESPONSE;
                if (resp.error) {
                    console.log('API Error: ' + JSON.stringify(resp.error));
                    '';
                } else if (resp.text) {
                    resp.text.trim();
                } else {
                    '';
                }
            } catch (e) {
                '';
            }
        " 2>&1)

        if [[ "$RESULT" == API\ Error:* ]]; then
            echo "$RESULT" >&2
            exit 1
        fi

        printf "%s" "$RESULT"
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

        RESULT=$(osascript -l JavaScript -e "
            try {
                var resp = $RESPONSE;
                if (resp.error) {
                    console.log('API Error: ' + JSON.stringify(resp.error));
                    '';
                } else if (resp.text) {
                    resp.text.trim();
                } else {
                    '';
                }
            } catch (e) {
                '';
            }
        " 2>&1)

        if [[ "$RESULT" == API\ Error:* ]]; then
            echo "$RESULT" >&2
            exit 1
        fi

        printf "%s" "$RESULT"
        ;;

    parakeet)
        ENDPOINT="${PARAKEET_ENDPOINT:-http://127.0.0.1:8080/v1/audio/transcriptions}"

        RESPONSE=$(curl -s "$ENDPOINT" \
          -F "file=@$AUDIO_FILE" \
          -F "model=parakeet")

        RESULT=$(osascript -l JavaScript -e "
            try {
                var resp = $RESPONSE;
                if (resp.text) { resp.text.trim(); } else { ''; }
            } catch(e) { ''; }
        ")

        printf "%s" "$RESULT"
        ;;

    *)
        echo "Error: Unknown provider '$PROVIDER'" >&2
        exit 1
        ;;
esac
