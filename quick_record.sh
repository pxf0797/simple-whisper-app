#!/bin/bash
# Quick recording script for Simple Whisper Application

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  SIMPLE WHISPER - QUICK RECORD${NC}"
echo -e "${BLUE}========================================${NC}"

# Check environment
if [[ -z "$VIRTUAL_ENV" ]]; then
    if [ -f "venv/bin/activate" ]; then
        source venv/bin/activate
        echo -e "${GREEN}✓ Virtual environment activated${NC}"
    else
        echo -e "${YELLOW}Virtual environment not found. Running setup...${NC}"
        ./setup.sh
        source venv/bin/activate
    fi
fi

# Default values
MODEL="base"
DURATION=""
OUTPUT_AUDIO=""
OUTPUT_TEXT=""
DEVICE=""
INPUT_DEVICE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--duration)
            DURATION="$2"
            shift 2
            ;;
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        --device)
            DEVICE="$2"
            shift 2
            ;;
        --input-device)
            INPUT_DEVICE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_AUDIO="record/$2"
            OUTPUT_TEXT="record/${2%.*}_transcription.txt"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Quick recording script for Simple Whisper"
            echo ""
            echo "Options:"
            echo "  -d, --duration SECONDS   Recording duration in seconds"
            echo "  -m, --model MODEL        Model size: tiny, base, small, medium, large (default: base)"
            echo "      --device DEVICE      Computation device: cpu, mps, cuda (default: auto)"
            echo "      --input-device ID    Audio input device ID (use --list-devices to see IDs)"
            echo "  -o, --output FILENAME    Base filename for output (audio and transcription)"
            echo "  -h, --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 -d 10                 Record for 10 seconds with base model"
            echo "  $0 -d 60 -m small        Record for 60 seconds with small model"
            echo "  $0 -d 300 -o meeting     Record 5 minutes, save as meeting.wav and meeting_transcription.txt"
            echo "  $0 -d 60 -m small --device mps --input-device 5  Record with GPU and specific microphone"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${YELLOW}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# If duration not specified, ask for it
if [ -z "$DURATION" ]; then
    echo -e "\n${BLUE}Recording Duration:${NC}"
    echo "  Enter duration in seconds (e.g., 10, 60, 300)"
    echo "  Or press Enter for manual stop (Ctrl+C to stop recording)"
    echo ""
    read -p "Duration (seconds, empty for manual): " DURATION_INPUT

    if [ -n "$DURATION_INPUT" ]; then
        DURATION="$DURATION_INPUT"
    fi
fi

# If output not specified, generate based on timestamp
if [ -z "$OUTPUT_AUDIO" ]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_AUDIO="record/recording_${TIMESTAMP}.wav"
    OUTPUT_TEXT="record/recording_${TIMESTAMP}_transcription.txt"
fi

mkdir -p record

echo -e "\n${BLUE}Configuration:${NC}"
echo "  Model: $MODEL"
echo "  Audio device: ${INPUT_DEVICE:-default}"
echo "  Computation device: ${DEVICE:-auto}"
if [ -n "$DURATION" ]; then
    echo "  Duration: $DURATION seconds"
else
    echo "  Duration: Manual stop (Ctrl+C)"
fi
echo "  Audio output: $OUTPUT_AUDIO"
echo "  Text output: $OUTPUT_TEXT"
echo ""

# Audio device selection
if [ -z "$INPUT_DEVICE" ]; then
    echo -e "${BLUE}Audio Device Selection:${NC}"
    echo "Listing available audio input devices..."
    python simple_whisper.py --list-audio-devices

    # Get default device ID
    DEFAULT_DEVICE=$(python -c "
import sounddevice as sd
try:
    default = sd.default.device[0]
    print(default)
except:
    print('')
")

    if [ -n "$DEFAULT_DEVICE" ]; then
        echo -e "\nDefault device ID: $DEFAULT_DEVICE"
        read -p "Enter device ID (press Enter for default $DEFAULT_DEVICE): " DEVICE_INPUT
        if [ -n "$DEVICE_INPUT" ]; then
            INPUT_DEVICE="$DEVICE_INPUT"
        else
            INPUT_DEVICE="$DEFAULT_DEVICE"
        fi
    else
        read -p "Enter device ID: " INPUT_DEVICE
    fi
fi

# Computation device selection
if [ -z "$DEVICE" ]; then
    echo -e "\n${BLUE}Computation Device Selection:${NC}"
    echo "  cpu  - Use CPU (default)"
    echo "  mps  - Use Apple Silicon GPU (M1/M2/M3)"
    echo "  cuda - Use NVIDIA GPU (CUDA)"
    read -p "Select device [cpu/mps/cuda] (press Enter for cpu): " DEVICE_INPUT
    if [ -n "$DEVICE_INPUT" ]; then
        DEVICE="$DEVICE_INPUT"
    else
        DEVICE="cpu"
    fi
fi

echo ""
if [ -n "$INPUT_DEVICE" ] && [ -n "$DEVICE" ]; then
    echo "All parameters set. Starting recording automatically..."
else
    read -p "Press Enter to start recording... (Ctrl+C to cancel)"
fi

# Build command
# Build command
CMD="python simple_whisper.py --record --model $MODEL --output-audio $OUTPUT_AUDIO --output-text $OUTPUT_TEXT"

if [ -n "$INPUT_DEVICE" ]; then
    CMD="$CMD --input-device $INPUT_DEVICE"
fi

if [ -n "$DEVICE" ]; then
    CMD="$CMD --device $DEVICE"
fi

if [ -n "$DURATION" ]; then
    CMD="$CMD --duration $DURATION"
fi

echo -e "\n${GREEN}Starting recording...${NC}"
echo "Command: $CMD"
echo ""

# Run the command
eval $CMD

echo -e "\n${GREEN}Recording completed!${NC}"
echo ""
echo "Files created:"
echo "  Audio: $OUTPUT_AUDIO"
echo "  Transcription: $OUTPUT_TEXT"
echo ""
echo "To transcribe another file:"
echo "  python simple_whisper.py --audio <filename>"
echo ""
echo "To use interactive mode:"
echo "  python interactive_whisper.py"