# Simple Whisper Application

A minimal Python application for real-time audio recording and transcription using OpenAI's Whisper model.

## Features

- **Real-time audio recording** from microphone with device selection
- **Streaming transcription** - process audio in real-time as you speak
- **Automatic transcription** using Whisper
- **Support for multiple Whisper model sizes** (tiny, base, small, medium, large)
- **Automatic language detection**
- **Save recordings and transcriptions** to files
- **Simple command-line interface** with streaming support
- **Interactive mode** with streaming option
- **GUI interface** with always-on-top window and transparency control
- **Audio input device selection** (list and choose specific microphone)
- **Computation device selection** (CPU, CUDA for GPU, MPS for Apple Silicon)

## Requirements

- Python 3.8+
- PyTorch (CPU or GPU)
- OpenAI Whisper
- Audio libraries (sounddevice, soundfile)

## Setup

### 1. Create and activate virtual environment

```bash
# Create virtual environment
python -m venv venv

# Activate on macOS/Linux
source venv/bin/activate

# Activate on Windows
venv\Scripts\activate
```

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

Note: On some systems, you may need to install additional system dependencies:

- **macOS**: `brew install portaudio`
- **Ubuntu/Debian**: `sudo apt-get install portaudio19-dev python3-pyaudio`
- **Windows**: Should work with pip install

## Usage

### Basic recording and transcription

```bash
# Record audio (press Ctrl+C to stop) and transcribe
python simple_whisper.py --record

# Record for specific duration (e.g., 10 seconds) and transcribe
python simple_whisper.py --record --duration 10

# Transcribe an existing audio file
python simple_whisper.py --audio path/to/audio.wav
```

### Advanced options

```bash
# Use a larger model for better accuracy
python simple_whisper.py --record --model medium

# Specify language (e.g., English)
python simple_whisper.py --record --language en

# Specify output files
python simple_whisper.py --record --output-audio my_recording.wav --output-text my_transcription.txt

# Use GPU if available (CUDA)
python simple_whisper.py --record --device cuda

# Use Apple Silicon GPU (MPS)
python simple_whisper.py --record --device mps

# List available audio input devices
python simple_whisper.py --list-audio-devices

# Use specific audio input device (e.g., device ID 5)
python simple_whisper.py --record --input-device 5

# Combine multiple options
python simple_whisper.py --record --duration 10 --model small --device cuda --input-device 0 --language en
```

### Help

```bash
python simple_whisper.py --help
```

### Streaming Mode (Real-time Transcription)

The application now supports **real-time streaming transcription** with low latency (3-5 seconds).

#### Command-line streaming:
```bash
# Basic streaming with tiny model
python simple_whisper.py --stream --model tiny

# Custom chunk parameters for better latency/accuracy balance
python simple_whisper.py --stream --model base --chunk-duration 2.0 --overlap 0.5

# Specify audio input device
python simple_whisper.py --stream --model tiny --input-device 1
```

#### Interactive streaming mode:
```bash
python interactive_whisper.py
# Select "STREAM" mode (option 2) and follow the prompts
```

#### Standalone GUI application:
```bash
python stream_gui.py --model tiny
```
Features:
- Always-on-top window
- Transparency control (30%-100%)
- Start/Stop/Pause buttons
- Real-time text display with auto-scroll
- Word count statistics

#### Streaming parameters:
- `--chunk-duration`: Audio chunk duration in seconds (default: 3.0)
- `--overlap`: Overlap between consecutive chunks in seconds (default: 1.0)

## Examples

1. **Quick test with tiny model:**
   ```bash
   python simple_whisper.py --record --duration 5 --model tiny
   ```

2. **Transcribe existing file with English language:**
   ```bash
   python simple_whisper.py --audio recording.wav --language en --model base
   ```

3. **High-quality transcription:**
   ```bash
   python simple_whisper.py --record --model medium --output-text important_meeting.txt
   ```

4. **Advanced usage with device selection:**
   ```bash
   # List audio devices first
   python simple_whisper.py --list-audio-devices

   # Record using specific microphone and GPU
   python simple_whisper.py --record --duration 15 --model small --device cuda --input-device 2

   # Transcribe existing file with CPU only
   python simple_whisper.py --audio meeting.wav --model base --device cpu
   ```

5. **Real-time streaming transcription:**
   ```bash
   # Low-latency streaming with tiny model
   python simple_whisper.py --stream --model tiny --chunk-duration 1.0

   # High-quality streaming with base model
   python simple_whisper.py --stream --model base --chunk-duration 3.0 --overlap 1.0

   # Interactive streaming mode
   python interactive_whisper.py

   # GUI streaming application
   python stream_gui.py --model tiny
   ```

## Output Files

- Audio recordings are saved as WAV files (e.g., `recording_20250221_143022.wav`)
- Transcriptions are saved as text files (e.g., `recording_20250221_143022_transcription.txt`)

## Troubleshooting

### "PortAudio not found" error
Install PortAudio library:
- macOS: `brew install portaudio`
- Ubuntu: `sudo apt-get install portaudio19-dev`
- Windows: Should be included with sounddevice

### "No module named 'sounddevice'"
Make sure virtual environment is activated and dependencies are installed:
```bash
source venv/bin/activate
pip install sounddevice soundfile
```

### Slow transcription
- Use smaller model (tiny, base)
- Use GPU if available (`--device cuda` or `--device mps`)
- Limit recording duration

### Poor transcription quality
- Use larger model (small, medium, large)
- Ensure clear audio input
- Specify language with `--language` option

## License

MIT