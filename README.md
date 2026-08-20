# Whisper Alfred 🎙️

Created by **Zettt** ([zettt.com](https://zettt.com))

Dictate into any text field on macOS using **Mistral AI**, **Groq Cloud**, or offline **Local AI** (`whisper.cpp`, `faster-whisper`, `sherpa-onnx`).

---

## Features

- ⚡ **Hotkey Toggle:** Press once to start dictation, press again to transcribe and paste into your frontmost app.
- 🌐 **Multi-Provider Support:** Switch between Mistral AI, Groq Cloud, and local server backends.
- ✨ **LLM Text Cleanup:** Fixes grammar, removes filler words (*um, uh*), and cleans punctuation before pasting.
- 🔒 **Offline Local Mode:** Run speech recognition locally on Apple Silicon Metal GPU.
- 🧹 **Automatic Cleanup:** Deletes recordings older than 7 days in the background.

---

## Prerequisites

Install `sox` for audio recording:

```bash
brew install sox
```

`sox` is responsible for recording the audio. When you run the workflow for the first time via hotkey, a macOS permission dialog should pop up asking to give microphone access to Alfred. During creation and testing, I didn't see the dialog right away. After I went to sleep and opened my MacBook's lid the next day, the permission prompt finally appeared and I approved it. I thought I should mention it, in case you're having a similar experience.If that doesn't work, try to reach out to me because I'd like to get a better idea about this macOS "feature."

> NOTE: To support a toggle workflow, `sox` runs in the background while recording. Once recording stops, the process terminates. If you experience setup issues, check Activity Monitor for stray `sox` processes and quit them.

This is the exact code that invokes `sox`:

```bash
# Detach stdin/stdout/stderr completely so Alfred subshell pipe closes instantly
nohup sox --buffer 32768 -q -d -c 1 -b 16 "$AUDIO_PATH" rate 16000 >"$LOG_FILE" 2>&1 </dev/null &
```

The `--buffer 32768` option reserves ~32 KB of RAM memory as a safety holding area. At 16 kHz 16-bit mono audio (32,000 bytes/sec), this provides roughly 1 second of RAM buffer to prevent dropped audio frames, clicks, or missing words if macOS briefly delays `sox` while Alfred runs background tasks.

---

## Cloud Setup (Mistral AI & Groq Cloud)

Cloud providers offer the fastest setup and highest accuracy.

### 1. API Keys

Get an API key from your provider dashboard:

- **Mistral AI:** [Mistral Console](https://console.mistral.ai/api-keys/)
- **Groq Cloud:** [Groq Console](https://console.groq.com/keys)

### 2. Model Configuration

Set the exact model string required by your provider in Alfred Workflow configuration:

| Provider | Default Transcription Model | Default Cleanup Model | Model Documentation |
| --- | --- | --- | --- |
| **Mistral AI** | `voxtral-mini-latest` | `mistral-small-latest` | [Mistral Models](https://docs.mistral.ai/getting-started/models/) |
| **Groq Cloud** | `whisper-large-v3-turbo` | `llama-3.1-8b-instant` | [Groq Models](https://console.groq.com/docs/models) |

### Which one should you pick?

If you live in the EU, you might want to pick Mistral. Mistral is generally a bit slower than Groq. In all my months of using either Groq or Mistral I couldn't manage to get near my usage limits just by whispering on my Mac. If you don't care as much about supporting an EU company, you can also just as well use Groq. They are generally a bit faster, and their free tier is also more than enough for this kind of use case.

---

## Local Setup (Offline Mode)

Run transcription locally on your Apple Silicon GPU using one of these engines:

| Engine | Best For | Setup | Binary |
| --- | --- | --- | --- |
| **Whisper.cpp** | German & English accuracy, proper punctuation | Homebrew | `whisper-server` |
| **Faster-Whisper** | Python CTranslate2 engine | `venv` + `pip` | `faster-whisper-server` |
| **NVIDIA Parakeet** | Inference speed and low memory | `venv` + ONNX | `sherpa-onnx` |

---

### Option A: Whisper.cpp

1. Install via Homebrew:

   ```bash
   brew install whisper-cpp
   ```

2. Download the base GGML model (~148 MB):

   ```bash
   mkdir -p ~/.models
   curl -L -o ~/.models/ggml-base.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin
   ```

3. Launch server on port 8080:

   ```bash
   whisper-server -m ~/.models/ggml-base.bin --port 8080
   ```

---

### Option B1: Faster-Whisper (Python)

```bash
mkdir -p ~/.local-transcribe-server
cd ~/.local-transcribe-server
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install faster-whisper-server

faster-whisper-server --host 127.0.0.1 --port 8080 --model base
```

---

### Option B2: NVIDIA Parakeet (Sherpa-ONNX)

Sherpa-ONNX runs NVIDIA Parakeet models converted to ONNX, optimized for Apple Silicon Metal GPU:

```bash
mkdir -p ~/.local-transcribe-server
cd ~/.local-transcribe-server
python3 -m venv venv
source venv/bin/activate

pip install --upgrade pip
pip install sherpa-onnx

mkdir -p models
curl -L -o models/model.onnx https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdnn-en-2023-05-23/resolve/main/model.onnx

sherpa-onnx-offline-http-server --port=8080 --model=~/.local-transcribe-server/models/model.onnx
```

---

## Alfred Workflow Configuration

1. Open **Alfred Preferences -> Workflows -> Whisper Alfred -> Configure Workflow**.
2. Set **`TRANSCRIPTION_PROVIDER`** (`mistral`, `groq`, or `local`).
3. Set your API Key (**`MISTRAL_API_KEY`** / **`GROQ_API_KEY`**) or Local Endpoint (**`PARAKEET_ENDPOINT`** = `http://127.0.0.1:8080/v1/audio/transcriptions`).
4. (Optional) Set **`TRANSCRIPTION_MODEL`** and **`CLEANUP_MODEL`** to override defaults.

---

## Error Handling

If a local server is offline when triggering dictation, Whisper Alfred pastes an error notification into your active application:

```text
[Whisper Alfred Error: Could not connect to local server on http://127.0.0.1:8080/v1/audio/transcriptions. Please verify your local server is running.]
```
