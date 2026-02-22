#!/usr/bin/env python3
"""
Stream Whisper Application
Streaming audio transcription with real-time processing.

Extends SimpleWhisper to add streaming capabilities with chunked processing.
"""

import sys
import os
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
import threading
import queue
import numpy as np
import sounddevice as sd
import soundfile as sf
import whisper

# Optional import for VAD
try:
    import webrtcvad
    HAS_WEBRTCVAD = True
except ImportError:
    webrtcvad = None
    HAS_WEBRTCVAD = False

# Optional import for zhconv (Chinese conversion)
try:
    import zhconv
    HAS_ZHCONV = True
except ImportError:
    zhconv = None
    HAS_ZHCONV = False

from typing import Optional, Dict, List, Tuple
from core.simple_whisper import SimpleWhisper


class StreamWhisper(SimpleWhisper):
    """Streaming Whisper for real-time audio transcription."""

    def __init__(self, model_size="base", device=None, sample_rate=16000,
                 chunk_duration=2.0, overlap=0.5, min_chunk_duration=1.0, output_audio=None,
                 output_text=None, use_vad=True, vad_aggressiveness=2,
                 silence_duration_ms=150, language=None, simplified_chinese=None):
        """
        Initialize the streaming Whisper model.

        Args:
            model_size (str): Whisper model size (tiny, base, small, medium, large)
            device: Device to run model on (None for auto-detection)
            sample_rate (int): Sample rate for audio recording
            chunk_duration (float): Duration of each audio chunk in seconds (used if use_vad=False)
            overlap (float): Overlap between consecutive chunks in seconds (used if use_vad=False)
            min_chunk_duration (float): Minimum chunk duration for processing (used if use_vad=False)
            output_audio (str): Path to save recorded audio
            use_vad (bool): Use Voice Activity Detection for sentence-based segmentation
            vad_aggressiveness (int): VAD aggressiveness (0-3, 3 most aggressive)
            silence_duration_ms (int): Minimum silence duration to consider as sentence end
            language (str): Language code for transcription (None for auto-detection)
            simplified_chinese (str): Convert Chinese to simplified Chinese ('yes' or 'no')
        """
        super().__init__(model_size, device, sample_rate)

        self.chunk_duration = chunk_duration
        self.overlap = overlap
        self.min_chunk_duration = min_chunk_duration
        self.use_vad = use_vad
        self.vad_aggressiveness = vad_aggressiveness
        self.silence_duration_ms = silence_duration_ms
        self.user_language = language  # Store user-specified language
        self.simplified_chinese = simplified_chinese  # Store simplified Chinese setting

        # Streaming state
        self.is_streaming = False
        self.audio_queue = queue.Queue(maxsize=10)
        self.result_queue = queue.Queue()
        self.audio_buffer = []
        self.samples_per_chunk = int(chunk_duration * sample_rate)
        self.samples_overlap = int(overlap * sample_rate)
        self.samples_per_min_chunk = int(min_chunk_duration * sample_rate)

        # VAD state (if use_vad=True)
        self.vad = None
        self.speech_buffer = []  # Buffer for current speech segment
        self.silence_frames = 0  # Count of consecutive silent frames
        # We'll use 10ms frames for faster response
        self.frame_duration_ms = 10  # Frame duration for VAD (10, 20 or 30 ms)
        self.samples_per_frame = int(sample_rate * self.frame_duration_ms / 1000)

        # Transcription context
        self.transcription_context = []
        self.last_chunk_text = ""
        self.full_transcription_text = ""
        # Initialize language: use user-specified language if provided, otherwise detect
        self.language = self.user_language

        # Threads
        self.audio_thread = None
        self.processing_thread = None

        # Audio recording
        self.output_audio = output_audio
        self.sf_file = None

        # Text output
        self.output_text = output_text
        self.text_file = None

        if use_vad:
            if not HAS_WEBRTCVAD:
                print(f"Warning: webrtcvad module not available (may be due to Python 3.12 compatibility). Cannot use VAD. Falling back to fixed chunk mode.")
                print("Note: webrtcvad may require pkg_resources which is not available. You can try: pip install 'setuptools<60'")
                self.use_vad = False
            else:
                try:
                    self.vad = webrtcvad.Vad(vad_aggressiveness)
                    print(f"StreamWhisper initialized with VAD: aggressiveness={vad_aggressiveness}, silence_threshold={silence_duration_ms}ms")
                except Exception as e:
                    print(f"Warning: Failed to initialize VAD: {e}. Falling back to fixed chunk mode.")
                    self.use_vad = False

        if not self.use_vad:
            print(f"StreamWhisper initialized: {chunk_duration}s chunks, {overlap}s overlap")

    def _audio_callback(self, indata, frames, time_info, status):
        """Callback for audio stream."""
        if status:
            print(f"Audio stream warning: {status}")

        # Write to audio file if recording
        if self.sf_file is not None:
            try:
                self.sf_file.write(indata)
            except Exception as e:
                print(f"Warning: Error writing audio data: {e}")
                self.sf_file = None

        if self.use_vad and self.vad is not None:
            # VAD-based sentence segmentation
            self._process_audio_with_vad(indata.copy())
        else:
            # Fixed chunk size mode (original behavior)
            # Add to audio buffer
            self.audio_buffer.append(indata.copy())

            # Check if we have enough data for a chunk
            buffer_length = sum(len(chunk) for chunk in self.audio_buffer)
            if buffer_length >= self.samples_per_chunk:
                # Extract a full chunk
                chunk_data = self._extract_chunk_from_buffer(target_size=self.samples_per_chunk)
                if chunk_data is not None:
                    try:
                        self.audio_queue.put(chunk_data, block=False)
                    except queue.Full:
                        # Drop oldest chunk if queue is full
                        try:
                            self.audio_queue.get_nowait()
                            self.audio_queue.put(chunk_data, block=False)
                        except queue.Empty:
                            pass
            # If we can't get a full chunk, try minimum chunk size
            elif buffer_length >= self.samples_per_min_chunk:
                # Extract a minimum chunk
                chunk_data = self._extract_chunk_from_buffer(target_size=self.samples_per_min_chunk)
                if chunk_data is not None:
                    try:
                        self.audio_queue.put(chunk_data, block=False)
                    except queue.Full:
                        # Drop oldest chunk if queue is full
                        try:
                            self.audio_queue.get_nowait()
                            self.audio_queue.put(chunk_data, block=False)
                        except queue.Empty:
                            pass

    def _process_audio_with_vad(self, audio_data: np.ndarray):
        """
        Process audio data with Voice Activity Detection.

        Args:
            audio_data: Audio data as float32 numpy array (shape: [samples] or [samples, channels])
        """
        # Ensure audio data is 1D (flatten if multi-channel)
        if audio_data.ndim > 1:
            audio_data = audio_data.flatten()

        # Convert float32 [-1.0, 1.0] to PCM16
        pcm_data = (audio_data * 32767).astype(np.int16).tobytes()

        # Process in frames (30ms each)
        bytes_per_frame = self.samples_per_frame * 2  # 2 bytes per sample (int16)

        for i in range(0, len(pcm_data), bytes_per_frame):
            frame = pcm_data[i:i+bytes_per_frame]
            if len(frame) < bytes_per_frame:
                # Incomplete frame, save for next callback
                continue

            try:
                is_speech = self.vad.is_speech(frame, self.sample_rate)
            except Exception as e:
                # VAD error, treat as non-speech
                is_speech = False

            if is_speech:
                # Add audio data corresponding to this frame to speech buffer
                frame_start = i // 2  # Convert bytes to samples
                frame_end = frame_start + self.samples_per_frame
                frame_audio = audio_data[frame_start:frame_end]
                if len(frame_audio) > 0:
                    self.speech_buffer.append(frame_audio)
                self.silence_frames = 0
            else:
                # Silent frame
                self.silence_frames += 1

                # Check if silence duration exceeds threshold
                silence_duration_ms = self.silence_frames * self.frame_duration_ms
                if silence_duration_ms >= self.silence_duration_ms:
                    # End of speech segment
                    if self.speech_buffer:
                        # Concatenate all speech frames into one chunk
                        speech_chunk = np.concatenate(self.speech_buffer, axis=0)
                        try:
                            self.audio_queue.put(speech_chunk, block=False)
                        except queue.Full:
                            # Drop oldest chunk if queue is full
                            try:
                                self.audio_queue.get_nowait()
                                self.audio_queue.put(speech_chunk, block=False)
                            except queue.Empty:
                                pass

                        # Clear speech buffer
                        self.speech_buffer = []

        # Safety check: if speech buffer gets too long (e.g., continuous speech),
        # force segmentation after maximum duration
        if self.speech_buffer:
            total_samples = sum(len(chunk) for chunk in self.speech_buffer)
            max_duration_samples = int(self.chunk_duration * self.sample_rate)
            if total_samples >= max_duration_samples:
                # Force segmentation
                speech_chunk = np.concatenate(self.speech_buffer, axis=0)
                try:
                    self.audio_queue.put(speech_chunk, block=False)
                except queue.Full:
                    try:
                        self.audio_queue.get_nowait()
                        self.audio_queue.put(speech_chunk, block=False)
                    except queue.Empty:
                        pass
                self.speech_buffer = []

    def _extract_chunk_from_buffer(self, target_size=None) -> Optional[np.ndarray]:
        """Extract a chunk from the audio buffer.

        Args:
            target_size: Target number of samples to extract. If None, uses self.samples_per_chunk.

        Returns:
            Extracted audio chunk or None if insufficient data.
        """
        if not self.audio_buffer:
            return None

        if target_size is None:
            target_size = self.samples_per_chunk

        # Collect enough samples for a chunk
        collected = []
        remaining = target_size

        while remaining > 0 and self.audio_buffer:
            chunk = self.audio_buffer[0]
            if len(chunk) <= remaining:
                # Use entire chunk
                collected.append(self.audio_buffer.pop(0))
                remaining -= len(chunk)
            else:
                # Take part of the chunk
                collected.append(chunk[:remaining])
                self.audio_buffer[0] = chunk[remaining:]
                remaining = 0

        if remaining > 0:
            # Not enough data for a chunk
            # Return buffer to preserve data for next call
            self.audio_buffer = [np.concatenate(collected, axis=0)] if collected else []
            return None

        # Concatenate collected chunks
        chunk_data = np.concatenate(collected, axis=0)

        # Keep overlap in buffer for next chunk
        # Only keep overlap for full chunks, not for minimum chunks
        if target_size == self.samples_per_chunk and self.samples_overlap > 0 and len(chunk_data) > self.samples_overlap:
            overlap_start = len(chunk_data) - self.samples_overlap
            overlap_data = chunk_data[overlap_start:].copy()
            self.audio_buffer.insert(0, overlap_data)

        return chunk_data

    def _process_audio_chunks(self):
        """Process audio chunks from queue."""
        while self.is_streaming:
            try:
                # Get audio chunk from queue
                audio_chunk = self.audio_queue.get(timeout=0.01)

                # Process chunk
                result = self._transcribe_chunk(audio_chunk)

                if result:
                    self.result_queue.put(result)

                self.audio_queue.task_done()

            except queue.Empty:
                continue
            except Exception as e:
                print(f"Error processing audio chunk: {e}")
                continue

    def _transcribe_chunk(self, audio_chunk: np.ndarray) -> Optional[Dict]:
        """
        Transcribe a single audio chunk.

        Args:
            audio_chunk: Audio data as numpy array

        Returns:
            Transcription result dictionary
        """
        try:
            # Convert to float32 if needed
            if audio_chunk.dtype != np.float32:
                audio_chunk = audio_chunk.astype(np.float32)

            # Pad or trim to 30 seconds for Whisper
            audio_whisper = whisper.pad_or_trim(audio_chunk.flatten())

            # Make log-Mel spectrogram
            mel = whisper.log_mel_spectrogram(audio_whisper).to(self.model.device)

            # Detect language if not already known
            if self.language is None:
                _, probs = self.model.detect_language(mel)
                self.language = max(probs, key=probs.get)
                print(f"Detected language: {self.language}")

            # Decode audio
            options = whisper.DecodingOptions(
                language=self.language,
                fp16=False,
                without_timestamps=True  # Faster for short chunks
            )

            result = whisper.decode(self.model, mel, options)

            # Get full transcription for the chunk
            # Note: For streaming, we use decode() for speed
            # Full transcribe() would be slower but more accurate
            chunk_result = {
                "text": result.text,
                "language": self.language,
                "timestamp": time.time()
            }

            # Process overlapping text
            chunk_result = self._handle_overlap(chunk_result)

            # Apply simplified Chinese conversion if requested
            if self.simplified_chinese == "yes" and chunk_result.get("text"):
                chunk_result = self._apply_simplified_chinese(chunk_result)

            return chunk_result

        except Exception as e:
            print(f"Error transcribing chunk: {e}")
            return None

    def _handle_overlap(self, chunk_result: Dict) -> Dict:
        """Handle overlapping text between chunks."""
        current_text = chunk_result["text"].strip()

        if not current_text:
            chunk_result["text"] = ""
            return chunk_result

        # Simple overlap handling: remove duplicate prefix
        if self.last_chunk_text and current_text.startswith(self.last_chunk_text):
            # Current text starts with last chunk's text (overlap)
            # Remove the overlapping prefix
            overlap_len = len(self.last_chunk_text)
            if len(current_text) > overlap_len:
                new_text = current_text[overlap_len:].strip()
                chunk_result["text"] = new_text
            else:
                # Entire chunk is overlap, discard
                chunk_result["text"] = ""

        # Update last chunk text for next comparison
        # Keep the end of current text for overlap detection
        # We'll keep last few words for overlap comparison
        words = current_text.split()
        if len(words) > 3:
            self.last_chunk_text = " ".join(words[-3:])  # Last 3 words
        else:
            self.last_chunk_text = current_text

        return chunk_result

    def _apply_simplified_chinese(self, chunk_result: Dict) -> Dict:
        """
        Convert Chinese text in chunk_result to simplified Chinese.

        Args:
            chunk_result: Transcription result dictionary

        Returns:
            Updated chunk_result with converted text
        """
        text = chunk_result.get("text", "")
        if not text:
            return chunk_result

        # Check if text contains Chinese characters
        import re
        has_chinese = re.search(r'[\u4e00-\u9fff]', text)

        if not has_chinese:
            return chunk_result

        # Use global zhconv if available
        if not HAS_ZHCONV:
            # Only warn once per session
            if not getattr(self, '_zhconv_warned', False):
                print("Warning: zhconv library not available. Cannot convert to simplified Chinese.")
                print("Install with: pip install zhconv")
                self._zhconv_warned = True
            return chunk_result

        try:
            converted_text = zhconv.convert(text, 'zh-cn')
            chunk_result["text"] = converted_text
            # Print conversion message only once
            if not getattr(self, '_conversion_reported', False):
                print("Converted Chinese text to simplified Chinese")
                self._conversion_reported = True
        except Exception as conv_e:
            print(f"Warning: Error converting to simplified Chinese: {conv_e}")

        return chunk_result

    def start_streaming(self, device_id=None):
        """
        Start streaming audio transcription.

        Args:
            device_id: Audio input device ID

        Returns:
            True if streaming started successfully
        """
        if self.is_streaming:
            print("Already streaming")
            return False

        # Validate device ID
        valid_device_id = self._validate_device_id(device_id)

        # Reset state
        self.is_streaming = True
        self.audio_buffer = []
        self.transcription_context = []
        self.last_chunk_text = ""
        self.language = self.user_language  # Use user-specified language if provided

        # Reset VAD state
        self.speech_buffer = []
        self.silence_frames = 0

        # Clear queues
        while not self.audio_queue.empty():
            try:
                self.audio_queue.get_nowait()
                self.audio_queue.task_done()
            except queue.Empty:
                break

        while not self.result_queue.empty():
            try:
                self.result_queue.get_nowait()
            except queue.Empty:
                break

        try:
            # Start audio stream
            self.stream = sd.InputStream(
                samplerate=self.sample_rate,
                channels=1,
                dtype='float32',
                callback=self._audio_callback,
                device=valid_device_id
            )

            # Open audio file for recording if output_audio is specified
            if self.output_audio:
                try:
                    self.sf_file = sf.SoundFile(self.output_audio, mode='w', samplerate=self.sample_rate, channels=1, subtype='PCM_16')
                    print(f"Audio recording to: {self.output_audio}")
                except Exception as e:
                    print(f"Warning: Could not open audio file for recording: {e}")
                    self.sf_file = None

            # Open text file for transcription if output_text is specified
            if self.output_text:
                try:
                    self.text_file = open(self.output_text, 'w', encoding='utf-8')
                    print(f"Transcription saving to: {self.output_text}")
                except Exception as e:
                    print(f"Warning: Could not open text file for writing: {e}")
                    self.text_file = None

            self.stream.start()
            print(f"Audio streaming started on device {valid_device_id or 'default'}")

            # Start processing thread
            self.processing_thread = threading.Thread(
                target=self._process_audio_chunks,
                daemon=True
            )
            self.processing_thread.start()

            return True

        except Exception as e:
            print(f"Error starting audio stream: {e}")
            self.is_streaming = False
            return False

    def stop_streaming(self):
        """Stop streaming audio transcription."""
        if not self.is_streaming:
            return

        self.is_streaming = False

        # Process any remaining speech in buffer before stopping
        if self.use_vad and self.vad is not None and self.speech_buffer:
            try:
                speech_chunk = np.concatenate(self.speech_buffer, axis=0)
                self.audio_queue.put(speech_chunk, block=False)
                print(f"Processed final speech segment ({len(speech_chunk)/self.sample_rate:.2f}s)")
            except Exception as e:
                print(f"Warning: Could not process final speech segment: {e}")
            finally:
                self.speech_buffer = []

        # Stop audio stream
        if hasattr(self, 'stream'):
            try:
                self.stream.stop()
                self.stream.close()
                print("Audio stream stopped")
            except Exception as e:
                print(f"Error stopping audio stream: {e}")

        # Wait for processing thread
        if self.processing_thread and self.processing_thread.is_alive():
            self.processing_thread.join(timeout=2.0)

        # Clear queues
        while not self.audio_queue.empty():
            try:
                self.audio_queue.get_nowait()
                self.audio_queue.task_done()
            except queue.Empty:
                break

        # Close audio file if recording
        if self.sf_file is not None:
            try:
                self.sf_file.close()
                print(f"Audio recording saved to: {self.output_audio}")
            except Exception as e:
                print(f"Warning: Error closing audio file: {e}")
            finally:
                self.sf_file = None

        # Close text file if writing
        if self.text_file is not None:
            try:
                # Save full transcription summary if we have content
                if self.full_transcription_text.strip():
                    # Write a separator and the complete transcription
                    self.text_file.write("\n" + "="*60 + "\n")
                    self.text_file.write("COMPLETE TRANSCRIPTION:\n")
                    self.text_file.write("="*60 + "\n")
                    self.text_file.write(self.full_transcription_text.strip() + "\n")

                self.text_file.close()
                print(f"Transcription saved to: {self.output_text}")
            except Exception as e:
                print(f"Warning: Error closing text file: {e}")
            finally:
                self.text_file = None

        print("Streaming stopped")

    def get_transcription(self, timeout: float = 0.1, start_time: float = None) -> Optional[str]:
        """
        Get latest transcription result.

        Args:
            timeout: Time to wait for result
            start_time: Optional start time for timestamping

        Returns:
            Transcription text or None if no new result
        """
        try:
            result = self.result_queue.get(timeout=timeout)
            if result and result.get("text"):
                text = result["text"]
                # Add to context
                self.transcription_context.append(result)

                # Limit context size
                if len(self.transcription_context) > 50:
                    self.transcription_context = self.transcription_context[-50:]

                # Add to full transcription text
                if text:
                    self.full_transcription_text += text + " "

                # Write to text file if available
                if self.text_file is not None and text:
                    try:
                        timestamp = result.get("timestamp")
                        if timestamp is not None and start_time is not None:
                            rel_time = timestamp - start_time
                            self.text_file.write(f"[{rel_time:.1f}s] {text}\n")
                        else:
                            self.text_file.write(f"{text}\n")
                        self.text_file.flush()
                    except Exception as e:
                        print(f"Warning: Error writing to text file: {e}")

                return text
        except queue.Empty:
            pass

        return None

    def get_full_transcription(self, with_timestamps: bool = False, start_time: float = None) -> str:
        """
        Get full transcription from context.

        Args:
            with_timestamps: If True, include timestamps in output
            start_time: Reference start time for relative timestamps (required if with_timestamps=True)

        Returns:
            Transcription text
        """
        if with_timestamps and start_time is not None:
            lines = []
            for result in self.transcription_context:
                if result.get("text"):
                    timestamp = result.get("timestamp")
                    if timestamp:
                        rel_time = timestamp - start_time
                        lines.append(f"[{rel_time:.1f}s] {result['text']}")
                    else:
                        lines.append(result['text'])
            return "\n".join(lines)
        else:
            return " ".join([r.get("text", "") for r in self.transcription_context if r.get("text")])

    def get_transcription_context(self) -> list:
        """Get the full transcription context with timestamps."""
        return self.transcription_context

    def __del__(self):
        """Destructor to ensure resources are cleaned up."""
        try:
            # Call parent's destructor if it exists
            super().__del__()
        except AttributeError:
            # SimpleWhisper may not have __del__ method
            pass

        # Ensure streaming is stopped
        if getattr(self, 'is_streaming', False):
            try:
                self.stop_streaming()
            except Exception:
                # Ignore errors during destruction
                pass

        # Close file handles if they're still open
        if hasattr(self, 'sf_file') and self.sf_file is not None:
            try:
                self.sf_file.close()
            except Exception:
                pass
            self.sf_file = None

        if hasattr(self, 'text_file') and self.text_file is not None:
            try:
                self.text_file.close()
            except Exception:
                pass
            self.text_file = None


