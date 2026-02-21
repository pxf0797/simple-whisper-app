#!/usr/bin/env python3
"""
Interactive Whisper Application
A user-friendly interactive interface for the Simple Whisper application.
"""

import sys
import os
import subprocess
import time
import sounddevice as sd

# Add current directory to path to import simple_whisper
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from simple_whisper import SimpleWhisper, list_audio_devices

# Try to import StreamWhisper
try:
    from stream_whisper import StreamWhisper
    HAS_STREAM = True
except ImportError:
    HAS_STREAM = False
    StreamWhisper = None


def clear_screen():
    """Clear terminal screen."""
    os.system('cls' if os.name == 'nt' else 'clear')


def print_header(title):
    """Print a formatted header."""
    print("=" * 60)
    print(f"{title:^60}")
    print("=" * 60)


def select_audio_device():
    """Let user select an audio input device."""
    print_header("SELECT AUDIO INPUT DEVICE")

    devices = sd.query_devices()
    default_input = sd.default.device[0]

    input_devices = []
    for i, device in enumerate(devices):
        if device['max_input_channels'] > 0:
            input_devices.append((i, device))

    print("Available audio input devices:\n")
    for idx, (device_id, device) in enumerate(input_devices):
        is_default = "(default)" if device_id == default_input else ""
        print(f"  [{idx}] Device {device_id}: {device['name']} {is_default}")
        print(f"      Channels: {device['max_input_channels']}, Sample rate: {device['default_samplerate']}")
        print()

    while True:
        try:
            choice = input(f"Select device [0-{len(input_devices)-1}] (Enter for default #{default_input}): ").strip()
            if not choice:
                return default_input

            choice_idx = int(choice)
            if 0 <= choice_idx < len(input_devices):
                return input_devices[choice_idx][0]
            else:
                print(f"Please enter a number between 0 and {len(input_devices)-1}")
        except ValueError:
            print("Please enter a valid number.")
        except KeyboardInterrupt:
            print("\nCancelled.")
            sys.exit(0)


def select_model():
    """Let user select Whisper model size."""
    print_header("SELECT WHISPER MODEL")

    models = [
        ("tiny", "Fastest, lowest accuracy (39M parameters)"),
        ("base", "Good balance of speed and accuracy (74M parameters)"),
        ("small", "Better accuracy, slower (244M parameters)"),
        ("medium", "High accuracy, slow (769M parameters)"),
        ("large", "Highest accuracy, very slow (1550M parameters)")
    ]

    print("Available Whisper models:\n")
    for i, (name, desc) in enumerate(models):
        print(f"  [{i}] {name.upper():6s} - {desc}")
    print()

    while True:
        try:
            choice = input(f"Select model [0-{len(models)-1}] (Enter for 'base'): ").strip()
            if not choice:
                return "base"

            choice_idx = int(choice)
            if 0 <= choice_idx < len(models):
                return models[choice_idx][0]
            else:
                print(f"Please enter a number between 0 and {len(models)-1}")
        except ValueError:
            print("Please enter a valid number.")
        except KeyboardInterrupt:
            print("\nCancelled.")
            sys.exit(0)


def select_computation_device():
    """Let user select computation device (CPU/GPU)."""
    print_header("SELECT COMPUTATION DEVICE")

    import torch

    devices = []

    # Check for CUDA (NVIDIA GPU)
    if torch.cuda.is_available():
        cuda_count = torch.cuda.device_count()
        for i in range(cuda_count):
            devices.append((f"cuda:{i}", f"NVIDIA GPU {i} ({torch.cuda.get_device_name(i)})"))

    # Check for MPS (Apple Silicon)
    if hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
        devices.append(("mps", "Apple Silicon GPU (MPS)"))

    # CPU is always available
    devices.append(("cpu", "CPU (slowest but guaranteed to work)"))

    print("Available computation devices:\n")
    for i, (device, desc) in enumerate(devices):
        print(f"  [{i}] {device.upper():10s} - {desc}")
    print()

    while True:
        try:
            choice = input(f"Select device [0-{len(devices)-1}] (Enter for auto-detect): ").strip()
            if not choice:
                return None  # Auto-detect

            choice_idx = int(choice)
            if 0 <= choice_idx < len(devices):
                return devices[choice_idx][0]
            else:
                print(f"Please enter a number between 0 and {len(devices)-1}")
        except ValueError:
            print("Please enter a valid number.")
        except KeyboardInterrupt:
            print("\nCancelled.")
            sys.exit(0)


