#!/bin/bash
# Transcribe existing audio file script for Simple Whisper Application

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  SIMPLE WHISPER - TRANSCRIBE FILE${NC}"
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
LANGUAGE=""
OUTPUT_TEXT=""
AUDIO_FILE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        -l|--language)
            LANGUAGE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_TEXT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS] AUDIO_FILE"
            echo ""
            echo "Transcribe existing audio file with Simple Whisper"
            echo ""
            echo "Options:"
            echo "  -m, --model MODEL    Model size: tiny, base, small, medium, large (default: base)"
            echo "  -l, --language CODE  Language code: en, zh, ja, etc. (default: auto-detect)"
            echo "  -o, --output FILE    Output transcription filename (default: auto-generated)"
            echo "  -h, --help           Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 recording.wav                    Transcribe with base model, auto-detect language"
            echo "  $0 -m small meeting.mp3            Transcribe with small model"
            echo "  $0 -l en interview.wav             Transcribe in English"
            echo "  $0 -o transcript.txt audio.m4a     Save transcription as transcript.txt"
            echo ""
            exit 0
            ;;
        *)
            if [ -z "$AUDIO_FILE" ]; then
                AUDIO_FILE="$1"
            else
                echo -e "${YELLOW}Unknown argument: $1${NC}"
                echo "Use --help for usage information"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if audio file is specified
if [ -z "$AUDIO_FILE" ]; then
    echo -e "${RED}Error: No audio file specified${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS] AUDIO_FILE"
    echo "Use --help for more information"
    exit 1
fi

# Check if audio file exists
if [ ! -f "$AUDIO_FILE" ]; then
    echo -e "${RED}Error: Audio file not found: $AUDIO_FILE${NC}"
    exit 1
fi

# Generate output filename if not specified
if [ -z "$OUTPUT_TEXT" ]; then
    BASENAME=$(basename "$AUDIO_FILE")
    FILENAME="${BASENAME%.*}"
    OUTPUT_TEXT="${FILENAME}_transcription.txt"
fi

echo -e "\n${BLUE}Configuration:${NC}"
echo "  Audio file: $AUDIO_FILE"
echo "  Model: $MODEL"
if [ -n "$LANGUAGE" ]; then
    echo "  Language: $LANGUAGE"
else
    echo "  Language: Auto-detect"
fi
echo "  Output: $OUTPUT_TEXT"
echo ""

# Check file size
FILESIZE=$(stat -f%z "$AUDIO_FILE" 2>/dev/null || stat -c%s "$AUDIO_FILE" 2>/dev/null || echo "unknown")
if [ "$FILESIZE" != "unknown" ]; then
    FILESIZE_MB=$((FILESIZE / 1024 / 1024))
    echo "  File size: ${FILESIZE_MB} MB"
fi

# Check file type
echo -n "  File type: "
file -b "$AUDIO_FILE" | head -1 || echo "unknown"

echo ""
read -p "Press Enter to start transcription... (Ctrl+C to cancel)"

# Build command
CMD="python simple_whisper.py --audio \"$AUDIO_FILE\" --model $MODEL --output-text \"$OUTPUT_TEXT\""
if [ -n "$LANGUAGE" ]; then
    CMD="$CMD --language $LANGUAGE"
fi

echo -e "\n${GREEN}Starting transcription...${NC}"
echo "Command: $CMD"
echo ""

# Run the command
eval $CMD

echo -e "\n${GREEN}Transcription completed!${NC}"
echo ""
echo "Output file: $OUTPUT_TEXT"
echo ""
echo "To view the transcription:"
echo "  cat \"$OUTPUT_TEXT\""
echo "  or"
echo "  less \"$OUTPUT_TEXT\""
echo ""
echo "To record new audio:"
echo "  ./quick_record.sh"
echo ""
echo "To use interactive mode:"
echo "  python interactive_whisper.py"