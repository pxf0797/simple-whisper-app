#!/bin/bash
# Comprehensive Workflow Control Script for Simple Whisper Application
# Supports: Recording, Streaming, GUI, Batch Processing, Interactive Mode, Testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log file for workflow tracking
LOG_FILE="workflow_$(date +"%Y%m%d_%H%M%S").log"

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    case $level in
        "INFO") echo -e "${GREEN}[INFO]${NC} $message" ;;
        "WARN") echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "DEBUG") echo -e "${CYAN}[DEBUG]${NC} $message" ;;
        *) echo -e "${BLUE}[$level]${NC} $message" ;;
    esac

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Function to display header
show_header() {
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${BLUE}   SIMPLE WHISPER - WORKFLOW CONTROL v2.0${NC}"
    echo -e "${BLUE}==================================================${NC}"
    echo ""
}

# Function to check environment
check_environment() {
    log_message "INFO" "Checking environment..."

    # Check Python
    if command -v python3 &> /dev/null; then
        PYTHON_VER=$(python3 --version 2>&1 | awk '{print $2}')
        log_message "INFO" "Python $PYTHON_VER found"
    else
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
            read -p "Create virtual environment? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                ./setup.sh
                source venv/bin/activate
                log_message "INFO" "Virtual environment created and activated"
            else
                log_message "WARN" "Running without virtual environment"
            fi
        fi
    else
        log_message "INFO" "Using existing virtual environment: $VIRTUAL_ENV"
    fi

    # Check dependencies
    log_message "INFO" "Checking dependencies..."
    local missing_deps=()

    check_dependency() {
        python3 -c "import $1" 2>/dev/null
        if [ $? -ne 0 ]; then
            missing_deps+=("$1")
            return 1
        fi
        return 0
    }

    # Core dependencies
    check_dependency "whisper" || true
    check_dependency "sounddevice" || true
    check_dependency "soundfile" || true

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_message "WARN" "Missing dependencies: ${missing_deps[*]}"
        read -p "Install missing dependencies? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_message "INFO" "Installing dependencies..."
            pip install ${missing_deps[@]}
            log_message "INFO" "Dependencies installed"
        else
            log_message "WARN" "Continuing without missing dependencies"
        fi
    else
        log_message "INFO" "All core dependencies are installed"
    fi

    # Check for streaming dependencies
    if [ -f "stream_whisper.py" ]; then
        log_message "INFO" "Streaming module found"
    else
        log_message "WARN" "Streaming module (stream_whisper.py) not found"
    fi

    if [ -f "stream_gui.py" ]; then
        log_message "INFO" "GUI module found"
    else
        log_message "WARN" "GUI module (stream_gui.py) not found"
    fi
}

# Function to show main menu
show_main_menu() {
    echo -e "${CYAN}Available Workflow Modes:${NC}"
    echo ""
    echo "  1) ${GREEN}Recording Mode${NC} - Record audio and transcribe"
    echo "     • Interactive parameter selection"
    echo "     • Supports multiple languages"
    echo "     • Device selection (audio/computation)"
    echo ""
    echo "  2) ${GREEN}Streaming Mode${NC} - Real-time transcription"
    echo "     • Low-latency processing (3-5 seconds)"
    echo "     • Chunk-based audio processing"
    echo "     • Real-time text display"
    echo ""
    echo "  3) ${GREEN}GUI Mode${NC} - Graphical interface"
    echo "     • Always-on-top window"
    echo "     • Transparency control"
    echo "     • Start/Stop/Pause buttons"
    echo "     • Auto-scrolling text display"
    echo ""
    echo "  4) ${GREEN}Batch Processing Mode${NC} - Process multiple files"
    echo "     • Transcribe directory of audio files"
    echo "     • Batch configuration"
    echo "     • Progress tracking"
    echo ""
    echo "  5) ${GREEN}Interactive Mode${NC} - Full interactive experience"
    echo "     • Guided step-by-step interface"
    echo "     • All options available"
    echo "     • Perfect for beginners"
    echo ""
    echo "  6) ${GREEN}Test Mode${NC} - Validate functionality"
    echo "     • Run test suite"
    echo "     • Check dependencies"
    echo "     • Verify audio devices"
    echo ""
    echo "  7) ${GREEN}Environment Setup${NC} - Setup and configuration"
    echo "     • Install dependencies"
    echo "     • Configure environment"
    echo "     • Update software"
    echo ""
    echo "  8) ${GREEN}Quick Tools${NC} - Utility functions"
    echo "     • List audio devices"
    echo "     • Download models"
    echo "     • View logs"
    echo ""
    echo "  0) ${RED}Exit${NC}"
    echo ""
}

