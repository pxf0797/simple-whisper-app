#!/bin/bash
# Workflow Controller for Simple Whisper Application
# Based on quick_record.sh style with workflow control features

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="workflow_controller_$(date +"%Y%m%d_%H%M%S").log"

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    case $level in
        "INFO") echo -e "${GREEN}[INFO]${NC} $message" ;;
        "WARN") echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        *) echo -e "${BLUE}[$level]${NC} $message" ;;
    esac

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Function to display header
show_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  SIMPLE WHISPER - WORKFLOW CONTROLLER${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Function to check environment
check_environment() {
    log_message "INFO" "Checking environment..."

    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_message "ERROR" "Python3 not found. Please install Python 3.8+"
        exit 1
    fi

    # Check virtual environment
    if [[ -z "$VIRTUAL_ENV" ]]; then
        if [ -f "venv/bin/activate" ]; then
            source venv/bin/activate
            log_message "INFO" "Virtual environment activated"
        else
            log_message "WARN" "Virtual environment not found"
            echo -e "${YELLOW}Running without virtual environment${NC}"
        fi
    fi

    echo -e "${BLUE}=== Dependency Check ===${NC}"

    # Core dependencies (required for basic functionality)
    echo -e "${CYAN}Checking core dependencies...${NC}"
    local core_missing=0
    if python3 -c "import whisper" 2>/dev/null; then
        echo -e "  ${GREEN}✓ whisper${NC}"
    else
        echo -e "  ${RED}✗ whisper${NC} (required)"
        core_missing=1
    fi

    if python3 -c "import sounddevice" 2>/dev/null; then
        echo -e "  ${GREEN}✓ sounddevice${NC}"
    else
        echo -e "  ${RED}✗ sounddevice${NC} (required)"
        core_missing=1
    fi

    if python3 -c "import soundfile" 2>/dev/null; then
        echo -e "  ${GREEN}✓ soundfile${NC}"
    else
        echo -e "  ${RED}✗ soundfile${NC} (required)"
        core_missing=1
    fi

    # Torch/GPU support
    echo -e "${CYAN}Checking PyTorch and compute environment...${NC}"
    if python3 -c "import torch" 2>/dev/null; then
        echo -e "  ${GREEN}✓ PyTorch${NC}"
        # Check compute device availability
        if python3 -c "import torch; print('CUDA available:', torch.cuda.is_available())" 2>/dev/null | grep -q "CUDA available: True"; then
            echo -e "  ${GREEN}✓ CUDA GPU support${NC}"
        elif python3 -c "import torch; has_mps = hasattr(torch.backends, 'mps') and torch.backends.mps.is_available(); print('MPS available:', has_mps)" 2>/dev/null | grep -q "MPS available: True"; then
            echo -e "  ${GREEN}✓ Apple Silicon (MPS) support${NC}"
        else
            echo -e "  ${YELLOW}⚠ No GPU acceleration (CPU only)${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠ PyTorch not found (required for whisper)${NC}"
    fi

    # Optional dependencies
    echo -e "${CYAN}Checking optional dependencies...${NC}"
    if python3 -c "import zhconv" 2>/dev/null; then
        echo -e "  ${GREEN}✓ zhconv${NC} (Chinese simplified/traditional conversion)"
    else
        echo -e "  ${YELLOW}⚠ zhconv${NC} (optional: Chinese conversion)"
        echo -e "    Install: ${CYAN}pip install zhconv${NC}"
    fi

    if python3 -c "import webrtcvad" 2>/dev/null; then
        echo -e "  ${GREEN}✓ webrtcvad${NC} (Voice Activity Detection)"
    else
        echo -e "  ${YELLOW}⚠ webrtcvad${NC} (optional: sentence-based VAD)"
        echo -e "    Install: ${CYAN}pip install webrtcvad${NC}"
        echo -e "    Note: For Python 3.12+, may need: ${CYAN}pip install 'setuptools<60'${NC}"
    fi

    # Audio devices
    echo -e "${CYAN}Checking audio devices...${NC}"
    if python3 -c "import sounddevice as sd; devices = sd.query_devices(); print('Audio devices available')" 2>/dev/null; then
        echo -e "  ${GREEN}✓ Audio system accessible${NC}"
    else
        echo -e "  ${YELLOW}⚠ Audio system may have issues${NC}"
    fi

    # Summary
    if [ $core_missing -eq 0 ]; then
        echo -e "${GREEN}✓ All core dependencies are installed${NC}"
        log_message "INFO" "All core dependencies are installed"
    else
        echo -e "${YELLOW}⚠ Some core dependencies are missing${NC}"
        echo -e "${YELLOW}  Basic functionality may be limited${NC}"
        log_message "WARN" "Some core dependencies missing"
    fi

    echo -e "${BLUE}=== End Dependency Check ===${NC}"
    echo ""
}

# Function to check if a Python module is available
check_python_module() {
    local module_name="$1"
    local description="$2"
    local required="$3"  # "required" or "optional"

    if python3 -c "import $module_name" 2>/dev/null; then
        echo -e "  ${GREEN}✓ $module_name${NC}"
        if [ -n "$description" ]; then
            echo -e "    ($description)"
        fi
        return 0
    else
        if [ "$required" = "required" ]; then
            echo -e "  ${RED}✗ $module_name${NC} (required)"
            if [ -n "$description" ]; then
                echo -e "    ($description)"
            fi
            return 1
        else
            echo -e "  ${YELLOW}⚠ $module_name${NC} (optional)"
            if [ -n "$description" ]; then
                echo -e "    ($description)"
            fi
            return 0
        fi
    fi
}

# Function to check VAD compatibility and provide installation guidance
check_vad_compatibility() {
    echo -e "${BLUE}Checking Voice Activity Detection (VAD) compatibility...${NC}"

    # Check if webrtcvad is importable
    if python3 -c "import webrtcvad" 2>/dev/null; then
        echo -e "${GREEN}✓ webrtcvad is available${NC}"
        VAD_AVAILABLE=1
        return 0
    else
        echo -e "${YELLOW}⚠ webrtcvad is not available${NC}"
        echo ""
        echo "Voice Activity Detection (VAD) is required for sentence-based transcription."
        echo "Without VAD, the system will use fixed chunk mode instead of sentence-based segmentation."
        echo ""
        echo "Possible solutions:"
        echo "1. Install webrtcvad (may require setuptools<60 for Python 3.12+):"
        echo "   pip install 'setuptools<60'"
        echo "   pip install webrtcvad"
        echo ""
        echo "2. Or disable VAD and use fixed chunk mode (less accurate for sentence detection)"
        echo ""

        read -p "Continue without VAD? (y/n, default: y): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            echo "You can install webrtcvad manually and try again."
            return 1
        fi
        VAD_AVAILABLE=0
        return 0
    fi
}

# Function to select workflow
select_workflow() {
    echo -e "${CYAN}Select Workflow:${NC}"
    echo ""
    echo "  1) ${GREEN}Quick Record & Transcribe${NC}"
    echo "     • Record audio and transcribe immediately"
    echo "     • Similar to quick_record.sh with enhanced workflow"
    echo ""
    echo "  2) ${GREEN}Live Streaming Transcription${NC}"
    echo "     • Real-time audio stream processing"
    echo "     • Low latency (3-5 seconds)"
    echo "     • Continuous transcription"
    echo ""
    echo "  3) ${GREEN}Batch File Processing${NC}"
    echo "     • Process multiple audio files"
    echo "     • Supports .wav, .mp3, .m4a formats"
    echo "     • Progress tracking"
    echo ""
    echo "  4) ${GREEN}Interactive Transcription${NC}"
    echo "     • Full interactive experience"
    echo "     • Step-by-step guidance"
    echo "     • All features available"
    echo ""
    echo "  5) ${GREEN}System Diagnostics${NC}"
    echo "     • Test environment and dependencies"
    echo "     • Check audio devices"
    echo "     • Test model loading"
    echo ""
    echo "  6) ${GREEN}Tools & Utilities${NC}"
    echo "     • Audio device listing"
    echo "     • Model information"
    echo "     • Disk space check"
    echo "     • Log viewing"
    echo ""
    echo "  0) ${RED}Exit${NC}"
    echo ""

    read -p "Select workflow (0-6): " WORKFLOW_CHOICE
    echo ""

    case $WORKFLOW_CHOICE in
        1) execute_quick_record ;;
        2) execute_live_streaming ;;
        3) execute_batch_processing ;;
        4) execute_interactive_transcription ;;
        5) execute_system_diagnostics ;;
        6) execute_tools_utilities ;;
        0) exit_controller ;;
        *) echo -e "${RED}Invalid selection${NC}"; return 1 ;;
    esac
}

