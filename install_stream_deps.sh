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

# Verify installations
echo ""
echo "5. Verifying installations..."
python3 -c "import torch; print(f'✓ PyTorch {torch.__version__}')"
python3 -c "import whisper; print(f'✓ Whisper {whisper.__version__}')"
python3 -c "import sounddevice; print('✓ sounddevice')"
python3 -c "import soundfile; print('✓ soundfile')"
python3 -c "import numpy; print(f'✓ NumPy {numpy.__version__}')"

echo ""
echo "Installation completed successfully!"
echo ""
echo "To test the installation, run:"
echo "  python test_stream.py"
echo ""
echo "To use streaming mode:"
echo "  python simple_whisper.py --stream --model tiny"
echo "  python interactive_whisper.py"
echo "  python stream_gui.py --model tiny"