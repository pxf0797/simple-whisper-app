#!/usr/bin/env python3
"""
Configuration manager for Simple Whisper application.
Handles user preferences and configuration persistence.
"""

import os
import json
import sys
from pathlib import Path


class ConfigManager:
    """Manage application configuration and user preferences."""

    def __init__(self, config_dir=None):
        """
        Initialize configuration manager.

        Args:
            config_dir (str): Directory to store configuration files.
                              If None, uses ~/.simple-whisper
        """
        if config_dir is None:
            # Use user's home directory
            home = Path.home()
            self.config_dir = home / ".simple-whisper"
        else:
            self.config_dir = Path(config_dir)

        self.config_file = self.config_dir / "config.json"
        self.first_run_file = self.config_dir / ".first_run"

        # Ensure config directory exists
        self.config_dir.mkdir(parents=True, exist_ok=True)

        # Default configuration
        self.default_config = {
            "language": "zh",  # Default Chinese
            "audio_device": -1,  # -1 means system default
            "model": "base",
            "sample_rate": 16000,
            "output_directory": "./recordings",
            "save_audio": True,
            "save_transcription": True,
            "computation_device": None,  # Auto-detect
            "first_run_completed": False
        }

        # Load or create configuration
        self.config = self._load_config()

    def _load_config(self):
        """Load configuration from file or create default."""
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    config = json.load(f)

                # Merge with defaults to ensure all keys exist
                for key, value in self.default_config.items():
                    if key not in config:
                        config[key] = value

                return config
            except (json.JSONDecodeError, IOError) as e:
                print(f"Warning: Could not load config file: {e}")
                print("Using default configuration.")
                return self.default_config.copy()
        else:
            # Config file doesn't exist, return defaults
            return self.default_config.copy()

    def save_config(self):
        """Save current configuration to file."""
        try:
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=2, ensure_ascii=False)
            return True
        except IOError as e:
            print(f"Error saving configuration: {e}")
            return False

    def is_first_run(self):
        """
        Check if this is the first time the application is running.

        Returns:
            bool: True if first run, False otherwise
        """
        # Check if first run file exists
        if not self.first_run_file.exists():
            return True

        # Also check config flag
        return not self.config.get("first_run_completed", False)

    def mark_first_run_completed(self):
        """Mark first run as completed."""
        self.config["first_run_completed"] = True
        self.save_config()

        # Create first run file
        try:
            self.first_run_file.touch()
        except IOError:
            pass  # Ignore if we can't create the file

    def get(self, key, default=None):
        """Get configuration value."""
        return self.config.get(key, default)

    def set(self, key, value):
        """Set configuration value."""
        self.config[key] = value

    def get_language(self):
        """Get preferred language."""
        return self.config.get("language", "zh")

    def set_language(self, language):
        """Set preferred language."""
        self.config["language"] = language

    def get_audio_device(self):
        """Get preferred audio device ID."""
        return self.config.get("audio_device", -1)

    def set_audio_device(self, device_id):
        """Set preferred audio device ID."""
        self.config["audio_device"] = device_id

    def get_mac_default_microphone_id(self):
        """
        Get the default microphone ID for macOS systems.

        Returns:
            int: Device ID for macOS built-in microphone, or -1 for default device
        """
        try:
            # Import the function from simple_whisper
            from simple_whisper import get_mac_default_microphone
            return get_mac_default_microphone()
        except ImportError:
            # If function not available, return -1 (system default)
            return -1


def main():
    """Test the configuration manager."""
    config = ConfigManager()

    print("Configuration Manager Test")
    print(f"Config directory: {config.config_dir}")
    print(f"Config file: {config.config_file}")
    print(f"Is first run: {config.is_first_run()}")
    print(f"Current language: {config.get_language()}")
    print(f"Current audio device: {config.get_audio_device()}")

    # Test macOS microphone detection
    if sys.platform == "darwin":
        mac_device_id = config.get_mac_default_microphone_id()
        print(f"macOS default microphone ID: {mac_device_id}")


if __name__ == "__main__":
    main()