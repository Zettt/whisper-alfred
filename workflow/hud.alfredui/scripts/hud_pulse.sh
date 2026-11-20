#!/bin/zsh

# Pulse status poller for hud.alfredui
# Emits Alfred UI JSON Actions reflecting recording/transcription/polish state

set -e

CACHE_DIR="${alfred_workflow_cache:-$HOME/Library/Caches/com.runningwithcrayons.Alfred/Workflow Data/com.zettt.whisper-alfred}"
STATUS_FILE="$CACHE_DIR/status.txt"
PID_FILE="$CACHE_DIR/record.pid"
START_FILE="$CACHE_DIR/record_start.txt"

STATUS=""
if [[ -f "$STATUS_FILE" ]]; then
	STATUS=$(cat "$STATUS_FILE" 2>/dev/null | tr -d '\r\n' || true)
fi

if [[ "$STATUS" == "recording" && -f "$PID_FILE" ]]; then
	PID=$(cat "$PID_FILE" 2>/dev/null | tr -d '\r\n' || true)
	if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
		NOW_TS=$(date +%s)
		START_TS="$NOW_TS"
		if [[ -f "$START_FILE" ]]; then
			RAW_START=$(cat "$START_FILE" 2>/dev/null | tr -d '\r\n' || true)
			if [[ "$RAW_START" =~ ^[0-9]+$ ]]; then
				START_TS="$RAW_START"
			fi
		fi
		ELAPSED=$(( NOW_TS - START_TS ))
		if (( ELAPSED < 0 )); then
			ELAPSED=0
		fi
		TIMER_STR=$(printf "%02d:%02d" $(( ELAPSED / 60 )) $(( ELAPSED % 60 )))
		printf '{"update":{"ids":{"statusLabel":{"text":"Recording..."},"timerLabel":{"text":"%s"},"statusIcon":{"contenttintcolour":"systemRedColor"},"stopBtn":{"enabled":true}}}}\n' "$TIMER_STR"
		exit 0
	fi
fi

if [[ "$STATUS" == "transcribing" ]]; then
	printf '{"update":{"ids":{"statusLabel":{"text":"Transcribing..."},"timerLabel":{"text":"Processing audio"},"statusIcon":{"contenttintcolour":"systemOrangeColor"},"stopBtn":{"enabled":false}}}}\n'
	exit 0
fi

if [[ "$STATUS" == "polishing" ]]; then
	printf '{"update":{"ids":{"statusLabel":{"text":"Polishing..."},"timerLabel":{"text":"Cleaning text"},"statusIcon":{"contenttintcolour":"systemPurpleColor"},"stopBtn":{"enabled":false}}}}\n'
	exit 0
fi

printf '{"pulse":{"interval":0},"finish":{}}\n'
