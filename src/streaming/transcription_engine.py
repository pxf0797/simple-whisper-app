#!/usr/bin/env python3
"""
Transcription Engine for real-time audio processing.

Provides intelligent text concatenation, overlap handling, and
sentence boundary detection for streaming transcription.
"""

import re
import time
from typing import List, Dict, Optional, Tuple
import numpy as np
import whisper


class RealTimeTranscriber:
    """Intelligent real-time transcription engine."""

    def __init__(self, model=None, language=None, max_context_words=100):
        """
        Initialize the transcription engine.

        Args:
            model: Whisper model instance (optional)
            language: Language code (optional, auto-detected if None)
            max_context_words: Maximum number of words to keep in context
        """
        self.model = model
        self.language = language
        self.max_context_words = max_context_words

        # Transcription state
        self.transcription_context = []
        self.partial_results = []
        self.last_text = ""
        self.last_words = []

        # Statistics
        self.chunks_processed = 0
        self.words_processed = 0

        # Configuration
        self.min_sentence_length = 3  # Minimum words for a sentence
        self.overlap_threshold = 0.7  # Threshold for overlap detection

        # Language-specific patterns
        self.sentence_end_patterns = {
            'en': r'[.!?]\s+',
            'zh': r'[。！？]\s*',
            'ja': r'[。！？]\s*',
            'ko': r'[.!?]\s+',
            'default': r'[.!?。！？]\s+'
        }

    def process_audio_chunk(self, audio_chunk: np.ndarray,
                           previous_context: Optional[List[str]] = None) -> Dict:
        """
        Process an audio chunk and return transcription result.

        Args:
            audio_chunk: Audio data as numpy array
            previous_context: Previous transcription context (optional)

        Returns:
            Dictionary with transcription result
        """
        if self.model is None:
            raise ValueError("Whisper model not provided")

        start_time = time.time()

        # Prepare audio for Whisper
        audio_whisper = whisper.pad_or_trim(audio_chunk.flatten())

        # Make log-Mel spectrogram
        mel = whisper.log_mel_spectrogram(audio_whisper).to(self.model.device)

        # Detect language if not specified
        if self.language is None:
            _, probs = self.model.detect_language(mel)
            detected_language = max(probs, key=probs.get)
            self.language = detected_language
            print(f"Language detected: {detected_language}")

        # Decode audio
        options = whisper.DecodingOptions(
            language=self.language,
            fp16=False,
            without_timestamps=True
        )

        result = whisper.decode(self.model, mel, options)
        processing_time = time.time() - start_time

        # Process the text
        processed_result = self._process_text_result(
            result.text,
            previous_context=previous_context,
            processing_time=processing_time
        )

        # Update statistics
        self.chunks_processed += 1
        if processed_result.get("final_text"):
            words = processed_result["final_text"].split()
            self.words_processed += len(words)

        return processed_result

    def _process_text_result(self, text: str,
                            previous_context: Optional[List[str]] = None,
                            processing_time: float = 0.0) -> Dict:
        """
        Process raw transcription text.

        Args:
            text: Raw transcription text
            previous_context: Previous context for overlap detection
            processing_time: Time taken to process the chunk

        Returns:
            Processed result dictionary
        """
        # Clean the text
        cleaned_text = self._clean_text(text)

        if not cleaned_text:
            return {
                "raw_text": text,
                "cleaned_text": "",
                "final_text": "",
                "is_new": False,
                "processing_time": processing_time
            }

        # Handle overlap with previous text
        is_new, new_text = self._handle_overlap(cleaned_text, previous_context)

        # Update context
        if new_text:
            self._update_context(new_text)

        # Check if we have a complete sentence
        is_complete_sentence = self._is_complete_sentence(new_text)

        # Get final text to output
        final_text = ""
        if is_new and new_text:
            if is_complete_sentence:
                # Output the sentence
                final_text = new_text
                self.partial_results = []  # Clear partial results
            else:
                # Add to partial results
                self.partial_results.append(new_text)

                # Check if partial results form a complete sentence
                combined = " ".join(self.partial_results)
                if self._is_complete_sentence(combined):
                    final_text = combined
                    self.partial_results = []

        return {
            "raw_text": text,
            "cleaned_text": cleaned_text,
            "final_text": final_text,
            "partial_results": self.partial_results.copy(),
            "is_new": is_new,
            "is_complete_sentence": is_complete_sentence,
            "processing_time": processing_time
        }

    def _clean_text(self, text: str) -> str:
        """Clean and normalize text."""
        if not text:
            return ""

        # Remove extra whitespace
        text = re.sub(r'\s+', ' ', text).strip()

        # Remove common transcription artifacts
        artifacts = [
            r'\[.*?\]',  # [Music], [Applause], etc.
            r'\(.*?\)',  # (background noise)
            r'\<.*?\>',  # <INAUDIBLE>
        ]

        for pattern in artifacts:
            text = re.sub(pattern, '', text)

        # Normalize punctuation
        text = re.sub(r'\.{2,}', '...', text)  # Multiple dots to ellipsis

        return text.strip()

    def _handle_overlap(self, current_text: str,
                       previous_context: Optional[List[str]] = None) -> Tuple[bool, str]:
        """
        Handle overlapping text between chunks.

        Returns:
            Tuple of (is_new_text, new_text)
        """
        if not current_text:
            return False, ""

        # Use previous context if provided, otherwise use internal context
        if previous_context is None:
            previous_context = self.transcription_context[-5:]  # Last 5 entries

        # Get previous text for comparison
        previous_text = " ".join([ctx.get("text", "") for ctx in previous_context if ctx.get("text")])

        if not previous_text:
            # No previous text, everything is new
            return True, current_text

        # Split into words for comparison
        current_words = current_text.split()
        previous_words = previous_text.split()

        if not current_words:
            return False, ""

        # Find overlap using simple prefix matching
        max_overlap = min(len(current_words), len(previous_words))
        overlap_count = 0

        # Check for overlap from the beginning
        for i in range(max_overlap):
            if current_words[i] == previous_words[-max_overlap + i]:
                overlap_count += 1
            else:
                break

        # Calculate overlap ratio
        overlap_ratio = overlap_count / len(current_words) if current_words else 0

        if overlap_ratio > self.overlap_threshold:
            # Mostly overlap, discard
            return False, ""
        elif overlap_count > 0:
            # Partial overlap, remove overlapping words
            new_words = current_words[overlap_count:]
            new_text = " ".join(new_words)
            return True, new_text
        else:
            # No significant overlap
            return True, current_text

    def _is_complete_sentence(self, text: str) -> bool:
        """Check if text appears to be a complete sentence."""
        if not text:
            return False

        words = text.split()
        if len(words) < self.min_sentence_length:
            return False

        # Get language-specific pattern
        pattern = self.sentence_end_patterns.get(
            self.language,
            self.sentence_end_patterns['default']
        )

        # Check if text ends with sentence-ending punctuation
        if re.search(pattern + '$', text):
            return True

        # Additional heuristics for different languages
        if self.language == 'zh':
            # Chinese: check for common sentence-ending words
            if text.endswith('。') or text.endswith('！') or text.endswith('？'):
                return True

        return False

    def _update_context(self, text: str):
        """Update transcription context."""
        if not text:
            return

        context_entry = {
            "text": text,
            "timestamp": time.time(),
            "word_count": len(text.split())
        }

        self.transcription_context.append(context_entry)

        # Trim context if too large
        total_words = sum(ctx["word_count"] for ctx in self.transcription_context)
        while total_words > self.max_context_words and self.transcription_context:
            removed = self.transcription_context.pop(0)
            total_words -= removed["word_count"]

        # Update last text for future overlap detection
        words = text.split()
        if words:
            # Keep last few words for overlap detection
            keep_words = min(5, len(words))
            self.last_words = words[-keep_words:]
            self.last_text = " ".join(self.last_words)

    def get_context(self, max_words: int = 50) -> List[Dict]:
        """Get recent transcription context."""
        if not self.transcription_context:
            return []

        # Collect context up to max_words
        context = []
        word_count = 0

        for entry in reversed(self.transcription_context):
            if word_count + entry["word_count"] <= max_words:
                context.insert(0, entry)  # Insert at beginning to maintain order
                word_count += entry["word_count"]
            else:
                break

        return context

    def get_full_transcription(self) -> str:
        """Get full transcription from context."""
        return " ".join([ctx["text"] for ctx in self.transcription_context])

    def reset(self):
        """Reset transcription state."""
        self.transcription_context = []
        self.partial_results = []
        self.last_text = ""
        self.last_words = []
        self.chunks_processed = 0
        self.words_processed = 0
        self.language = None

    def get_statistics(self) -> Dict:
        """Get transcription statistics."""
        return {
            "chunks_processed": self.chunks_processed,
            "words_processed": self.words_processed,
            "context_size": len(self.transcription_context),
            "partial_results_count": len(self.partial_results),
            "language": self.language
        }


