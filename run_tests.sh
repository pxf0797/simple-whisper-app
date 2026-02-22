#!/bin/bash
# Simple Whisper test runner

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Simple Whisper Test Runner ==="
echo ""

# Check if we're in a virtual environment
if [ -z "$VIRTUAL_ENV" ]; then
    echo "Warning: Not running in a virtual environment."
    echo "It's recommended to activate the project virtual environment first."
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Install test dependencies if needed
echo "Installing test dependencies..."
pip install -r requirements-test.txt > /dev/null 2>&1 || {
    echo "Failed to install test dependencies. Trying with pip3..."
    pip3 install -r requirements-test.txt
}

# Run tests
echo ""
echo "Running tests with pytest..."
echo ""

# Default pytest arguments
PYTEST_ARGS=(
    "-v"
    "--tb=short"
    "--strict-markers"
    "-m" "not integration and not slow"
)

# Add coverage if requested
if [ "$1" == "--coverage" ]; then
    PYTEST_ARGS+=("--cov=src" "--cov-report=term" "--cov-report=html")
    echo "Running with coverage..."
    echo ""
fi

# Run pytest
python -m pytest "${PYTEST_ARGS[@]}"

if [ $? -eq 0 ]; then
    echo ""
    echo "=== All tests passed! ==="
else
    echo ""
    echo "=== Some tests failed ==="
    exit 1
fi