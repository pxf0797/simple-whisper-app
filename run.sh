#!/bin/bash
# Run script for Simple Whisper Application

# Get directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Activate virtual environment
if [ -f "$SCRIPT_DIR/venv/bin/activate" ]; then
    source "$SCRIPT_DIR/venv/bin/activate"
else
    echo "Virtual environment not found. Running setup.sh..."
    "$SCRIPT_DIR/setup.sh"
    source "$SCRIPT_DIR/venv/bin/activate"
fi

# Run the application with all arguments
python "$SCRIPT_DIR/simple_whisper.py" "$@"