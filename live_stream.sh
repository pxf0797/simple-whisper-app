#!/bin/bash
# Live streaming script for Simple Whisper - Real-time transcription
# Usage: ./live_stream.sh [duration] [other parameters]

cd "$(dirname "$0")"

DURATION=${1:-30}  # Default 30 seconds

echo "=== Live Streaming Transcription ==="
echo "Duration: $DURATION seconds"
echo ""

# Execute workflow with standard preset
./scripts/workflow/workflow_controller.sh --workflow 2 --preset 2 --duration "$DURATION" --auto-start "${@:2}"