#!/bin/zsh

# Build history_data.json from Whisper Alfred recording sidecars
# Outputs entries sorted newest-first for history.alfredui

set -e

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h}"

DATA_DIR="${alfred_workflow_data:-$HOME/Library/Application Support/Alfred/Workflow Data/com.zettt.whisper-alfred}"
RECORDINGS_DIR="$DATA_DIR/recordings"
OUT_FILE="${HISTORY_DATA_FILE:-$ROOT_DIR/history.alfredui/resources/history_data.json}"

mkdir -p "${OUT_FILE:h}"

python3 - "$RECORDINGS_DIR" "$OUT_FILE" <<'PY'
import glob, json, os, sys

rec_dir, out_file = sys.argv[1], sys.argv[2]
entries = []

if os.path.isdir(rec_dir):
    json_paths = glob.glob(os.path.join(rec_dir, "*.json"))
    json_paths.sort(key=lambda p: os.path.getmtime(p), reverse=True)

    for json_path in json_paths:
        try:
            with open(json_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            continue

        stem = os.path.splitext(os.path.basename(json_path))[0]
        ts = str(data.get("timestamp") or stem)
        ts_display = ts.replace("T", " ").replace("Z", " UTC") if "T" in ts else ts

        trans = data.get("transcription") or {}
        prov = str(trans.get("provider") or "unknown")
        model = str(trans.get("model") or "default")
        raw_text = str(trans.get("raw_text") or "")

        cleanup = data.get("cleanup") or {}
        cleanup_enabled = bool(cleanup.get("enabled"))
        c_prov = str(cleanup.get("provider") or "off")
        polished = str(cleanup.get("polished_text") or "")

        final_text = polished if polished else raw_text
        single_line = " ".join(final_text.split())
        preview = single_line[:90] + ("..." if len(single_line) > 90 else "")
        if not preview:
            preview = "(empty transcript)"

        audio_path = str(data.get("audio_file") or "")
        if not audio_path or not os.path.isfile(audio_path):
            audio_path = ""
            for ext in (".m4a", ".wav", ".mp4", ".aac"):
                candidate = os.path.splitext(json_path)[0] + ext
                if os.path.isfile(candidate):
                    audio_path = candidate
                    break

        audio_status = "Present" if audio_path else "Pruned"
        cleanup_label = c_prov if cleanup_enabled else "off"

        entries.append({
            "uid": stem,
            "cellTitle.text": f"{ts_display}  •  {prov} ({model})",
            "cellSubtitle.text": preview,
            "cellPolished.text": final_text,
            "cellRaw.text": raw_text,
            "cellMeta.text": f"Timestamp: {ts_display} | Provider: {prov} ({model}) | Cleanup: {cleanup_label} | Audio: {audio_status}",
            "cellAudio.text": audio_path,
            "cellJson.text": json_path,
        })

tmp_file = out_file + ".tmp"
with open(tmp_file, "w", encoding="utf-8") as f:
    json.dump(entries, f, indent=2, ensure_ascii=False)
os.replace(tmp_file, out_file)
PY
