# Alfred 5 Dictation Workflow Manual Setup Guide

Follow these steps to wire up the workflow in the Alfred 5 Workflow Editor.

## 1. Create a Blank Workflow
1. Open **Alfred Preferences** -> **Workflows**.
2. Click **+** at the bottom of the list and choose **Blank Workflow**.
3. Name: `Transcribe & Polish`
4. Bundle Identifier: `com.alfred.transcribe.polish`

## 2. Configure Workflow Environment Variables
Click the **Configure Workflow** button (top right of workflow window) and add:

- `TRANSCRIPTION_PROVIDER`: `mistral` (Options: `mistral`, `groq`, `parakeet`)
- `MISTRAL_API_KEY`: *(Your Mistral AI API key)*
- `GROQ_API_KEY`: *(Optional - Your Groq API key)*
- `PARAKEET_ENDPOINT`: `http://127.0.0.1:8080/v1/audio/transcriptions`
- `ENABLE_CLEANUP`: `false` (Set to `true` for LLM grammar polish)
- `RETENTION_DAYS`: `7`

## 3. Add Workflow Nodes

### Node A: Hotkey Trigger
- Right-click -> **Triggers** -> **Hotkey**.
- Set hotkey shortcut (e.g. `Cmd + Shift + D`).
- Action: **Pass through to workflow**.

### Node B: Recording Toggle (`scripts/toggle_rec.sh`)
- Right-click -> **Actions** -> **Run Script**.
- Language: `/bin/zsh`
- Script:
  ```zsh
  ./scripts/toggle_rec.sh
  ```
- Connect Node A to Node B.

### Node C: Conditional Check
- Right-click -> **Utilities** -> **Conditional**.
- Condition: `{query}` `is not equal to` (leave value field blank).
- Connect Node B to Node C.

### Node D: Transcription Dispatcher (`scripts/transcribe.sh`)
- Right-click -> **Actions** -> **Run Script**.
- Language: `/bin/zsh`
- Script:
  ```zsh
  ./scripts/transcribe.sh "{query}"
  ```
- Connect top port of Node C (Match) to Node D.

### Node E: LLM Polish Dispatcher (`scripts/polish.sh`)
- Right-click -> **Actions** -> **Run Script**.
- Language: `/bin/zsh`
- Script:
  ```zsh
  ./scripts/polish.sh "{query}"
  ```
- Connect Node D to Node E.

### Node F: Clipboard & Auto-Paste
- Right-click -> **Outputs** -> **Copy to Clipboard**.
- Content: `{query}`
- Check: **Automatically paste to frontmost app**.
- Check: **Mark transient in clipboard history**.
- Connect Node E to Node F.

### Node G: Audio Pruner (Background Run Script)
- Right-click -> **Actions** -> **Run Script**.
- Language: `/bin/zsh`
- Script:
  ```zsh
  ./scripts/prune.sh &
  ```
- Connect Node E to Node G (runs non-blocking in background).
