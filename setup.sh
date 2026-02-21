#!/bin/bash
# Setup script for Simple Whisper Application

set -e

echo "Setting up Simple Whisper Application..."

# Check Python version
echo "Checking Python version..."
python --version

# Create virtual environment
echo "Creating virtual environment..."
python -m venv venv

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt

echo ""
echo "Setup complete!"
echo ""
echo "To use the application:"
echo "1. Activate virtual environment: source venv/bin/activate"
echo "2. Run the application: python simple_whisper.py --help"
echo ""
echo "Quick test:"
echo "  python simple_whisper.py --record --duration 5 --model tiny"