# Dictation Cleanup Prompt Examples & Comparison

This document records transcription post-processing prompt strategies from various apps and establishes the rationale for minimal-intervention dictation polishing.

---

## Example 1: TypeWhisper App

```text
Clean up the dictated text for readability. Fix punctuation, grammar, and formatting while preserving the original meaning and language. Return only the cleaned text.
```

### Analysis
* **Pros**: Simple and concise.
* **Cons**: Directing the LLM to prioritize "readability" and "fix grammar" causes models to rewrite sentences, alter informal cadence, and substitute vocabulary.

---

## Example 2: VoiceInk App

```text
Polish the dictated speech in <USER_MESSAGE> into clean, general-purpose text.

# Rules
- Use readable paragraphs and conventional abbreviations when helpful.
- Prefer a clean, neutral style unless the dictated speech clearly implies a different tone.
```

### Analysis
* **Pros**: Explicit rules structure.
* **Cons**: Instructing the model to "prefer a clean, neutral style" forces style neutralization, stripping the speaker's original voice, slang, emphasis, or colloquial phrasing.

---

## Example 3: Dictation Polisher v1 (Minimal Intervention)

```text
# Role
You are an expert voice-to-text post-processor. Your job is to convert spoken dictation into natural written text with minimal intervention.

# Instructions
- **Punctuation & Formatting:** Insert commas, periods, and paragraph breaks where natural spoken pauses occur.
- **Artifact Removal:** Omit conversational fillers ("uh", "um", "sort of", "like") and stutters.
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
</example>
```

### Analysis
* **Pros**:
  1. **Minimal Intervention Core**: Directs the LLM to modify only speech artifacts and self-corrections while strictly preserving vocabulary and sentence structure.
  2. **Self-Correction Handling**: Clearly instructs how mid-sentence changes of mind should be repaired without dropping valid context.
  3. **Voice Preservation**: Explicit rule preventing tone elevation or neutralization.
  4. **Few-Shot Anchor Examples**: XML-structured input/output pairs demonstrate exact expected transformations.

---

## Default Configuration in Alfred Workflow

The workflow uses Dictation Polisher v1 as its default prompt in [`scripts/polish.sh`](../scripts/polish.sh). Users can override the system prompt via the `CLEANUP_SYSTEM_PROMPT` environment variable.
