#!/usr/bin/env python3
"""
Pytest configuration file for Simple Whisper tests.
"""

import os
import sys
import tempfile
import shutil
from pathlib import Path

# Add src directory to Python path
src_dir = Path(__file__).parent.parent / "src"
sys.path.insert(0, str(src_dir))

# Test fixtures and utilities


def pytest_configure(config):
    """Configure pytest."""
    # Add custom markers
    config.addinivalue_line(
        "markers",
        "integration: mark test as integration test (requires external dependencies)"
    )
    config.addinivalue_line(
        "markers",
        "slow: mark test as slow (skip by default)"
    )
    config.addinivalue_line(
        "markers",
        "first_run: tests that simulate first-time setup"
    )


class TempConfigDir:
    """Temporary directory for configuration files."""

    def __init__(self):
        self.temp_dir = None
        self.original_env = {}

    def __enter__(self):
        """Create temporary directory."""
        self.temp_dir = tempfile.mkdtemp(prefix="simple_whisper_test_")
        # Store original environment variables
        self.original_env = {
            'HOME': os.environ.get('HOME'),
            'SIMPLE_WHISPER_CONFIG_DIR': os.environ.get('SIMPLE_WHISPER_CONFIG_DIR')
        }
        # Set environment to use temp directory
        os.environ['HOME'] = self.temp_dir
        os.environ['SIMPLE_WHISPER_CONFIG_DIR'] = self.temp_dir
        return Path(self.temp_dir)

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Clean up temporary directory."""
        # Restore original environment
        for key, value in self.original_env.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value
        # Remove temp directory
        if self.temp_dir and os.path.exists(self.temp_dir):
            shutil.rmtree(self.temp_dir, ignore_errors=True)