# Function for recording mode
recording_mode() {
    log_message "INFO" "Starting Recording Mode"
    echo -e "${CYAN}Recording Mode Configuration${NC}"
    echo ""

    # Check if quick_record.sh exists
    if [ -f "quick_record.sh" ]; then
        log_message "INFO" "Using quick_record.sh script"
        ./quick_record.sh "$@"
    else
        log_message "ERROR" "quick_record.sh not found"
        echo -e "${YELLOW}Falling back to direct simple_whisper.py execution${NC}"

        # Build command manually
        CMD="python $PROJECT_ROOT/src/core/simple_whisper.py --record"

        # Ask for parameters
        read -p "Recording duration (seconds, empty for manual): " DURATION
        if [ -n "$DURATION" ]; then
            CMD="$CMD --duration $DURATION"
        fi

        read -p "Model (tiny/base/small/medium/large, default: base): " MODEL
        MODEL=${MODEL:-base}
        CMD="$CMD --model $MODEL"

        read -p "Language code (empty for auto): " LANGUAGE
        if [ -n "$LANGUAGE" ]; then
            CMD="$CMD --language $LANGUAGE"
        fi

        echo -e "${GREEN}Command: $CMD${NC}"
        echo "Starting recording..."
        eval $CMD
    fi
}

# Function for streaming mode
streaming_mode() {
    log_message "INFO" "Starting Streaming Mode"
    echo -e "${CYAN}Streaming Mode Configuration${NC}"
    echo ""

    if [ ! -f "stream_whisper.py" ]; then
        log_message "ERROR" "Streaming module not found"
        echo -e "${YELLOW}Streaming features require stream_whisper.py${NC}"
        read -p "Use CLI streaming instead? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Use simple_whisper.py with --stream flag
            CMD="python $PROJECT_ROOT/src/core/simple_whisper.py --stream"

            read -p "Model (tiny/base/small, default: tiny): " MODEL
            MODEL=${MODEL:-tiny}
            CMD="$CMD --model $MODEL"

            read -p "Chunk duration (seconds, default: 3.0): " CHUNK_DUR
            CHUNK_DUR=${CHUNK_DUR:-3.0}
            CMD="$CMD --chunk-duration $CHUNK_DUR"

            read -p "Overlap (seconds, default: 1.0): " OVERLAP
            OVERLAP=${OVERLAP:-1.0}
            CMD="$CMD --overlap $OVERLAP"

            read -p "Test duration (seconds, default: 30): " TEST_DUR
            TEST_DUR=${TEST_DUR:-30}

            echo -e "${GREEN}Streaming for $TEST_DUR seconds...${NC}"
            echo -e "${GREEN}Command: $CMD${NC}"

            # Run in background to allow timeout
            (eval $CMD) &
            STREAM_PID=$!

            # Wait for specified duration
            sleep $TEST_DUR

            # Kill the stream
            kill $STREAM_PID 2>/dev/null || true
            wait $STREAM_PID 2>/dev/null || true

            echo -e "${GREEN}Streaming test completed${NC}"
        fi
        return
    fi

    # Use stream_whisper.py directly
    echo "Streaming options:"
    echo "  1) Quick test (30 seconds, tiny model)"
    echo "  2) Custom configuration"
    echo "  3) Use stream_gui.py (GUI interface)"

    read -p "Select option (1-3): " STREAM_OPT

    case $STREAM_OPT in
        1)
            echo -e "${GREEN}Running quick streaming test...${NC}"
            python $PROJECT_ROOT/src/streaming/stream_whisper.py --model tiny --duration 30 --chunk-duration 2.0
            ;;
        2)
            # Custom configuration
            read -p "Model (tiny/base/small/medium, default: tiny): " MODEL
            MODEL=${MODEL:-tiny}

            read -p "Test duration (seconds, default: 30): " TEST_DUR
            TEST_DUR=${TEST_DUR:-30}

            read -p "Chunk duration (seconds, default: 3.0): " CHUNK_DUR
            CHUNK_DUR=${CHUNK_DUR:-3.0}

            read -p "Overlap (seconds, default: 1.0): " OVERLAP
            OVERLAP=${OVERLAP:-1.0}

            read -p "Audio device ID (empty for default): " AUDIO_DEVICE

            CMD="python $PROJECT_ROOT/src/streaming/stream_whisper.py --model $MODEL --duration $TEST_DUR --chunk-duration $CHUNK_DUR --overlap $OVERLAP"
            if [ -n "$AUDIO_DEVICE" ]; then
                CMD="$CMD --input-device $AUDIO_DEVICE"
            fi

            echo -e "${GREEN}Command: $CMD${NC}"
            eval $CMD
            ;;
        3)
            if [ -f "stream_gui.py" ]; then
                echo -e "${GREEN}Starting GUI streaming application...${NC}"
                read -p "Model (tiny/base/small, default: tiny): " MODEL
                MODEL=${MODEL:-tiny}

                CMD="python $PROJECT_ROOT/src/streaming/stream_gui.py --model $MODEL"
                read -p "Additional parameters (press Enter for none): " EXTRA_PARAMS

                if [ -n "$EXTRA_PARAMS" ]; then
                    CMD="$CMD $EXTRA_PARAMS"
                fi

                echo -e "${GREEN}Command: $CMD${NC}"
                eval $CMD
            else
                echo -e "${RED}GUI module not found${NC}"
            fi
            ;;
        *)
            echo -e "${YELLOW}Invalid option${NC}"
            ;;
    esac
}

