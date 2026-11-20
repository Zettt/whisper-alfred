## Setup

Ensure Alfred has microphone access under **System Settings → Privacy & Security → Microphone**. macOS will also prompt for Microphone permissions on first run.

If you select **Local** in the Workflow’s Configuration, run an OpenAI-compatible transcription server (such as `whisper-server`, `faster-whisper-server`, or `sherpa-onnx-offline-http-server`) and optionally a local LLM server (such as Ollama or LM Studio) for cleanup.

## Usage

Dictate text into any active application via the `whisper` keyword. Trigger once to start recording, and trigger again to stop, transcribe, clean up, and paste into the frontmost application.

![Recording status HUD](images/hud.png)

Configure the Hotkey for faster triggering. While recording, the status HUD shows progress and lets you stop or cancel:

* <kbd>↩</kbd> Stop recording, transcribe, and paste.
* <kbd>⎋</kbd> Cancel recording and discard audio.

Alternatively, browse past transcripts via the `whisper history` keyword.

![Transcript history browser](images/history.png)

Manage stored recordings via the `whisper cancel`, `whisper open`, and `whisper prune` keywords.

![Pruning stored recordings](images/prune.png)

Customize providers, API keys, endpoints, keyword prefix, audio format, and retention limits in the Workflow’s Configuration.
