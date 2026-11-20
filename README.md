# Whisper Alfred 🎙️

## Setup

Install `ffmpeg` via Homebrew:

```bash
brew install ffmpeg
```

Double-click `Whisper Alfred.alfredworkflow` in Finder (built at the repository root via `./scripts/package.sh` or downloaded from GitHub Releases) to import or update the workflow in Alfred.

*Note: macOS will prompt for Microphone permissions on first run. Ensure Alfred has microphone access under System Settings → Privacy & Security → Microphone.*

## Usage

Dictate text into any active application via the Hotkey (default: <kbd>⇧</kbd><kbd>⌃</kbd><kbd>=</kbd>) or via the `whisper` keyword.

Press once to start recording, and press again (or click **Stop** / press <kbd>↩︎</kbd> on the status HUD) to stop, transcribe, clean up, and paste the output into your frontmost application.

Available keywords:

- `whisper`: Start or stop dictation recording manually.
- `whisper cancel`: Abort an active dictation recording and delete partial audio.
- `whisper history`: Open the Transcript History window (`history.alfredui`) to search transcripts, inspect polished and raw text, play back audio, copy text, and delete entries.
- `whisper open`: Open the workflow’s recordings directory in Finder.
- `whisper prune`: Open an interactive Script Filter showing recording counts, storage usage, and prune actions (`auto`, `recordings`, `keep N`, `archive`, `force`, or `<N>` days).

### Features

- ⚡ **Hotkey Toggle:** Press once to start recording, press again to transcribe and paste into your frontmost app.
- 🪟 **Floating Status HUD:** Borderless Alfred UI window (`hud.alfredui`) displaying live recording duration, pipeline stage (`Recording...`, `Transcribing...`, `Polishing...`), Stop (<kbd>↩︎</kbd>), and Cancel (<kbd>⎋</kbd>) buttons.
- 📜 **Transcript History Browser:** Searchable Alfred UI browser (`history.alfredui`) with side-by-side polished and raw transcripts, audio playback, clipboard copy, and entry deletion.
- 🌐 **Multi-Provider Support:** Switch between Mistral AI, Groq Cloud, and offline Local AI for both transcription and cleanup.
- ✨ **LLM Text Cleanup:** Fixes grammar, removes filler words (*um, uh*), and cleans punctuation before pasting.
- 🔒 **Offline Local Mode:** Run speech recognition locally on Apple Silicon Metal GPU.
- 🧹 **Configurable Retention:** Prunes recordings older than `RETENTION_DAYS` (default: 30 days) and optionally caps stored recordings via `MAX_RECORDINGS`.

## Cloud Setup (Mistral AI & Groq Cloud)

Cloud providers offer fast setup and high accuracy:

- **Mistral AI:** Recommended for EU data residency (`voxtral-mini-latest` for transcription, `mistral-small-latest` for cleanup). Get key at [Mistral Console](https://admin.mistral.ai/organization/api-keys).
- **Groq Cloud:** Recommended for maximum speed and generous free tier (`whisper-large-v3-turbo` for transcription, `llama-3.1-8b-instant` for cleanup). Get key at [Groq Console](https://console.groq.com/keys).

## Local Setup (Offline Mode)

Run transcription locally on your Apple Silicon GPU using one of these engines:

| Engine | Best For | Setup | Binary / Command |
| --- | --- | --- | --- |
| **Whisper.cpp** | High accuracy (German/English), proper punctuation | Homebrew | `whisper-server -m ~/.models/ggml-base.bin --port 8080` |
| **Faster-Whisper** | Python CTranslate2 engine | `pip install faster-whisper-server` | `faster-whisper-server --port 8080 --model base` |
| **NVIDIA Parakeet** | Ultra-fast inference & low RAM on Apple Silicon | `pip install sherpa-onnx` | `sherpa-onnx-offline-http-server --port=8080` |

## Workflow Configuration

Set provider keys, endpoints, models, and retention settings in the Workflow’s Configuration:

| Environment Variable | Default Value | Description |
| --- | --- | --- |
| **`TRANSCRIPTION_PROVIDER`** | `mistral` | Transcription backend (`mistral`, `groq`, or `local`). |
| **`TRANSCRIPTION_MODEL`** | *(provider default)* | Override default transcription model string. |
| **`PARAKEET_ENDPOINT`** | `http://127.0.0.1:8080/v1/audio/transcriptions` | Endpoint URL for local server transcription. |
| **`MISTRAL_API_KEY`** | *(empty)* | API Key for Mistral AI backend. |
| **`GROQ_API_KEY`** | *(empty)* | API Key for Groq Cloud backend. |
| **`ENABLE_CLEANUP`** | `true` | Run LLM post-processing to fix grammar and remove filler words. |
| **`CLEANUP_PROVIDER`** | `mistral` | LLM cleanup backend (`mistral`, `groq`, or `local`). |
| **`CLEANUP_MODEL`** | *(provider default)* | Override default LLM text cleanup model string. |
| **`CLEANUP_SYSTEM_PROMPT`** | *(default prompt)* | Optional custom system prompt overriding default cleanup rules. |
| **`LOCAL_CLEANUP_ENDPOINT`** | `http://127.0.0.1:11434/v1/chat/completions` | Endpoint URL for local LLM cleanup (Ollama / LM Studio). |
| **`AUDIO_FORMAT`** | `m4a` | Audio recording container format (`m4a` or `wav`). |
| **`MAX_RECORDING_DURATION`** | `600` | Maximum recording length in seconds (`0` disables limit). |
| **`RETENTION_DAYS`** | `30` | Days to keep local audio recordings and metadata sidecars before auto-pruning. |
| **`MAX_RECORDINGS`** | `0` | Maximum number of recent recordings to retain on disk (`0` disables cap). |

## Development & Packaging

All unpacked workflow source files live in `workflow/` and the workflow version is centralized in `VERSION`:

- `workflow/`: Unpacked Alfred workflow payload (`info.plist`, `icon.png`, `scripts/`, `history.alfredui/`, `hud.alfredui/`).
- `VERSION`: Single source of truth for the workflow version.
- `scripts/package.sh`: Syncs `VERSION` and `README.md` into `workflow/info.plist`, validates configuration, and outputs `Whisper Alfred.alfredworkflow` at the repository root.
- `test/test_workflow.sh`: Automated verification suite.

Package the workflow using the current `VERSION` or bump to a new version:

```bash
./scripts/package.sh        # Builds ./Whisper Alfred.alfredworkflow from workflow/
./scripts/package.sh 0.8.4  # Updates VERSION, syncs workflow/info.plist, and rebuilds package
```

Double-click `Whisper Alfred.alfredworkflow` in Finder to import or update your local Alfred installation.

Run the verification suite:

```bash
./test/test_workflow.sh
```

## Technical & Audio Recording Details

By default, the workflow uses `ffmpeg` to capture 16kHz mono audio directly into compressed MPEG-4 (`.m4a` AAC) format to maximize upload speed and reduce disk usage by 80%+ while remaining fully compatible with Groq, Mistral, and Faster-Whisper:

```bash
nohup ffmpeg -hide_banner -loglevel error -y "${DURATION_ARGS[@]}" -thread_queue_size 1024 -f avfoundation -i ":default" -ar 16000 -ac 1 -c:a aac -b:a 64k "$AUDIO_PATH" >"$LOG_FILE" 2>&1 </dev/null &
```

If a local server is offline when triggering dictation, Whisper Alfred pastes an error notification into your active application:

```text
[Whisper Alfred Error: Could not connect to local server on http://127.0.0.1:8080/v1/audio/transcriptions. Please verify your local server is running.]
```
