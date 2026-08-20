#!/bin/zsh

# LLM Text Polish Script for Alfred Workflow
# Fixes grammar, filler words, speech repetitions using Mistral AI

set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

TEXT_INPUT="$1"

if [[ -z "$TEXT_INPUT" ]]; then
    # Read from standard input if no argument passed
    TEXT_INPUT=$(cat)
fi

if [[ -z "$TEXT_INPUT" ]]; then
    exit 0
fi

ENABLE="${ENABLE_CLEANUP:-false}"

if [[ "$ENABLE" != "true" || -z "$MISTRAL_API_KEY" ]]; then
    printf "%s" "$TEXT_INPUT"
    exit 0
fi

MODEL="${POLISH_MODEL:-mistral-small-latest}"

PROMPT="You are a text cleanup assistant. Fix grammar, remove filler words (such as um, uh, like), eliminate speech repetitions, and fix punctuation. Return ONLY the polished text with no introduction, explanation, or markdown wrappers."

# Safely construct JSON payload using osascript argument passing
PAYLOAD=$(osascript -l JavaScript -e '
    function run(argv) {
        return JSON.stringify({
            model: argv[0],
            messages: [
                { role: "system", content: argv[1] },
                { role: "user", content: argv[2] }
            ],
            temperature: 0.2
        });
    }
' "$MODEL" "$PROMPT" "$TEXT_INPUT")

RESPONSE=$(curl -s https://api.mistral.ai/v1/chat/completions \
  -H "Authorization: Bearer $MISTRAL_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

POLISHED=$(osascript -l JavaScript -e '
    function run(argv) {
        try {
            var resp = JSON.parse(argv[0]);
            if (resp && resp.choices && resp.choices[0] && resp.choices[0].message) {
                return resp.choices[0].message.content.trim();
            }
            return "";
        } catch(e) {
            return "";
        }
    }
' "$RESPONSE")

if [[ -n "$POLISHED" ]]; then
    printf "%s" "$POLISHED"
else
    printf "%s" "$TEXT_INPUT"
fi
