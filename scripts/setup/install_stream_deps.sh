#!/bin/bash
# Installation script for Stream Whisper dependencies

set -e

echo "Installing Stream Whisper dependencies..."
echo "=========================================="

# Check Python version
python_version=$(python3 --version 2>&1 | awk '{print $2}')
echo "Python version: $python_version"

# Install core dependencies
echo ""
echo "1. Installing core dependencies..."
pip install torch torchaudio openai-whisper

# Install audio dependencies
echo ""
echo "2. Installing audio dependencies..."
pip install sounddevice soundfile

# Install utility dependencies
echo ""
echo "3. Installing utility dependencies..."
pip install numpy scipy

# Optional: Chinese text conversion
echo ""
echo "4. Optional: Chinese text conversion..."
read -p "Install zhconv for Chinese text conversion? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    pip install zhconv
    echo "zhconv installed."
else
    echo "Skipping zhconv installation."
fi

# Optional: Voice Activity Detection (VAD)
echo ""
echo "5. Optional: Voice Activity Detection (VAD)..."
read -p "Install webrtcvad for sentence-based transcription? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Check Python version for compatibility
    PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
    echo "Python version: $PYTHON_VERSION"
    IS_PYTHON_312_OR_LATER=$(python3 -c "
import sys
version = sys.version_info
if version.major > 3 or (version.major == 3 and version.minor >= 12):
    print('1')
else:
    print('0')
" | tr -d '\n')

    if [ "$IS_PYTHON_312_OR_LATER" = "1" ]; then
        echo "Python 3.12+ detected. Installing setuptools<60 for compatibility..."
        if pip install 'setuptools<60'; then
            echo "✓ setuptools<60 installed"
        else
            echo "⚠ Could not install setuptools<60, trying anyway..."
        fi
    fi

    if pip install webrtcvad; then
        echo "✓ webrtcvad installed"
    else
        echo "⚠ Failed to install webrtcvad. You may need to install it manually."
        echo "  For Python 3.12+: pip install 'setuptools<60' && pip install webrtcvad"
        echo "  For older Python: pip install webrtcvad"
    fi
else
    echo "Skipping webrtcvad installation."
fi

# Verify installations
echo ""
echo "6. Verifying installations..."
python3 -c "import torch; print(f'✓ PyTorch {torch.__version__}')"
python3 -c "import whisper; print(f'✓ Whisper {whisper.__version__}')"
python3 -c "import sounddevice; print('✓ sounddevice')"
python3 -c "import soundfile; print('✓ soundfile')"
python3 -c "import numpy; print(f'✓ NumPy {numpy.__version__}')"
python3 -c "
try:
    import webrtcvad
    print('✓ webrtcvad (VAD)')
except ImportError:
    print('⚠ webrtcvad not installed (optional for sentence-based transcription)')
"

echo ""
echo "Installation completed successfully!"
echo ""
echo "To test the installation, run:"
echo "  python src/streaming/test_stream.py"
echo ""
echo "To use streaming mode:"
echo "  python src/core/simple_whisper.py --stream --model tiny"
echo "  python src/core/interactive_whisper.py"
echo "  python src/streaming/stream_gui.py --model tiny"