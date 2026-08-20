# Alfred Transcribe 🎙️✨

Created by **Zettt** ([zettt.com](https://zettt.com))

Whisper into any text field on your Mac using **Mistral AI**, **Groq Cloud**, or **Zero-Cloud Local AI** (`whisper.cpp` / `faster-whisper` / `sherpa-onnx`).

---

## Features

- ⚡ **One-Hotkey Toggle:** Press hotkey once to start dictation, press again to transcribe and auto-paste into your active app.
- 🌐 **Multi-Provider Support:** Switch between **Mistral AI** (`voxtral-mini`), **Groq Cloud** (`whisper-large-v3-turbo`), and **Local AI Servers** (`whisper.cpp` / Parakeet).
- ✨ **Optional LLM Text Cleanup:** Automatically fixes grammar, removes filler words (*um, uh, like*), and cleans up punctuation before auto-pasting.
- 🔒 **Zero-Cloud Local Mode:** Run 100% offline transcription and LLM text polishing on Apple Silicon Metal GPU.
- 🧹 **Automatic Pruning:** Non-blocking background cleanup for audio recordings older than 7 days.

---

## Quick Start

### 1. Prerequisites
Install `sox` (required for audio capture):
```bash
brew install sox
```

### 2. Workflow Installation
1. Download and open `Alfred Transcribe.alfredworkflow`.
2. Assign your preferred **Hotkey Trigger** (e.g. `Cmd + Shift + =`).

---

## User Configuration & Environment Variables

Configure these in **Alfred Preferences** -> **Workflows** -> **Alfred Transcribe** -> **Configure Workflow**:

### 🗣️ Transcription Settings
| Control / Variable | Description | Allowed Values | Default |
|---|---|---|---|
| `TRANSCRIPTION_PROVIDER` | Active speech recognition engine | `mistral`, `groq`, `local` | `mistral` |
| `TRANSCRIPTION_MODEL` | Transcription model identifier | Model identifier string | `voxtral-mini-latest` (Mistral)<br>`whisper-large-v3-turbo` (Groq)<br>`local` (Local) |
| `MISTRAL_API_KEY` | Mistral AI API Key | Bearer Token | - |
| `GROQ_API_KEY` | Groq Cloud API Key | Bearer Token | - |
| `LOCAL_TRANSCRIPTION_ENDPOINT` | Local server HTTP endpoint | URL string | `http://127.0.0.1:8080/v1/audio/transcriptions` |

### ✨ LLM Text Cleanup Settings
| Control / Variable | Description | Allowed Values | Default |
|---|---|---|---|
| `ENABLE_CLEANUP` | Enable/disable LLM text polish | `1` / `true`, `0` / `false` | `0` (`false`) |
| `CLEANUP_PROVIDER` | LLM provider for cleanup | `mistral`, `groq`, `local` | `mistral` |
| `CLEANUP_MODEL` | Cleanup model identifier | Model identifier string | `mistral-small-latest` (Mistral)<br>`llama-3.1-8b-instant` (Groq)<br>`llama3.2` (Local Ollama) |
| `LOCAL_CLEANUP_ENDPOINT` | Local Ollama / LocalAI endpoint | URL string | `http://127.0.0.1:11434/v1/chat/completions` |

### 🧹 Maintenance Settings
| Control / Variable | Description | Default |
|---|---|---|
| `RETENTION_DAYS` | Days to keep `.wav` recordings before auto-deletion | `7` |

---

## 🔒 Local Offline Guide

For step-by-step instructions on setting up zero-cloud local transcription engines (`whisper.cpp`, `faster-whisper-server`, or `sherpa-onnx`), see the [Local Setup Guide](docs/api-parakeet-local.md).
