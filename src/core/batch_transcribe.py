#!/usr/bin/env python3
"""
Batch transcription script for Simple Whisper.
Transcribes all audio files in a folder.
"""

import argparse
import os
import sys
import glob
from pathlib import Path

# Add current directory to path to import simple_whisper
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from simple_whisper import SimpleWhisper


def get_audio_files(folder_path, extensions=None):
    """Get all audio files in folder with given extensions."""
    if extensions is None:
        extensions = ['.wav', '.mp3', '.m4a', '.flac', '.ogg', '.aac']

    audio_files = []
    for ext in extensions:
        pattern = os.path.join(folder_path, f'*{ext}')
        audio_files.extend(glob.glob(pattern))

    return sorted(audio_files)


def create_output_dir(base_output_dir):
    """Create output directory if it doesn't exist."""
    if not os.path.exists(base_output_dir):
        os.makedirs(base_output_dir)
        print(f"Created output directory: {base_output_dir}")


def transcribe_file(app, audio_file, output_dir, language=None):
    """Transcribe a single audio file."""
    print(f"\nProcessing: {os.path.basename(audio_file)}")

    try:
        # Transcribe audio
        result = app.transcribe_audio(audio_file, language=language)
        if result is None:
            print(f"  Failed to transcribe {audio_file}")
            return None

        # Add audio path to result
        result["audio_path"] = audio_file

        # Generate output filename
        base_name = os.path.splitext(os.path.basename(audio_file))[0]
        output_file = os.path.join(output_dir, f"{base_name}_transcription.txt")

        # Save transcription
        saved_path = app.save_transcription(result, output_path=output_file)

        print(f"  ✓ Transcribed successfully")
        print(f"  Output: {saved_path}")
        print(f"  Language: {result.get('language', 'unknown')}")
        print(f"  Text preview: {result['text'][:100]}...")

        return saved_path

    except FileNotFoundError as e:
        print(f"  ✗ Error: File not found: {audio_file}")
        print(f"  Details: {e}")
        return None
    except PermissionError as e:
        print(f"  ✗ Error: Permission denied accessing file: {audio_file}")
        print(f"  Details: {e}")
        return None
    except RuntimeError as e:
        print(f"  ✗ Error: Runtime error processing {audio_file}")
        if "memory" in str(e).lower():
            print(f"  Memory error. Try processing fewer files at once.")
        print(f"  Details: {e}")
        return None
    except OSError as e:
        print(f"  ✗ Error: System error processing {audio_file}")
        print(f"  Details: {e}")
        return None
    except Exception as e:
        print(f"  ✗ Unexpected error processing {audio_file}: {e}")
        print(f"  Please check the file format and try again.")
        return None


def main():
    """Main batch transcription function."""
    parser = argparse.ArgumentParser(description="Batch transcription of audio files")

    # Input/output options
    parser.add_argument("input_folder", type=str,
                       help="Folder containing audio files")
    parser.add_argument("--output-folder", type=str, default="./transcriptions",
                       help="Output folder for transcriptions (default: ./transcriptions)")
    parser.add_argument("--recursive", action="store_true",
                       help="Search for audio files recursively in subdirectories")

    # Model options
    parser.add_argument("--model", default="base",
                       choices=["tiny", "base", "small", "medium", "large"],
                       help="Whisper model size (default: base)")

    # Language options
    parser.add_argument("--language", type=str,
                       help="Language code for transcription (e.g., 'en', 'zh'). Auto-detected if not specified.")

    # Device options
    parser.add_argument("--device", type=str,
                       help="Device to run model on (cpu, cuda, mps). Auto-detected if not specified.")

    # Filter options
    parser.add_argument("--extensions", type=str, default="wav,mp3,m4a,flac",
                       help="Comma-separated audio file extensions (default: wav,mp3,m4a,flac)")

    args = parser.parse_args()

    # Check input folder
    if not os.path.isdir(args.input_folder):
        print(f"Error: Input folder not found: {args.input_folder}")
        sys.exit(1)

    # Parse extensions
    extensions = [f'.{ext.strip().lower()}' for ext in args.extensions.split(',')]

    # Get audio files
    print(f"Looking for audio files in: {args.input_folder}")
    print(f"Extensions: {', '.join(extensions)}")

    if args.recursive:
        audio_files = []
        for root, dirs, files in os.walk(args.input_folder):
            for file in files:
                if any(file.lower().endswith(ext) for ext in extensions):
                    audio_files.append(os.path.join(root, file))
    else:
        audio_files = get_audio_files(args.input_folder, extensions)

    if not audio_files:
        print(f"No audio files found with extensions: {', '.join(extensions)}")
        sys.exit(1)

    print(f"Found {len(audio_files)} audio file(s)")

    # Create output directory
    create_output_dir(args.output_folder)

    # Initialize Whisper
    print(f"\nInitializing Whisper model '{args.model}'...")
    try:
        app = SimpleWhisper(model_size=args.model, device=args.device)
    except FileNotFoundError as e:
        print(f"Error: Model file not found for '{args.model}'.")
        print("The model may need to be downloaded. Whisper will download it automatically on first use.")
        print(f"Details: {e}")
        sys.exit(1)
    except RuntimeError as e:
        print(f"Error: Runtime error loading model '{args.model}'.")
        if "CUDA" in str(e):
            print("CUDA/GPU error. Check your CUDA installation and GPU availability.")
        elif "MPS" in str(e):
            print("MPS (Apple Silicon) error. Check your PyTorch MPS support.")
        print(f"Details: {e}")
        sys.exit(1)
    except ConnectionError as e:
        print(f"Error: Network connection failed while downloading model '{args.model}'.")
        print("Check your internet connection or try again later.")
        print(f"Details: {e}")
        sys.exit(1)
    except ValueError as e:
        print(f"Error: Invalid parameter for model loading.")
        print(f"Model size: '{args.model}', Device: '{args.device}'")
        print(f"Valid model sizes: tiny, base, small, medium, large")
        print(f"Details: {e}")
        sys.exit(1)
    except ImportError as e:
        print(f"Error: Required library not found.")
        print("Make sure OpenAI Whisper is installed: pip install openai-whisper")
        print(f"Details: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error initializing Whisper: {e}")
        print("Please check your installation and try again.")
        sys.exit(1)

    # Process files
    print(f"\nStarting batch transcription...")
    print(f"Output folder: {args.output_folder}")

    successful = 0
    failed = 0

    for i, audio_file in enumerate(audio_files, 1):
        print(f"\n[{i}/{len(audio_files)}] ", end="")

        result = transcribe_file(app, audio_file, args.output_folder, args.language)
        if result:
            successful += 1
        else:
            failed += 1

    # Summary
    print("\n" + "="*60)
    print("BATCH TRANSCRIPTION COMPLETE")
    print("="*60)
    print(f"Total files processed: {len(audio_files)}")
    print(f"  Successful: {successful}")
    print(f"  Failed: {failed}")
    print(f"Output folder: {os.path.abspath(args.output_folder)}")

    if successful > 0:
        print(f"\nTranscriptions saved in: {os.path.abspath(args.output_folder)}")
        print("Each transcription file contains:")
        print("  - Full transcribed text")
        print("  - Timestamped segments (if available)")
        print("  - Language detection information")

    if failed > 0:
        print(f"\nWarning: {failed} file(s) failed to transcribe.")
        print("Check the error messages above for details.")


if __name__ == "__main__":
    main()