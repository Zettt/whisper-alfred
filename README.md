# Whisper Alfred 🎙️

## Setup

Install `ffmpeg` (recommended for MPEG-4 `.m4a` recording) or `sox` via Homebrew:

```bash
brew install ffmpeg sox
```

*Note: macOS will prompt for Microphone permissions on first run. Ensure Alfred has microphone access under System Settings → Privacy & Security → Microphone.*

## Usage

Dictate text into any active application via the Hotkey (default: <kbd>⇧</kbd><kbd>⌃</kbd><kbd>=</kbd>) or via the `whisper` keyword.

Configure the Hotkey to toggle dictation on and off. Press once to start recording, and press again to stop, transcribe, clean up, and paste the output into your frontmost application.

Alternatively, manage workflow recordings via keywords:

* `whisper`: Trigger dictation recording manually via keyword.
* `whisper open`: Open the workflow’s recordings directory in Finder.
* `whisper prune`: Delete local recordings and sidecars (supports optional arguments: `recordings` to delete only audio files, `archive` to archive files, `auto` for retention check, or a number `N` to delete files older than N days).

### Features

- ⚡ **Hotkey Toggle:** Press once to start recording, press again to transcribe and paste into your frontmost app.
- 🌐 **Multi-Provider Support:** Switch between Mistral AI, Groq Cloud, and offline Local AI.
- ✨ **LLM Text Cleanup:** Fixes grammar, removes filler words (*um, uh*), and cleans punctuation before pasting.
- 🔒 **Offline Local Mode:** Run speech recognition locally on Apple Silicon Metal GPU.
- 🧹 **Configurable Retention:** Prunes recordings older than `RETENTION_DAYS` (default: 7 days) in the background.

## Cloud Setup (Mistral AI & Groq Cloud)

Cloud providers offer fast setup and high accuracy:

- **Mistral AI:** Recommended for EU data residency (`voxtral-mini-latest` for transcription, `mistral-small-latest` for cleanup). Get key at [Mistral Console](https://console.mistral.ai/api-keys/).
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
| **`AUDIO_FORMAT`** | `m4a` | Audio recording container format (`m4a` or `wav`). |
| **`MISTRAL_API_KEY`** | *(empty)* | API Key for Mistral AI backend. |
| **`GROQ_API_KEY`** | *(empty)* | API Key for Groq Cloud backend. |
| **`PARAKEET_ENDPOINT`** | `http://127.0.0.1:8080/v1/audio/transcriptions` | Endpoint URL for local server transcription. |
| **`TRANSCRIPTION_MODEL`** | *(provider default)* | Override default transcription model string. |
| **`CLEANUP_MODEL`** | *(provider default)* | Override default LLM text cleanup model string. |
| **`RETENTION_DAYS`** | `7` | Days to keep local audio recordings and metadata sidecars before auto-pruning. |

## Technical & Audio Recording Details

By default, the workflow uses `ffmpeg` to capture 16kHz mono audio directly into compressed MPEG-4 (`.m4a` AAC) format to maximize upload speed and reduce disk usage by 80%+ while remaining fully compatible with Groq, Mistral, and Faster-Whisper:

```bash
nohup ffmpeg -hide_banner -loglevel error -y -f avfoundation -i ":default" -ar 16000 -ac 1 -c:a aac -b:a 64k "$AUDIO_PATH" >"$LOG_FILE" 2>&1 </dev/null &
```

If a local server is offline when triggering dictation, Whisper Alfred pastes an error notification into your active application:

```text
[Whisper Alfred Error: Could not connect to local server on http://127.0.0.1:8080/v1/audio/transcriptions. Please verify your local server is running.]
```
