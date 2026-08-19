#!/bin/zsh

# Audio Transcription Dispatcher for Alfred Workflow
# Supports Mistral AI (voxtral), Groq (whisper), and local Parakeet endpoints

set -e

AUDIO_FILE="$1"

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
          --form "file=@\"$AUDIO_FILE\"" \
          --form 'model="voxtral-mini-latest"')
          
        osascript -l JavaScript -e "
            var resp = $RESPONSE;
            if (resp.text) { resp.text.trim(); } else { ''; }
        "
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

        osascript -l JavaScript -e "
            var resp = $RESPONSE;
            if (resp.text) { resp.text.trim(); } else { ''; }
        "
        ;;

    parakeet)
        ENDPOINT="${PARAKEET_ENDPOINT:-http://127.0.0.1:8080/v1/audio/transcriptions}"

        RESPONSE=$(curl -s "$ENDPOINT" \
          -F "file=@$AUDIO_FILE" \
          -F "model=parakeet")

        osascript -l JavaScript -e "
            var resp = $RESPONSE;
            if (resp.text) { resp.text.trim(); } else { ''; }
        "
        ;;

    *)
        echo "Error: Unknown provider '$PROVIDER'" >&2
        exit 1
        ;;
esac
