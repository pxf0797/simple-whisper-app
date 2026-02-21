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
MODEL=""
DURATION=""
OUTPUT_AUDIO=""
OUTPUT_TEXT=""
DEVICE=""
INPUT_DEVICE=""
LANGUAGE=""
SIMPLIFIED_CHINESE=""

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
        -l|--language)
            LANGUAGE="$2"
            shift 2
            ;;
        --simplified-chinese)
            SIMPLIFIED_CHINESE="$2"
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
            echo "  -m, --model MODEL        Model size: tiny, base, small, medium, large"
            echo "      --device DEVICE      Computation device: cpu, mps, cuda"
            echo "      --input-device ID    Audio input device ID (use --list-devices to see IDs)"
            echo "  -l, --language CODE      Language code: en, zh, ja, etc. (empty for auto detect).
                           Use 'multi:lang1,lang2' for multiple language hints."
            echo "      --simplified-chinese yes/no  Convert Chinese to simplified Chinese"
            echo "  -o, --output FILENAME    Base filename for output (audio and transcription)"
            echo "  -h, --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                       Interactive selection of all options"
            echo "  $0 -d 10 -m base         Record for 10 seconds with base model"
            echo "  $0 -d 60 -m small -l zh  Record for 60 seconds with small model, Chinese language"
            echo "  $0 -d 60 -m medium -l zh+en  Record for 60 seconds with medium model, bilingual Chinese-English"
            echo "  $0 -d 300 -o meeting     Record 5 minutes, save as meeting.wav and meeting_transcription.txt"
            echo "  $0 -d 60 -m small --device mps --input-device 5  Record with GPU and specific microphone"
            echo "  $0 -d 120 -m medium -l auto  Record 2 minutes with medium model, auto language detection"
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

# Model selection
if [ -z "$MODEL" ]; then
    echo -e "\n${BLUE}Model Selection:${NC}"
    echo "  1) tiny    - Fastest, lowest accuracy"
    echo "  2) base    - Good balance"
    echo "  3) small   - Better accuracy"
    echo "  4) medium  - High accuracy"
    echo "  5) large   - Highest accuracy"

    while true; do
        read -p "Select model (1-5): " MODEL_CHOICE
        case $MODEL_CHOICE in
            1) MODEL="tiny"; break ;;
            2) MODEL="base"; break ;;
            3) MODEL="small"; break ;;
            4) MODEL="medium"; break ;;
            5) MODEL="large"; break ;;
            *) echo "Please enter a number 1-5" ;;
        esac
    done
fi

