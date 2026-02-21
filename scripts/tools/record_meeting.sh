#!/bin/bash
# Meeting recording script for Simple Whisper Application

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  SIMPLE WHISPER - MEETING RECORDER${NC}"
echo -e "${CYAN}========================================${NC}"

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
MODEL="small"  # Better quality for meetings
MEETING_NAME=""
DURATION=""
LANGUAGE=""

echo -e "\n${CYAN}Meeting Information:${NC}"

# Get meeting name
while [ -z "$MEETING_NAME" ]; do
    echo ""
    echo "  Enter meeting name (e.g., 'Team Meeting', 'Project Review'):"
    read -p "  Meeting name: " MEETING_NAME

    if [ -z "$MEETING_NAME" ]; then
        echo -e "  ${YELLOW}Meeting name cannot be empty${NC}"
    fi
done

# Sanitize meeting name for filename
SAFE_NAME=$(echo "$MEETING_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | tr -cd '[:alnum:]_')

# Get duration
echo ""
echo "  Enter meeting duration:"
echo "    Format examples:"
echo "      30  = 30 minutes"
echo "      1.5 = 1.5 hours (90 minutes)"
echo "      0.5 = 30 minutes"
echo ""
read -p "  Duration (hours/minutes): " DURATION_INPUT

# Parse duration
if [[ "$DURATION_INPUT" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    # If duration is less than 10, assume hours, convert to minutes
    HOURS=$(echo "$DURATION_INPUT" | bc)
    MINUTES=$(echo "$HOURS * 60" | bc)
    SECONDS=$(echo "$MINUTES * 60" | bc | cut -d'.' -f1)  # Remove decimal

    echo -e "  ${GREEN}Duration: $HOURS hours ($MINUTES minutes, $SECONDS seconds)${NC}"
    DURATION="$SECONDS"
else
    echo -e "  ${YELLOW}Invalid duration. Using default: 60 minutes${NC}"
    DURATION=3600  # 60 minutes in seconds
fi

# Get language
echo ""
echo "  Select meeting language:"
echo "    1. Auto-detect (recommended for multilingual meetings)"
echo "    2. English"
echo "    3. Chinese"
echo "    4. Japanese"
echo "    5. Other (specify code)"
echo ""
read -p "  Choice [1-5]: " LANG_CHOICE

case $LANG_CHOICE in
    1)
        LANGUAGE=""
        echo -e "  ${GREEN}Language: Auto-detect${NC}"
        ;;
    2)
        LANGUAGE="en"
        echo -e "  ${GREEN}Language: English${NC}"
        ;;
    3)
        LANGUAGE="zh"
        echo -e "  ${GREEN}Language: Chinese${NC}"
        ;;
    4)
        LANGUAGE="ja"
        echo -e "  ${GREEN}Language: Japanese${NC}"
        ;;
    5)
        read -p "  Enter language code (e.g., 'fr', 'de', 'ko'): " CUSTOM_LANG
        LANGUAGE="$CUSTOM_LANG"
        echo -e "  ${GREEN}Language: $LANGUAGE${NC}"
        ;;
    *)
        LANGUAGE=""
        echo -e "  ${YELLOW}Invalid choice. Using auto-detect${NC}"
        ;;
esac

# Generate filenames
TIMESTAMP=$(date +"%Y%m%d_%H%M")
AUDIO_FILE="${SAFE_NAME}_${TIMESTAMP}.wav"
TRANSCRIPT_FILE="${SAFE_NAME}_${TIMESTAMP}_transcript.txt"

echo -e "\n${CYAN}Summary:${NC}"
echo "  Meeting: $MEETING_NAME"
echo "  Duration: $DURATION seconds ($(echo "$DURATION/60" | bc) minutes)"
echo "  Model: $MODEL (good quality for meetings)"
echo "  Language: ${LANGUAGE:-Auto-detect}"
echo "  Audio file: $AUDIO_FILE"
echo "  Transcript file: $TRANSCRIPT_FILE"
echo ""

# Show audio device info
echo -e "${CYAN}Audio Device:${NC}"
python -c "
import sounddevice as sd
devices = sd.query_devices()
default = sd.default.device[0]
device_name = devices[default]['name']
print(f'  Using: {device_name} (Device {default})')
print(f'  Make sure your microphone is properly connected and working.')
"

echo ""
echo -e "${YELLOW}Important:${NC}"
echo "  1. Find a quiet location"
echo "  2. Place microphone close to speakers"
echo "  3. Speak clearly"
echo "  4. Avoid background noise"
echo ""

read -p "Press Enter to start meeting recording... (Ctrl+C to cancel)"

# Build command
CMD="python src/core/simple_whisper.py --record --duration $DURATION --model $MODEL"
CMD="$CMD --output-audio \"$AUDIO_FILE\" --output-text \"$TRANSCRIPT_FILE\""
if [ -n "$LANGUAGE" ]; then
    CMD="$CMD --language $LANGUAGE"
fi

echo -e "\n${GREEN}Starting meeting recording...${NC}"
echo "Command: $CMD"
echo ""
echo -e "${CYAN}Recording in progress...${NC}"
echo "Meeting: $MEETING_NAME"
echo "Started: $(date)"
echo ""

# Run the command
eval $CMD

echo -e "\n${GREEN}Meeting recording completed!${NC}"
echo ""
echo -e "${CYAN}Summary:${NC}"
echo "  Meeting: $MEETING_NAME"
echo "  Duration: $(echo "$DURATION/60" | bc) minutes"
echo "  Audio: $AUDIO_FILE"
echo "  Transcript: $TRANSCRIPT_FILE"
echo "  Completed: $(date)"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "  1. Review the transcript: cat \"$TRANSCRIPT_FILE\" | less"
echo "  2. Edit if needed"
echo "  3. Share with participants"
echo ""
echo -e "${CYAN}Additional commands:${NC}"
echo "  Transcribe another file: ./transcribe_file.sh <audiofile>"
echo "  Quick recording: ./quick_record.sh"
echo "  Interactive mode: python src/core/interactive_whisper.py"
echo ""