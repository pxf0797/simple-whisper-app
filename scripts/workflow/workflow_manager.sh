#!/bin/bash
# Advanced Workflow Manager for Simple Whisper Application
# Based on quick_record.sh with enhanced workflow control features
# Supports: Task sequencing, conditional execution, error recovery, monitoring

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

# Configuration files
CONFIG_DIR="$SCRIPT_DIR/config"
WORKFLOW_CONFIG="$CONFIG_DIR/workflow_config.json"
TASK_DEFINITIONS="$CONFIG_DIR/task_definitions.json"
LOG_DIR="$SCRIPT_DIR/logs"

# Create directories if they don't exist
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOG_DIR"

# Log file
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/workflow_manager_${TIMESTAMP}.log"

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
        "TASK") echo -e "${PURPLE}[TASK]${NC} $message" ;;
        *) echo -e "${BLUE}[$level]${NC} $message" ;;
    esac

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Function to display header
show_header() {
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${BLUE}   SIMPLE WHISPER - ADVANCED WORKFLOW MANAGER${NC}"
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

    # Check core dependencies
    log_message "INFO" "Checking core dependencies..."
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
}

# Function to initialize configuration
init_configuration() {
    log_message "INFO" "Initializing configuration..."

    # Create default workflow config if it doesn't exist
    if [ ! -f "$WORKFLOW_CONFIG" ]; then
        cat > "$WORKFLOW_CONFIG" << 'EOF'
{
    "workflows": {
        "quick_record": {
            "description": "Quick recording workflow",
            "tasks": ["check_env", "select_params", "record_audio", "transcribe", "save_outputs"]
        },
        "stream_live": {
            "description": "Live streaming transcription",
            "tasks": ["check_env", "stream_setup", "start_stream", "monitor_stream"]
        },
        "batch_process": {
            "description": "Batch processing workflow",
            "tasks": ["check_env", "select_input_dir", "process_files", "generate_report"]
        },
        "system_test": {
            "description": "System testing workflow",
            "tasks": ["check_env", "test_audio", "test_models", "test_streaming", "generate_test_report"]
        }
    },
    "settings": {
        "default_model": "base",
        "default_language": "auto",
        "audio_device": "default",
        "computation_device": "auto",
        "log_level": "INFO",
        "max_retries": 3,
        "retry_delay": 5
    }
}
EOF
        log_message "INFO" "Created default workflow configuration"
    fi

    # Create default task definitions if they don't exist
    if [ ! -f "$TASK_DEFINITIONS" ]; then
        cat > "$TASK_DEFINITIONS" << 'EOF'
{
    "tasks": {
        "check_env": {
            "description": "Check environment and dependencies",
            "command": "check_environment",
            "type": "internal"
        },
        "select_params": {
            "description": "Select recording parameters",
            "command": "select_parameters",
            "type": "interactive"
        },
        "record_audio": {
            "description": "Record audio",
            "command": "record_audio_task",
            "type": "execution"
        },
        "transcribe": {
            "description": "Transcribe recorded audio",
            "command": "transcribe_audio_task",
            "type": "execution"
        },
        "save_outputs": {
            "description": "Save audio and transcription files",
            "command": "save_outputs_task",
            "type": "execution"
        },
        "stream_setup": {
            "description": "Setup streaming parameters",
            "command": "stream_setup_task",
            "type": "interactive"
        },
        "start_stream": {
            "description": "Start streaming transcription",
            "command": "start_stream_task",
            "type": "execution"
        },
        "monitor_stream": {
            "description": "Monitor streaming process",
            "command": "monitor_stream_task",
            "type": "monitoring"
        }
    }
}
EOF
        log_message "INFO" "Created default task definitions"
    fi
}

