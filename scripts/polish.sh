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

if [[ "$ENABLE" != "true" ]]; then
    printf "%s" "$TEXT_INPUT"
    exit 0
fi

if [[ -z "$MISTRAL_API_KEY" ]]; then
    printf "%s" "$TEXT_INPUT"
    exit 0
fi

MODEL="${POLISH_MODEL:-mistral-small-latest}"

# Escape JSON string safely via osascript JSON stringify
JSON_INPUT=$(osascript -l JavaScript -e "JSON.stringify('$TEXT_INPUT')")

PROMPT="You are a text cleanup assistant. Fix grammar, remove filler words (such as um, uh, like), eliminate speech repetitions, and fix punctuation. Return ONLY the polished text with no introduction, explanation, or markdown wrappers."

PAYLOAD=$(osascript -l JavaScript -e "
    JSON.stringify({
        model: '$MODEL',
        messages: [
            { role: 'system', content: '$PROMPT' },
            { role: 'user', content: $JSON_INPUT }
        ],
        temperature: 0.2
    });
")

RESPONSE=$(curl -s https://api.mistral.ai/v1/chat/completions \
  -H "Authorization: Bearer $MISTRAL_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

POLISHED=$(osascript -l JavaScript -e "
    var resp = $RESPONSE;
    if (resp && resp.choices && resp.choices[0] && resp.choices[0].message) {
        resp.choices[0].message.content.trim();
    } else {
        '';
    }
")

if [[ -n "$POLISHED" ]]; then
    printf "%s" "$POLISHED"
else
    printf "%s" "$TEXT_INPUT"
fi
