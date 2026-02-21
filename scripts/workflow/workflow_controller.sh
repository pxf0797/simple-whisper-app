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

    # Quick dependency check
    log_message "INFO" "Checking core dependencies..."
    python3 -c "import whisper, sounddevice, soundfile" 2>/dev/null && {
        log_message "INFO" "All core dependencies are installed"
    } || {
        log_message "WARN" "Some dependencies missing. Continuing anyway..."
    }
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

    echo -e "${BLUE}Audio Device Selection:${NC}"
    echo "Listing available audio input devices..."
    python $PROJECT_ROOT/src/core/simple_whisper.py --list-audio-devices

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
        echo -e "\nDefault device ID: $default_device"
        read -p "Enter device ID (press Enter for default $default_device): " device_input
        if [ -n "$device_input" ]; then
            echo "$device_input"
        else
            echo "$default_device"
        fi
    else
        read -p "Enter device ID: " device_input
        echo "$device_input"
    fi
}

# Function to select model interactively
select_model_interactive() {
    local default_choice=${1:-2}

    echo -e "${BLUE}Model Selection:${NC}"
    echo "  1) tiny    - Fastest, lowest accuracy"
    echo "  2) base    - Good balance"
    echo "  3) small   - Better accuracy"
    echo "  4) medium  - High accuracy"
    echo "  5) large   - Highest accuracy"

    while true; do
        read -p "Select model (1-5, default: $default_choice): " model_choice
        case $model_choice in
            1) echo "tiny"; break ;;
            2|"") echo "base"; break ;;
            3) echo "small"; break ;;
            4) echo "medium"; break ;;
            5) echo "large"; break ;;
            *) echo "Please enter a number 1-5" ;;
        esac
    done
}

# Function: Quick Record & Transcribe
execute_quick_record() {
    log_message "INFO" "Starting Quick Record workflow"

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

    # Model selection
    MODEL=$(select_model_interactive 2)

    # Language selection
    echo -e "\n${BLUE}Language Selection:${NC}"
    echo "  1) auto detect (recommended)"
    echo "  2) English (en)"
    echo "  3) Chinese (zh)"
    echo "  4) Japanese (ja)"
    echo "  5) Custom language code"

    read -p "Select language (1-5, default: 1): " LANG_CHOICE

    case $LANG_CHOICE in
        1|"") LANGUAGE="" ;;
        2) LANGUAGE="en" ;;
        3) LANGUAGE="zh" ;;
        4) LANGUAGE="ja" ;;
        5) read -p "Enter language code: " LANGUAGE ;;
        *) LANGUAGE="" ;;
    esac

    # Audio device selection
    echo -e "\n${BLUE}Audio Device Selection:${NC}"
    INPUT_DEVICE=$(select_audio_device_interactive)

    # Duration selection
    echo -e "\n${BLUE}Recording Duration:${NC}"
    echo "  Enter duration in seconds (e.g., 10, 60, 300)"
    echo "  Or press Enter for manual stop (Ctrl+C to stop)"
    echo ""
    read -p "Duration (seconds, empty for manual): " DURATION

    # Generate output filenames
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    AUDIO_FILE="record/recording_${TIMESTAMP}.wav"
    TEXT_FILE="record/recording_${TIMESTAMP}_transcription.txt"

    mkdir -p record

    # Build command
    CMD="python $PROJECT_ROOT/src/core/simple_whisper.py --record --model $MODEL --output-audio $AUDIO_FILE --output-text $TEXT_FILE"

    if [ -n "$LANGUAGE" ]; then
        CMD="$CMD --language $LANGUAGE"
    fi

    if [ -n "$DURATION" ]; then
        CMD="$CMD --duration $DURATION"
    fi

    if [ -n "$INPUT_DEVICE" ]; then
        CMD="$CMD --input-device $INPUT_DEVICE"
    fi

    echo -e "\n${GREEN}Configuration:${NC}"
    echo "  Model: $MODEL"
    echo "  Language: ${LANGUAGE:-auto detect}"
    echo "  Audio device: ${INPUT_DEVICE:-default}"
    echo "  Duration: ${DURATION:-manual stop}"
    echo "  Audio output: $AUDIO_FILE"
    echo "  Text output: $TEXT_FILE"
    echo ""

    read -p "Start recording? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cancelled${NC}"
        return
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

    echo -e "${CYAN}Live Streaming Transcription${NC}"
    echo ""

    # Check for streaming module
    if [ ! -f "stream_whisper.py" ]; then
        echo -e "${RED}Streaming module not found${NC}"
        echo -e "${YELLOW}Streaming features require stream_whisper.py${NC}"
        echo "You can use simple_whisper.py with --stream flag instead."
        echo ""
        read -p "Use simple_whisper.py with --stream? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
        USE_SIMPLE_STREAM=true
    else
        USE_SIMPLE_STREAM=false
    fi

    # Streaming configuration
    echo -e "${BLUE}Streaming Configuration:${NC}"

    # Model selection
    MODEL=$(select_model_interactive 1)

    # Audio device selection
    INPUT_DEVICE=$(select_audio_device_interactive)

    read -p "Test duration in seconds (default: 30): " DURATION
    DURATION=${DURATION:-30}

    read -p "Chunk duration in seconds (default: 3.0): " CHUNK_DUR
    CHUNK_DUR=${CHUNK_DUR:-3.0}

    read -p "Overlap in seconds (default: 1.0): " OVERLAP
    OVERLAP=${OVERLAP:-1.0}

    if [ "$USE_SIMPLE_STREAM" = true ]; then
        CMD="python $PROJECT_ROOT/src/core/simple_whisper.py --stream --model $MODEL --chunk-duration $CHUNK_DUR --overlap $OVERLAP"
    else
        CMD="python $PROJECT_ROOT/src/streaming/stream_whisper.py --model $MODEL --duration $DURATION --chunk-duration $CHUNK_DUR --overlap $OVERLAP"
    fi

    # Add input device if specified
    if [ -n "$INPUT_DEVICE" ]; then
        CMD="$CMD --input-device $INPUT_DEVICE"
    fi

    echo -e "\n${GREEN}Streaming configuration:${NC}"
    echo "  Model: $MODEL"
    echo "  Audio device: ${INPUT_DEVICE:-default}"
    echo "  Duration: $DURATION seconds"
    echo "  Chunk duration: $CHUNK_DUR seconds"
    echo "  Overlap: $OVERLAP seconds"
    echo "  Command: $CMD"
    echo ""

    read -p "Start streaming? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cancelled${NC}"
        return
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

    mkdir -p "$OUTPUT_DIR"

    echo -e "\n${GREEN}Batch processing configuration:${NC}"
    echo "  Input directory: $INPUT_DIR"
    echo "  Output directory: $OUTPUT_DIR"
    echo "  Model: $MODEL"
    echo "  Language: ${LANGUAGE:-auto detect}"
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
    echo "Examples:"
    echo "  $0                     # Interactive menu"
    echo "  $0 --workflow 1        # Quick Record workflow"
    echo "  $0 --workflow 3        # Batch Processing workflow"
    echo "  $0 --log               # Show latest log"
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