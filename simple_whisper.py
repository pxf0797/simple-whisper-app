#!/usr/bin/env python3
"""
Simple Whisper Application
A minimal Python application for real-time audio recording and transcription using Whisper.
"""

import argparse
import os
import sys
import time
import wave
import sounddevice as sd
import soundfile as sf
import numpy as np
import whisper
from pathlib import Path
from datetime import datetime

# Try to import streaming module (optional)
try:
    from stream_whisper import StreamWhisper
    HAS_STREAM = True
except ImportError:
    HAS_STREAM = False
    StreamWhisper = None


def list_audio_devices():
    """List all available audio input devices."""
    print("Available audio input devices:")
    print("-" * 60)

    devices = sd.query_devices()
    default_input = sd.default.device[0]

    for i, device in enumerate(devices):
        if device['max_input_channels'] > 0:
            is_default = "(default)" if i == default_input else ""
            print(f"  [{i}] {device['name']} {is_default}")
            print(f"      Input channels: {device['max_input_channels']}, Sample rate: {device['default_samplerate']}")

    print("-" * 60)
    print(f"Default input device ID: {default_input}")
    return devices


class SimpleWhisper:
    """Simple Whisper application for recording and transcribing audio."""

    def __init__(self, model_size="base", device=None, sample_rate=16000):
        """
        Initialize the Whisper model.

        Args:
            model_size (str): Whisper model size (tiny, base, small, medium, large)
            device: Device to run model on (None for auto-detection)
            sample_rate (int): Sample rate for audio recording
        """
        self.sample_rate = sample_rate
        self.model_size = model_size

        print(f"Loading Whisper model '{model_size}'...")
        try:
            self.model = whisper.load_model(model_size, device=device)
            print(f"Model loaded successfully (running on {self.model.device}).")
        except Exception as e:
            print(f"Error loading model: {e}")
            sys.exit(1)

    def _validate_device_id(self, device_id):
        """Validate audio input device ID."""
        if device_id is None:
            return None

        try:
            devices = sd.query_devices()
            device_info = devices[device_id]

            # Check if device has input capability
            if device_info['max_input_channels'] <= 0:
                print(f"Warning: Device [{device_id}] has no input channels. Using default device instead.")
                return None

            return device_id
        except (IndexError, KeyError):
            print(f"Error: Invalid audio device ID: {device_id}")
            print("Use --list-audio-devices to see available devices.")
            return None

    def record_audio(self, duration=None, output_path=None, device_id=None):
        """
        Record audio from microphone.

        Args:
            duration (float): Recording duration in seconds. If None, record until interrupted.
            output_path (str): Path to save recorded audio. If None, auto-generate filename.
            device_id (int): Audio input device ID. If None, use default device.

        Returns:
            str: Path to saved audio file
        """
        if output_path is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_path = f"recording_{timestamp}.wav"

        print(f"Recording audio... (Press Ctrl+C to stop)")

        # Validate device ID
        valid_device_id = self._validate_device_id(device_id)
        if device_id is not None and valid_device_id is None:
            print("Falling back to default audio device.")

        try:
            if duration:
                # Record for specified duration
                print(f"Recording for {duration} seconds...")
                audio_data = sd.rec(
                    int(duration * self.sample_rate),
                    samplerate=self.sample_rate,
                    channels=1,
                    dtype='float32',
                    device=valid_device_id
                )
                sd.wait()  # Wait until recording is finished

                # Save audio
                sf.write(output_path, audio_data, self.sample_rate)
                print(f"Audio saved to: {output_path}")

            else:
                # Record until interrupted
                print("Recording until interrupted (Ctrl+C)...")
                audio_frames = []

                def callback(indata, frames, time, status):
                    if status:
                        print(f"Recording error: {status}")
                    audio_frames.append(indata.copy())

                with sd.InputStream(
                    samplerate=self.sample_rate,
                    channels=1,
                    dtype='float32',
                    callback=callback,
                    device=valid_device_id
                ):
                    try:
                        while True:
                            time.sleep(0.1)
                    except KeyboardInterrupt:
                        print("\nRecording stopped.")

                if audio_frames:
                    audio_data = np.concatenate(audio_frames, axis=0)
                    sf.write(output_path, audio_data, self.sample_rate)
                    print(f"Audio saved to: {output_path}")
                else:
                    print("No audio recorded.")
                    return None

        except Exception as e:
            print(f"Error during recording: {e}")
            return None

        return output_path

    def transcribe_audio(self, audio_path, language=None, simplified_chinese=None):
        """
        Transcribe audio file using Whisper.

        Args:
            audio_path (str): Path to audio file
            language (str): Language code (e.g., 'en', 'zh'). If None, auto-detect.
                           Special value 'zh+en' for Chinese-English bilingual content.
                           'multi:lang1,lang2' for multiple language hints.
            simplified_chinese (str): Convert Chinese to simplified Chinese ('yes' or 'no')

        Returns:
            dict: Transcription result with text, segments, language, etc.
        """
        if not os.path.exists(audio_path):
            print(f"Audio file not found: {audio_path}")
            return None

        print(f"Transcribing audio: {audio_path}")

        # Store simplified_chinese setting in result for later use
        simplified_chinese_setting = simplified_chinese

        try:
            # Load audio and pad/trim to fit 30 seconds
            audio = whisper.load_audio(audio_path)
            audio = whisper.pad_or_trim(audio)

            # Make log-Mel spectrogram
            mel = whisper.log_mel_spectrogram(audio).to(self.model.device)

            # Detect language
            _, probs = self.model.detect_language(mel)
            detected_language = max(probs, key=probs.get)

            # Handle special language codes
            original_language = language
            multi_languages = []

            if language and language.startswith("multi:"):
                # Multiple languages hint
                multi_lang_str = language[6:]  # Remove "multi:" prefix
                multi_languages = multi_lang_str.split(',')
                print(f"Multiple language hint: {', '.join(multi_languages)}")

                # Show probabilities for hinted languages
                for lang in multi_languages:
                    prob = probs.get(lang, 0.0)
                    print(f"  {lang} probability: {prob:.2f}")

                # Use auto-detection for multiple languages
                language = None
                print("Using auto-detection for multiple languages")

            elif language == "zh+en":
                # For Chinese-English bilingual content
                print("Bilingual mode: Chinese-English")
                zh_prob = probs.get("zh", 0.0)
                en_prob = probs.get("en", 0.0)

                print(f"Chinese probability: {zh_prob:.2f}")
                print(f"English probability: {en_prob:.2f}")

                # Use auto-detection for bilingual content
                # Whisper's auto-detection handles mixed languages better
                language = None
            elif language is None:
                language = detected_language

            print(f"Detected language: {detected_language} (confidence: {probs[detected_language]:.2f})")

            # Show simplified Chinese setting if applicable
            if simplified_chinese_setting and (language == "zh" or "zh" in multi_languages or original_language == "zh+en"):
                if simplified_chinese_setting == "yes":
                    print("Will convert Chinese text to simplified Chinese")
                else:
                    print("Keeping original Chinese text format")

            if original_language and original_language.startswith("multi:"):
                print(f"Transcribing in language: auto (multiple languages: {', '.join(multi_languages)})")
            elif original_language == "zh+en":
                print(f"Transcribing in language: auto (bilingual Chinese-English)")
            else:
                print(f"Transcribing in language: {language if language else 'auto'}")

            # Decode audio
            options = whisper.DecodingOptions(language=language, fp16=False)
            result = whisper.decode(self.model, mel, options)

            # Get full transcription
            transcription_result = self.model.transcribe(audio_path, language=language)

            # Add simplified_chinese setting to result for save_transcription
            transcription_result["simplified_chinese"] = simplified_chinese_setting
            transcription_result["original_language_param"] = original_language

            return transcription_result

        except Exception as e:
            print(f"Error during transcription: {e}")
            return None

    def save_transcription(self, result, output_path=None):
        """
        Save transcription result to text file.

        Args:
            result (dict): Transcription result from Whisper
            output_path (str): Path to save transcription. If None, auto-generate filename.

        Returns:
            str: Path to saved transcription file
        """
        if result is None:
            print("No transcription result to save.")
            return None

        if output_path is None:
            audio_path = result.get("audio_path", "audio")
            base_name = os.path.splitext(os.path.basename(audio_path))[0]
            output_path = f"{base_name}_transcription.txt"

        try:
            # Get text and segments
            text = result.get("text", "")
            segments = result.get("segments", [])
            simplified_chinese = result.get("simplified_chinese")

            # Convert to simplified Chinese if requested
            if simplified_chinese == "yes" and text:
                # Check if text contains Chinese characters
                import re
                has_chinese = re.search(r'[\u4e00-\u9fff]', text)

                if has_chinese:
                    try:
                        # Try to import zhconv for conversion
                        import zhconv
                        text = zhconv.convert(text, 'zh-cn')
                        print("Converted Chinese text to simplified Chinese")

                        # Also convert segment texts
                        for segment in segments:
                            if 'text' in segment:
                                segment_text = segment['text']
                                if re.search(r'[\u4e00-\u9fff]', segment_text):
                                    segment['text'] = zhconv.convert(segment_text, 'zh-cn')
                    except ImportError:
                        print("Warning: zhconv library not installed. Cannot convert to simplified Chinese.")
                        print("Install with: pip install zhconv")
                    except Exception as conv_e:
                        print(f"Warning: Error converting to simplified Chinese: {conv_e}")

            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(text)
                if segments:
                    f.write("\n\n--- Detailed Segments ---\n")
                    for segment in segments:
                        f.write(f"[{segment['start']:.2f}s - {segment['end']:.2f}s]: {segment['text']}\n")

            print(f"Transcription saved to: {output_path}")
            return output_path

        except Exception as e:
            print(f"Error saving transcription: {e}")
            return None