# Function to select audio device interactively
select_audio_device_interactive() {
    local default_device=""
    local device_list=""

    # Output menu to stderr, result to stdout
    echo -e "${BLUE}Audio Device Selection:${NC}" >&2
    echo "Listing available audio input devices..." >&2

    # Capture device list and display to stderr
    device_list=$(python $PROJECT_ROOT/src/core/simple_whisper.py --list-audio-devices 2>&1)
    echo "$device_list" >&2

    # Get default device ID
    default_device=$(python -c "
import sounddevice as sd
try:
    default = sd.default.device[0]
    print(default)
except:
    print('')
")

    if [ -n "$default_device" ]; then
        echo -e "\nDefault device ID: $default_device" >&2
        read -p "Enter device ID (press Enter for default $default_device): " device_input >&2
        if [ -n "$device_input" ]; then
            echo "$device_input"
        else
            echo "$default_device"
        fi
    else
        read -p "Enter device ID: " device_input >&2
        echo "$device_input"
    fi
}

# Function to select model interactively
select_model_interactive() {
    local default_choice=${1:-2}

    # Output menu to stderr, result to stdout
    echo -e "${BLUE}Model Selection:${NC}" >&2
    echo "  1) tiny    - Fastest, lowest accuracy" >&2
    echo "  2) base    - Good balance" >&2
    echo "  3) small   - Better accuracy" >&2
    echo "  4) medium  - High accuracy" >&2
    echo "  5) large   - Highest accuracy" >&2

    while true; do
        read -p "Select model (1-5, default: $default_choice): " model_choice >&2
        case $model_choice in
            1) echo "tiny"; break ;;
            2|"") echo "base"; break ;;
            3) echo "small"; break ;;
            4) echo "medium"; break ;;
            5) echo "large"; break ;;
            *) echo "Please enter a number 1-5" >&2 ;;
        esac
    done
}

