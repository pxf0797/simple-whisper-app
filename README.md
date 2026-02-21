# Simple Whisper Application

A comprehensive audio recording and transcription application based on OpenAI's Whisper model.

## 📋 Project Overview

Simple Whisper provides a complete speech-to-text solution with multiple interfaces and workflows:

- **Real-time audio recording and transcription**
- **Streaming audio processing** with low latency (3-5 seconds)
- **Batch file processing** for multiple audio files
- **Interactive command-line interface**
- **Graphical user interface** with always-on-top display
- **Comprehensive workflow control** through shell scripts

## 🚀 Quick Start

### 1. Installation
```bash
# Clone the repository
git clone https://github.com/pxf0797/simple-whisper-app.git
cd simple-whisper-app

# Setup environment
./setup.sh
```

### 2. Basic Usage
```bash
# Quick recording and transcription
./quick_record.sh

# Transcribe an existing audio file
./transcribe_file.sh audio_file.wav

# Start interactive mode
python interactive_whisper.py

# Use workflow controller
./workflow_controller.sh
```

## 📁 Project Structure

The project is organized into the following directories:

### Documentation
- `docs/en/` - English documentation
- `docs/zh/` - Chinese documentation
- `docs/reference/` - Reference documentation

### Scripts
- `quick_record.sh` - Quick recording with interactive parameter selection
- `record_meeting.sh` - Meeting recording optimized script
- `transcribe_file.sh` - Transcribe existing audio files
- `workflow_*.sh` - Three workflow control scripts (simple, advanced, comprehensive)
- `setup.sh`, `run.sh`, `install_stream_deps.sh` - Environment setup scripts

### Python Modules
- `simple_whisper.py` - Core recording and transcription class
- `interactive_whisper.py` - Interactive command-line interface
- `batch_transcribe.py` - Batch file processing
- `stream_whisper.py`, `transcription_engine.py` - Streaming processing
- `stream_gui.py` - Graphical user interface
- `test_stream.py` - Streaming functionality tests

### Configuration
- `config/` - Workflow and task configuration files
- `requirements.txt` - Python dependencies
- `config_example.json` - Example configuration

## 📚 Documentation

### English Documentation
- **[Main Documentation](docs/en/README.md)** - Complete project overview
- **[Streaming Features](docs/en/README_stream.md)** - Streaming processing guide
- **[Workflow Control](docs/en/README_workflow.md)** - Workflow scripts usage
- **[Advanced Workflow Manager](docs/en/README_workflow_manager.md)** - JSON-based workflow system

### Chinese Documentation (中文文档)
- **[使用指南](docs/zh/使用指南.md)** - Basic usage guide
- **[快速入门指南](docs/zh/快速入门指南.md)** - Quick start tutorial
- **[详细教学文档](docs/zh/详细教学文档.md)** - Detailed tutorial
- **[详细教学文档 V2](docs/zh/详细教学文档_v2.md)** - Updated tutorial

### Reference Documentation
- **[Project Structure](docs/reference/PROJECT_STRUCTURE.md)** - Detailed file structure
- **[File Organization](docs/reference/FILE_ORGANIZATION.md)** - File categorization and classification

## 🎯 Key Features

### Core Features
- **Audio Recording**: Real-time recording from microphone with device selection
- **Whisper Transcription**: Using OpenAI's Whisper models (tiny, base, small, medium, large)
- **Multi-language Support**: Automatic language detection or specified language
- **Device Selection**: Audio input device and computation device (CPU/MPS/CUDA) selection

### Advanced Features
- **Streaming Processing**: Real-time audio stream transcription with low latency
- **Batch Processing**: Process multiple audio files in batch
- **GUI Interface**: Always-on-top window with transparency control
- **Intelligent Text Processing**: Sentence boundary detection, overlap handling

### Workflow Management
- **Quick Record**: Interactive parameter selection (`quick_record.sh`)
- **Workflow Control**: Three levels of workflow control scripts
- **System Diagnostics**: Environment testing and validation
- **Configuration Management**: JSON-based workflow configuration

## 🛠️ Usage Examples

### Quick Recording
```bash
./quick_record.sh
# Interactive selection of model, language, duration, and devices
```

### Meeting Recording
```bash
./record_meeting.sh
# Optimized for long-duration meeting recording
```

### File Transcription
```bash
./transcribe_file.sh meeting_recording.wav
# Transcribe existing audio file
```

### Streaming Transcription
```bash
# Using workflow controller
./workflow_controller.sh --workflow 2

# Direct streaming
python stream_whisper.py --model tiny --duration 60
```

### Batch Processing
```bash
python batch_transcribe.py --input-dir audio_files --output-dir transcriptions
```

## 🔧 Script Comparison

| Script | Size | Purpose | Best For |
|--------|------|---------|----------|
| `quick_record.sh` | 13.7KB | Quick recording with interactive selection | Beginners, quick use |
| `workflow_controller.sh` | 19.9KB | Simplified workflow control | Regular users |
| `workflow_control.sh` | 28.9KB | 8-mode menu-driven system | Feature exploration |
| `workflow_manager.sh` | 32.9KB | Advanced workflow with JSON config | Complex workflows, automation |

## 📊 Model Performance

| Model | Parameters | Speed | Accuracy | Recommended Use |
|-------|------------|-------|----------|-----------------|
| `tiny` | 39M | Fastest | Lowest | Real-time streaming, quick tests |
| `base` | 74M | Fast | Good | General use, good balance |
| `small` | 244M | Medium | Better | Important recordings |
| `medium` | 769M | Slow | High | Critical applications |
| `large` | 1550M | Slowest | Highest | Research, maximum accuracy |

## 🏗️ Technical Architecture

```
Audio Input → Recording/Streaming → Whisper Model → Text Processing → Output
    │              │                    │                │
    │              ├── Batch Mode       ├── Model        ├── Sentence
    │              ├── Streaming Mode   │   Selection    │   Detection
    │              └── Interactive      └── Language     └── Overlap
    │                  Mode                Detection        Handling
    │
    └── Device Selection
        (Audio Input, CPU/MPS/CUDA)
```

## 📈 Project Status

- **Core Features**: ✅ Complete and stable
- **Streaming Features**: ✅ Complete with GUI support
- **Workflow Control**: ✅ Three-level system implemented
- **Documentation**: ✅ Comprehensive documentation in English and Chinese
- **Testing**: ✅ Basic testing implemented

## 🤝 Contributing

Contributions are welcome! Please see the [contributing guidelines](docs/en/README.md#contributing) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

- **Documentation**: Refer to the documentation in `docs/` directory
- **Issues**: Report issues on GitHub
- **Questions**: Check the example usage scripts and documentation

---

**Last Updated**: 2026-02-21
**Version**: 2.0.0 (with comprehensive workflow control system)