def select_language():
    """Let user select transcription language."""
    print_header("SELECT LANGUAGE")

    # Common languages supported by Whisper
    languages = [
        ("auto", "Auto-detect (recommended)"),
        ("en", "English"),
        ("zh", "Chinese"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("ru", "Russian"),
        ("ar", "Arabic")
    ]

    print("Language options:\n")
    for i, (code, name) in enumerate(languages):
        print(f"  [{i}] {code.upper():4s} - {name}")
    print()

    while True:
        try:
            choice = input(f"Select language [0-{len(languages)-1}] (Enter for auto-detect): ").strip()
            if not choice:
                return None  # Auto-detect

            choice_idx = int(choice)
            if 0 <= choice_idx < len(languages):
                return languages[choice_idx][0]
            else:
                print(f"Please enter a number between 0 and {len(languages)-1}")
        except ValueError:
            print("Please enter a valid number.")
        except KeyboardInterrupt:
            print("\nCancelled.")
            sys.exit(0)


def select_recording_mode():
    """Let user select recording mode."""
    print_header("SELECT MODE")

    modes = [
        ("record", "Record from microphone"),
        ("file", "Transcribe existing audio file"),
        ("stream", "Stream in real-time")
    ]

    print("Available modes:\n")
    for i, (mode, desc) in enumerate(modes):
        print(f"  [{i}] {mode.upper():10s} - {desc}")
    print()

    while True:
        try:
            choice = input(f"Select mode [0-{len(modes)-1}]: ").strip()

            choice_idx = int(choice)
            if 0 <= choice_idx < len(modes):
                return modes[choice_idx][0]
            else:
                print(f"Please enter a number between 0 and {len(modes)-1}")
        except ValueError:
            print("Please enter a valid number.")
        except KeyboardInterrupt:
            print("\nCancelled.")
            sys.exit(0)


def get_recording_duration():
    """Get recording duration from user."""
    while True:
        try:
            duration = input("Enter recording duration in seconds (Enter for manual stop with Ctrl+C): ").strip()
            if not duration:
                return None

            duration_float = float(duration)
            if duration_float <= 0:
                print("Duration must be positive.")
                continue

            return duration_float
        except ValueError:
            print("Please enter a valid number.")
        except KeyboardInterrupt:
            print("\nCancelled.")
            sys.exit(0)


def get_audio_file_path():
    """Get audio file path from user."""
    while True:
        file_path = input("Enter path to audio file: ").strip()
        if not file_path:
            print("Please enter a file path.")
            continue

        if os.path.exists(file_path):
            return file_path
        else:
            print(f"File not found: {file_path}")
            print("Please enter a valid file path.")


def run_transcription(params):
    """Run transcription with selected parameters."""
    print_header("STARTING TRANSCRIPTION")

    print("Configuration:")
    print(f"  Mode: {params['mode']}")
    if params['mode'] == 'record':
        print(f"  Audio device: {params.get('device_id', 'default')}")
        if params.get('duration'):
            print(f"  Duration: {params['duration']} seconds")
        else:
            print(f"  Duration: Manual stop (Ctrl+C)")
    elif params['mode'] == 'stream':
        print(f"  Audio device: {params.get('device_id', 'default')}")
        print(f"  Chunk duration: {params.get('chunk_duration', 3.0)} seconds")
        print(f"  Overlap: {params.get('overlap', 1.0)} seconds")
    else:
        print(f"  Audio file: {params['audio_file']}")

    print(f"  Model: {params['model']}")
    print(f"  Computation device: {params.get('computation_device', 'auto-detect')}")
    print(f"  Language: {params.get('language', 'auto-detect')}")
    print()

    input("Press Enter to start... (Ctrl+C to cancel)")

    try:
        # Initialize Whisper
        app = SimpleWhisper(
            model_size=params['model'],
            device=params.get('computation_device')
        )

        if params['mode'] == 'record':
            # Record audio
            audio_path = app.record_audio(
                duration=params.get('duration'),
                output_path=params.get('output_audio'),
                device_id=params.get('device_id')
            )

            if audio_path is None:
                print("Failed to record audio.")
                return

            # Transcribe audio
            result = app.transcribe_audio(audio_path, language=params.get('language'))
            if result is None:
                print("Failed to transcribe audio.")
                return

        elif params['mode'] == 'stream':
            # Streaming mode
            if not HAS_STREAM:
                print("Error: Streaming module not available.")
                print("Make sure stream_whisper.py is in the same directory.")
                return

            # Initialize StreamWhisper
            streamer = StreamWhisper(
                model_size=params['model'],
                chunk_duration=params.get('chunk_duration', 3.0),
                overlap=params.get('overlap', 1.0)
            )

            # Start streaming
            print(f"\nStarting streaming...")
            if not streamer.start_streaming(device_id=params.get('device_id')):
                print("Failed to start streaming.")
                return

            try:
                print("Streaming started. Press Ctrl+C to stop.\n")
                start_time = time.time()

                while True:
                    # Get transcription
                    text = streamer.get_transcription(timeout=0.5)
                    if text and text.strip():
                        print(f"[{time.time() - start_time:.1f}s] {text}")

                    time.sleep(0.1)

            except KeyboardInterrupt:
                print("\n\nStreaming stopped by user.")
            finally:
                streamer.stop_streaming()
                print("\nFull transcription:")
                print(streamer.get_full_transcription())

            # Exit after streaming
            return

        else:
            # Use existing audio file
            audio_path = params['audio_file']

            # Transcribe audio
            result = app.transcribe_audio(audio_path, language=params.get('language'))
            if result is None:
                print("Failed to transcribe audio.")
                return

        # Add audio path to result for saving
        result["audio_path"] = audio_path

        # Print transcription
        print("\n" + "="*50)
        print("TRANSCRIPTION RESULT:")
        print("="*50)
        print(result["text"])
        print("="*50)

        # Save transcription
        saved_path = app.save_transcription(result, output_path=params.get('output_text'))

        print(f"\nSummary:")
        print(f"- Audio: {audio_path}")
        if saved_path:
            print(f"- Transcription: {saved_path}")
        print(f"- Model: {params['model']}")
        print(f"- Language: {result.get('language', 'unknown')}")

    except KeyboardInterrupt:
        print("\n\nTranscription cancelled.")
    except Exception as e:
        print(f"\nError: {e}")
        import traceback
        traceback.print_exc()


def main():
    """Main interactive application."""
    clear_screen()
    print_header("SIMPLE WHISPER - INTERACTIVE MODE")

    try:
        # Get user preferences
        mode = select_recording_mode()

        params = {
            'mode': mode,
            'model': select_model(),
            'computation_device': select_computation_device(),
            'language': select_language()
        }

        if mode == 'record':
            params['device_id'] = select_audio_device()
            params['duration'] = get_recording_duration()

            # Ask for output file names
            custom_output = input("Custom audio filename (Enter for auto-generated): ").strip()
            if custom_output:
                params['output_audio'] = custom_output

            custom_text = input("Custom transcription filename (Enter for auto-generated): ").strip()
            if custom_text:
                params['output_text'] = custom_text

        elif mode == 'stream':
            params['device_id'] = select_audio_device()

            # Get chunk duration
            while True:
                try:
                    chunk_input = input("Chunk duration in seconds (default: 3.0): ").strip()
                    if not chunk_input:
                        params['chunk_duration'] = 3.0
                        break
                    chunk_duration = float(chunk_input)
                    if chunk_duration <= 0:
                        print("Chunk duration must be positive.")
                        continue
                    params['chunk_duration'] = chunk_duration
                    break
                except ValueError:
                    print("Please enter a valid number.")

            # Get overlap
            while True:
                try:
                    overlap_input = input("Overlap between chunks in seconds (default: 1.0): ").strip()
                    if not overlap_input:
                        params['overlap'] = 1.0
                        break
                    overlap = float(overlap_input)
                    if overlap < 0:
                        print("Overlap cannot be negative.")
                        continue
                    params['overlap'] = overlap
                    break
                except ValueError:
                    print("Please enter a valid number.")

        else:  # mode == 'file'
            params['audio_file'] = get_audio_file_path()

            custom_text = input("Custom transcription filename (Enter for auto-generated): ").strip()
            if custom_text:
                params['output_text'] = custom_text

        # Run transcription
        run_transcription(params)

    except KeyboardInterrupt:
        print("\n\nApplication cancelled.")
    except Exception as e:
        print(f"\nUnexpected error: {e}")
        import traceback
        traceback.print_exc()

    print("\n" + "="*60)
    print("Thank you for using Simple Whisper!")
    print("="*60)


if __name__ == "__main__":
    main()