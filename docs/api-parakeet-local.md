# Local Transcription Setup Guide: Whisper vs. Parakeet

This guide walks through setting up local, zero-cloud audio transcription for `alfred-transcribe`.

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

* **NVIDIA Models (`.nemo`):** Raw original weights trained by NVIDIA (requires PyTorch / CUDA).
* **Sherpa-ONNX Models (`.onnx`):** Converted ONNX version of the same NVIDIA weights, optimized for macOS Apple Silicon.

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

Regardless of whether you choose **Path A** or **Path B**:

1. Open **Alfred Preferences** -> **Workflows** -> **Alfred Transcribe**.
2. Set **`TRANSCRIPTION_PROVIDER`** = `parakeet` (or `local`).
3. Set **`PARAKEET_ENDPOINT`** = `http://127.0.0.1:8080/v1/audio/transcriptions`.

---

## Error Handling & Server Status

If your local server is offline or stopped when triggering the Hotkey, `alfred-transcribe` will paste a friendly notification message into your frontmost application:

```text
[Alfred Transcribe Error: Could not connect to local server on http://127.0.0.1:8080/v1/audio/transcriptions. Please verify your local server is running.]
```