def main():
    """Test function for StreamWhisper."""
    import argparse

    parser = argparse.ArgumentParser(description="Stream Whisper Test")
    parser.add_argument("--model", default="tiny",
                       choices=["tiny", "base", "small", "medium", "large"],
                       help="Whisper model size")
    parser.add_argument("--device", type=str,
                       help="Computation device (cpu, cuda, mps)")
    parser.add_argument("--input-device", type=int,
                       help="Audio input device ID")
    parser.add_argument("--chunk-duration", type=float, default=2.0,
                       help="Chunk duration in seconds")
    parser.add_argument("--overlap", type=float, default=0.5,
                       help="Overlap between chunks in seconds")
    parser.add_argument("--min-chunk-duration", type=float, default=1.0,
                       help="Minimum chunk duration for processing (seconds)")
    parser.add_argument("--duration", type=float, default=30.0,
                       help="Test duration in seconds")
    parser.add_argument("--no-vad", action="store_true",
                       help="Disable Voice Activity Detection (use fixed chunks)")
    parser.add_argument("--vad-aggressiveness", type=int, default=3, choices=[0, 1, 2, 3],
                       help="VAD aggressiveness (0=least, 3=most aggressive)")
    parser.add_argument("--silence-duration-ms", type=int, default=150,
                       help="Minimum silence duration to end a sentence (milliseconds)")
    parser.add_argument("--language", type=str,
                       help="Language code for transcription (e.g., 'en', 'zh'). Auto-detected if not specified.")
    parser.add_argument("--simplified-chinese", type=str, choices=["yes", "no"],
                       help="Convert Chinese text to simplified Chinese (yes/no).")
    parser.add_argument("--output-audio", type=str,
                       help="Path to save recorded audio file")
    parser.add_argument("--output-text", type=str,
                       help="Path to save transcription text file")

    args = parser.parse_args()

    print("Initializing StreamWhisper...")
    streamer = StreamWhisper(
        model_size=args.model,
        device=args.device,
        chunk_duration=args.chunk_duration,
        overlap=args.overlap,
        min_chunk_duration=args.min_chunk_duration,
        output_audio=args.output_audio,
        output_text=args.output_text,
        use_vad=not args.no_vad,
        vad_aggressiveness=args.vad_aggressiveness,
        silence_duration_ms=args.silence_duration_ms,
        language=args.language,
        simplified_chinese=args.simplified_chinese
    )

    # Determine if we're running with a time limit
    if args.duration > 0:
        print(f"Starting streaming for {args.duration} seconds...")
    else:
        print("Starting streaming (no time limit, press Ctrl+C to stop)...")

    if streamer.start_streaming(device_id=args.input_device):
        try:
            start_time = time.time()
            if args.duration > 0:
                # Run with time limit
                while time.time() - start_time < args.duration:
                    text = streamer.get_transcription(timeout=0.1, start_time=start_time)
                    if text:
                        print(f"[{time.time() - start_time:.1f}s] {text}")

                    time.sleep(0.1)

                print("\nFull transcription:")
                print(streamer.get_full_transcription())
            else:
                # Run indefinitely until interrupted
                while True:
                    text = streamer.get_transcription(timeout=0.1, start_time=start_time)
                    if text:
                        print(f"[{time.time() - start_time:.1f}s] {text}")

                    time.sleep(0.1)

        except KeyboardInterrupt:
            print("\nInterrupted by user")
        finally:
            streamer.stop_streaming()
    else:
        print("Failed to start streaming")


if __name__ == "__main__":
    main()