# Function to select language interactively (returns language code via stdout)
select_language_interactive() {
    # Output menu to stderr, result to stdout
    echo -e "${BLUE}Language Selection Mode:${NC}" >&2
    echo "  1) auto           - Automatic language detection (recommended)" >&2
    echo "  2) single         - Specify a single language" >&2
    echo "  3) multiple       - Specify multiple languages (e.g., Chinese + English)" >&2

    read -p "Select mode (1-3, default: 1): " MODE_CHOICE >&2
    # Clean input (remove whitespace, newlines)
    MODE_CHOICE=$(echo "$MODE_CHOICE" | tr -d '[:space:]')

    case $MODE_CHOICE in
        1|"")
            # Auto detection - return empty string for language
            echo ""
            ;;
        2)
            # Single language selection
            echo -e "\n${BLUE}Single Language Selection:${NC}" >&2
            echo "  1) en  - English" >&2
            echo "  2) zh  - Chinese" >&2
            echo "  3) ja  - Japanese" >&2
            echo "  4) ko  - Korean" >&2
            echo "  5) fr  - French" >&2
            echo "  6) de  - German" >&2
            echo "  7) other - Enter custom language code" >&2

            read -p "Select language (1-7): " LANG_CHOICE >&2
            # Clean input (remove whitespace, newlines)
            LANG_CHOICE=$(echo "$LANG_CHOICE" | tr -d '[:space:]')
            local SELECTED_LANG=""
            case $LANG_CHOICE in
                1) SELECTED_LANG="en" ;;
                2) SELECTED_LANG="zh" ;;
                3) SELECTED_LANG="ja" ;;
                4) SELECTED_LANG="ko" ;;
                5) SELECTED_LANG="fr" ;;
                6) SELECTED_LANG="de" ;;
                7) read -p "Enter language code (e.g., 'es', 'ru', 'pt'): " SELECTED_LANG >&2; SELECTED_LANG=$(echo "$SELECTED_LANG" | tr -d '[:space:]') ;;
                *) SELECTED_LANG="en" ;;  # Default to English
            esac

            # For Chinese, ask about simplified Chinese
            local SIMPLIFIED=""
            if [ "$SELECTED_LANG" = "zh" ]; then
                read -p "Convert to Simplified Chinese? (y/n, default: y): " SIMPLIFY_INPUT >&2
                SIMPLIFY_INPUT=$(echo "$SIMPLIFY_INPUT" | tr -d '[:space:]')
                if [[ "$SIMPLIFY_INPUT" =~ ^[Nn]$ ]]; then
                    echo "zh:no"
                else
                    echo "zh:yes"
                fi
            else
                echo "$SELECTED_LANG"
            fi
            ;;
        3)
            # Multiple languages selection
            echo -e "\n${BLUE}Multiple Languages Selection:${NC}" >&2
            echo "You can add multiple languages. The system will use auto-detection" >&2
            echo "but will be aware of these languages for better accuracy." >&2
            echo "" >&2

            local LANGUAGES_ARRAY=()
            while true; do
                echo "Current selected languages: ${LANGUAGES_ARRAY[*]}" >&2
                echo "" >&2
                echo "  1) Add English" >&2
                echo "  2) Add Chinese" >&2
                echo "  3) Add Japanese" >&2
                echo "  4) Add Korean" >&2
                echo "  5) Add French" >&2
                echo "  6) Add German" >&2
                echo "  7) Add custom language" >&2
                echo "  8) Done adding languages" >&2

                read -p "Select option (1-8): " MULTI_CHOICE >&2
                # Clean input (remove whitespace, newlines)
                MULTI_CHOICE=$(echo "$MULTI_CHOICE" | tr -d '[:space:]')
                case $MULTI_CHOICE in
                    1) LANGUAGES_ARRAY+=("en") ;;
                    2) LANGUAGES_ARRAY+=("zh") ;;
                    3) LANGUAGES_ARRAY+=("ja") ;;
                    4) LANGUAGES_ARRAY+=("ko") ;;
                    5) LANGUAGES_ARRAY+=("fr") ;;
                    6) LANGUAGES_ARRAY+=("de") ;;
                    7) read -p "Enter language code: " CUSTOM_LANG >&2; CUSTOM_LANG=$(echo "$CUSTOM_LANG" | tr -d '[:space:]'); LANGUAGES_ARRAY+=("$CUSTOM_LANG") ;;
                    8) break ;;
                    *) echo "Please enter 1-8" >&2 ;;
                esac

                # If we have at least 2 languages, ask if user wants to add more
                if [ ${#LANGUAGES_ARRAY[@]} -ge 2 ]; then
                    read -p "Add more languages? (y/n, default: n): " ADD_MORE >&2
                    if [[ ! "$ADD_MORE" =~ ^[Yy]$ ]]; then
                        break
                    fi
                fi
            done

            # Format languages for passing to script
            if [ ${#LANGUAGES_ARRAY[@]} -eq 0 ]; then
                echo ""  # Auto detection if no languages selected
            elif [ ${#LANGUAGES_ARRAY[@]} -eq 1 ]; then
                local SINGLE_LANG="${LANGUAGES_ARRAY[0]}"
                # For Chinese, ask about simplified Chinese
                if [ "$SINGLE_LANG" = "zh" ]; then
                    read -p "Convert to Simplified Chinese? (y/n, default: y): " SIMPLIFY_INPUT >&2
                    SIMPLIFY_INPUT=$(echo "$SIMPLIFY_INPUT" | tr -d '[:space:]')
                    if [[ "$SIMPLIFY_INPUT" =~ ^[Nn]$ ]]; then
                        echo "zh:no"
                    else
                        echo "zh:yes"
                    fi
                else
                    echo "$SINGLE_LANG"
                fi
            else
                # Multiple languages - use auto detection but pass languages as hint
                local MULTI_LANGS="multi:$(IFS=,; echo "${LANGUAGES_ARRAY[*]}")"
                # Check if Chinese is in the list
                if [[ " ${LANGUAGES_ARRAY[*]} " =~ " zh " ]]; then
                    read -p "Convert Chinese to Simplified Chinese? (y/n, default: y): " SIMPLIFY_INPUT >&2
                    SIMPLIFY_INPUT=$(echo "$SIMPLIFY_INPUT" | tr -d '[:space:]')
                    if [[ "$SIMPLIFY_INPUT" =~ ^[Nn]$ ]]; then
                        echo "$MULTI_LANGS:no"
                    else
                        echo "$MULTI_LANGS:yes"
                    fi
                else
                    echo "$MULTI_LANGS"
                fi
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to select computation device interactively
select_device_interactive() {
    # Output menu to stderr, result to stdout
    echo -e "${BLUE}Computation Device Selection:${NC}" >&2
    echo "  1) cpu   - Use CPU" >&2
    echo "  2) mps   - Use Apple Silicon GPU (M1/M2/M3)" >&2
    echo "  3) cuda  - Use NVIDIA GPU (CUDA)" >&2

    while true; do
        read -p "Select device (1-3, default: 1): " DEVICE_CHOICE >&2
        case $DEVICE_CHOICE in
            1|"") echo "cpu"; break ;;
            2) echo "mps"; break ;;
            3) echo "cuda"; break ;;
            *) echo "Please enter a number 1-3 or press Enter for default" >&2 ;;
        esac
    done
}

# Function: Quick Record & Transcribe
execute_quick_record() {
    log_message "INFO" "Starting Quick Record workflow"

    # Parse command line arguments for this workflow
    local PRESET=""
    local MODEL_OVERRIDE=""
    local LANGUAGE_OVERRIDE=""
    local DURATION_ARG=""
    local INPUT_DEVICE_ARG=""
    local DEVICE_ARG=""
    local SIMPLIFIED_CHINESE_ARG=""
    local AUTO_START=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --preset)
                PRESET="$2"
                shift 2
                ;;
            --model)
                MODEL_OVERRIDE="$2"
                shift 2
                ;;
            --language)
                LANGUAGE_OVERRIDE="$2"
                shift 2
                ;;
            --duration)
                DURATION_ARG="$2"
                shift 2
                ;;
            --input-device)
                INPUT_DEVICE_ARG="$2"
                shift 2
                ;;
            --device)
                DEVICE_ARG="$2"
                shift 2
                ;;
            --simplified-chinese)
                SIMPLIFIED_CHINESE_ARG="$2"
                shift 2
                ;;
            --auto-start)
                AUTO_START=true
                shift
                ;;
            *)
                # Skip unknown arguments or keep for quick_record.sh
                shift
                ;;
        esac
    done

    echo -e "${CYAN}Quick Record & Transcribe${NC}"
    echo ""

    # Check if quick_record.sh exists
    if [ -f "quick_record.sh" ]; then
        echo -e "${GREEN}Using quick_record.sh script${NC}"
        ./quick_record.sh "$@"
        return
    fi

    # Otherwise use interactive parameter selection
    echo -e "${YELLOW}quick_record.sh not found, using built-in workflow${NC}"
    echo ""

    # Configuration mode selection
    echo -e "${YELLOW}Select configuration mode:${NC}"
    echo "  1) Quick setup (recommended for most users)"
    echo "     • Base model, auto language detection, default audio device"
    echo "     • CPU computation, balanced settings"
    echo ""
    echo "  2) Standard setup (balanced performance)"
    echo "     • Small model, auto language, default audio device"
    echo "     • Good balance between speed and accuracy"
    echo ""
    echo "  3) High quality setup (maximum accuracy)"
    echo "     • Medium model, auto language, default audio device"
    echo "     • Higher accuracy, slower processing"
    echo ""
    echo "  4) Custom setup (full control)"
    echo "     • Select all parameters manually"
    echo ""

    if [ -n "$PRESET" ]; then
        CONFIG_MODE="$PRESET"
        echo -e "${GREEN}Using preset mode $PRESET${NC}"
    else
        read -p "Select mode (1-4, default: 1): " CONFIG_MODE
        CONFIG_MODE=${CONFIG_MODE:-1}
    fi

    case $CONFIG_MODE in
        1)
            # Quick setup - base model, auto language, default device
            echo -e "${GREEN}Using quick setup (base model, auto language)${NC}"
            MODEL="base"
            LANGUAGE=""
            SIMPLIFIED_CHINESE=""
            ;;
        2)
            # Standard setup - small model, auto language, default device
            echo -e "${GREEN}Using standard setup (balanced performance)${NC}"
            MODEL="small"
            LANGUAGE=""
            SIMPLIFIED_CHINESE=""
            ;;
        3)
            # High quality setup - medium model, auto language, default device
            echo -e "${GREEN}Using high quality setup (maximum accuracy)${NC}"
            MODEL="medium"
            LANGUAGE=""
            SIMPLIFIED_CHINESE=""
            ;;
        4)
            # Custom setup - interactive selection
            echo -e "${GREEN}Custom setup - select parameters manually${NC}"

            # Model selection
            MODEL=$(select_model_interactive 2)

            # Language selection
            LANGUAGE_RESULT=$(select_language_interactive)

            # Parse language result (may contain simplified chinese setting)
            LANGUAGE=""
            SIMPLIFIED_CHINESE=""
            if [ -n "$LANGUAGE_RESULT" ]; then
                if [[ "$LANGUAGE_RESULT" == *:* ]]; then
                    # Format: "language:simplified" or "multi:lang1,lang2:simplified"
                    LANGUAGE="${LANGUAGE_RESULT%:*}"
                    SIMPLIFIED_CHINESE="${LANGUAGE_RESULT##*:}"
                else
                    LANGUAGE="$LANGUAGE_RESULT"
                fi
            fi

            # Audio device selection
            echo -e "\n${BLUE}Audio Device Selection:${NC}"
            INPUT_DEVICE=$(select_audio_device_interactive)

            # Computation device selection
            DEVICE=$(select_device_interactive)
            ;;
        *)
            # Default to quick setup
            echo -e "${GREEN}Using quick setup (base model, auto language)${NC}"
            MODEL="base"
            LANGUAGE=""
            SIMPLIFIED_CHINESE=""
            ;;
    esac

    # Apply parameter overrides from command line
    if [ -n "$MODEL_OVERRIDE" ]; then
        MODEL="$MODEL_OVERRIDE"
        echo -e "${GREEN}Overriding model to: $MODEL${NC}"
    fi
    if [ -n "$LANGUAGE_OVERRIDE" ]; then
        LANGUAGE="$LANGUAGE_OVERRIDE"
        echo -e "${GREEN}Overriding language to: $LANGUAGE${NC}"
    fi
    if [ -n "$SIMPLIFIED_CHINESE_ARG" ]; then
        SIMPLIFIED_CHINESE="$SIMPLIFIED_CHINESE_ARG"
        echo -e "${GREEN}Overriding simplified Chinese to: $SIMPLIFIED_CHINESE${NC}"
    fi
    if [ -n "$DEVICE_ARG" ]; then
        DEVICE="$DEVICE_ARG"
        echo -e "${GREEN}Overriding computation device to: $DEVICE${NC}"
    fi
    if [ -n "$INPUT_DEVICE_ARG" ]; then
        INPUT_DEVICE="$INPUT_DEVICE_ARG"
        echo -e "${GREEN}Overriding audio device to: $INPUT_DEVICE${NC}"
    fi

    # Computation device selection (if not specified via command line)
    if [ -z "$DEVICE" ]; then
        DEVICE=$(select_device_interactive)
    fi

    # For preset modes (1-3), get default audio device
    if [ "$CONFIG_MODE" -le 3 ]; then
        echo "Getting default audio device..."
        INPUT_DEVICE=$(python -c "
import sounddevice as sd
try:
    default = sd.default.device[0]
    print(default)
except:
    print('')
")
        if [ -z "$INPUT_DEVICE" ]; then
            INPUT_DEVICE=""
        fi

        # Override with command line argument if provided
        if [ -n "$INPUT_DEVICE_ARG" ]; then
            INPUT_DEVICE="$INPUT_DEVICE_ARG"
            echo -e "${GREEN}Overriding audio device to: $INPUT_DEVICE${NC}"
        fi
    fi

    # Duration selection
    if [ -n "$DURATION_ARG" ]; then
        DURATION="$DURATION_ARG"
        echo -e "${GREEN}Using duration from command line: $DURATION seconds${NC}"
    else
        echo -e "\n${BLUE}Recording Duration:${NC}"
        echo "  Enter duration in seconds (e.g., 10, 60, 300)"
        echo "  Or press Enter for manual stop (Ctrl+C to stop)"
        echo ""
        read -p "Duration (seconds, empty for manual): " DURATION
    fi

    # Generate output filenames
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    AUDIO_FILE="$PROJECT_ROOT/record/recording_${TIMESTAMP}.wav"
    TEXT_FILE="$PROJECT_ROOT/record/recording_${TIMESTAMP}_transcription.txt"

    mkdir -p "$PROJECT_ROOT/record"

    # Check zhconv dependency if simplified Chinese conversion is requested
    if [ "$SIMPLIFIED_CHINESE" = "yes" ]; then
        if [[ "$LANGUAGE" == *zh* ]] || [[ "$LANGUAGE" == multi:* ]] && [[ "$LANGUAGE" == *zh* ]]; then
            if ! python3 -c "import zhconv" 2>/dev/null; then
                echo -e "${YELLOW}Warning: zhconv library not found${NC}"
                echo -e "${YELLOW}Simplified Chinese conversion requires zhconv module${NC}"
                echo -e "${CYAN}Install with: pip install zhconv${NC}"
                read -p "Continue without simplified Chinese conversion? (y/n, default: y): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Nn]$ ]]; then
                    echo -e "${YELLOW}Cancelling...${NC}"
                    return
                else
                    # Disable simplified Chinese conversion
                    SIMPLIFIED_CHINESE="no"
                    echo -e "${YELLOW}Simplified Chinese conversion disabled${NC}"
                fi
            fi
        fi
    fi

    # Build command
    CMD="python $PROJECT_ROOT/src/core/simple_whisper.py --record --model $MODEL --output-audio \"$AUDIO_FILE\" --output-text \"$TEXT_FILE\""

    if [ -n "$LANGUAGE" ]; then
        CMD="$CMD --language $LANGUAGE"
    fi

    if [ -n "$SIMPLIFIED_CHINESE" ]; then
        CMD="$CMD --simplified-chinese $SIMPLIFIED_CHINESE"
    fi

    if [ -n "$DURATION" ]; then
        CMD="$CMD --duration $DURATION"
    fi

    if [ -n "$INPUT_DEVICE" ]; then
        CMD="$CMD --input-device $INPUT_DEVICE"
    fi

    if [ -n "$DEVICE" ]; then
        CMD="$CMD --device $DEVICE"
    fi

    echo -e "\n${GREEN}Configuration:${NC}"
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
    echo "  Duration: ${DURATION:-manual stop}"
    echo "  Audio output: $AUDIO_FILE"
    echo "  Text output: $TEXT_FILE"
    echo ""

    if [ "$AUTO_START" = true ]; then
        echo -e "${GREEN}Auto-start enabled, starting immediately...${NC}"
    else
        read -p "Start recording? (y/n): " START_RESPONSE
        START_RESPONSE=$(echo "$START_RESPONSE" | tr -d '[:space:]')
        if [[ ! "$START_RESPONSE" =~ ^[Yy] ]]; then
            echo -e "${YELLOW}Cancelled${NC}"
            return
        fi
    fi

    echo -e "${GREEN}Starting recording...${NC}"
    log_message "INFO" "Executing: $CMD"

    if eval $CMD; then
        echo -e "${GREEN}Recording completed!${NC}"
        echo ""
        echo "Files created:"
        echo "  Audio: $AUDIO_FILE"
        echo "  Transcription: $TEXT_FILE"
        log_message "INFO" "Quick record workflow completed"
    else
        echo -e "${RED}Recording failed${NC}"
        log_message "ERROR" "Quick record workflow failed"
    fi
}