# Function for GUI mode
gui_mode() {
    log_message "INFO" "Starting GUI Mode"
    echo -e "${CYAN}GUI Mode Configuration${NC}"
    echo ""

    if [ ! -f "stream_gui.py" ]; then
        log_message "ERROR" "GUI module not found"
        echo -e "${YELLOW}GUI features require stream_gui.py${NC}"
        return
    fi

    echo "GUI options:"
    echo "  1) Basic GUI (tiny model)"
    echo "  2) Custom configuration"
    echo "  3) Advanced GUI with all options"

    read -p "Select option (1-3): " GUI_OPT

    case $GUI_OPT in
        1)
            echo -e "${GREEN}Starting basic GUI...${NC}"
            python $PROJECT_ROOT/src/streaming/stream_gui.py --model tiny
            ;;
        2)
            read -p "Model (tiny/base/small, default: tiny): " MODEL
            MODEL=${MODEL:-tiny}

            read -p "Chunk duration (seconds, default: 3.0): " CHUNK_DUR
            CHUNK_DUR=${CHUNK_DUR:-3.0}

            read -p "Overlap (seconds, default: 1.0): " OVERLAP
            OVERLAP=${OVERLAP:-1.0}

            CMD="python $PROJECT_ROOT/src/streaming/stream_gui.py --model $MODEL --chunk-duration $CHUNK_DUR --overlap $OVERLAP"

            read -p "Audio device ID (empty for default): " AUDIO_DEVICE
            if [ -n "$AUDIO_DEVICE" ]; then
                CMD="$CMD --device $AUDIO_DEVICE"
            fi

            echo -e "${GREEN}Command: $CMD${NC}"
            eval $CMD
            ;;
        3)
            echo -e "${GREEN}Starting advanced GUI...${NC}"
            echo "Available parameters:"
            echo "  --model MODEL          : tiny, base, small, medium, large"
            echo "  --device ID            : Audio input device ID"
            echo "  --chunk-duration SECS  : Chunk duration in seconds"
            echo "  --overlap SECS         : Overlap between chunks"

            CMD="python $PROJECT_ROOT/src/streaming/stream_gui.py"

            while true; do
                read -p "Enter parameter (or 'done' to finish): " PARAM
                if [ "$PARAM" = "done" ]; then
                    break
                fi

                if [ -n "$PARAM" ]; then
                    CMD="$CMD $PARAM"
                fi
            done

            echo -e "${GREEN}Command: $CMD${NC}"
            eval $CMD
            ;;
        *)
            echo -e "${YELLOW}Invalid option${NC}"
            ;;
    esac
}

