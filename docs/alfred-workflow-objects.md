# Alfred 6 Workflow Building Blocks Reference

## Workflow Objects Topology

```text
[ Hotkey Trigger ] ──┐
[ Keyword: whisper ]─┼──▶ [ Run Script: ./scripts/toggle_rec.sh "$1" ]
[ External: toggle_dictation ] ──┘        │
                                          ▼
                       [ Conditional: Output not empty ]
                          │                         │
                 (empty: started)           (path: stopped)
                          │                         │
                          ▼                         ▼
           [ Alfred UI: hud.alfredui ]   [ Run Script: ./scripts/transcribe.sh "$1" ]
                                                    │
                                                    ▼
                                         [ Run Script: ./scripts/polish.sh "$1" ]
                                                    │
                                                    ▼
                                         [ Conditional: Error prefix? ]
                                          │         │             │
                                   (match: error)   │      (all outputs)
                                          │         │             │
                                          ▼         ▼             ▼
                                 [ Notification ] [ Clipboard ] [ Args & Vars ]
                                                                  │
                                                                  ▼
                                                       [ Run Script: ./scripts/prune.sh "$1" ]

[ Keyword: whisper cancel ]  ──▶ [ Run Script: ./scripts/toggle_rec.sh cancel ]
[ Keyword: whisper open ]    ──▶ [ Run Script: ./scripts/open_recordings.sh "$1" ]
[ Script Filter: whisper prune ] (./scripts/prune_filter.sh "$1") ──▶ [ Run Script: ./scripts/prune.sh "$1" ]
[ Keyword: whisper history ] ──▶ [ Run Script: ./scripts/history_prepare.sh ] ──▶ [ Alfred UI: history.alfredui ]
```

## Object Configurations

### 1. Dictation Triggers

- **Hotkey Trigger**: Passes through to `./scripts/toggle_rec.sh` (default: `⇧⌃=`).
- **Keyword (`whisper`)**: Manual dictation toggle (`argumenttype: 2`, no argument).
- **External Trigger (`toggle_dictation`)**: Invoked by `hud.alfredui` (`hud_action.sh stop`) via AppleScript to stop an active recording and continue the transcription pipeline.

### 2. Toggle Controller (`./scripts/toggle_rec.sh "$1"`)

- **Language:** `/bin/zsh`
- **Behavior:** Starts `ffmpeg` recording in the background (`.m4a` AAC or `.wav` PCM) and exits with empty output; on second invocation, stops `ffmpeg` and prints the recorded audio file path to `stdout`.
- **Cancel Mode (`./scripts/toggle_rec.sh cancel`):** Triggered via `whisper cancel` or `hud_action.sh cancel` to terminate `ffmpeg`, clear cache state, and delete partial audio.

### 3. Floating Status HUD (`hud.alfredui`)

- **Launch Mode:** External borderless window (`launchmode: 1`), launched on the `else` branch when `toggle_rec.sh` starts recording.
- **Pulse (`./scripts/hud_pulse.sh`):** Polls cache state every `0.25s` and updates `Recording...`, `Transcribing...`, or `Polishing...`, finishing automatically when the pipeline completes.
- **Actions (`./scripts/hud_action.sh`):** Handles Stop (`↩︎` → `toggle_dictation` external trigger) and Cancel (`⎋` → `toggle_rec.sh cancel`).

### 4. Transcription (`./scripts/transcribe.sh "$1"`)

- **Language:** `/bin/zsh`
- **Providers:** `mistral` (`voxtral-mini-latest`), `groq` (`whisper-large-v3-turbo`), or `local` (`PARAKEET_ENDPOINT`).
- **Sidecar:** Writes a JSON metadata sidecar alongside the audio file and stores its path in `$CACHE_DIR/latest_sidecar.txt`.

### 5. LLM Cleanup (`./scripts/polish.sh "$1"`)

- **Language:** `/bin/zsh`
- **Providers:** `mistral` (`mistral-small-latest`), `groq` (`llama-3.1-8b-instant`), or `local` (`LOCAL_CLEANUP_ENDPOINT`).
- **Behavior:** Bypasses cleanup on error strings or when `ENABLE_CLEANUP` is disabled; otherwise polishes text and updates the sidecar JSON.

### 6. Output & Background Retention

- **Error Conditional:** Routes `[Whisper Alfred Error:...]` strings to macOS Notification while still copying output to clipboard.
- **Copy to Clipboard:** Automatically pastes to the frontmost app (`{query}`).
- **Background Pruner (`./scripts/prune.sh "$1"`):** Runs retention cleanup (`RETENTION_DAYS` and `MAX_RECORDINGS`) after dictation.

### 7. Maintenance & History Triggers

- **`whisper open`**: Runs `./scripts/open_recordings.sh "$1"` to open `$DATA_DIR/recordings` in Finder.
- **`whisper prune`**: Script Filter running `./scripts/prune_filter.sh "$1"` to display recording counts and disk usage, passing `auto`, `recordings`, `keep N`, `archive`, `force`, or `<N>` days to `./scripts/prune.sh "$1"`.
- **`whisper history`**: Runs `./scripts/history_prepare.sh` to build `history.alfredui/resources/history_data.json` from sidecars, then opens `history.alfredui` (`launchmode: 0`) for search, audio playback, clipboard copy, and deletion (`./scripts/history_action.sh`).

### 8. Workflow Configuration Variables (`workflow/info.plist`)

| Variable | Default Value | Description |
| --- | --- | --- |
| `TRANSCRIPTION_PROVIDER` | `mistral` | Transcription backend (`mistral`, `groq`, or `local`) |
| `TRANSCRIPTION_MODEL` | *(empty)* | Optional transcription model override |
| `PARAKEET_ENDPOINT` | `http://127.0.0.1:8080/v1/audio/transcriptions` | Local transcription endpoint URL |
| `MISTRAL_API_KEY` | *(empty)* | Secret key for Mistral AI (`variablesdontexport`) |
| `GROQ_API_KEY` | *(empty)* | Secret key for Groq Cloud (`variablesdontexport`) |
| `ENABLE_CLEANUP` | `true` | Enable LLM text cleanup (`true`/`false`) |
| `CLEANUP_PROVIDER` | `mistral` | Cleanup backend (`mistral`, `groq`, or `local`) |
| `CLEANUP_MODEL` | *(empty)* | Optional cleanup model override |
| `CLEANUP_SYSTEM_PROMPT` | *(empty)* | Optional custom system prompt override |
| `LOCAL_CLEANUP_ENDPOINT` | `http://127.0.0.1:11434/v1/chat/completions` | Local LLM cleanup endpoint URL |
| `AUDIO_FORMAT` | `m4a` | Audio container format (`m4a` or `wav`) |
| `MAX_RECORDING_DURATION` | `600` | Maximum recording length in seconds (`0` disables limit) |
| `RETENTION_DAYS` | `30` | Retention period in days for recordings and sidecars |
| `MAX_RECORDINGS` | `0` | Maximum recent recordings to retain (`0` disables cap) |
