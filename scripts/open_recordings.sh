#!/bin/zsh

# Open Recordings Directory Script for Alfred Workflow
# Opens the workflow recordings and JSON sidecars directory in macOS Finder

set -e

export PATH="/usr/bin:/bin:$PATH"

DATA_DIR="${alfred_workflow_data:-$HOME/Library/Application Support/Alfred/Workflow Data/transcribe}"
RECORDINGS_DIR="$DATA_DIR/recordings"

mkdir -p "$RECORDINGS_DIR"
open "$RECORDINGS_DIR"
