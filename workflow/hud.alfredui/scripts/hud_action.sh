#!/bin/zsh

# Action handler for hud.alfredui Stop and Cancel buttons

set -e

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h:h}"
ACTION="${1:-}"

case "$ACTION" in
cancel)
	"$ROOT_DIR/scripts/toggle_rec.sh" cancel >/dev/null 2>&1 || true
	printf '{"pulse":{"interval":0},"finish":{}}\n'
	;;

stop)
	osascript -e 'tell application id "com.runningwithcrayons.Alfred" to run trigger "toggle_dictation" in workflow "com.zettt.whisper-alfred"' >/dev/null 2>&1 &!
	printf '{"update":{"ids":{"statusLabel":{"text":"Transcribing..."},"timerLabel":{"text":"Processing audio"},"statusIcon":{"contenttintcolour":"systemOrangeColor"},"stopBtn":{"enabled":false}}}}\n'
	;;

*)
	printf '{}\n'
	;;
esac
