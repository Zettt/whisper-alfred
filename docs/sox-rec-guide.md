# SoX `rec` Audio Capture & Process Lifecycle Guide

## Overview

SoX (`soundechange`) provides the `rec` CLI binary used for lightweight audio capture on macOS via Homebrew (`brew install sox`).

## Parameters

```bash
rec -r 16000 -c 1 -b 16 "$AUDIO_FILE"
```

- `-r 16000`: Sample rate set to 16 kHz (standard for speech recognition models).
- `-c 1`: Mono audio channel.
- `-b 16`: Bit depth set to 16-bit PCM.

## Process Lifecycle & Signals

### Start Recording
```bash
nohup rec -r 16000 -c 1 -b 16 "$AUDIO_FILE" >/dev/null 2>&1 &
echo $! > "$CACHE_DIR/record.pid"
```

### Stop Recording cleanly
```bash
PID=$(cat "$CACHE_DIR/record.pid")
kill -2 "$PID" # SIGINT allows rec to write WAV header properly
while kill -0 "$PID" 2>/dev/null; do
    sleep 0.05
done
rm -f "$CACHE_DIR/record.pid"
```

> **Note on SIGINT (`kill -2`):**
> `rec` handles `SIGINT` gracefully by flushing raw PCM audio data and updating the canonical WAV header length fields before exiting. `SIGKILL` (`kill -9`) must be avoided as it results in corrupted WAV files.

## Environment Variables
- `alfred_workflow_cache`: Directory for process state files (`record.pid`).
- `alfred_workflow_data`: Long-term storage directory for recorded WAV files.