# Function: Live Streaming Transcription
execute_live_streaming() {
    log_message "INFO" "Starting Live Streaming workflow"

    # Check VAD compatibility
    if ! check_vad_compatibility; then
        echo -e "${YELLOW}VAD check failed. Exiting streaming workflow.${NC}"
        return 1
    fi

    # Parse command line arguments for this workflow
    local PRESET=""
    local MODEL_OVERRIDE=""
    local LANGUAGE_OVERRIDE=""
    local DURATION_ARG=""
    local INPUT_DEVICE_ARG=""
    local DEVICE_ARG=""
    local CHUNK_DUR_ARG=""
    local OVERLAP_ARG=""
    local SIMPLIFIED_CHINESE_ARG=""
    local NO_VAD_ARG=""
    local VAD_AGGRESSIVENESS_ARG=""
    local SILENCE_DURATION_MS_ARG=""
    local AUTO_START=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --preset)
                PRESET="$2"
                shift 2
                ;;
            --model)
                MODEL_OVERRIDE="$2"
                shift 2
                ;;
            --language)
                LANGUAGE_OVERRIDE="$2"
                shift 2
                ;;
            --duration)
                DURATION_ARG="$2"
                shift 2
                ;;
            --input-device)
                INPUT_DEVICE_ARG="$2"
                shift 2
                ;;
            --device)
                DEVICE_ARG="$2"
                shift 2
                ;;
            --chunk-duration)
                CHUNK_DUR_ARG="$2"
                shift 2
                ;;
            --overlap)
                OVERLAP_ARG="$2"
                shift 2
                ;;
            --simplified-chinese)
                SIMPLIFIED_CHINESE_ARG="$2"
                shift 2
                ;;
            --no-vad)
                NO_VAD_ARG="true"
                shift
                ;;
            --vad-aggressiveness)
                VAD_AGGRESSIVENESS_ARG="$2"
                shift 2
                ;;
            --silence-duration-ms)
                SILENCE_DURATION_MS_ARG="$2"
                shift 2
                ;;
            --auto-start)
                AUTO_START=true
                shift
                ;;
            *)
                # Skip unknown arguments
                shift
                ;;
        esac
    done

    echo -e "${CYAN}Live Streaming Transcription${NC}"
    echo ""

    # Check for streaming module
    if [ ! -f "$PROJECT_ROOT/src/streaming/stream_whisper.py" ]; then
        echo -e "${RED}Streaming module not found${NC}"
        echo -e "${YELLOW}Streaming features require $PROJECT_ROOT/src/streaming/stream_whisper.py${NC}"
        echo "You can use simple_whisper.py with --stream flag instead."
        echo ""
        read -p "Use simple_whisper.py with --stream? (y/n): " STREAM_RESPONSE
        STREAM_RESPONSE=$(echo "$STREAM_RESPONSE" | tr -d '[:space:]')
        if [[ ! "$STREAM_RESPONSE" =~ ^[Yy] ]]; then
            return
        fi
        USE_SIMPLE_STREAM=true
    else
        USE_SIMPLE_STREAM=false
    fi

    # Configuration mode selection
    echo -e "${YELLOW}Select configuration mode:${NC}"
    echo "  1) Quick setup (recommended for most users)"
    echo "     • Fast model, auto language detection, default audio device"
    echo "     • Balanced settings for real-time transcription"
    echo ""
    echo "  2) Standard setup (balanced performance)"
    echo "     • Base model, auto language, default audio device"
    echo "     • Good balance between speed and accuracy"
    echo ""
    echo "  3) High quality setup (maximum accuracy)"
    echo "     • Medium model, auto language, default audio device"
    echo "     • Higher accuracy, slower processing"
    echo ""
    echo "  4) Custom setup (full control)"
    echo "     • Select all parameters manually"
    echo ""

    if [ -n "$PRESET" ]; then
        CONFIG_MODE="$PRESET"
        echo -e "${GREEN}Using preset mode $PRESET${NC}"
    else
        read -p "Select mode (1-4, default: 1): " CONFIG_MODE
        CONFIG_MODE=${CONFIG_MODE:-1}
    fi

    # VAD configuration defaults
    NO_VAD=""
    VAD_AGGRESSIVENESS="3"
    SILENCE_DURATION_MS="300"

    # Streaming configuration
    echo -e "${BLUE}Streaming Configuration:${NC}"

    case $CONFIG_MODE in
        1)
            # Quick setup - fast model, auto language, default device
            echo -e "${GREEN}Using quick setup (fast model, auto language)${NC}"
            MODEL="tiny"
            CHUNK_DUR=3.0
            OVERLAP=1.0
            # VAD configuration based on availability
            if [ "${VAD_AVAILABLE:-0}" -eq 1 ]; then
                NO_VAD=""
                VAD_AGGRESSIVENESS="3"
                SILENCE_DURATION_MS="300"
            else
                NO_VAD="true"
                VAD_AGGRESSIVENESS=""
                SILENCE_DURATION_MS=""
            fi

            # Language selection (optional)
            echo -e "${BLUE}Language Configuration:${NC}"
            read -p "Use auto language detection? (y/n, default: y): " AUTO_LANG
            AUTO_LANG=$(echo "$AUTO_LANG" | tr -d '[:space:]')
            if [[ "$AUTO_LANG" =~ ^[Nn]$ ]]; then
                LANGUAGE_RESULT=$(select_language_interactive)
                # Parse language result (may contain simplified chinese setting)
                LANGUAGE=""
                SIMPLIFIED_CHINESE=""
                if [ -n "$LANGUAGE_RESULT" ]; then
                    if [[ "$LANGUAGE_RESULT" == *:* ]]; then
                        # Format: "language:simplified" or "multi:lang1,lang2:simplified"
                        LANGUAGE="${LANGUAGE_RESULT%:*}"
                        SIMPLIFIED_CHINESE="${LANGUAGE_RESULT##*:}"
                    else
                        LANGUAGE="$LANGUAGE_RESULT"
                    fi
                fi
            else
                LANGUAGE=""
                SIMPLIFIED_CHINESE=""
            fi

            # Recording duration selection
            echo -e "${BLUE}Recording Duration:${NC}"
            echo "Enter duration in seconds (0 for unlimited, press Enter for 300 seconds):"
            read -p "Duration: " DURATION_INPUT
            DURATION_INPUT=$(echo "$DURATION_INPUT" | tr -d '[:space:]')
            if [ -z "$DURATION_INPUT" ]; then
                # Empty input - use 300 seconds (5 minutes) as default
                DURATION=300
            elif [ "$DURATION_INPUT" = "0" ]; then
                # 0 means unlimited
                DURATION=0
            else
                # Use the number provided
                DURATION="$DURATION_INPUT"
            fi

            # Audio device selection (optional)
            echo -e "${BLUE}Audio Device Configuration:${NC}"
            read -p "Use default audio device? (y/n, default: y): " DEFAULT_AUDIO
            DEFAULT_AUDIO=$(echo "$DEFAULT_AUDIO" | tr -d '[:space:]')
            if [[ "$DEFAULT_AUDIO" =~ ^[Nn]$ ]]; then
                INPUT_DEVICE=$(select_audio_device_interactive)
            else
                echo "Getting default audio device..."
                INPUT_DEVICE=$(python -c "
import sounddevice as sd
try:
    default = sd.default.device[0]
    print(default)
except:
    print('')
")
                if [ -z "$INPUT_DEVICE" ]; then
                    INPUT_DEVICE=""
                fi
            fi
            ;;
        2)
            # Standard setup - balanced performance
            echo -e "${GREEN}Using standard setup (balanced performance)${NC}"
            MODEL="base"
            CHUNK_DUR=3.0
            OVERLAP=1.0
            # VAD configuration based on availability
            if [ "${VAD_AVAILABLE:-0}" -eq 1 ]; then
                NO_VAD=""
                VAD_AGGRESSIVENESS="3"
                SILENCE_DURATION_MS="300"
            else
                NO_VAD="true"
                VAD_AGGRESSIVENESS=""
                SILENCE_DURATION_MS=""
            fi

            # Language selection (optional)
            echo -e "${BLUE}Language Configuration:${NC}"
            read -p "Use auto language detection? (y/n, default: y): " AUTO_LANG
            AUTO_LANG=$(echo "$AUTO_LANG" | tr -d '[:space:]')
            if [[ "$AUTO_LANG" =~ ^[Nn]$ ]]; then
                LANGUAGE_RESULT=$(select_language_interactive)
                # Parse language result (may contain simplified chinese setting)
                LANGUAGE=""
                SIMPLIFIED_CHINESE=""
                if [ -n "$LANGUAGE_RESULT" ]; then
                    if [[ "$LANGUAGE_RESULT" == *:* ]]; then
                        # Format: "language:simplified" or "multi:lang1,lang2:simplified"
                        LANGUAGE="${LANGUAGE_RESULT%:*}"
                        SIMPLIFIED_CHINESE="${LANGUAGE_RESULT##*:}"
                    else
                        LANGUAGE="$LANGUAGE_RESULT"
                    fi
                fi
            else
                LANGUAGE=""
                SIMPLIFIED_CHINESE=""
            fi

            # Recording duration selection
            echo -e "${BLUE}Recording Duration:${NC}"
            echo "Enter duration in seconds (0 for unlimited, press Enter for 300 seconds):"
            read -p "Duration: " DURATION_INPUT
            DURATION_INPUT=$(echo "$DURATION_INPUT" | tr -d '[:space:]')
            if [ -z "$DURATION_INPUT" ]; then
                # Empty input - use 300 seconds (5 minutes) as default
                DURATION=300
            elif [ "$DURATION_INPUT" = "0" ]; then
                # 0 means unlimited
                DURATION=0
            else
                # Use the number provided
                DURATION="$DURATION_INPUT"
            fi

            # Audio device selection (optional)
            echo -e "${BLUE}Audio Device Configuration:${NC}"
            read -p "Use default audio device? (y/n, default: y): " DEFAULT_AUDIO
            DEFAULT_AUDIO=$(echo "$DEFAULT_AUDIO" | tr -d '[:space:]')
            if [[ "$DEFAULT_AUDIO" =~ ^[Nn]$ ]]; then
                INPUT_DEVICE=$(select_audio_device_interactive)
            else
                echo "Getting default audio device..."
                INPUT_DEVICE=$(python -c "
import sounddevice as sd
try:
    default = sd.default.device[0]
    print(default)
except:
    print('')
")
                if [ -z "$INPUT_DEVICE" ]; then
                    INPUT_DEVICE=""
                fi
            fi
            ;;
        3)
            # High quality setup - maximum accuracy
            echo -e "${GREEN}Using high quality setup (maximum accuracy)${NC}"
            MODEL="medium"
            CHUNK_DUR=5.0
            OVERLAP=2.0
            # VAD configuration based on availability
            if [ "${VAD_AVAILABLE:-0}" -eq 1 ]; then
                NO_VAD=""
                VAD_AGGRESSIVENESS="3"
                SILENCE_DURATION_MS="300"
            else
                NO_VAD="true"
                VAD_AGGRESSIVENESS=""
                SILENCE_DURATION_MS=""
            fi

            # Language selection (optional)
            echo -e "${BLUE}Language Configuration:${NC}"
            read -p "Use auto language detection? (y/n, default: y): " AUTO_LANG
            AUTO_LANG=$(echo "$AUTO_LANG" | tr -d '[:space:]')
            if [[ "$AUTO_LANG" =~ ^[Nn]$ ]]; then
                LANGUAGE_RESULT=$(select_language_interactive)
                # Parse language result (may contain simplified chinese setting)
                LANGUAGE=""
                SIMPLIFIED_CHINESE=""
                if [ -n "$LANGUAGE_RESULT" ]; then
                    if [[ "$LANGUAGE_RESULT" == *:* ]]; then
                        # Format: "language:simplified" or "multi:lang1,lang2:simplified"
                        LANGUAGE="${LANGUAGE_RESULT%:*}"
                        SIMPLIFIED_CHINESE="${LANGUAGE_RESULT##*:}"
                    else
                        LANGUAGE="$LANGUAGE_RESULT"
                    fi
                fi
            else
                LANGUAGE=""
                SIMPLIFIED_CHINESE=""
            fi

            # Recording duration selection
            echo -e "${BLUE}Recording Duration:${NC}"
            echo "Enter duration in seconds (0 for unlimited, press Enter for 300 seconds):"
            read -p "Duration: " DURATION_INPUT
            DURATION_INPUT=$(echo "$DURATION_INPUT" | tr -d '[:space:]')
            if [ -z "$DURATION_INPUT" ]; then
                # Empty input - use 300 seconds (5 minutes) as default
                DURATION=300
            elif [ "$DURATION_INPUT" = "0" ]; then
                # 0 means unlimited
                DURATION=0
            else
                # Use the number provided
                DURATION="$DURATION_INPUT"
            fi

            # Audio device selection (optional)
            echo -e "${BLUE}Audio Device Configuration:${NC}"
            read -p "Use default audio device? (y/n, default: y): " DEFAULT_AUDIO
            DEFAULT_AUDIO=$(echo "$DEFAULT_AUDIO" | tr -d '[:space:]')
            if [[ "$DEFAULT_AUDIO" =~ ^[Nn]$ ]]; then
                INPUT_DEVICE=$(select_audio_device_interactive)
            else
                echo "Getting default audio device..."
                INPUT_DEVICE=$(python -c "
import sounddevice as sd
try:
    default = sd.default.device[0]
    print(default)
except:
    print('')
")
                if [ -z "$INPUT_DEVICE" ]; then
                    INPUT_DEVICE=""
                fi
            fi
            ;;
        4)
            # Custom setup - interactive selection
            echo -e "${GREEN}Custom setup - select parameters manually${NC}"

            # Model selection
            MODEL=$(select_model_interactive 1)

            # Language selection
            LANGUAGE_RESULT=$(select_language_interactive)

            # Parse language result (may contain simplified chinese setting)
            LANGUAGE=""
            SIMPLIFIED_CHINESE=""
            if [ -n "$LANGUAGE_RESULT" ]; then
                if [[ "$LANGUAGE_RESULT" == *:* ]]; then
                    # Format: "language:simplified" or "multi:lang1,lang2:simplified"
                    LANGUAGE="${LANGUAGE_RESULT%:*}"
                    SIMPLIFIED_CHINESE="${LANGUAGE_RESULT##*:}"
                else
                    LANGUAGE="$LANGUAGE_RESULT"
                fi
            fi

            # Audio device selection
            INPUT_DEVICE=$(select_audio_device_interactive)

            # Computation device selection
            DEVICE=$(select_device_interactive)

            echo "Recording duration in seconds (press Enter for no time limit, 0 for unlimited, or enter a number):"
            read -p "Duration (Enter for unlimited, 0 for unlimited, or number for seconds): " DURATION_INPUT
            # Clean input
            DURATION_INPUT=$(echo "$DURATION_INPUT" | tr -d '[:space:]')
            if [ -z "$DURATION_INPUT" ] || [ "$DURATION_INPUT" = "0" ]; then
                # Empty input or 0 means unlimited (no time limit)
                DURATION=0
            else
                # Use the number provided
                DURATION="$DURATION_INPUT"
            fi

            read -p "Chunk duration in seconds (default: 3.0): " CHUNK_DUR
            CHUNK_DUR=${CHUNK_DUR:-3.0}

            read -p "Overlap in seconds (default: 1.0): " OVERLAP
            OVERLAP=${OVERLAP:-1.0}

            # VAD configuration
            echo -e "${BLUE}Voice Activity Detection (VAD) Configuration:${NC}"

            if [ "${VAD_AVAILABLE:-0}" -eq 1 ]; then
                # VAD is available
                read -p "Enable VAD for sentence-based segmentation? (y/n, default: y): " ENABLE_VAD
                ENABLE_VAD=$(echo "$ENABLE_VAD" | tr -d '[:space:]')
                if [[ "$ENABLE_VAD" =~ ^[Nn]$ ]]; then
                    NO_VAD="true"
                else
                    NO_VAD=""
                    read -p "VAD aggressiveness (0-3, 3 most aggressive, default: 3): " VAD_AGGRESSIVENESS
                    VAD_AGGRESSIVENESS=${VAD_AGGRESSIVENESS:-3}
                    read -p "Silence duration to end sentence (ms, default: 300): " SILENCE_DURATION_MS
                    SILENCE_DURATION_MS=${SILENCE_DURATION_MS:-300}
                fi
            else
                # VAD is not available
                echo -e "${YELLOW}VAD is not available (webrtcvad module missing)${NC}"
                echo -e "${YELLOW}Using fixed chunk mode instead of sentence-based segmentation${NC}"
                NO_VAD="true"
                VAD_AGGRESSIVENESS=""
                SILENCE_DURATION_MS=""
            fi
            ;;
        *)
            # Default to quick setup
            echo -e "${GREEN}Using quick setup (fast model, auto language)${NC}"
            MODEL="tiny"
            LANGUAGE=""
            SIMPLIFIED_CHINESE=""
            DURATION=30
            CHUNK_DUR=3.0
            OVERLAP=1.0
            # VAD configuration based on availability
            if [ "${VAD_AVAILABLE:-0}" -eq 1 ]; then
                NO_VAD=""
                VAD_AGGRESSIVENESS="3"
                SILENCE_DURATION_MS="300"
            else
                NO_VAD="true"
                VAD_AGGRESSIVENESS=""
                SILENCE_DURATION_MS=""
            fi
            ;;
    esac

    # Apply parameter overrides from command line
    if [ -n "$MODEL_OVERRIDE" ]; then
        MODEL="$MODEL_OVERRIDE"
        echo -e "${GREEN}Overriding model to: $MODEL${NC}"
    fi
    if [ -n "$LANGUAGE_OVERRIDE" ]; then
        LANGUAGE="$LANGUAGE_OVERRIDE"
        echo -e "${GREEN}Overriding language to: $LANGUAGE${NC}"
    fi
    if [ -n "$SIMPLIFIED_CHINESE_ARG" ]; then
        SIMPLIFIED_CHINESE="$SIMPLIFIED_CHINESE_ARG"
        echo -e "${GREEN}Overriding simplified Chinese to: $SIMPLIFIED_CHINESE${NC}"
    fi
    if [ -n "$DEVICE_ARG" ]; then
        DEVICE="$DEVICE_ARG"
        echo -e "${GREEN}Overriding computation device to: $DEVICE${NC}"
    fi
    if [ -n "$DURATION_ARG" ]; then
        DURATION="$DURATION_ARG"
        echo -e "${GREEN}Overriding duration to: $DURATION seconds${NC}"
    fi
    if [ -n "$CHUNK_DUR_ARG" ]; then
        CHUNK_DUR="$CHUNK_DUR_ARG"
        echo -e "${GREEN}Overriding chunk duration to: $CHUNK_DUR seconds${NC}"
    fi
    if [ -n "$OVERLAP_ARG" ]; then
        OVERLAP="$OVERLAP_ARG"
        echo -e "${GREEN}Overriding overlap to: $OVERLAP seconds${NC}"
    fi
    if [ -n "$INPUT_DEVICE_ARG" ]; then
        INPUT_DEVICE="$INPUT_DEVICE_ARG"
        echo -e "${GREEN}Overriding audio device to: $INPUT_DEVICE${NC}"
    fi
    if [ -n "$NO_VAD_ARG" ]; then
        NO_VAD="$NO_VAD_ARG"
        echo -e "${GREEN}Overriding VAD: disabled${NC}"
    fi
    if [ -n "$VAD_AGGRESSIVENESS_ARG" ]; then
        VAD_AGGRESSIVENESS="$VAD_AGGRESSIVENESS_ARG"
        echo -e "${GREEN}Overriding VAD aggressiveness to: $VAD_AGGRESSIVENESS${NC}"
    fi
    if [ -n "$SILENCE_DURATION_MS_ARG" ]; then
        SILENCE_DURATION_MS="$SILENCE_DURATION_MS_ARG"
        echo -e "${GREEN}Overriding silence duration to: $SILENCE_DURATION_MS ms${NC}"
    fi

    # Computation device selection (if not specified via command line)
    if [ -z "$DEVICE" ]; then
        DEVICE=$(select_device_interactive)
    fi

    # Generate output filenames for streaming
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    TEXT_FILE="$PROJECT_ROOT/record/streaming_${TIMESTAMP}_transcription.txt"
    AUDIO_FILE="$PROJECT_ROOT/record/streaming_${TIMESTAMP}.wav"

    mkdir -p "$PROJECT_ROOT/record"

    # Check zhconv dependency if simplified Chinese conversion is requested
    if [ "$SIMPLIFIED_CHINESE" = "yes" ]; then
        if [[ "$LANGUAGE" == *zh* ]] || [[ "$LANGUAGE" == multi:* ]] && [[ "$LANGUAGE" == *zh* ]]; then
            if ! python3 -c "import zhconv" 2>/dev/null; then
                echo -e "${YELLOW}Warning: zhconv library not found${NC}"
                echo -e "${YELLOW}Simplified Chinese conversion requires zhconv module${NC}"
                echo -e "${CYAN}Install with: pip install zhconv${NC}"
                read -p "Continue without simplified Chinese conversion? (y/n, default: y): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Nn]$ ]]; then
                    echo -e "${YELLOW}Cancelling...${NC}"
                    return
                else
                    # Disable simplified Chinese conversion
                    SIMPLIFIED_CHINESE="no"
                    echo -e "${YELLOW}Simplified Chinese conversion disabled${NC}"
                fi
            fi
        fi
    fi

    if [ "$USE_SIMPLE_STREAM" = true ]; then
        CMD="python $PROJECT_ROOT/src/core/simple_whisper.py --stream --model $MODEL --chunk-duration $CHUNK_DUR --overlap $OVERLAP --output-text \"$TEXT_FILE\" --output-audio \"$AUDIO_FILE\""
    else
        CMD="python $PROJECT_ROOT/src/streaming/stream_whisper.py --model $MODEL --duration $DURATION --chunk-duration $CHUNK_DUR --overlap $OVERLAP --output-audio \"$AUDIO_FILE\" --output-text \"$TEXT_FILE\""
    fi

    # Add language parameters if specified
    if [ -n "$LANGUAGE" ]; then
        CMD="$CMD --language $LANGUAGE"
    fi

    if [ -n "$SIMPLIFIED_CHINESE" ]; then
        CMD="$CMD --simplified-chinese $SIMPLIFIED_CHINESE"
    fi

    # Add input device if specified
    if [ -n "$INPUT_DEVICE" ]; then
        CMD="$CMD --input-device $INPUT_DEVICE"
    fi

    # Add computation device if specified
    if [ -n "$DEVICE" ]; then
        CMD="$CMD --device $DEVICE"
    fi

    # Add VAD parameters if specified
    if [ -n "$NO_VAD" ]; then
        CMD="$CMD --no-vad"
    fi
    if [ -n "$VAD_AGGRESSIVENESS" ] && [ -z "$NO_VAD" ]; then
        CMD="$CMD --vad-aggressiveness $VAD_AGGRESSIVENESS"
    fi
    if [ -n "$SILENCE_DURATION_MS" ] && [ -z "$NO_VAD" ]; then
        CMD="$CMD --silence-duration-ms $SILENCE_DURATION_MS"
    fi

    echo -e "\n${GREEN}Streaming configuration:${NC}"
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

    # Show VAD configuration
    if [ -n "$NO_VAD" ]; then
        echo "  VAD: disabled (using fixed chunks)"
    else
        echo "  VAD: enabled"
        echo "  VAD aggressiveness: $VAD_AGGRESSIVENESS"
        echo "  Silence threshold: $SILENCE_DURATION_MS ms"
    fi

    echo "  Audio device: ${INPUT_DEVICE:-default}"
    echo "  Computation device: ${DEVICE:-auto}"
    echo "  Duration: $DURATION seconds"
    echo "  Chunk duration: $CHUNK_DUR seconds"
    echo "  Overlap: $OVERLAP seconds"
    echo "  Text output: $TEXT_FILE"
    echo "  Audio output: $AUDIO_FILE"
    echo "  Command: $CMD"
    echo ""

    if [ "$AUTO_START" = true ]; then
        echo -e "${GREEN}Auto-start enabled, starting immediately...${NC}"
    else
        read -p "Start streaming? (y/n): " START_RESPONSE
        START_RESPONSE=$(echo "$START_RESPONSE" | tr -d '[:space:]')
        if [[ ! "$START_RESPONSE" =~ ^[Yy] ]]; then
            echo -e "${YELLOW}Cancelled${NC}"
            return
        fi
    fi

    echo -e "${GREEN}Starting streaming transcription...${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    log_message "INFO" "Starting streaming: $CMD"

    if eval $CMD; then
        echo -e "${GREEN}Streaming completed${NC}"
        log_message "INFO" "Live streaming workflow completed"
    else
        echo -e "${RED}Streaming failed${NC}"
        log_message "ERROR" "Live streaming workflow failed"
    fi
}

