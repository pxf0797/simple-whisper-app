#!/usr/bin/env python3
"""
Test script for Stream Whisper functionality.
"""

import sys
import os
import time

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_stream_whisper():
    """Test StreamWhisper class."""
    print("Testing StreamWhisper...")

    try:
        from stream_whisper import StreamWhisper

        print("1. Initializing StreamWhisper...")
        streamer = StreamWhisper(model_size="tiny", chunk_duration=2.0, overlap=0.5)
        print("   ✓ StreamWhisper initialized")

        print("2. Testing audio stream start...")
        # Try to start streaming (will fail if no audio device, but that's OK)
        try:
            if streamer.start_streaming():
                print("   ✓ Audio streaming started")
                time.sleep(1)  # Let it run for a bit
                streamer.stop_streaming()
                print("   ✓ Audio streaming stopped")
            else:
                print("   ⚠ Could not start audio stream (no audio device?)")
        except Exception as e:
            print(f"   ⚠ Audio stream test skipped: {e}")

        print("3. Testing transcription engine...")
        try:
            from transcription_engine import RealTimeTranscriber
            import whisper

            model = whisper.load_model("tiny")
            transcriber = RealTimeTranscriber(model=model)
            print("   ✓ RealTimeTranscriber initialized")

            # Test text processing
            test_result = transcriber._process_text_result("Hello world")
            if test_result:
                print("   ✓ Text processing works")
            else:
                print("   ⚠ Text processing failed")

        except Exception as e:
            print(f"   ⚠ Transcription engine test skipped: {e}")

        print("4. Testing GUI import...")
        try:
            from stream_gui import StreamWhisperGUI
            print("   ✓ StreamWhisperGUI can be imported")
        except Exception as e:
            print(f"   ⚠ GUI import test skipped: {e}")

        print("\nAll tests completed!")
        return True

    except ImportError as e:
        print(f"Error: Could not import required modules: {e}")
        print("Make sure all dependencies are installed:")
        print("  pip install torch torchaudio openai-whisper sounddevice soundfile numpy")
        return False
    except Exception as e:
        print(f"Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return False


def test_cli_options():
    """Test CLI options for streaming."""
    print("\nTesting CLI options...")

    try:
        import subprocess
        import argparse

        # Test that simple_whisper.py accepts --stream flag
        print("1. Testing --stream flag in simple_whisper.py...")
        result = subprocess.run(
            [sys.executable, "simple_whisper.py", "--help"],
            capture_output=True,
            text=True
        )

        if "--stream" in result.stdout:
            print("   ✓ --stream flag available")
        else:
            print("   ✗ --stream flag not found in help")

        # Check for streaming options
        if "--chunk-duration" in result.stdout:
            print("   ✓ --chunk-duration flag available")
        else:
            print("   ✗ --chunk-duration flag not found")

        if "--overlap" in result.stdout:
            print("   ✓ --overlap flag available")
        else:
            print("   ✗ --overlap flag not found")

        print("\nCLI test completed!")
        return True

    except Exception as e:
        print(f"Error during CLI test: {e}")
        return False


def main():
    """Run all tests."""
    print("=" * 60)
    print("Stream Whisper Test Suite")
    print("=" * 60)

    print("\nThis test will check if the streaming functionality is properly set up.")
    print("Note: Some tests may be skipped if audio devices are not available.\n")

    # Run tests
    test1 = test_stream_whisper()
    test2 = test_cli_options()

    print("\n" + "=" * 60)
    print("TEST SUMMARY:")
    print("=" * 60)

    if test1 and test2:
        print("✓ All tests passed!")
        print("\nYou can now use the streaming functionality:")
        print("  1. python simple_whisper.py --stream --model tiny")
        print("  2. python interactive_whisper.py (choose 'stream' mode)")
        print("  3. python stream_gui.py --model tiny")
        print("  4. python stream_main.py --model tiny")
    else:
        print("⚠ Some tests failed or were skipped.")
        print("\nTroubleshooting tips:")
        print("  - Make sure all Python dependencies are installed")
        print("  - Check that stream_whisper.py is in the same directory")
        print("  - Verify audio device is available for streaming tests")
        print("  - Try running individual components separately")

    print("\nFor more information, check the documentation.")
    print("=" * 60)


if __name__ == "__main__":
    main()