# Language selection
if [ -z "$LANGUAGE" ]; then
    echo -e "\n${BLUE}Language Selection Mode:${NC}"
    echo "  1) auto           - Automatic language detection (recommended)"
    echo "  2) single         - Specify a single language"
    echo "  3) multiple       - Specify multiple languages (e.g., Chinese + English)"

    read -p "Select mode (1-3, default: 1): " MODE_CHOICE

    case $MODE_CHOICE in
        1|"")
            # Auto detection
            LANGUAGE=""
            SIMPLIFIED_CHINESE=""
            ;;
        2)
            # Single language selection
            echo -e "\n${BLUE}Single Language Selection:${NC}"
            echo "  1) en  - English"
            echo "  2) zh  - Chinese"
            echo "  3) ja  - Japanese"
            echo "  4) ko  - Korean"
            echo "  5) fr  - French"
            echo "  6) de  - German"
            echo "  7) other - Enter custom language code"

            read -p "Select language (1-7): " LANG_CHOICE
            case $LANG_CHOICE in
                1) LANGUAGE="en" ;;
                2) LANGUAGE="zh" ;;
                3) LANGUAGE="ja" ;;
                4) LANGUAGE="ko" ;;
                5) LANGUAGE="fr" ;;
                6) LANGUAGE="de" ;;
                7) read -p "Enter language code (e.g., 'es', 'ru', 'pt'): " LANGUAGE ;;
                *) LANGUAGE="en" ;;  # Default to English
            esac

            # For Chinese, ask about simplified Chinese
            if [ "$LANGUAGE" = "zh" ]; then
                read -p "Convert to Simplified Chinese? (y/n, default: y): " SIMPLIFY_INPUT
                if [[ "$SIMPLIFY_INPUT" =~ ^[Nn]$ ]]; then
                    SIMPLIFIED_CHINESE="no"
                else
                    SIMPLIFIED_CHINESE="yes"
                fi
            else
                SIMPLIFIED_CHINESE=""
            fi
            ;;
        3)
            # Multiple languages selection
            echo -e "\n${BLUE}Multiple Languages Selection:${NC}"
            echo "You can add multiple languages. The system will use auto-detection"
            echo "but will be aware of these languages for better accuracy."
            echo ""

            LANGUAGES_ARRAY=()
            while true; do
                echo "Current selected languages: ${LANGUAGES_ARRAY[*]}"
                echo ""
                echo "  1) Add English"
                echo "  2) Add Chinese"
                echo "  3) Add Japanese"
                echo "  4) Add Korean"
                echo "  5) Add French"
                echo "  6) Add German"
                echo "  7) Add custom language"
                echo "  8) Done adding languages"

                read -p "Select option (1-8): " MULTI_CHOICE
                case $MULTI_CHOICE in
                    1) LANGUAGES_ARRAY+=("en") ;;
                    2) LANGUAGES_ARRAY+=("zh") ;;
                    3) LANGUAGES_ARRAY+=("ja") ;;
                    4) LANGUAGES_ARRAY+=("ko") ;;
                    5) LANGUAGES_ARRAY+=("fr") ;;
                    6) LANGUAGES_ARRAY+=("de") ;;
                    7) read -p "Enter language code: " CUSTOM_LANG && LANGUAGES_ARRAY+=("$CUSTOM_LANG") ;;
                    8) break ;;
                    *) echo "Please enter 1-8" ;;
                esac

                # If we have at least 2 languages, ask if user wants to add more
                if [ ${#LANGUAGES_ARRAY[@]} -ge 2 ]; then
                    read -p "Add more languages? (y/n, default: n): " ADD_MORE
                    if [[ ! "$ADD_MORE" =~ ^[Yy]$ ]]; then
                        break
                    fi
                fi
            done

            # Format languages for display and passing to script
            if [ ${#LANGUAGES_ARRAY[@]} -eq 0 ]; then
                LANGUAGE=""  # Auto detection if no languages selected
            elif [ ${#LANGUAGES_ARRAY[@]} -eq 1 ]; then
                LANGUAGE="${LANGUAGES_ARRAY[0]}"
                # For Chinese, ask about simplified Chinese
                if [ "$LANGUAGE" = "zh" ]; then
                    read -p "Convert to Simplified Chinese? (y/n, default: y): " SIMPLIFY_INPUT
                    if [[ "$SIMPLIFY_INPUT" =~ ^[Nn]$ ]]; then
                        SIMPLIFIED_CHINESE="no"
                    else
                        SIMPLIFIED_CHINESE="yes"
                    fi
                else
                    SIMPLIFIED_CHINESE=""
                fi
            else
                # Multiple languages - use auto detection but pass languages as hint
                LANGUAGE="multi:$(IFS=,; echo "${LANGUAGES_ARRAY[*]}")"
                # Check if Chinese is in the list
                if [[ " ${LANGUAGES_ARRAY[*]} " =~ " zh " ]]; then
                    read -p "Convert Chinese to Simplified Chinese? (y/n, default: y): " SIMPLIFY_INPUT
                    if [[ "$SIMPLIFY_INPUT" =~ ^[Nn]$ ]]; then
                        SIMPLIFIED_CHINESE="no"
                    else
                        SIMPLIFIED_CHINESE="yes"
                    fi
                else
                    SIMPLIFIED_CHINESE=""
                fi
            fi
            ;;
        *)
            LANGUAGE=""
            SIMPLIFIED_CHINESE=""
            ;;
    esac
fi

echo -e "\n${BLUE}Configuration:${NC}"
echo "  Model: $MODEL"

# Format language display
if [ -z "$LANGUAGE" ]; then
    echo "  Language: auto detect"
elif [[ "$LANGUAGE" == multi:* ]]; then
    # Extract languages after "multi:" prefix
    LANGS=${LANGUAGE#multi:}
    echo "  Languages: Multiple (${LANGS})"
else
    echo "  Language: $LANGUAGE"
fi

# Show simplified Chinese setting if applicable
if [ -n "$SIMPLIFIED_CHINESE" ]; then
    if [[ "$LANGUAGE" == *zh* ]] || [[ "$LANGUAGE" == multi:* ]] && [[ "$LANGUAGE" == *zh* ]]; then
        if [ "$SIMPLIFIED_CHINESE" = "yes" ]; then
            echo "  Simplified Chinese: yes"
        else
            echo "  Simplified Chinese: no"
        fi
    fi
fi

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
    echo "  1) cpu   - Use CPU"
    echo "  2) mps   - Use Apple Silicon GPU (M1/M2/M3)"
    echo "  3) cuda  - Use NVIDIA GPU (CUDA)"

    while true; do
        read -p "Select device (1-3, default: 1): " DEVICE_CHOICE
        case $DEVICE_CHOICE in
            1|"") DEVICE="cpu"; break ;;
            2) DEVICE="mps"; break ;;
            3) DEVICE="cuda"; break ;;
            *) echo "Please enter a number 1-3 or press Enter for default" ;;
        esac
    done
fi

echo ""
if [ -n "$INPUT_DEVICE" ] && [ -n "$DEVICE" ]; then
    echo "All parameters set. Starting recording automatically..."
else
    read -p "Press Enter to start recording... (Ctrl+C to cancel)"
fi

# Build command
CMD="python simple_whisper.py --record --model $MODEL --output-audio $OUTPUT_AUDIO --output-text $OUTPUT_TEXT"

if [ -n "$INPUT_DEVICE" ]; then
    CMD="$CMD --input-device $INPUT_DEVICE"
fi

if [ -n "$DEVICE" ]; then
    CMD="$CMD --device $DEVICE"
fi

if [ -n "$LANGUAGE" ]; then
    CMD="$CMD --language $LANGUAGE"
fi

if [ -n "$SIMPLIFIED_CHINESE" ]; then
    CMD="$CMD --simplified-chinese $SIMPLIFIED_CHINESE"
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