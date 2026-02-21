#!/bin/bash
# Quick start script for Simple Whisper - Quick Record workflow
# Usage: ./quick_start.sh [duration] [other parameters]

cd "$(dirname "$0")"

DURATION=${1:-10}  # Default 10 seconds

echo "=== Quick Start: Recording and Transcription ==="
echo "Duration: $DURATION seconds"
echo ""

# Execute workflow with quick preset
./scripts/workflow/workflow_controller.sh --workflow 1 --preset 1 --duration "$DURATION" --auto-start "${@:2}"