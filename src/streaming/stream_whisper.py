#!/usr/bin/env python3
"""
Stream Whisper Application
Streaming audio transcription with real-time processing.

Extends SimpleWhisper to add streaming capabilities with chunked processing.
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import time
import threading
import queue
import numpy as np
import sounddevice as sd
import whisper
from typing import Optional, Dict, List, Tuple
from core.simple_whisper import SimpleWhisper


class StreamWhisper(SimpleWhisper):
    """Streaming Whisper for real-time audio transcription."""

    def __init__(self, model_size="base", device=None, sample_rate=16000,
                 chunk_duration=3.0, overlap=1.0):
        """
        Initialize the streaming Whisper model.

        Args:
            model_size (str): Whisper model size (tiny, base, small, medium, large)
            device: Device to run model on (None for auto-detection)
            sample_rate (int): Sample rate for audio recording
            chunk_duration (float): Duration of each audio chunk in seconds
            overlap (float): Overlap between consecutive chunks in seconds
        """
        super().__init__(model_size, device, sample_rate)

        self.chunk_duration = chunk_duration
        self.overlap = overlap

        # Streaming state
        self.is_streaming = False
        self.audio_queue = queue.Queue(maxsize=10)
        self.result_queue = queue.Queue()
        self.audio_buffer = []
        self.samples_per_chunk = int(chunk_duration * sample_rate)
        self.samples_overlap = int(overlap * sample_rate)

        # Transcription context
        self.transcription_context = []
        self.last_chunk_text = ""
        self.language = None

        # Threads
        self.audio_thread = None
        self.processing_thread = None

        print(f"StreamWhisper initialized: {chunk_duration}s chunks, {overlap}s overlap")

    def _audio_callback(self, indata, frames, time_info, status):
        """Callback for audio stream."""
        if status:
            print(f"Audio stream warning: {status}")

        # Add to audio buffer
        self.audio_buffer.append(indata.copy())

        # Check if we have enough data for a chunk
        buffer_length = sum(len(chunk) for chunk in self.audio_buffer)
        if buffer_length >= self.samples_per_chunk:
            # Extract a chunk
            chunk_data = self._extract_chunk_from_buffer()
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

    def _extract_chunk_from_buffer(self) -> Optional[np.ndarray]:
        """Extract a chunk from the audio buffer."""
        if not self.audio_buffer:
            return None

        # Collect enough samples for a chunk
        collected = []
        remaining = self.samples_per_chunk

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
            # Not enough data for a full chunk
            # Return buffer to preserve data for next call
            self.audio_buffer = [np.concatenate(collected, axis=0)] if collected else []
            return None

        # Concatenate collected chunks
        chunk_data = np.concatenate(collected, axis=0)

        # Keep overlap in buffer for next chunk
        if self.samples_overlap > 0 and len(chunk_data) > self.samples_overlap:
            overlap_start = len(chunk_data) - self.samples_overlap
            overlap_data = chunk_data[overlap_start:].copy()
            self.audio_buffer.insert(0, overlap_data)

        return chunk_data

    def _process_audio_chunks(self):
        """Process audio chunks from queue."""
        while self.is_streaming:
            try:
                # Get audio chunk from queue
                audio_chunk = self.audio_queue.get(timeout=0.1)

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
        self.language = None

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

        print("Streaming stopped")

    def get_transcription(self, timeout: float = 0.1) -> Optional[str]:
        """
        Get latest transcription result.

        Args:
            timeout: Time to wait for result

        Returns:
            Transcription text or None if no new result
        """
        try:
            result = self.result_queue.get(timeout=timeout)
            if result and result.get("text"):
                # Add to context
                self.transcription_context.append(result)

                # Limit context size
                if len(self.transcription_context) > 50:
                    self.transcription_context = self.transcription_context[-50:]

                return result["text"]
        except queue.Empty:
            pass

        return None

    def get_full_transcription(self) -> str:
        """Get full transcription from context."""
        return " ".join([r.get("text", "") for r in self.transcription_context if r.get("text")])


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
    parser.add_argument("--chunk-duration", type=float, default=3.0,
                       help="Chunk duration in seconds")
    parser.add_argument("--overlap", type=float, default=1.0,
                       help="Overlap between chunks in seconds")
    parser.add_argument("--duration", type=float, default=30.0,
                       help="Test duration in seconds")

    args = parser.parse_args()

    print("Initializing StreamWhisper...")
    streamer = StreamWhisper(
        model_size=args.model,
        device=args.device,
        chunk_duration=args.chunk_duration,
        overlap=args.overlap
    )

    print(f"Starting streaming for {args.duration} seconds...")
    if streamer.start_streaming(device_id=args.input_device):
        try:
            start_time = time.time()
            while time.time() - start_time < args.duration:
                text = streamer.get_transcription(timeout=0.5)
                if text:
                    print(f"[{time.time() - start_time:.1f}s] {text}")

                time.sleep(0.1)

            print("\nFull transcription:")
            print(streamer.get_full_transcription())

        except KeyboardInterrupt:
            print("\nInterrupted by user")
        finally:
            streamer.stop_streaming()
    else:
        print("Failed to start streaming")


if __name__ == "__main__":
    main()