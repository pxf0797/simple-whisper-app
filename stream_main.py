#!/usr/bin/env python3
"""
Stream Whisper Main Controller.

Coordinates audio streaming, transcription engine, and GUI components
for real-time transcription application.
"""

import sys
import os
import time
import threading
import queue
from typing import Optional, Dict, Any
import signal
import numpy as np

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from stream_whisper import StreamWhisper
    from transcription_engine import RealTimeTranscriber
    import whisper
    HAS_DEPS = True
except ImportError as e:
    print(f"Warning: Missing dependencies: {e}")
    HAS_DEPS = False
    StreamWhisper = None
    RealTimeTranscriber = None
    whisper = None


class StreamWhisperApp:
    """Main controller for streaming transcription application."""

    def __init__(self, model_size: str = "tiny", device_id: Optional[int] = None,
                 chunk_duration: float = 3.0, overlap: float = 1.0,
                 use_gui: bool = True, language: Optional[str] = None):
        """
        Initialize the streaming application.

        Args:
            model_size: Whisper model size
            device_id: Audio input device ID
            chunk_duration: Chunk duration in seconds
            overlap: Overlap between chunks in seconds
            use_gui: Whether to use GUI interface
            language: Language code for transcription
        """
        self.model_size = model_size
        self.device_id = device_id
        self.chunk_duration = chunk_duration
        self.overlap = overlap
        self.use_gui = use_gui
        self.language = language

        # Components
        self.streamer = None
        self.transcriber = None
        self.gui = None

        # State
        self.is_running = False
        self.is_paused = False

        # Queues for communication
        self.text_queue = queue.Queue()
        self.control_queue = queue.Queue()

        # Statistics
        self.start_time = None
        self.words_transcribed = 0

        # Signal handling
        signal.signal(signal.SIGINT, self._signal_handler)

    def initialize(self) -> bool:
        """Initialize all components."""
        if not HAS_DEPS:
            print("Error: Required dependencies not available")
            return False

        try:
            print("初始化流式转录应用...")
            print(f"配置: 模型={self.model_size}, 分块={self.chunk_duration}s, 重叠={self.overlap}s")

            # Initialize Whisper model
            print(f"加载 Whisper 模型 '{self.model_size}'...")
            model = whisper.load_model(self.model_size)
            print(f"模型加载完成 (设备: {model.device})")

            # Initialize streamer
            self.streamer = StreamWhisper(
                model_size=self.model_size,
                chunk_duration=self.chunk_duration,
                overlap=self.overlap
            )

            # Initialize transcription engine
            self.transcriber = RealTimeTranscriber(
                model=model,
                language=self.language
            )

            # Initialize GUI if requested
            if self.use_gui:
                try:
                    from stream_gui import StreamWhisperGUI
                    self.gui = StreamWhisperGUI(
                        model_size=self.model_size,
                        device_id=self.device_id,
                        chunk_duration=self.chunk_duration,
                        overlap=self.overlap
                    )
                    print("GUI 初始化完成")
                except ImportError as e:
                    print(f"警告: 无法初始化 GUI: {e}")
                    print("回退到控制台模式")
                    self.use_gui = False

            print("初始化完成")
            return True

        except Exception as e:
            print(f"初始化错误: {e}")
            import traceback
            traceback.print_exc()
            return False

    def start(self) -> bool:
        """Start the streaming application."""
        if self.is_running:
            print("应用已在运行中")
            return False

        if not self.initialize():
            return False

        try:
            self.is_running = True
            self.is_paused = False
            self.start_time = time.time()
            self.words_transcribed = 0

            # Start audio streaming
            print("启动音频流...")
            if not self.streamer.start_streaming(device_id=self.device_id):
                print("错误: 无法启动音频流")
                self.is_running = False
                return False

            # Start processing thread
            self.processing_thread = threading.Thread(
                target=self._processing_loop,
                daemon=True
            )
            self.processing_thread.start()

            # Start GUI if available
            if self.gui:
                print("启动 GUI...")
                # We need to run GUI in main thread
                # For now, we'll handle this differently
                return self._run_with_gui()
            else:
                print("流式转录已开始 (控制台模式)")
                print("按 Ctrl+C 停止")
                self._run_console()
                return True

        except Exception as e:
            print(f"启动错误: {e}")
            self.is_running = False
            return False

    def _run_with_gui(self) -> bool:
        """Run application with GUI."""
        # In this simplified version, we let GUI handle everything
        # The GUI already has its own StreamWhisper integration
        print("注意: 使用独立 GUI 模式")
        print("请直接运行 stream_gui.py 以使用 GUI")
        return False

    def _run_console(self):
        """Run application in console mode."""
        try:
            last_update = time.time()
            update_interval = 0.5  # seconds

            while self.is_running:
                current_time = time.time()

                # Process control commands
                self._process_control_queue()

                # Get new transcription
                if not self.is_paused:
                    text = self.streamer.get_transcription(timeout=0.1)
                    if text and text.strip():
                        # Process through transcription engine
                        result = self.transcriber.process_audio_chunk(
                            audio_chunk=np.zeros(1),  # Placeholder
                            previous_context=None
                        )
                        # For now, just print the text
                        print(f"转录: {text}")

                        # Update statistics
                        self.words_transcribed += len(text.split())

                # Print statistics periodically
                if current_time - last_update >= update_interval:
                    self._print_statistics()
                    last_update = current_time

                time.sleep(0.05)

        except KeyboardInterrupt:
            print("\n用户中断")
        except Exception as e:
            print(f"运行错误: {e}")
        finally:
            self.stop()

    def _processing_loop(self):
        """Main processing loop (run in separate thread)."""
        while self.is_running:
            try:
                # Get audio chunk from streamer
                # This is a simplified version - actual implementation
                # would get chunks from streamer's internal queue
                time.sleep(0.1)
            except Exception as e:
                print(f"处理循环错误: {e}")
                break

    def _process_control_queue(self):
        """Process control commands from queue."""
        try:
            while not self.control_queue.empty():
                command = self.control_queue.get_nowait()
                self._handle_command(command)
                self.control_queue.task_done()
        except queue.Empty:
            pass

    def _handle_command(self, command: Dict[str, Any]):
        """Handle control command."""
        cmd = command.get("command")

        if cmd == "pause":
            self.is_paused = True
            print("已暂停")
        elif cmd == "resume":
            self.is_paused = False
            print("已继续")
        elif cmd == "stop":
            self.is_running = False
            print("正在停止...")

    def _print_statistics(self):
        """Print current statistics."""
        if not self.start_time:
            return

        elapsed = time.time() - self.start_time
        words_per_minute = (self.words_transcribed / elapsed * 60) if elapsed > 0 else 0

        stats = self.transcriber.get_statistics() if self.transcriber else {}

        print(f"\r时间: {elapsed:.1f}s | 字数: {self.words_transcribed} | "
              f"速度: {words_per_minute:.1f} 字/分钟 | "
              f"语言: {stats.get('language', '未知')}", end="")

    def pause(self):
        """Pause transcription."""
        if self.is_running and not self.is_paused:
            self.is_paused = True
            self.control_queue.put({"command": "pause"})

    def resume(self):
        """Resume transcription."""
        if self.is_running and self.is_paused:
            self.is_paused = False
            self.control_queue.put({"command": "resume"})

    def stop(self):
        """Stop the application."""
        if not self.is_running:
            return

        print("\n正在停止应用...")

        self.is_running = False

        # Stop streamer
        if self.streamer:
            self.streamer.stop_streaming()

        # Wait for processing thread
        if hasattr(self, 'processing_thread') and self.processing_thread.is_alive():
            self.processing_thread.join(timeout=2.0)

        # Print final statistics
        if self.start_time:
            elapsed = time.time() - self.start_time
            print(f"\n最终统计:")
            print(f"  总时间: {elapsed:.1f} 秒")
            print(f"  总字数: {self.words_transcribed}")
            if elapsed > 0:
                print(f"  平均速度: {self.words_transcribed / elapsed * 60:.1f} 字/分钟")

        # Get final transcription
        if self.transcriber:
            final_text = self.transcriber.get_full_transcription()
            if final_text:
                print(f"\n完整转录:\n{final_text}")

        print("应用已停止")

    def _signal_handler(self, signum, frame):
        """Handle interrupt signals."""
        print(f"\n收到信号 {signum}, 正在停止...")
        self.stop()
        sys.exit(0)

    def get_status(self) -> Dict[str, Any]:
        """Get current application status."""
        return {
            "running": self.is_running,
            "paused": self.is_paused,
            "words_transcribed": self.words_transcribed,
            "elapsed_time": time.time() - self.start_time if self.start_time else 0,
            "language": self.transcriber.language if self.transcriber else None
        }


