#!/bin/zsh

# Audio & Metadata Sidecar Retention Pruner for Alfred Workflow
# Supports arguments ($1):
#   (empty) / auto / text -> Retention check (deletes files older than RETENTION_DAYS, default: 7)
#   force / all / purge / 0 -> Purges ALL recordings & sidecars immediately
#   recordings / m4a / audio -> Deletes only audio files, keeping JSON sidecars
#   archive                 -> Moves recordings & sidecars to $DATA_DIR/archive/
#   keep N / max N          -> Retains only the N most recent recordings & sidecars
#   N (number)              -> Prunes files older than N days

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

DATA_DIR="${alfred_workflow_data:-$HOME/Library/Application Support/Alfred/Workflow Data/com.zettt.whisper-alfred}"
RECORDINGS_DIR="$DATA_DIR/recordings"
ARCHIVE_DIR="$DATA_DIR/archive"

if [[ ! -d "$RECORDINGS_DIR" ]]; then
	exit 0
fi

enforce_max_recordings() {
	local max_count="$1"
	if ! [[ "$max_count" =~ ^[1-9][0-9]*$ ]]; then
		return
	fi
	local -a audio_files
	audio_files=("$RECORDINGS_DIR"/*.(m4a|wav|mp4|aac)(N.om))
	if (( ${#audio_files[@]} <= max_count )); then
		return
	fi
	local idx f
	for (( idx = max_count + 1; idx <= ${#audio_files[@]}; idx++ )); do
		f="${audio_files[$idx]}"
		rm -f "$f" "${f%.*}.json" 2>/dev/null || true
	done
}

prune_by_age() {
	local days="$1"
	local min_keep="${MIN_KEEP_RECORDINGS:-0}"

	if [[ "$min_keep" =~ ^[1-9][0-9]*$ ]]; then
		local -a audio_files
		audio_files=("$RECORDINGS_DIR"/*.(m4a|wav|mp4|aac)(N.om))
		typeset -A protected
		local idx f
		for (( idx = 1; idx <= min_keep && idx <= ${#audio_files[@]}; idx++ )); do
			f="${audio_files[$idx]}"
			protected[$f]=1
			protected[${f%.*}.json]=1
		done

		while IFS= read -r -d '' candidate; do
			if [[ -z "${protected[$candidate]:-}" ]]; then
				rm -f "$candidate" 2>/dev/null || true
			fi
		done < <(find "$RECORDINGS_DIR" -type f \( -name "*.m4a" -o -name "*.wav" -o -name "*.mp4" -o -name "*.aac" -o -name "*.json" \) -mtime +${days} -print0 2>/dev/null)
	else
		find "$RECORDINGS_DIR" -type f \( -name "*.m4a" -o -name "*.wav" -o -name "*.mp4" -o -name "*.aac" -o -name "*.json" \) -mtime +${days} -delete 2>/dev/null || true
	fi
}

RAW_ARG=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d '\r\n' | xargs)
ARG="${RAW_ARG#prune}"
ARG=$(echo "$ARG" | xargs)

case "$ARG" in
	"force" | "all" | "purge" | "0")
		find "$RECORDINGS_DIR" -type f \( -name "*.m4a" -o -name "*.wav" -o -name "*.mp4" -o -name "*.aac" -o -name "*.json" \) -delete 2>/dev/null || true
		printf "Purged all audio recordings and JSON sidecars."
		;;
	"recordings" | "wav" | "m4a" | "audio")
		find "$RECORDINGS_DIR" -type f \( -name "*.m4a" -o -name "*.wav" -o -name "*.mp4" -o -name "*.aac" \) -delete 2>/dev/null || true
		printf "Deleted all audio files. JSON sidecars preserved."
		;;
	"archive")
		mkdir -p "$ARCHIVE_DIR"
		find "$RECORDINGS_DIR" -type f \( -name "*.m4a" -o -name "*.wav" -o -name "*.mp4" -o -name "*.aac" -o -name "*.json" \) -exec mv {} "$ARCHIVE_DIR/" \; 2>/dev/null || true
		printf "Archived all recordings to %s" "$ARCHIVE_DIR"
		;;
	*)
		if [[ "$ARG" =~ ^(keep|max)[[:space:]]+([0-9]+)$ ]]; then
			COUNT="${match[2]}"
			enforce_max_recordings "$COUNT"
			printf "Retained latest %s recordings." "$COUNT"
		else
			if [[ "$ARG" =~ ^[0-9]+$ ]]; then
				DAYS="$ARG"
			else
				DAYS="${RETENTION_DAYS:-7}"
			fi
			prune_by_age "$DAYS"
			if [[ "${MAX_RECORDINGS:-0}" =~ ^[1-9][0-9]*$ ]]; then
				enforce_max_recordings "$MAX_RECORDINGS"
			fi
			printf "Pruned recordings older than %s days." "$DAYS"
		fi
		;;
esac