def main():
    """Main entry point for the simple whisper application."""
    parser = argparse.ArgumentParser(description="Simple Whisper: Real-time audio recording and transcription")

    # Model options
    parser.add_argument("--model", default="base",
                       choices=["tiny", "base", "small", "medium", "large"],
                       help="Whisper model size (default: base)")

    # Recording options
    parser.add_argument("--record", action="store_true",
                       help="Record audio from microphone")
    parser.add_argument("--stream", action="store_true",
                       help="Stream audio in real-time (requires stream_whisper module)")
    parser.add_argument("--duration", type=float,
                       help="Recording duration in seconds (for --record)")
    parser.add_argument("--audio", type=str,
                       help="Audio file to transcribe (instead of recording)")

    # Output options
    parser.add_argument("--output-audio", type=str,
                       help="Path to save recorded audio")
    parser.add_argument("--output-text", type=str,
                       help="Path to save transcription text")

    # Language options
    parser.add_argument("--language", type=str,
                       help="Language code for transcription (e.g., 'en', 'zh', 'zh+en' for bilingual Chinese-English, 'multi:lang1,lang2' for multiple language hints). Auto-detected if not specified.")
    parser.add_argument("--simplified-chinese", type=str, choices=["yes", "no"],
                       help="Convert Chinese text to simplified Chinese (yes/no).")

    # Device options
    parser.add_argument("--device", type=str,
                       help="Device to run model on (cpu, cuda, mps). Auto-detected if not specified.")
    parser.add_argument("--input-device", type=int,
                       help="Audio input device ID for recording. Use --list-audio-devices to see available devices.")
    # Streaming options
    parser.add_argument("--chunk-duration", type=float, default=3.0,
                       help="Chunk duration in seconds for streaming (default: 3.0)")
    parser.add_argument("--overlap", type=float, default=1.0,
                       help="Overlap between chunks in seconds for streaming (default: 1.0)")
    parser.add_argument("--list-audio-devices", action="store_true",
                       help="List available audio input devices and exit.")

    args = parser.parse_args()

    # List audio devices if requested
    if args.list_audio_devices:
        list_audio_devices()
        return

    # Check if either recording, audio file, or streaming is provided
    if not args.record and not args.audio and not args.stream:
        print("Either --record, --audio, or --stream must be specified.")
        parser.print_help()
        return

    # Initialize Whisper
    app = SimpleWhisper(model_size=args.model, device=args.device)

    # Record, stream, or use provided audio
    if args.record:
        # Show audio device information
        if args.input_device is None:
            print("\nAudio device information:")
            devices = sd.query_devices()
            default_input = sd.default.device[0]
            print(f"Using default input device: [{default_input}] {devices[default_input]['name']}")
            print("Use --list-audio-devices to see all available devices or --input-device <ID> to specify a device.")
        else:
            devices = sd.query_devices()
            try:
                if args.input_device < 0 or args.input_device >= len(devices):
                    print(f"Error: Invalid audio device ID: {args.input_device}")
                    print("Use --list-audio-devices to see available devices.")
                    return
                device_info = devices[args.input_device]
                print(f"\nUsing specified input device: [{args.input_device}] {device_info['name']}")
            except (IndexError, KeyError):
                print(f"Error: Invalid audio device ID: {args.input_device}")
                print("Use --list-audio-devices to see available devices.")
                return

        audio_path = app.record_audio(duration=args.duration, output_path=args.output_audio, device_id=args.input_device)
        if audio_path is None:
            print("Failed to record audio.")
            return

    elif args.stream:
        # Streaming mode
        if not HAS_STREAM:
            print("Error: Streaming module not available.")
            print("Make sure stream_whisper.py is in the same directory.")
            return

        print("\n" + "="*50)
        print("STREAMING MODE - Real-time Transcription")
        print("="*50)

        # Initialize StreamWhisper
        streamer = StreamWhisper(
            model_size=args.model,
            device=args.device,
            chunk_duration=args.chunk_duration,
            overlap=args.overlap
        )

        # Start streaming
        print(f"Starting streaming with {args.chunk_duration}s chunks, {args.overlap}s overlap")
        if not streamer.start_streaming(device_id=args.input_device):
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

        # Exit after streaming (don't continue to transcription step)
        return

    else:
        audio_path = args.audio

    # Transcribe audio
    result = app.transcribe_audio(audio_path, language=args.language, simplified_chinese=args.simplified_chinese)
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
    saved_path = app.save_transcription(result, output_path=args.output_text)

    print(f"\nSummary:")
    print(f"- Audio: {audio_path}")
    if saved_path:
        print(f"- Transcription: {saved_path}")
    print(f"- Model: {args.model}")
    # Show original language parameter or detected language
    display_language = args.language if args.language else result.get('language', 'auto')
    print(f"- Language: {display_language}")

if __name__ == "__main__":
    main()