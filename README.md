# Whisper Alfred 🎙️

Created by **Zettt** ([zettt.com](https://zettt.com))

Whisper into any text field on your Mac using **Mistral AI**, **Groq Cloud**, or **Zero-Cloud Local AI** (`whisper.cpp / faster-whisper / sherpa-onnx`).

---

## Features

- ⚡ **One-Hotkey Toggle:** Press hotkey once to start dictation, press again to transcribe and auto-paste into your active app.
- 🌐 **Multi-Provider Support:** Switch between **Mistral AI** (`voxtral-mini`), **Groq Cloud** (`whisper-large-v3-turbo`), and **Local AI Servers** (`whisper.cpp` / Parakeet).
- ✨ **Optional LLM Text Cleanup:** Automatically fixes grammar, removes filler words (*um, uh, like*), and cleans up punctuation before auto-pasting.
- 🔒 **Zero-Cloud Local Mode:** Run 100% offline transcription and LLM text polishing on Apple Silicon Metal GPU.
- 🧹 **Automatic Pruning:** Non-blocking background cleanup for audio recordings older than 7 days.

This workflow **REQUIRES** `sox` which you can install via homebrew:

```bash
brew install sox
```

`sox` is responsible for recording the audio. When you run the workflow for the first time via hotkey, you should see a permission box pop up asking to give microphone access to Alfred. During creation and testing, I didn't have see the dialog right away but after I went to sleep, and opened my MacBook's lid the next day, I was able to approve it.

> NOTE: To make the workflow support a "toggle", and because it has to hand the recording off its operation to a background CLI tool, `sox` is being invoked, and **kept running** in the background. After each recording is done, the process will be gone too. If you experience any issus during setup, you might want to open Activity Monitor and check for any stray `sox` processes, and quit them. Shouldn't happen but if it does you know where to look.

This is the exact line that invokes `sox`:

```bash
# Detach stdin/stdout/stderr completely so Alfred subshell pipe closes instantly
nohup sox --buffer 32768 -q -d -c 1 -b 16 "$AUDIO_PATH" rate 16000 >"$LOG_FILE" 2>&1 </dev/null &
```

---

## Cloud Transcription & LLM Cleanup Setup

Cloud-based API inference is supported out of the box using **Mistral AI** or **Groq Cloud**.

### 1. Obtain API Keys

Create an account and generate an API key from the provider's dashboard:

- **Mistral AI:** [Mistral Console API Keys](https://console.mistral.ai/api-keys/)
- **Groq Cloud:** [Groq Console API Keys](https://console.groq.com/keys)

### 2. Model Identifier Strings

You must supply the exact model identifier string expected by each provider. You can find up-to-date model lists on each provider's website:

| Provider | Default Transcription Model | Default LLM Cleanup Model | Available Models & Documentation |
| --- | --- | --- | --- |
| **Mistral AI** | `voxtral-mini-latest` | `mistral-small-latest` | [Mistral Models Documentation](https://docs.mistral.ai/getting-started/models/) |
| **Groq Cloud** | `whisper-large-v3-turbo` | `llama-3.1-8b-instant` | [Groq Supported Models List](https://console.groq.com/docs/models) |

> 💡 **Custom Models:** Set `TRANSCRIPTION_MODEL` and `CLEANUP_MODEL` in your Alfred Workflow configuration to use any supported model string from the provider's documentation.

---

## Local Transcription Setup Guide: Whisper vs. Parakeet (Optional Offline Mode)

If you prefer zero-cloud, 100% offline local transcription on your Apple Silicon Metal GPU, follow this guide.

You can choose between **Path A (Whisper.cpp)** or **Path B (Python Local Servers: Parakeet & Faster-Whisper)** depending on your engine preference.

---

## Model & Engine Decision Matrix

| Engine Path | Primary Benefit | Installation Complexity | Server Binary |
| --- | --- | --- | --- |
| **Path A: Whisper.cpp** | **Highest Accuracy & Formatting** (Best German/English mixed speech, punctuation) | **Easy** (Available via Homebrew) | `whisper-server` |
| **Path B1: Faster-Whisper** | **Python Whisper Engine** (Fast CTranslate2 backend for Whisper models) | **Intermediate** (Python `venv` setup) | `faster-whisper-server` |
| **Path B2: NVIDIA Parakeet** | **Highest Speed** (2x–4x faster inference, ultra-low RAM) | **Advanced** (Python `venv` + ONNX setup) | `sherpa-onnx` |

---

## Path A: Setting Up Whisper Models (`whisper.cpp`)

### 1. Installation via Homebrew

```bash
brew install whisper-cpp
```

### 2. Download GGML Model File

Official `whisper.cpp` models are hosted on [HuggingFace (ggerganov/whisper.cpp)](https://huggingface.co/ggerganov/whisper.cpp/tree/main):

```bash
mkdir -p ~/.models
# Download recommended base model (~148 MB)
curl -L -o ~/.models/ggml-base.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin
```

### 3. Launch Server

```bash
whisper-server -m ~/.models/ggml-base.bin --port 8080
```

---

## Path B: Python Local Servers (`faster-whisper-server` & `sherpa-onnx`)

> 💡 **Why Virtual Environments?**  
> We use a Python virtual environment (`venv`) to keep all dependencies isolated in a single folder, ensuring they never interfere with system software.

### 1. Create Folder & Isolated Virtual Environment

```bash
mkdir -p ~/.local-transcribe-server
cd ~/.local-transcribe-server
python3 -m venv venv
source venv/bin/activate
```

### 2. Option B1: Install & Run `faster-whisper-server` (Whisper Models)

`faster-whisper-server` runs OpenAI Whisper models using CTranslate2 for high performance.

```bash
pip install --upgrade pip
pip install faster-whisper-server

# Launch faster-whisper server on port 8080
faster-whisper-server --host 127.0.0.1 --port 8080 --model base
```

---

### 3. Option B2: Install & Run `sherpa-onnx` (NVIDIA Parakeet Models)

- **NVIDIA Models (`.nemo`):** Raw original weights trained by NVIDIA (requires PyTorch / CUDA).
- **Sherpa-ONNX Models (`.onnx`):** Converted ONNX version of the same NVIDIA weights, optimized for macOS Apple Silicon.

```bash
pip install --upgrade pip
pip install sherpa-onnx

# Download Sherpa-ONNX Parakeet model for Mac
mkdir -p models
curl -L -o models/model.onnx https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdnn-en-2023-05-23/resolve/main/model.onnx

# Launch Sherpa-ONNX Parakeet server on port 8080
sherpa-onnx-offline-http-server --port=8080 --model=~/.local-transcribe-server/models/model.onnx
```

---

## Alfred Workflow Configuration

Regardless of whether you choose **Cloud (Mistral/Groq)** or **Local (Path A/B)**:

1. Open **Alfred Preferences** -> **Workflows** -> **Whisper Alfred** -> **Configure Workflow**.
2. Set **`TRANSCRIPTION_PROVIDER`** = `mistral`, `groq`, or `local`.
3. Set your API Key (**`MISTRAL_API_KEY`** / **`GROQ_API_KEY`**) or Local Endpoint (**`PARAKEET_ENDPOINT`** = `http://127.0.0.1:8080/v1/audio/transcriptions`).
4. (Optional) Set **`TRANSCRIPTION_MODEL`** and **`CLEANUP_MODEL`** to override defaults with custom model strings.

---

## Error Handling & Server Status

If your local server is offline or stopped when triggering the Hotkey, `alfred-transcribe` will paste a friendly notification message into your frontmost application:

```text
[Whisper Alfred Error: Could not connect to local server on http://127.0.0.1:8080/v1/audio/transcriptions. Please verify your local server is running.]
```
