#!/usr/bin/env python3
"""
Simple Whisper Application
A minimal Python application for real-time audio recording and transcription using Whisper.
"""

import argparse
import os
import sys
import threading
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

# Patch pkgutil for compatibility with Python 3.12+
# Some libraries (webrtcvad, zhconv) still use pkg_resources which depends on pkgutil.ImpImporter
# ImpImporter was removed in Python 3.12, so we provide a dummy implementation
import pkgutil
if not hasattr(pkgutil, 'ImpImporter'):
    class ImpImporter:
        """Dummy Importer for compatibility with pkg_resources"""
        pass
    pkgutil.ImpImporter = ImpImporter

import time
import wave
import sounddevice as sd
import soundfile as sf
import numpy as np
import whisper
from pathlib import Path
from datetime import datetime

# Streaming module is imported dynamically when needed


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


def get_mac_default_microphone():
    """
    Get the default microphone for macOS systems.

    Returns:
        int: Device ID for macOS built-in microphone, or -1 for default device
    """
    import sys
    if sys.platform == "darwin":  # macOS
        import sounddevice as sd
        devices = sd.query_devices()

        # Priority search patterns for macOS built-in microphones
        search_patterns = [
            "mac",           # Generic Mac identifier
            "built-in",      # Built-in microphone
            "internal",      # Internal microphone
            "default",       # Default input
        ]

        for i, device in enumerate(devices):
            if device['max_input_channels'] > 0:  # Only input devices
                device_name_lower = device['name'].lower()
                for pattern in search_patterns:
                    if pattern in device_name_lower:
                        return i

        # If no pattern matches, try to find device with "input" in name
        for i, device in enumerate(devices):
            if device['max_input_channels'] > 0:
                if "input" in device['name'].lower():
                    return i

    # Return -1 to indicate use system default device
    return -1