# Function for batch processing mode
batch_processing_mode() {
    log_message "INFO" "Starting Batch Processing Mode"
    echo -e "${CYAN}Batch Processing Configuration${NC}"
    echo ""

    if [ ! -f "batch_transcribe.py" ]; then
        log_message "WARN" "batch_transcribe.py not found"
        echo -e "${YELLOW}Creating batch processing script...${NC}"

        # Create a simple batch processing script
        cat > batch_processing.sh << 'EOF'
#!/bin/bash
# Simple batch processing script

set -e

INPUT_DIR="${1:-audio_files}"
OUTPUT_DIR="${2:-transcriptions}"
MODEL="${3:-base}"
LANGUAGE="${4:-}"

mkdir -p "$OUTPUT_DIR"

echo "Batch processing configuration:"
echo "  Input directory: $INPUT_DIR"
echo "  Output directory: $OUTPUT_DIR"
echo "  Model: $MODEL"
echo "  Language: $LANGUAGE"
echo ""

count=0
for audio_file in "$INPUT_DIR"/*.wav "$INPUT_DIR"/*.mp3 "$INPUT_DIR"/*.m4a 2>/dev/null; do
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

        echo ""
    fi
done

if [ $count -eq 0 ]; then
    echo "No audio files found in $INPUT_DIR"
    echo "Supported formats: .wav, .mp3, .m4a"
fi
EOF

        chmod +x batch_processing.sh
        log_message "INFO" "Created batch_processing.sh"
    fi

    echo "Batch processing options:"
    echo "  1) Quick batch (current directory)"
    echo "  2) Custom directory"
    echo "  3) Configure all parameters"

    read -p "Select option (1-3): " BATCH_OPT

    case $BATCH_OPT in
        1)
            echo -e "${GREEN}Processing audio files in current directory...${NC}"
            ./batch_processing.sh "." "batch_output" "base" ""
            ;;
        2)
            read -p "Input directory (default: audio_files): " INPUT_DIR
            INPUT_DIR=${INPUT_DIR:-audio_files}

            read -p "Output directory (default: transcriptions): " OUTPUT_DIR
            OUTPUT_DIR=${OUTPUT_DIR:-transcriptions}

            read -p "Model (default: base): " MODEL
            MODEL=${MODEL:-base}

            ./batch_processing.sh "$INPUT_DIR" "$OUTPUT_DIR" "$MODEL" ""
            ;;
        3)
            read -p "Input directory: " INPUT_DIR
            read -p "Output directory: " OUTPUT_DIR
            read -p "Model (tiny/base/small/medium/large): " MODEL
            read -p "Language code (empty for auto): " LANGUAGE

            if [ -f "batch_transcribe.py" ]; then
                CMD="python $PROJECT_ROOT/src/core/batch_transcribe.py"
                [ -n "$INPUT_DIR" ] && CMD="$CMD --input-dir \"$INPUT_DIR\""
                [ -n "$OUTPUT_DIR" ] && CMD="$CMD --output-dir \"$OUTPUT_DIR\""
                [ -n "$MODEL" ] && CMD="$CMD --model $MODEL"
                [ -n "$LANGUAGE" ] && CMD="$CMD --language $LANGUAGE"

                echo -e "${GREEN}Command: $CMD${NC}"
                eval $CMD
            else
                ./batch_processing.sh "$INPUT_DIR" "$OUTPUT_DIR" "$MODEL" "$LANGUAGE"
            fi
            ;;
        *)
            echo -e "${YELLOW}Invalid option${NC}"
            ;;
    esac
}

# Function for interactive mode
interactive_mode() {
    log_message "INFO" "Starting Interactive Mode"
    echo -e "${CYAN}Interactive Mode${NC}"
    echo ""

    if [ ! -f "interactive_whisper.py" ]; then
        log_message "ERROR" "interactive_whisper.py not found"
        echo -e "${YELLOW}Creating simple interactive script...${NC}"

        # Fallback to quick_record.sh
        if [ -f "quick_record.sh" ]; then
            ./quick_record.sh
        else
            echo -e "${RED}No interactive script available${NC}"
        fi
        return
    fi

    echo "Interactive Whisper Application starting..."
    python $PROJECT_ROOT/src/core/interactive_whisper.py
}

# Function for test mode
test_mode() {
    log_message "INFO" "Starting Test Mode"
    echo -e "${CYAN}Test Mode${NC}"
    echo ""

    echo "Test options:"
    echo "  1) Quick test (basic functionality)"
    echo "  2) Full test suite"
    echo "  3) Audio device test"
    echo "  4) Model loading test"
    echo "  5) Streaming functionality test"

    read -p "Select test (1-5): " TEST_OPT

    case $TEST_OPT in
        1)
            echo -e "${GREEN}Running quick test...${NC}"
            if [ -f "test_stream.py" ]; then
                python $PROJECT_ROOT/src/streaming/test_stream.py
            else
                python -c "import whisper; print('✓ Whisper imported successfully')"
                python -c "import sounddevice; print('✓ Sounddevice imported successfully')"
                echo "✓ Basic imports successful"
            fi
            ;;
        2)
            if [ -f "test_stream.py" ]; then
                python $PROJECT_ROOT/src/streaming/test_stream.py
            else
                echo -e "${YELLOW}test_stream.py not found${NC}"
                echo "Running component tests..."

                echo "Testing Whisper import..."
                python -c "import whisper; print('✓ Whisper OK')"

                echo "Testing audio libraries..."
                python -c "import sounddevice; print('✓ Sounddevice OK')"
                python -c "import soundfile; print('✓ Soundfile OK')"

                echo "Testing script imports..."
                python -c "from simple_whisper import SimpleWhisper; print('✓ SimpleWhisper OK')"

                echo "✓ All tests passed"
            fi
            ;;
        3)
            echo -e "${GREEN}Testing audio devices...${NC}"
            python $PROJECT_ROOT/src/core/simple_whisper.py --list-audio-devices
            ;;
        4)
            echo -e "${GREEN}Testing model loading...${NC}"
            read -p "Model to test (tiny/base, default: tiny): " TEST_MODEL
            TEST_MODEL=${TEST_MODEL:-tiny}

            python -c "
import whisper
import time

print(f'Loading {\"$TEST_MODEL\"} model...')
start = time.time()
model = whisper.load_model(\"$TEST_MODEL\")
load_time = time.time() - start

print(f'✓ Model loaded successfully')
print(f'  Device: {model.device}')
print(f'  Load time: {load_time:.2f} seconds')
print(f'  Model size: \"$TEST_MODEL\"')
"
            ;;
        5)
            echo -e "${GREEN}Testing streaming functionality...${NC}"
            if [ -f "stream_whisper.py" ]; then
                python $PROJECT_ROOT/src/streaming/stream_whisper.py --model tiny --duration 5 --chunk-duration 1.0
            else
                echo -e "${YELLOW}Streaming module not available${NC}"
            fi
            ;;
        *)
            echo -e "${YELLOW}Invalid option${NC}"
            ;;
    esac
}

# Function for environment setup
environment_setup_mode() {
    log_message "INFO" "Starting Environment Setup Mode"
    echo -e "${CYAN}Environment Setup${NC}"
    echo ""

    echo "Setup options:"
    echo "  1) Install all dependencies"
    echo "  2) Create virtual environment"
    echo "  3) Update all packages"
    echo "  4) Download Whisper models"
    echo "  5) Configure audio devices"

    read -p "Select option (1-5): " SETUP_OPT

    case $SETUP_OPT in
        1)
            echo -e "${GREEN}Installing all dependencies...${NC}"
            if [ -f "install_stream_deps.sh" ]; then
                ./install_stream_deps.sh
            elif [ -f "requirements.txt" ]; then
                pip install -r requirements.txt
            else
                echo "Installing core dependencies..."
                pip install torch torchaudio openai-whisper sounddevice soundfile numpy
            fi
            ;;
        2)
            echo -e "${GREEN}Creating virtual environment...${NC}"
            if [ -f "setup.sh" ]; then
                ./setup.sh
            else
                python -m venv venv
                echo "Virtual environment created. Activate with: source venv/bin/activate"
            fi
            ;;
        3)
            echo -e "${GREEN}Updating packages...${NC}"
            pip install --upgrade torch torchaudio openai-whisper sounddevice soundfile
            ;;
        4)
            echo -e "${GREEN}Downloading Whisper models...${NC}"
            echo "This will download all Whisper models (approx 10GB)"
            read -p "Continue? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                python -c "
import whisper
for model_size in ['tiny', 'base', 'small', 'medium', 'large']:
    print(f'Downloading {model_size} model...')
    model = whisper.load_model(model_size)
    print(f'  ✓ {model_size} model downloaded')
"
            fi
            ;;
        5)
            echo -e "${GREEN}Configuring audio devices...${NC}"
            python $PROJECT_ROOT/src/core/simple_whisper.py --list-audio-devices
            echo ""
            echo "Audio configuration notes:"
            echo "• On macOS: System Preferences > Sound > Input"
            echo "• On Linux: pavucontrol or alsamixer"
            echo "• On Windows: Sound Settings"
            ;;
        *)
            echo -e "${YELLOW}Invalid option${NC}"
            ;;
    esac
}

# Function for quick tools
quick_tools_mode() {
    log_message "INFO" "Starting Quick Tools Mode"
    echo -e "${CYAN}Quick Tools${NC}"
    echo ""

    echo "Tool options:"
    echo "  1) List audio devices"
    echo "  2) List available models"
    echo "  3) Check disk space"
    echo "  4) View log files"
    echo "  5) Clean up temporary files"
    echo "  6) System information"

    read -p "Select tool (1-6): " TOOL_OPT

    case $TOOL_OPT in
        1)
            echo -e "${GREEN}Listing audio devices...${NC}"
            python $PROJECT_ROOT/src/core/simple_whisper.py --list-audio-devices
            ;;
        2)
            echo -e "${GREEN}Available Whisper models:${NC}"
            echo "  tiny    - 39M parameters, fastest"
            echo "  base    - 74M parameters, good balance"
            echo "  small   - 244M parameters, better accuracy"
            echo "  medium  - 769M parameters, high accuracy"
            echo "  large   - 1550M parameters, highest accuracy"
            echo ""
            echo "Models are downloaded automatically on first use."
            ;;
        3)
            echo -e "${GREEN}Disk space:${NC}"
            df -h .
            echo ""
            echo "Whisper models location: ~/.cache/whisper/"
            ;;
        4)
            echo -e "${GREEN}Log files:${NC}"
            ls -la *.log 2>/dev/null || echo "No log files found"

            if ls *.log 2>/dev/null; then
                read -p "View latest log? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    latest_log=$(ls -t *.log | head -1)
                    if [ -n "$latest_log" ]; then
                        echo "=== Last 20 lines of $latest_log ==="
                        tail -20 "$latest_log"
                    fi
                fi
            fi
            ;;
        5)
            echo -e "${GREEN}Cleaning up...${NC}"
            echo "Removing temporary files..."

            # Remove temporary audio files
            rm -f recording_*.wav
            rm -f test_*.wav

            # Remove old log files (keep last 5)
            ls -t *.log 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true

            echo "✓ Cleanup completed"
            ;;
        6)
            echo -e "${GREEN}System Information:${NC}"
            echo "Python: $(python3 --version 2>&1)"
            echo "Pip: $(pip --version 2>&1 | cut -d' ' -f1-2)"
            echo "System: $(uname -srm)"
            echo "Directory: $(pwd)"
            echo "Virtual env: ${VIRTUAL_ENV:-Not activated}"
            ;;
        *)
            echo -e "${YELLOW}Invalid option${NC}"
            ;;
    esac
}

# Main function
main() {
    show_header
    check_environment

    log_message "INFO" "Workflow control script started"
    echo "Log file: $LOG_FILE"
    echo ""

    while true; do
        show_main_menu

        read -p "Select mode (0-8): " MAIN_CHOICE

        case $MAIN_CHOICE in
            0)
                echo -e "${GREEN}Exiting workflow control. Goodbye!${NC}"
                log_message "INFO" "Workflow control script exited"
                exit 0
                ;;
            1)
                recording_mode
                ;;
            2)
                streaming_mode
                ;;
            3)
                gui_mode
                ;;
            4)
                batch_processing_mode
                ;;
            5)
                interactive_mode
                ;;
            6)
                test_mode
                ;;
            7)
                environment_setup_mode
                ;;
            8)
                quick_tools_mode
                ;;
            *)
                echo -e "${RED}Invalid selection. Please try again.${NC}"
                ;;
        esac

        echo ""
        read -p "Return to main menu? (y/n, default: y): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]] && [ -n "$REPLY" ]; then
            echo -e "${GREEN}Exiting workflow control. Goodbye!${NC}"
            log_message "INFO" "Workflow control script exited"
            exit 0
        fi

        echo ""
        echo -e "${BLUE}==================================================${NC}"
        echo ""
    done
}

# Handle command line arguments
if [[ $# -gt 0 ]]; then
    case $1 in
        --help|-h)
            echo "Usage: $0 [MODE]"
            echo ""
            echo "Workflow Control Script for Simple Whisper Application"
            echo ""
            echo "Modes:"
            echo "  record      - Recording mode"
            echo "  stream      - Streaming mode"
            echo "  gui         - GUI mode"
            echo "  batch       - Batch processing mode"
            echo "  interactive - Interactive mode"
            echo "  test        - Test mode"
            echo "  setup       - Environment setup"
            echo "  tools       - Quick tools"
            echo "  --help, -h  - Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 record      # Start recording mode"
            echo "  $0 stream      # Start streaming mode"
            echo "  $0 gui         # Start GUI mode"
            echo "  $0            # Interactive menu mode"
            exit 0
            ;;
        record)
            show_header
            check_environment
            recording_mode "${@:2}"
            exit 0
            ;;
        stream)
            show_header
            check_environment
            streaming_mode "${@:2}"
            exit 0
            ;;
        gui)
            show_header
            check_environment
            gui_mode "${@:2}"
            exit 0
            ;;
        batch)
            show_header
            check_environment
            batch_processing_mode "${@:2}"
            exit 0
            ;;
        interactive)
            show_header
            check_environment
            interactive_mode "${@:2}"
            exit 0
            ;;
        test)
            show_header
            check_environment
            test_mode "${@:2}"
            exit 0
            ;;
        setup)
            show_header
            check_environment
            environment_setup_mode "${@:2}"
            exit 0
            ;;
        tools)
            show_header
            check_environment
            quick_tools_mode "${@:2}"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown mode: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
fi

# Run main interactive mode
main