# Function: Batch File Processing
execute_batch_processing() {
    log_message "INFO" "Starting Batch Processing workflow"

    echo -e "${CYAN}Batch File Processing${NC}"
    echo ""

    read -p "Input directory (default: audio_files): " INPUT_DIR
    INPUT_DIR=${INPUT_DIR:-audio_files}

    read -p "Output directory (default: transcriptions): " OUTPUT_DIR
    OUTPUT_DIR=${OUTPUT_DIR:-transcriptions}

    # Model selection
    MODEL=$(select_model_interactive 2)

    read -p "Language code (empty for auto detect): " LANGUAGE

    # Computation device selection
    DEVICE=$(select_device_interactive)

    mkdir -p "$OUTPUT_DIR"

    echo -e "\n${GREEN}Batch processing configuration:${NC}"
    echo "  Input directory: $INPUT_DIR"
    echo "  Output directory: $OUTPUT_DIR"
    echo "  Model: $MODEL"
    echo "  Language: ${LANGUAGE:-auto detect}"
    echo "  Computation device: ${DEVICE:-auto}"
    echo ""

    if [ ! -d "$INPUT_DIR" ]; then
        echo -e "${YELLOW}Input directory does not exist: $INPUT_DIR${NC}"
        read -p "Create directory? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            mkdir -p "$INPUT_DIR"
            echo -e "${GREEN}Directory created${NC}"
        else
            return
        fi
    fi

    read -p "Start batch processing? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cancelled${NC}"
        return
    fi

    echo -e "${GREEN}Starting batch processing...${NC}"
    log_message "INFO" "Starting batch processing: $INPUT_DIR → $OUTPUT_DIR"

    count=0
    for audio_file in "$INPUT_DIR"/*.wav "$INPUT_DIR"/*.mp3 "$INPUT_DIR"/*.m4a; do
        if [ -f "$audio_file" ]; then
            count=$((count + 1))
            base_name=$(basename "$audio_file")
            output_file="$OUTPUT_DIR/${base_name%.*}_transcription.txt"

            echo "Processing [$count]: $base_name"

            CMD="python $PROJECT_ROOT/src/core/simple_whisper.py --audio \"$audio_file\" --model $MODEL --output-text \"$output_file\""
            if [ -n "$DEVICE" ]; then
                CMD="$CMD --device $DEVICE"
            fi
            if [ -n "$LANGUAGE" ]; then
                CMD="$CMD --language $LANGUAGE"
            fi

            if eval $CMD; then
                echo "  ✓ Saved to: $output_file"
            else
                echo "  ✗ Failed to process"
            fi
        fi
    done 2>/dev/null

    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}No audio files found in $INPUT_DIR${NC}"
        echo "Supported formats: .wav, .mp3, .m4a"
    else
        echo -e "${GREEN}Batch processing completed!${NC}"
        echo "  Processed $count files"
        echo "  Output directory: $OUTPUT_DIR"
        log_message "INFO" "Batch processing completed: $count files"
    fi
}

# Function: Interactive Transcription
execute_interactive_transcription() {
    log_message "INFO" "Starting Interactive Transcription workflow"

    echo -e "${CYAN}Interactive Transcription${NC}"
    echo ""

    if [ -f "interactive_whisper.py" ]; then
        echo -e "${GREEN}Starting interactive_whisper.py...${NC}"
        python $PROJECT_ROOT/src/core/interactive_whisper.py
    else
        echo -e "${YELLOW}interactive_whisper.py not found${NC}"
        echo "Falling back to quick_record.sh"

        if [ -f "quick_record.sh" ]; then
            ./quick_record.sh
        else
            echo -e "${RED}No interactive script available${NC}"
            echo "Please install interactive_whisper.py or quick_record.sh"
        fi
    fi
}

# Function: System Diagnostics
execute_system_diagnostics() {
    log_message "INFO" "Starting System Diagnostics workflow"

    echo -e "${CYAN}System Diagnostics${NC}"
    echo ""

    echo "Running system tests..."
    echo ""

    # Test 1: Python environment
    echo -e "${BLUE}1. Python Environment:${NC}"
    python3 --version
    echo ""

    # Test 2: Dependencies
    echo -e "${BLUE}2. Dependencies:${NC}"
    python3 -c "import whisper; print('✓ whisper')" 2>/dev/null || echo "✗ whisper"
    python3 -c "import sounddevice; print('✓ sounddevice')" 2>/dev/null || echo "✗ sounddevice"
    python3 -c "import soundfile; print('✓ soundfile')" 2>/dev/null || echo "✗ soundfile"
    echo ""

    # Test 3: Audio devices
    echo -e "${BLUE}3. Audio Devices:${NC}"
    python $PROJECT_ROOT/src/core/simple_whisper.py --list-audio-devices 2>/dev/null || echo "✗ Failed to list audio devices"
    echo ""

    # Test 4: Model loading
    echo -e "${BLUE}4. Model Loading Test:${NC}"
    read -p "Test model loading? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        python -c "
import whisper
import time

print('Loading tiny model...')
start = time.time()
try:
    model = whisper.load_model('tiny')
    load_time = time.time() - start
    print(f'✓ Tiny model loaded in {load_time:.2f}s on {model.device}')
except Exception as e:
    print(f'✗ Failed to load tiny model: {e}')
"
    fi

    echo ""
    echo -e "${GREEN}System diagnostics completed${NC}"
    log_message "INFO" "System diagnostics completed"
}

# Function: Tools & Utilities
execute_tools_utilities() {
    log_message "INFO" "Starting Tools & Utilities"

    echo -e "${CYAN}Tools & Utilities${NC}"
    echo ""

    echo "Available tools:"
    echo "  1) List audio devices"
    echo "  2) Show model information"
    echo "  3) Check disk space"
    echo "  4) View log files"
    echo "  5) Clean temporary files"
    echo "  6) System information"
    echo ""

    read -p "Select tool (1-6): " TOOL_CHOICE

    case $TOOL_CHOICE in
        1)
            echo -e "${GREEN}Audio Devices:${NC}"
            python $PROJECT_ROOT/src/core/simple_whisper.py --list-audio-devices
            ;;
        2)
            echo -e "${GREEN}Whisper Models:${NC}"
            echo "  tiny    - 39M parameters, fastest"
            echo "  base    - 74M parameters, good balance"
            echo "  small   - 244M parameters, better accuracy"
            echo "  medium  - 769M parameters, high accuracy"
            echo "  large   - 1550M parameters, highest accuracy"
            echo ""
            echo "Models are downloaded automatically on first use."
            ;;
        3)
            echo -e "${GREEN}Disk Space:${NC}"
            df -h .
            echo ""
            echo "Whisper models cache: ~/.cache/whisper/"
            ;;
        4)
            echo -e "${GREEN}Log Files:${NC}"
            ls -la *.log 2>/dev/null || echo "No log files found"

            if ls *.log 2>/dev/null; then
                read -p "View latest log? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    latest_log=$(ls -t *.log | head -1)
                    echo "=== Last 20 lines of $latest_log ==="
                    tail -20 "$latest_log"
                fi
            fi
            ;;
        5)
            echo -e "${GREEN}Cleaning temporary files...${NC}"
            rm -f recording_*.wav test_*.wav 2>/dev/null || true
            ls -t *.log 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
            echo "Cleanup completed"
            ;;
        6)
            echo -e "${GREEN}System Information:${NC}"
            echo "Python: $(python3 --version 2>&1)"
            echo "System: $(uname -srm)"
            echo "Directory: $(pwd)"
            echo "Virtual env: ${VIRTUAL_ENV:-Not activated}"
            ;;
        *)
            echo -e "${RED}Invalid selection${NC}"
            ;;
    esac
}

# Function: Exit controller
exit_controller() {
    echo -e "${GREEN}Exiting Workflow Controller. Goodbye!${NC}"
    log_message "INFO" "Workflow controller exited"
    exit 0
}

# Function: Show help
show_help() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Workflow Controller for Simple Whisper Application"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --workflow N   Execute workflow directly (1-6)"
    echo "                 1: Quick Record, 2: Live Streaming"
    echo "                 3: Batch Processing, 4: Interactive"
    echo "                 5: System Diagnostics, 6: Tools"
    echo "  --log          Show latest log"
    echo "  --cleanup      Clean temporary files"
    echo ""
    echo "Workflow Parameters (for --workflow 1 and 2):"
    echo "  --preset N      Preset mode: 1=Quick, 2=Standard, 3=High quality, 4=Custom"
    echo "  --model NAME    Override model: tiny, base, small, medium, large"
    echo "  --language CODE Language code (empty for auto): en, zh, ja, etc."
    echo "  --duration SEC  Recording/streaming duration in seconds"
    echo "  --input-device ID Audio input device ID"
    echo "  --device TYPE   Computation device: cpu, mps, cuda"
    echo "  --simplified-chinese yes/no Convert Chinese to simplified"
    echo "  --no-vad        Disable Voice Activity Detection for streaming"
    echo "  --vad-aggressiveness N VAD aggressiveness (0-3, 3 most aggressive)"
    echo "  --silence-duration-ms MS Minimum silence to end sentence (milliseconds)"
    echo "  --auto-start    Skip confirmation and start immediately"
    echo ""
    echo "Examples:"
    echo "  $0                     # Interactive menu"
    echo "  $0 --workflow 1        # Quick Record workflow"
    echo "  $0 --workflow 3        # Batch Processing workflow"
    echo "  $0 --log               # Show latest log"
    echo ""
    echo "  # Quick start with presets:"
    echo "  $0 --workflow 1 --preset 1 --duration 10      # Quick recording"
    echo "  $0 --workflow 2 --preset 2 --duration 30      # Standard streaming"
    echo "  $0 --workflow 1 --preset 3 --duration 60      # High quality recording"
    echo ""
    echo "  # Custom parameters:"
    echo "  $0 --workflow 1 --model base --language zh --duration 30"
    echo "  $0 --workflow 2 --model small --input-device 4 --auto-start"
    exit 0
}

# Main function
main() {
    show_header
    check_environment

    log_message "INFO" "Workflow controller started"
    echo "Log file: $LOG_FILE"
    echo ""

    # Parse command line arguments
    if [[ $# -gt 0 ]]; then
        case $1 in
            --help|-h)
                show_help
                ;;
            --workflow)
                case $2 in
                    1) execute_quick_record "${@:3}" ;;
                    2) execute_live_streaming "${@:3}" ;;
                    3) execute_batch_processing "${@:3}" ;;
                    4) execute_interactive_transcription "${@:3}" ;;
                    5) execute_system_diagnostics "${@:3}" ;;
                    6) execute_tools_utilities "${@:3}" ;;
                    *) echo -e "${RED}Invalid workflow number: $2${NC}"; exit 1 ;;
                esac
                exit 0
                ;;
            --log)
                if ls *.log 2>/dev/null; then
                    latest_log=$(ls -t *.log | head -1)
                    echo "=== Latest log: $latest_log ==="
                    tail -50 "$latest_log"
                else
                    echo "No log files found"
                fi
                exit 0
                ;;
            --cleanup)
                echo -e "${GREEN}Cleaning temporary files...${NC}"
                rm -f recording_*.wav test_*.wav 2>/dev/null || true
                echo "Cleanup completed"
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    fi

    # Interactive mode
    while true; do
        select_workflow

        echo ""
        echo -e "${BLUE}========================================${NC}"
        echo ""

        read -p "Return to main menu? (y/n, default: y): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]] && [ -n "$REPLY" ]; then
            exit_controller
        fi

        echo ""
    done
}

# Run main function
main "$@"