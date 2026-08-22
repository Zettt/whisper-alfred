# Alfred 5 Workflow Building Blocks Reference

## Workflow Objects Topology

```text
[ Hotkey Trigger ]
       │
       ▼
[ Run Script: Toggle Controller ]
       │
       ▼
[ Conditional: Output not empty ]
       │
       ▼
[ Run Script: Transcribe Audio ]
       │
       ├── (ENABLE_CLEANUP == "false") ────┐
       │                                   │
       ▼ (ENABLE_CLEANUP == "true")        │
[ Run Script: LLM Text Polish ]            │
       │                                   │
       ├───────────────────────────────────┘
       │
       ▼
[ Copy to Clipboard (Auto-paste) ]
       │
       ▼
[ Run Script: Background Pruner ]
```

## Object Configurations

### 1. Hotkey Trigger

- **Action:** Pass through to workflow.
- **Argument:** None.
- **Trigger Type:** Toggle key combination.

### 2. Run Script: Toggle Controller (`scripts/toggle_rec.sh`)

- **Language:** `/bin/zsh`
- **Input:** None.
- **Output:** Standard Output (`stdout`) receives the absolute WAV file path when recording stops; empty output when recording starts.

### 3. Conditional Object

- **Condition:** `{query}` `is not equal to` (empty string).
- **Match:** Passes path to Transcribe script.
- **No Match:** Execution terminates silently.

### 4. Run Script: Transcribe (`scripts/transcribe.sh`)

- **Language:** `/bin/zsh`
- **Environment Variables Passed:**
- `TRANSCRIPTION_PROVIDER` (`mistral`, `groq`, `parakeet`)
- `MISTRAL_API_KEY`
- `GROQ_API_KEY`
- `PARAKEET_ENDPOINT` (default: `http://localhost:8080/v1/audio/transcriptions`)

### 5. Conditional: LLM Cleanup Switch

- **Condition:** `{var:ENABLE_CLEANUP}` `is equal to` `true`.

### 6. Run Script: LLM Polish (`scripts/polish.sh`)

- **Language:** `/bin/zsh`
- **Input:** Transcribed text via stdin / `{query}`.
- **Environment Variables Passed:**
- `MISTRAL_API_KEY`
- `POLISH_MODEL` (default: `mistral-small-latest`)

### 7. Copy to Clipboard

- **Text:** `{query}`
- **Automatically paste to frontmost app:** Checked (`true`).
- **Mark transient in clipboard history:** Checked.

### 8. Run Script: Background Pruner (`scripts/prune.sh auto &`)

- **Language:** `/bin/zsh`
- **Script:** `./scripts/prune.sh auto &`
- **Description:** Non-blocking background retention check. Removes audio recordings and JSON sidecars older than `RETENTION_DAYS`.

### 9. Keyword Triggers

- **`whisper open`**: Executes `./scripts/open_recordings.sh` to open recordings directory in Finder.
- **`whisper prune`**: Executes `./scripts/prune.sh "{query}"`.
  - Empty: Prunes recordings older than `RETENTION_DAYS`.
  - `force` / `all` / `purge`: Full purge of all recordings and metadata sidecars immediately.
  - `recordings`: Deletes audio files only (`.m4a`, `.wav`, `.mp4`, `.aac`).
  - `archive`: Moves recordings to `archive/` directory.
  - `<N>`: Deletes recordings older than $N$ days.

### 10. Workflow Configuration Variables

| Variable | Default Value | Description |
| --- | --- | --- |
| `TRANSCRIPTION_PROVIDER` | `mistral` | Selected transcription engine (`mistral`, `groq`, `parakeet`) |
| `MISTRAL_API_KEY` | | Secret key for Mistral AI |
| `GROQ_API_KEY` | | Secret key for Groq Cloud |
| `PARAKEET_ENDPOINT` | `http://127.0.0.1:8080/v1/audio/transcriptions` | Endpoint for local Parakeet model |
| `ENABLE_CLEANUP` | `false` | Enable LLM text polish (`true`/`false`) |
| `RETENTION_DAYS` | `7` | Retention period in days for audio files |