def main():
    """Main entry point for stream application."""
    import argparse

    parser = argparse.ArgumentParser(description="Stream Whisper Main Application")
    parser.add_argument("--model", default="tiny",
                       choices=["tiny", "base", "small", "medium", "large"],
                       help="Whisper model size")
    parser.add_argument("--device", type=int,
                       help="Audio input device ID")
    parser.add_argument("--chunk-duration", type=float, default=3.0,
                       help="Chunk duration in seconds")
    parser.add_argument("--overlap", type=float, default=1.0,
                       help="Overlap between chunks in seconds")
    parser.add_argument("--language", type=str,
                       help="Language code for transcription")
    parser.add_argument("--gui", action="store_true",
                       help="Use GUI interface")
    parser.add_argument("--console", action="store_true",
                       help="Use console interface")

    args = parser.parse_args()

    print("=" * 60)
    print("Stream Whisper - 实时转录应用")
    print("=" * 60)

    # Determine interface mode
    use_gui = args.gui or (not args.console and sys.platform != "linux")

    # Create and run application
    app = StreamWhisperApp(
        model_size=args.model,
        device_id=args.device,
        chunk_duration=args.chunk_duration,
        overlap=args.overlap,
        use_gui=use_gui,
        language=args.language
    )

    if use_gui:
        print("使用 GUI 模式")
        print("注意: 对于完整 GUI 体验，请直接运行 stream_gui.py")
        # For now, we'll just suggest running stream_gui.py
        print(f"\n运行以下命令以启动 GUI:")
        print(f"  python stream_gui.py --model {args.model} "
              f"--chunk-duration {args.chunk_duration} --overlap {args.overlap}")
        if args.device is not None:
            print(f"  --device {args.device}")
    else:
        print("使用控制台模式")
        if app.start():
            # _run_console will handle the main loop
            pass
        else:
            print("启动失败")


if __name__ == "__main__":
    main()