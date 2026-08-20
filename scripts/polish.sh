#!/bin/zsh

# LLM Text Cleanup Script for Alfred Workflow
# Supports Mistral AI, Groq, and Local Ollama / LocalAI LLM endpoints

set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

TEXT_INPUT="$1"

if [[ -z "$TEXT_INPUT" ]]; then
	TEXT_INPUT=$(cat)
fi

if [[ -z "$TEXT_INPUT" ]]; then
	exit 0
fi

ENABLE="${ENABLE_CLEANUP:-false}"
CACHE_DIR="${alfred_workflow_cache:-$HOME/Library/Caches/com.runningwithcrayons.Alfred/Workflow Data/transcribe}"
LATEST_SIDECAR="$CACHE_DIR/latest_sidecar.txt"

if [[ "$ENABLE" != "1" && "$ENABLE" != "true" ]]; then
	printf "%s" "$TEXT_INPUT"
	exit 0
fi

PROVIDER="${CLEANUP_PROVIDER:-${POLISH_PROVIDER:-mistral}}"

case "$PROVIDER" in
mistral)
	if [[ -z "$MISTRAL_API_KEY" ]]; then
		printf "%s" "$TEXT_INPUT"
		exit 0
	fi
	MODEL="${CLEANUP_MODEL:-${POLISH_MODEL:-mistral-small-latest}}"
	ENDPOINT="https://api.mistral.ai/v1/chat/completions"
	AUTH_HEADER="Authorization: Bearer $MISTRAL_API_KEY"
	;;

groq)
	if [[ -z "$GROQ_API_KEY" ]]; then
		printf "%s" "$TEXT_INPUT"
		exit 0
	fi
	MODEL="${CLEANUP_MODEL:-${POLISH_MODEL:-llama-3.1-8b-instant}}"
	ENDPOINT="https://api.groq.com/openai/v1/chat/completions"
	AUTH_HEADER="Authorization: Bearer $GROQ_API_KEY"
	;;

local)
	MODEL="${CLEANUP_MODEL:-${POLISH_MODEL:-llama3.2}}"
	ENDPOINT="${LOCAL_CLEANUP_ENDPOINT:-${LOCAL_LLM_ENDPOINT:-http://127.0.0.1:11434/v1/chat/completions}}"
	AUTH_HEADER="Authorization: Bearer local"
	;;

*)
	printf "%s" "$TEXT_INPUT"
	exit 0
	;;
esac

DEFAULT_PROMPT="# Role
You are an expert voice-to-text post-processor. Your job is to convert spoken dictation into natural written text with minimal intervention.

# Instructions
- **Punctuation & Formatting:** Insert commas, periods, and paragraph breaks where natural spoken pauses occur.
- **Artifact Removal:** Omit conversational fillers (\"uh\", \"um\", \"sort of\", \"like\") and stutters.
- **Repair Self-Corrections:** If a thought is corrected mid-sentence, output only the intended correction.
- **Preserve Voice:** Maintain the speaker's exact vocabulary, style, and sentence sequence. Do not elevate or neutralize informal tone if the speaker intended it.
- **Output:** Output only the cleaned transcript with no preamble or wrapping.

# Examples

<example>
<USER_MESSAGE>
hey mark um just wanted to see if the report is ready yet or if you need more time let me know
</USER_MESSAGE>
<output>
Hey Mark, just wanted to see if the report is ready yet or if you need more time. Let me know.
</output>
</example>

<example>
<USER_MESSAGE>
we should schedule the release for next friday wait actually thursday morning would be better
</USER_MESSAGE>
<output>
We should schedule the release for next Thursday morning.
</output>
</example>"

PROMPT="${CLEANUP_SYSTEM_PROMPT:-$DEFAULT_PROMPT}"

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

RESPONSE=$(curl -s --connect-timeout 2 "$ENDPOINT" \
	-H "$AUTH_HEADER" \
	-H "Content-Type: application/json" \
	-d "$PAYLOAD" 2>/dev/null || echo '{"error":"LOCAL_LLM_OFFLINE"}')

POLISHED=$(osascript -l JavaScript -e '
    function run(argv) {
        try {
            var resp = JSON.parse(argv[0]);
            if (resp.error) {
                return "";
            }
            if (resp && resp.choices && resp.choices[0] && resp.choices[0].message) {
                return resp.choices[0].message.content.trim();
            }
            return "";
        } catch(e) {
            return "";
        }
    }
' "$RESPONSE")

FINAL_TEXT="$TEXT_INPUT"
if [[ -n "$POLISHED" ]]; then
	FINAL_TEXT="$POLISHED"
fi

# Update matching JSON sidecar file with cleanup metadata if available
if [[ -f "$LATEST_SIDECAR" ]]; then
	JSON_FILE=$(cat "$LATEST_SIDECAR" | tr -d '\r\n')
	if [[ -f "$JSON_FILE" ]]; then
		osascript -l JavaScript -e '
            function run(argv) {
                try {
                    var jsonPath = argv[0];
                    var content = $.NSString.stringWithContentsOfFileEncodingError(jsonPath, $.NSUTF8StringEncoding, null);
                    if (content) {
                        var data = JSON.parse(content.js);
                        data.cleanup = {
                            enabled: true,
                            provider: argv[1],
                            model: argv[2],
                            polished_text: argv[3]
                        };
                        var str = $.NSString.stringWithString(JSON.stringify(data, null, 2));
                        str.writeToFileAtomicallyEncodingError(jsonPath, true, $.NSUTF8StringEncoding, null);
                    }
                } catch(e) {}
            }
        ' "$JSON_FILE" "$PROVIDER" "$MODEL" "$FINAL_TEXT" 2>/dev/null || true
	fi
fi

printf "%s" "$FINAL_TEXT"