# Function to select parameters (similar to quick_record.sh)
select_parameters() {
    log_message "TASK" "Starting parameter selection"

    local params=()

    # Model selection
    echo -e "\n${CYAN}Model Selection:${NC}"
    echo "  1) tiny    - Fastest, lowest accuracy"
    echo "  2) base    - Good balance"
    echo "  3) small   - Better accuracy"
    echo "  4) medium  - High accuracy"
    echo "  5) large   - Highest accuracy"

    while true; do
        read -p "Select model (1-5): " MODEL_CHOICE
        case $MODEL_CHOICE in
            1) params+=("--model tiny"); break ;;
            2) params+=("--model base"); break ;;
            3) params+=("--model small"); break ;;
            4) params+=("--model medium"); break ;;
            5) params+=("--model large"); break ;;
            *) echo "Please enter a number 1-5" ;;
        esac
    done

    # Language selection
    echo -e "\n${CYAN}Language Selection Mode:${NC}"
    echo "  1) auto           - Automatic language detection (recommended)"
    echo "  2) single         - Specify a single language"
    echo "  3) multiple       - Specify multiple languages (e.g., Chinese + English)"

    read -p "Select mode (1-3, default: 1): " LANG_MODE

    case $LANG_MODE in
        1|"")
            # Auto detection
            ;;
        2)
            # Single language selection
            echo -e "\n${CYAN}Single Language Selection:${NC}"
            echo "  1) en  - English"
            echo "  2) zh  - Chinese"
            echo "  3) ja  - Japanese"
            echo "  4) ko  - Korean"
            echo "  5) fr  - French"
            echo "  6) de  - German"
            echo "  7) other - Enter custom language code"

            read -p "Select language (1-7): " LANG_CHOICE
            case $LANG_CHOICE in
                1) params+=("--language en") ;;
                2) params+=("--language zh") ;;
                3) params+=("--language ja") ;;
                4) params+=("--language ko") ;;
                5) params+=("--language fr") ;;
                6) params+=("--language de") ;;
                7) read -p "Enter language code (e.g., 'es', 'ru', 'pt'): " CUSTOM_LANG && params+=("--language $CUSTOM_LANG") ;;
                *) params+=("--language en") ;;  # Default to English
            esac
            ;;
        3)
            # Multiple languages selection
            echo -e "\n${CYAN}Multiple Languages Selection:${NC}"
            echo "You can add multiple languages. The system will use auto-detection"
            echo "but will be aware of these languages for better accuracy."

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
            done

            if [ ${#LANGUAGES_ARRAY[@]} -gt 0 ]; then
                if [ ${#LANGUAGES_ARRAY[@]} -eq 1 ]; then
                    params+=("--language ${LANGUAGES_ARRAY[0]}")
                else
                    LANGUAGE_STRING="multi:$(IFS=,; echo "${LANGUAGES_ARRAY[*]}")"
                    params+=("--language '$LANGUAGE_STRING'")
                fi
            fi
            ;;
    esac

    # Duration selection
    echo -e "\n${CYAN}Recording Duration:${NC}"
    echo "  Enter duration in seconds (e.g., 10, 60, 300)"
    echo "  Or press Enter for manual stop (Ctrl+C to stop recording)"
    echo ""
    read -p "Duration (seconds, empty for manual): " DURATION

    if [ -n "$DURATION" ]; then
        params+=("--duration $DURATION")
    fi

    # Save parameters to temporary file
    PARAMS_FILE="/tmp/whisper_params_${TIMESTAMP}.txt"
    printf "%s\n" "${params[@]}" > "$PARAMS_FILE"

    log_message "INFO" "Parameters saved to $PARAMS_FILE"
    echo "${params[@]}"
}

# Function to record audio task
record_audio_task() {
    log_message "TASK" "Starting audio recording task"

    # Generate output filenames
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local audio_file="record/recording_${timestamp}.wav"
    local text_file="record/recording_${timestamp}_transcription.txt"

    mkdir -p record

    # Read parameters from file if exists
    local params=""
    if [ -f "/tmp/whisper_params_${TIMESTAMP}.txt" ]; then
        params=$(cat "/tmp/whisper_params_${TIMESTAMP}.txt" | tr '\n' ' ')
    else
        # Default parameters
        params="--model base --language auto"
    fi

    # Build command
    local CMD="python $PROJECT_ROOT/src/core/simple_whisper.py --record --output-audio $audio_file --output-text $text_file $params"

    log_message "INFO" "Command: $CMD"
    echo -e "${GREEN}Starting recording...${NC}"

    # Execute command
    if eval $CMD; then
        log_message "INFO" "Recording completed successfully"
        echo -e "${GREEN}Recording saved to:${NC}"
        echo "  Audio: $audio_file"
        echo "  Transcription: $text_file"

        # Save file paths for next tasks
        echo "$audio_file" > "/tmp/audio_file_${TIMESTAMP}.txt"
        echo "$text_file" > "/tmp/text_file_${TIMESTAMP}.txt"
    else
        log_message "ERROR" "Recording failed"
        return 1
    fi
}

# Function to transcribe audio task
transcribe_audio_task() {
    log_message "TASK" "Starting transcription task"

    # Get audio file from previous task
    local audio_file=""
    if [ -f "/tmp/audio_file_${TIMESTAMP}.txt" ]; then
        audio_file=$(cat "/tmp/audio_file_${TIMESTAMP}.txt")
    else
        log_message "ERROR" "No audio file found from previous task"
        return 1
    fi

    # Read parameters
    local params=""
    if [ -f "/tmp/whisper_params_${TIMESTAMP}.txt" ]; then
        params=$(cat "/tmp/whisper_params_${TIMESTAMP}.txt" | tr '\n' ' ')
    fi

    # Get text file path
    local text_file=""
    if [ -f "/tmp/text_file_${TIMESTAMP}.txt" ]; then
        text_file=$(cat "/tmp/text_file_${TIMESTAMP}.txt")
    else
        text_file="${audio_file%.*}_transcription.txt"
    fi

    # Build command (transcribe existing audio file)
    local CMD="python $PROJECT_ROOT/src/core/simple_whisper.py --audio \"$audio_file\" --output-text \"$text_file\" $params"

    log_message "INFO" "Transcribing audio file: $audio_file"
    log_message "INFO" "Command: $CMD"

    if eval $CMD; then
        log_message "INFO" "Transcription completed successfully"
        echo -e "${GREEN}Transcription saved to: $text_file${NC}"

        # Update text file path
        echo "$text_file" > "/tmp/text_file_${TIMESTAMP}.txt"
    else
        log_message "ERROR" "Transcription failed"
        return 1
    fi
}

# Function to save outputs task
save_outputs_task() {
    log_message "TASK" "Starting output saving task"

    # Get file paths
    local audio_file=""
    local text_file=""

    if [ -f "/tmp/audio_file_${TIMESTAMP}.txt" ]; then
        audio_file=$(cat "/tmp/audio_file_${TIMESTAMP}.txt")
    fi

    if [ -f "/tmp/text_file_${TIMESTAMP}.txt" ]; then
        text_file=$(cat "/tmp/text_file_${TIMESTAMP}.txt")
    fi

    if [ -z "$audio_file" ] && [ -z "$text_file" ]; then
        log_message "WARN" "No output files to save"
        return 0
    fi

    # Create summary report
    local report_file="record/workflow_report_${TIMESTAMP}.txt"

    cat > "$report_file" << EOF
Workflow Execution Report
========================
Timestamp: $(date)
Workflow ID: $TIMESTAMP

Generated Files:
$(if [ -n "$audio_file" ]; then echo "  Audio: $audio_file"; fi)
$(if [ -n "$text_file" ]; then echo "  Transcription: $text_file"; fi)

Parameters Used:
$(if [ -f "/tmp/whisper_params_${TIMESTAMP}.txt" ]; then cat "/tmp/whisper_params_${TIMESTAMP}.txt"; fi)

System Information:
  Python: $(python3 --version 2>&1)
  System: $(uname -srm)
  Directory: $(pwd)

EOF

    log_message "INFO" "Report saved to: $report_file"
    echo -e "${GREEN}Workflow completed successfully!${NC}"
    echo -e "${CYAN}Report: $report_file${NC}"

    # Cleanup temporary files
    rm -f "/tmp/whisper_params_${TIMESTAMP}.txt" \
          "/tmp/audio_file_${TIMESTAMP}.txt" \
          "/tmp/text_file_${TIMESTAMP}.txt" 2>/dev/null || true
}

# Function to execute workflow
execute_workflow() {
    local workflow_name="$1"

    log_message "INFO" "Executing workflow: $workflow_name"
    show_header

    # Check environment first
    check_environment

    # Initialize configuration
    init_configuration

    # Execute based on workflow name
    case $workflow_name in
        "quick_record")
            log_message "INFO" "Starting Quick Record workflow"

            # Task sequence
            select_parameters
            record_audio_task
            transcribe_audio_task
            save_outputs_task
            ;;

        "stream_live")
            log_message "INFO" "Starting Live Stream workflow"

            # Check for streaming module
            if [ ! -f "stream_whisper.py" ]; then
                log_message "ERROR" "Streaming module not found"
                echo -e "${YELLOW}Please install streaming dependencies first${NC}"
                return 1
            fi

            echo -e "${CYAN}Live Streaming Configuration${NC}"
            read -p "Model (tiny/base/small, default: tiny): " STREAM_MODEL
            STREAM_MODEL=${STREAM_MODEL:-tiny}

            read -p "Duration (seconds, default: 3600): " STREAM_DURATION
            STREAM_DURATION=${STREAM_DURATION:-3600}

            read -p "Chunk duration (seconds, default: 3.0): " CHUNK_DUR
            CHUNK_DUR=${CHUNK_DUR:-3.0}

            read -p "Overlap (seconds, default: 1.0): " OVERLAP
            OVERLAP=${OVERLAP:-1.0}

            CMD="python $PROJECT_ROOT/src/streaming/stream_whisper.py --model $STREAM_MODEL --duration $STREAM_DURATION --chunk-duration $CHUNK_DUR --overlap $OVERLAP"

            log_message "INFO" "Starting live stream: $CMD"
            echo -e "${GREEN}Starting live streaming transcription...${NC}"
            echo -e "${YELLOW}Press Ctrl+C to stop${NC}"

            eval $CMD
            ;;

        "batch_process")
            log_message "INFO" "Starting Batch Process workflow"

            # Check for batch processing script
            if [ ! -f "batch_transcribe.py" ]; then
                log_message "WARN" "Batch processing script not found"
                echo -e "${YELLOW}Using built-in batch processing${NC}"
            fi

            read -p "Input directory (default: audio_files): " INPUT_DIR
            INPUT_DIR=${INPUT_DIR:-audio_files}

            read -p "Output directory (default: transcriptions): " OUTPUT_DIR
            OUTPUT_DIR=${OUTPUT_DIR:-transcriptions}

            read -p "Model (default: base): " BATCH_MODEL
            BATCH_MODEL=${BATCH_MODEL:-base}

            mkdir -p "$OUTPUT_DIR"

            echo -e "${GREEN}Processing files in $INPUT_DIR...${NC}"

            # Simple batch processing
            count=0
            for audio_file in "$INPUT_DIR"/*.wav "$INPUT_DIR"/*.mp3 "$INPUT_DIR"/*.m4a; do
                if [ -f "$audio_file" ]; then
                    count=$((count + 1))
                    base_name=$(basename "$audio_file")
                    output_file="$OUTPUT_DIR/${base_name%.*}_transcription.txt"

                    echo "Processing [$count]: $base_name"

                    CMD="python $PROJECT_ROOT/src/core/simple_whisper.py --audio \"$audio_file\" --model $BATCH_MODEL --output-text \"$output_file\""

                    if eval $CMD; then
                        echo "  ✓ Saved to: $output_file"
                    else
                        echo "  ✗ Failed to process"
                    fi
                fi
            done 2>/dev/null

            if [ $count -eq 0 ]; then
                echo "No audio files found in $INPUT_DIR"
            else
                echo -e "${GREEN}Batch processing completed: $count files processed${NC}"
            fi
            ;;

        "system_test")
            log_message "INFO" "Starting System Test workflow"

            echo -e "${CYAN}Running System Tests${NC}"
            echo ""

            # Test 1: Environment check
            echo -e "${BLUE}Test 1: Environment Check${NC}"
            check_environment
            echo ""

            # Test 2: Audio devices
            echo -e "${BLUE}Test 2: Audio Devices${NC}"
            python $PROJECT_ROOT/src/core/simple_whisper.py --list-audio-devices
            echo ""

            # Test 3: Model loading
            echo -e "${BLUE}Test 3: Model Loading${NC}"
            python -c "
import whisper
import time

print('Testing model loading...')
for model_size in ['tiny', 'base']:
    try:
        start = time.time()
        model = whisper.load_model(model_size)
        load_time = time.time() - start
        print(f'  ✓ {model_size} model loaded in {load_time:.2f}s on {model.device}')
    except Exception as e:
        print(f'  ✗ {model_size} model failed: {e}')
"
            echo ""

            # Test 4: Quick recording test
            echo -e "${BLUE}Test 4: Quick Recording Test${NC}"
            read -p "Run quick recording test? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                TEST_AUDIO="test_recording_${TIMESTAMP}.wav"
                echo "Recording 5 seconds of audio..."
                python $PROJECT_ROOT/src/core/simple_whisper.py --record --duration 5 --model tiny --output-audio "$TEST_AUDIO"

                if [ -f "$TEST_AUDIO" ]; then
                    echo "  ✓ Recording successful"
                    rm -f "$TEST_AUDIO"
                else
                    echo "  ✗ Recording failed"
                fi
            fi

            echo ""
            echo -e "${GREEN}System tests completed${NC}"
            ;;

        *)
            log_message "ERROR" "Unknown workflow: $workflow_name"
            echo -e "${RED}Unknown workflow. Available workflows:${NC}"
            echo "  quick_record, stream_live, batch_process, system_test"
            return 1
            ;;
    esac

    log_message "INFO" "Workflow $workflow_name completed"
}

# Function to show main menu
show_main_menu() {
    echo -e "${CYAN}Advanced Workflow Manager${NC}"
    echo ""
    echo "Select workflow to execute:"
    echo ""
    echo "  1) ${GREEN}Quick Record${NC}"
    echo "     • Record audio with interactive parameter selection"
    echo "     • Transcribe immediately"
    echo "     • Save outputs with report"
    echo ""
    echo "  2) ${GREEN}Live Stream${NC}"
    echo "     • Real-time streaming transcription"
    echo "     • Configurable chunk size and overlap"
    echo "     • Long-duration streaming support"
    echo ""
    echo "  3) ${GREEN}Batch Process${NC}"
    echo "     • Process multiple audio files"
    echo "     • Custom input/output directories"
    echo "     • Progress tracking"
    echo ""
    echo "  4) ${GREEN}System Test${NC}"
    echo "     • Comprehensive system validation"
    echo "     • Environment, audio, model tests"
    echo "     • Diagnostic report"
    echo ""
    echo "  5) ${GREEN}Manage Workflows${NC}"
    echo "     • View workflow configurations"
    echo "     • Create custom workflows"
    echo "     • Edit task definitions"
    echo ""
    echo "  6) ${GREEN}Monitor & Tools${NC}"
    echo "     • View logs and reports"
    echo "     • System resource monitoring"
    echo "     • Cleanup and maintenance"
    echo ""
    echo "  0) ${RED}Exit${NC}"
    echo ""
}

# Function to manage workflows
manage_workflows() {
    echo -e "${CYAN}Workflow Management${NC}"
    echo ""

    echo "Options:"
    echo "  1) View workflow configurations"
    echo "  2) View task definitions"
    echo "  3) Create new workflow"
    echo "  4) Edit existing workflow"
    echo "  5) Backup configurations"
    echo "  6) Restore configurations"
    echo ""

    read -p "Select option (1-6): " MANAGE_OPT

    case $MANAGE_OPT in
        1)
            echo -e "${GREEN}Workflow Configurations:${NC}"
            if [ -f "$WORKFLOW_CONFIG" ]; then
                python -m json.tool "$WORKFLOW_CONFIG" 2>/dev/null || cat "$WORKFLOW_CONFIG"
            else
                echo "No workflow configuration found"
            fi
            ;;
        2)
            echo -e "${GREEN}Task Definitions:${NC}"
            if [ -f "$TASK_DEFINITIONS" ]; then
                python -m json.tool "$TASK_DEFINITIONS" 2>/dev/null || cat "$TASK_DEFINITIONS"
            else
                echo "No task definitions found"
            fi
            ;;
        3)
            echo -e "${GREEN}Create New Workflow${NC}"
            read -p "Workflow name: " NEW_WORKFLOW
            read -p "Description: " WORKFLOW_DESC

            # Simple workflow creation
            if [ -f "$WORKFLOW_CONFIG" ]; then
                # Note: This is a simple implementation
                echo "Workflow creation would be implemented here"
                echo "Created workflow: $NEW_WORKFLOW - $WORKFLOW_DESC"
            else
                echo "Configuration file not found"
            fi
            ;;
        4)
            echo -e "${GREEN}Edit Workflow${NC}"
            echo "Workflow editing would be implemented here"
            echo "For now, you can edit files directly:"
            echo "  $WORKFLOW_CONFIG"
            echo "  $TASK_DEFINITIONS"
            ;;
        5)
            echo -e "${GREEN}Backup Configurations${NC}"
            BACKUP_DIR="$CONFIG_DIR/backup_$(date +"%Y%m%d_%H%M%S")"
            mkdir -p "$BACKUP_DIR"

            cp "$WORKFLOW_CONFIG" "$BACKUP_DIR/" 2>/dev/null || true
            cp "$TASK_DEFINITIONS" "$BACKUP_DIR/" 2>/dev/null || true

            echo "Backup created in: $BACKUP_DIR"
            ;;
        6)
            echo -e "${GREEN}Restore Configurations${NC}"
            echo "Available backups:"
            ls -la "$CONFIG_DIR/backup_"* 2>/dev/null || echo "No backups found"
            ;;
        *)
            echo -e "${YELLOW}Invalid option${NC}"
            ;;
    esac
}

# Function for monitoring and tools
monitor_tools() {
    echo -e "${CYAN}Monitoring & Tools${NC}"
    echo ""

    echo "Options:"
    echo "  1) View recent logs"
    echo "  2) System resource usage"
    echo "  3) Disk space check"
    echo "  4) Cleanup temporary files"
    echo "  5) Check audio devices"
    echo "  6) Test model loading"
    echo ""

    read -p "Select option (1-6): " MONITOR_OPT

    case $MONITOR_OPT in
        1)
            echo -e "${GREEN}Recent Log Files:${NC}"
            ls -lt "$LOG_DIR/"*.log 2>/dev/null | head -5

            read -p "View latest log? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                latest_log=$(ls -t "$LOG_DIR/"*.log 2>/dev/null | head -1)
                if [ -n "$latest_log" ]; then
                    echo "=== Last 20 lines of $(basename $latest_log) ==="
                    tail -20 "$latest_log"
                fi
            fi
            ;;
        2)
            echo -e "${GREEN}System Resource Usage:${NC}"
            echo "CPU and Memory:"
            top -l 1 -s 0 | head -10 2>/dev/null || echo "Top command not available"

            echo -e "\nProcesses related to Whisper:"
            ps aux | grep -i "whisper\|python" | grep -v grep | head -5
            ;;
        3)
            echo -e "${GREEN}Disk Space:${NC}"
            df -h .

            echo -e "\nWhisper models cache:"
            du -sh ~/.cache/whisper/ 2>/dev/null || echo "Cache directory not found"
            ;;
        4)
            echo -e "${GREEN}Cleaning up...${NC}"

            # Remove temporary audio files
            rm -f recording_*.wav test_*.wav 2>/dev/null || true

            # Remove old log files (keep last 10)
            ls -t "$LOG_DIR/"*.log 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true

            # Remove temporary parameter files
            rm -f /tmp/whisper_params_*.txt 2>/dev/null || true
            rm -f /tmp/audio_file_*.txt 2>/dev/null || true
            rm -f /tmp/text_file_*.txt 2>/dev/null || true

            echo "Cleanup completed"
            ;;
        5)
            echo -e "${GREEN}Audio Devices:${NC}"
            python $PROJECT_ROOT/src/core/simple_whisper.py --list-audio-devices
            ;;
        6)
            echo -e "${GREEN}Model Loading Test:${NC}"
            read -p "Model to test (tiny/base, default: tiny): " TEST_MODEL
            TEST_MODEL=${TEST_MODEL:-tiny}

            python -c "
import whisper
import time

print(f'Loading {$TEST_MODEL} model...')
start = time.time()
model = whisper.load_model(\"$TEST_MODEL\")
load_time = time.time() - start

print(f'✓ Model loaded successfully')
print(f'  Device: {model.device}')
print(f'  Load time: {load_time:.2f} seconds')
"
            ;;
        *)
            echo -e "${YELLOW}Invalid option${NC}"
            ;;
    esac
}

# Main interactive mode
main_interactive() {
    while true; do
        show_header
        show_main_menu

        read -p "Select option (0-6): " MAIN_CHOICE

        case $MAIN_CHOICE in
            0)
                echo -e "${GREEN}Exiting Workflow Manager. Goodbye!${NC}"
                log_message "INFO" "Workflow manager exited"
                exit 0
                ;;
            1)
                execute_workflow "quick_record"
                ;;
            2)
                execute_workflow "stream_live"
                ;;
            3)
                execute_workflow "batch_process"
                ;;
            4)
                execute_workflow "system_test"
                ;;
            5)
                manage_workflows
                ;;
            6)
                monitor_tools
                ;;
            *)
                echo -e "${RED}Invalid selection. Please try again.${NC}"
                ;;
        esac

        echo ""
        read -p "Return to main menu? (y/n, default: y): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]] && [ -n "$REPLY" ]; then
            echo -e "${GREEN}Exiting Workflow Manager. Goodbye!${NC}"
            log_message "INFO" "Workflow manager exited"
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
            echo "Usage: $0 [WORKFLOW|OPTION]"
            echo ""
            echo "Advanced Workflow Manager for Simple Whisper Application"
            echo ""
            echo "Workflows:"
            echo "  quick_record    - Quick recording and transcription"
            echo "  stream_live     - Live streaming transcription"
            echo "  batch_process   - Batch processing of audio files"
            echo "  system_test     - Comprehensive system testing"
            echo ""
            echo "Options:"
            echo "  --help, -h      - Show this help"
            echo "  --config        - Show configuration"
            echo "  --logs          - Show recent logs"
            echo "  --cleanup       - Cleanup temporary files"
            echo "  --test          - Run quick system test"
            echo ""
            echo "Examples:"
            echo "  $0                       # Interactive mode"
            echo "  $0 quick_record          # Execute quick record workflow"
            echo "  $0 stream_live           # Execute live stream workflow"
            echo "  $0 --config              # Show configuration"
            echo "  $0 --logs                # Show recent logs"
            exit 0
            ;;
        quick_record)
            execute_workflow "quick_record"
            exit 0
            ;;
        stream_live)
            execute_workflow "stream_live"
            exit 0
            ;;
        batch_process)
            execute_workflow "batch_process"
            exit 0
            ;;
        system_test)
            execute_workflow "system_test"
            exit 0
            ;;
        --config)
            show_header
            echo -e "${CYAN}Configuration Files:${NC}"
            echo ""
            echo "Workflow config: $WORKFLOW_CONFIG"
            echo "Task definitions: $TASK_DEFINITIONS"
            echo "Log directory: $LOG_DIR"
            echo ""

            if [ -f "$WORKFLOW_CONFIG" ]; then
                echo -e "${GREEN}Workflow Configuration:${NC}"
                cat "$WORKFLOW_CONFIG"
            fi
            exit 0
            ;;
        --logs)
            show_header
            echo -e "${CYAN}Recent Log Files:${NC}"
            ls -lt "$LOG_DIR/"*.log 2>/dev/null | head -10
            exit 0
            ;;
        --cleanup)
            show_header
            echo -e "${CYAN}Cleaning up temporary files...${NC}"
            rm -f recording_*.wav test_*.wav 2>/dev/null || true
            rm -f /tmp/whisper_params_*.txt 2>/dev/null || true
            echo "Cleanup completed"
            exit 0
            ;;
        --test)
            show_header
            execute_workflow "system_test"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
fi

# Start interactive mode
main_interactive