# Utility functions for text processing

def find_overlap(text1: str, text2: str) -> Tuple[int, float]:
    """
    Find overlap between two texts.

    Returns:
        Tuple of (overlap_word_count, overlap_ratio)
    """
    words1 = text1.split()
    words2 = text2.split()

    if not words1 or not words2:
        return 0, 0.0

    # Find longest common suffix of words1 and prefix of words2
    max_overlap = min(len(words1), len(words2))
    overlap = 0

    for i in range(1, max_overlap + 1):
        if words1[-i:] == words2[:i]:
            overlap = i

    ratio = overlap / len(words2) if words2 else 0.0
    return overlap, ratio


def merge_texts(text1: str, text2: str, overlap: int) -> str:
    """Merge two texts given the overlap count."""
    if overlap == 0:
        return f"{text1} {text2}".strip()

    words1 = text1.split()
    words2 = text2.split()

    # Remove overlapping words from text2
    merged_words = words1 + words2[overlap:]
    return " ".join(merged_words).strip()


def detect_sentence_boundaries(text: str, language: str = 'en') -> List[Tuple[int, int]]:
    """
    Detect sentence boundaries in text.

    Returns:
        List of (start_index, end_index) for each sentence
    """
    if not text:
        return []

    # Language-specific sentence boundary patterns
    patterns = {
        'en': r'[.!?]\s+',
        'zh': r'[。！？]\s*',
        'ja': r'[。！？]\s*',
        'ko': r'[.!?]\s+',
        'default': r'[.!?。！？]\s+'
    }

    pattern = patterns.get(language, patterns['default'])
    sentences = []
    start = 0

    for match in re.finditer(pattern, text):
        end = match.end()
        sentences.append((start, end))
        start = end

    # Add last sentence if any
    if start < len(text):
        sentences.append((start, len(text)))

    return sentences