class SimpleWhisper:
    """Simple Whisper application for recording and transcribing audio."""

    # Class-level model cache to share models between instances
    _model_cache = {}
    _model_cache_lock = threading.Lock() if 'threading' in sys.modules else None

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

        # Try to use mirror for model download if available
        # This can help users in regions with limited access to Hugging Face
        mirror_urls = [
            "https://hf-mirror.com",  # Hugging Face mirror
            "https://mirror.ghproxy.com/https://huggingface.co",  # GitHub proxy mirror
        ]

        # Check if HF_ENDPOINT is already set
        if "HF_ENDPOINT" not in os.environ:
            # Try each mirror in order
            for mirror_url in mirror_urls:
                try:
                    # Test the mirror by attempting a simple HEAD request (or just set it)
                    os.environ["HF_ENDPOINT"] = mirror_url
                    print(f"Using Hugging Face mirror: {mirror_url}")
                    break
                except Exception:
                    # If setting fails, try next mirror
                    continue

        # Retry configuration
        max_retries = 3
        retry_delay = 2  # seconds
        last_exception = None

        for attempt in range(1, max_retries + 1):
            try:
                if attempt > 1:
                    print(f"Retry attempt {attempt}/{max_retries}...")
                    time.sleep(retry_delay * (attempt - 1))  # Exponential backoff

                self.model = whisper.load_model(model_size, device=device)
                print(f"Model loaded successfully (running on {self.model.device}).")
                return  # Success, exit method

            except ConnectionError as e:
                # Network connection error - retryable
                last_exception = e
                print(f"Network error (attempt {attempt}/{max_retries}): {e}")
                if attempt < max_retries:
                    print(f"Retrying in {retry_delay * attempt} seconds...")
                else:
                    print(f"Error: Failed to download model '{model_size}' after {max_retries} attempts.")
                    print("Check your internet connection or try again later.")
                    print(f"Details: {e}")
                    sys.exit(1)

            except FileNotFoundError as e:
                # File not found - not retryable
                print(f"Error: Model file not found for '{model_size}'.")
                print("The model may need to be downloaded. Whisper will download it automatically on first use.")
                print(f"Details: {e}")
                sys.exit(1)

            except RuntimeError as e:
                # Runtime error - check if it's a connection issue
                if "download" in str(e).lower() or "connection" in str(e).lower():
                    # Might be a download error, retry
                    last_exception = e
                    print(f"Download error (attempt {attempt}/{max_retries}): {e}")
                    if attempt < max_retries:
                        print(f"Retrying in {retry_delay * attempt} seconds...")
                    else:
                        print(f"Error: Failed to download model '{model_size}' after {max_retries} attempts.")
                        if "CUDA" in str(e):
                            print("CUDA/GPU error. Check your CUDA installation and GPU availability.")
                        elif "MPS" in str(e):
                            print("MPS (Apple Silicon) error. Check your PyTorch MPS support.")
                        print(f"Details: {e}")
                        sys.exit(1)
                else:
                    # Other runtime error - not retryable
                    print(f"Error: Runtime error loading model '{model_size}'.")
                    if "CUDA" in str(e):
                        print("CUDA/GPU error. Check your CUDA installation and GPU availability.")
                    elif "MPS" in str(e):
                        print("MPS (Apple Silicon) error. Check your PyTorch MPS support.")
                    print(f"Details: {e}")
                    sys.exit(1)

            except ValueError as e:
                # Invalid parameter - not retryable
                print(f"Error: Invalid parameter for model loading.")
                print(f"Model size: '{model_size}', Device: '{device}'")
                print(f"Valid model sizes: tiny, base, small, medium, large")
                print(f"Details: {e}")
                sys.exit(1)

            except ImportError as e:
                # Missing library - not retryable
                print(f"Error: Required library not found.")
                print("Make sure OpenAI Whisper is installed: pip install openai-whisper")
                print(f"Details: {e}")
                sys.exit(1)

            except Exception as e:
                # Other errors - retryable for network/download issues
                error_str = str(e).lower()
                if any(keyword in error_str for keyword in ['connection', 'download', 'network', 'timeout', 'ssl']):
                    last_exception = e
                    print(f"Network/download error (attempt {attempt}/{max_retries}): {e}")
                    if attempt < max_retries:
                        print(f"Retrying in {retry_delay * attempt} seconds...")
                    else:
                        print(f"Error: Failed to load model '{model_size}' after {max_retries} attempts.")
                        print("Please check your installation and try again.")
                        print(f"Details: {e}")
                        sys.exit(1)
                else:
                    # Non-retryable error
                    print(f"Unexpected error loading model '{model_size}': {e}")
                    print("Please check your installation and try again.")
                    sys.exit(1)

        # If we get here, all retries failed
        if last_exception:
            print(f"Error: Failed to load model '{model_size}' after {max_retries} attempts.")
            print(f"Last error: {last_exception}")
            sys.exit(1)
        else:
            print(f"Error: Failed to load model '{model_size}' for unknown reason.")
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

        except sd.PortAudioError as e:
            print(f"Error: Audio device error during recording.")
            print("Check if your microphone is connected and accessible.")
            print(f"Device ID: {device_id}, Validated ID: {valid_device_id}")
            print(f"Details: {e}")
            return None
        except FileNotFoundError as e:
            print(f"Error: Output directory not found: {output_path}")
            print("Make sure the directory exists or provide a different path.")
            print(f"Details: {e}")
            return None
        except PermissionError as e:
            print(f"Error: Permission denied when saving audio file.")
            print(f"Cannot write to: {output_path}")
            print("Check file permissions or choose a different location.")
            print(f"Details: {e}")
            return None
        except ValueError as e:
            print(f"Error: Invalid parameter for recording.")
            print(f"Duration: {duration}, Sample rate: {self.sample_rate}")
            print("Check recording parameters.")
            print(f"Details: {e}")
            return None
        except OSError as e:
            print(f"Error: System error during recording.")
            print("Check audio system configuration.")
            print(f"Details: {e}")
            return None
        except Exception as e:
            print(f"Unexpected error during recording: {e}")
            print("Please check your audio configuration and try again.")
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

        except FileNotFoundError as e:
            print(f"Error: Audio file not found during transcription.")
            print(f"File: {audio_path}")
            print("Make sure the file exists and is accessible.")
            print(f"Details: {e}")
            return None
        except RuntimeError as e:
            print(f"Error: Runtime error during transcription.")
            if "CUDA" in str(e) or "GPU" in str(e):
                print("GPU/CUDA error. Check your CUDA installation and GPU memory.")
            elif "MPS" in str(e):
                print("MPS (Apple Silicon) error. Check your PyTorch MPS support.")
            elif "memory" in str(e).lower():
                print("Memory error. Try using a smaller model or closing other applications.")
            print(f"Details: {e}")
            return None
        except ValueError as e:
            print(f"Error: Invalid parameter or audio format.")
            print(f"Audio file: {audio_path}, Language: {language}")
            print("Check audio format (should be WAV, MP3, etc. supported by Whisper).")
            print(f"Details: {e}")
            return None
        except OSError as e:
            print(f"Error: System error reading audio file.")
            print(f"File: {audio_path}")
            print("Check file permissions and format.")
            print(f"Details: {e}")
            return None
        except MemoryError as e:
            print(f"Error: Insufficient memory for transcription.")
            print("Try using a smaller model (tiny or base) or close other applications.")
            print(f"Details: {e}")
            return None
        except Exception as e:
            print(f"Unexpected error during transcription: {e}")
            print("Please check the audio file and try again.")
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

        except FileNotFoundError as e:
            print(f"Error: Output directory not found: {output_path}")
            print("Make sure the directory exists or provide a different path.")
            print(f"Details: {e}")
            return None
        except PermissionError as e:
            print(f"Error: Permission denied when saving transcription.")
            print(f"Cannot write to: {output_path}")
            print("Check file permissions or choose a different location.")
            print(f"Details: {e}")
            return None
        except IsADirectoryError as e:
            print(f"Error: Output path is a directory, not a file: {output_path}")
            print("Provide a full file path including filename.")
            print(f"Details: {e}")
            return None
        except UnicodeEncodeError as e:
            print(f"Error: Encoding error when saving transcription.")
            print("The text contains characters that cannot be encoded in UTF-8.")
            print(f"Details: {e}")
            return None
        except OSError as e:
            print(f"Error: System error saving transcription file.")
            print(f"File: {output_path}")
            print("Check disk space and file system permissions.")
            print(f"Details: {e}")
            return None
        except Exception as e:
            print(f"Unexpected error saving transcription: {e}")
            print("Please check the output path and try again.")
            return None

    def unload_model(self):
        """
        Unload the Whisper model to free up memory.

        This method releases the model from memory. Useful when the model is no longer needed
        or when switching between different models.
        """
        if hasattr(self, 'model') and self.model is not None:
            # Move model to CPU first to release GPU memory
            try:
                if str(self.model.device) != 'cpu':
                    self.model.to('cpu')
            except Exception as e:
                print(f"Warning: Error moving model to CPU: {e}")

            # Delete model reference
            del self.model
            self.model = None

            # Force garbage collection
            import gc
            gc.collect()

            print(f"Model '{self.model_size}' unloaded from memory.")
        else:
            print("No model loaded to unload.")

    def __del__(self):
        """Destructor to ensure model is unloaded when object is deleted."""
        try:
            self.unload_model()
        except Exception:
            # Ignore errors during destruction
            pass

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
    parser.add_argument("--chunk-duration", type=float, default=2.0,
                       help="Chunk duration in seconds for streaming (default: 2.0)")
    parser.add_argument("--overlap", type=float, default=0.5,
                       help="Overlap between chunks in seconds for streaming (default: 0.5)")
    parser.add_argument("--no-vad", action="store_true",
                       help="Disable Voice Activity Detection for streaming (use fixed chunks)")
    parser.add_argument("--vad-aggressiveness", type=int, default=2, choices=[0, 1, 2, 3],
                       help="VAD aggressiveness for streaming (0=least, 3=most aggressive, default: 2)")
    parser.add_argument("--silence-duration-ms", type=int, default=150,
                       help="Minimum silence duration to end a sentence in milliseconds (default: 150)")
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
        try:
            from streaming.stream_whisper import StreamWhisper
        except Exception as e:
            print("Error: Streaming module not available.")
            print(f"Failed to import stream_whisper: {e}")
            print("Make sure stream_whisper.py is in the src/streaming directory.")
            print("If missing webrtcvad, install with: pip install webrtcvad")
            return

        print("\n" + "="*50)
        print("STREAMING MODE - Real-time Transcription")
        print("="*50)

        # Initialize StreamWhisper
        streamer = StreamWhisper(
            model_size=args.model,
            device=args.device,
            chunk_duration=args.chunk_duration,
            overlap=args.overlap,
            output_audio=args.output_audio,
            use_vad=not args.no_vad,
            vad_aggressiveness=args.vad_aggressiveness,
            silence_duration_ms=args.silence_duration_ms,
            language=args.language,
            simplified_chinese=args.simplified_chinese
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
            # Get transcription context before stopping streaming
            transcription_context = []
            if hasattr(streamer, 'get_transcription_context'):
                transcription_context = streamer.get_transcription_context()

            streamer.stop_streaming()

            # Get full transcription with timestamps for display and saving
            full_text = streamer.get_full_transcription(with_timestamps=True, start_time=start_time)
            print("\nFull transcription:")
            print(full_text)

            # Save transcription if output text path is provided
            if args.output_text:
                # Create segments from transcription context
                segments = []
                for i, item in enumerate(transcription_context):
                    if item.get("text"):
                        timestamp = item.get("timestamp")
                        if timestamp:
                            start = timestamp - start_time
                            # Assume each chunk is about chunk_duration seconds
                            end = start + args.chunk_duration
                        else:
                            # Fallback: estimate based on index
                            start = i * (args.chunk_duration - args.overlap)
                            end = start + args.chunk_duration

                        segments.append({
                            "start": start,
                            "end": end,
                            "text": item["text"]
                        })

                result = {
                    "text": full_text,  # This includes timestamps
                    "segments": segments,
                    "language": getattr(streamer, 'language', 'unknown'),
                    "simplified_chinese": args.simplified_chinese
                }
                saved_path = streamer.save_transcription(result, output_path=args.output_text)
                if saved_path:
                    print(f"\nTranscription saved to: {saved_path}")

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