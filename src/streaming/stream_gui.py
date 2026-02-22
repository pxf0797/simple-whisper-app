#!/usr/bin/env python3
"""
Stream Whisper GUI Application.

Provides a real-time transcription display with:
- Always-on-top window
- Transparency control
- Quick control buttons
- Auto-scrolling text display
"""

import tkinter as tk
from tkinter import ttk, scrolledtext
import threading
import queue
import time
from typing import Optional, Callable
import sys
import os

# Add current directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from stream_whisper import StreamWhisper
except ImportError:
    print("Warning: StreamWhisper not found. GUI will run in demo mode.")
    StreamWhisper = None


class StreamWhisperGUI:
    """Main GUI application for streaming transcription."""

    def __init__(self, model_size: str = "tiny", device_id: Optional[int] = None,
                 chunk_duration: float = 3.0, overlap: float = 1.0):
        """
        Initialize the GUI application.

        Args:
            model_size: Whisper model size
            device_id: Audio input device ID
            chunk_duration: Chunk duration in seconds
            overlap: Overlap between chunks in seconds
        """
        self.model_size = model_size
        self.device_id = device_id
        self.chunk_duration = chunk_duration
        self.overlap = overlap

        # Transcription state
        self.is_recording = False
        self.is_paused = False
        self.transcriber = None
        self.update_interval = 100  # ms

        # Threading
        self.update_queue = queue.Queue()
        self.gui_thread = None

        # Initialize GUI
        self._init_gui()

    def _init_gui(self):
        """Initialize the GUI components."""
        self.root = tk.Tk()
        self.root.title("实时转录 - Stream Whisper")
        self.root.geometry("600x500")

        # Set window always on top
        self.root.attributes('-topmost', True)

        # Set default transparency (85%)
        self.transparency = 0.85
        self.root.attributes('-alpha', self.transparency)

        # Configure grid weights
        self.root.grid_rowconfigure(1, weight=1)
        self.root.grid_columnconfigure(0, weight=1)

        # Create widgets
        self._create_control_panel()
        self._create_text_display()
        self._create_status_bar()

        # Set up update loop
        self._schedule_update()

        # Bind close event
        self.root.protocol("WM_DELETE_WINDOW", self._on_closing)

    def _create_control_panel(self):
        """Create control panel with buttons and sliders."""
        control_frame = ttk.Frame(self.root, padding="10")
        control_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N))

        # Control buttons
        button_frame = ttk.Frame(control_frame)
        button_frame.pack(side=tk.LEFT, fill=tk.Y, padx=(0, 20))

        self.start_button = ttk.Button(
            button_frame,
            text="开始录音",
            command=self._start_recording,
            width=10
        )
        self.start_button.pack(side=tk.LEFT, padx=2)

        self.pause_button = ttk.Button(
            button_frame,
            text="暂停",
            command=self._toggle_pause,
            width=10,
            state=tk.DISABLED
        )
        self.pause_button.pack(side=tk.LEFT, padx=2)

        self.stop_button = ttk.Button(
            button_frame,
            text="停止",
            command=self._stop_recording,
            width=10,
            state=tk.DISABLED
        )
        self.stop_button.pack(side=tk.LEFT, padx=2)

        # Model info
        info_frame = ttk.Frame(control_frame)
        info_frame.pack(side=tk.LEFT, fill=tk.Y, padx=(0, 20))

        ttk.Label(info_frame, text=f"模型: {self.model_size}").pack(anchor=tk.W)
        ttk.Label(info_frame, text=f"分块: {self.chunk_duration}s").pack(anchor=tk.W)
        ttk.Label(info_frame, text=f"重叠: {self.overlap}s").pack(anchor=tk.W)

        # Transparency control
        transparency_frame = ttk.Frame(control_frame)
        transparency_frame.pack(side=tk.LEFT, fill=tk.Y)

        ttk.Label(transparency_frame, text="透明度:").pack(anchor=tk.W)

        self.transparency_scale = ttk.Scale(
            transparency_frame,
            from_=0.3,
            to=1.0,
            value=self.transparency,
            command=self._update_transparency,
            length=150
        )
        self.transparency_scale.pack(anchor=tk.W)

        self.transparency_label = ttk.Label(
            transparency_frame,
            text=f"{int(self.transparency * 100)}%"
        )
        self.transparency_label.pack(anchor=tk.W)

        # Clear button
        clear_button = ttk.Button(
            control_frame,
            text="清空文本",
            command=self._clear_text,
            width=10
        )
        clear_button.pack(side=tk.RIGHT, padx=2)

    def _create_text_display(self):
        """Create text display area with scrollbar."""
        text_frame = ttk.Frame(self.root, padding="10")
        text_frame.grid(row=1, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

        # Configure grid
        text_frame.grid_rowconfigure(0, weight=1)
        text_frame.grid_columnconfigure(0, weight=1)

        # Create scrolled text widget
        self.text_display = scrolledtext.ScrolledText(
            text_frame,
            wrap=tk.WORD,
            font=("Monospace", 11),
            bg="white",
            relief=tk.SUNKEN,
            borderwidth=1
        )
        self.text_display.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))

        # Configure tags for styling
        self.text_display.tag_configure("timestamp", foreground="gray", font=("Monospace", 9))
        self.text_display.tag_configure("text", foreground="black", font=("Monospace", 11))
        self.text_display.tag_configure("partial", foreground="blue", font=("Monospace", 11))

        # Make text widget read-only
        self.text_display.configure(state=tk.DISABLED)

    def _create_status_bar(self):
        """Create status bar at bottom of window."""
        self.status_bar = ttk.Frame(self.root, relief=tk.SUNKEN, borderwidth=1)
        self.status_bar.grid(row=2, column=0, sticky=(tk.W, tk.E, tk.S))

        self.status_label = ttk.Label(
            self.status_bar,
            text="就绪 - 点击'开始录音'开始转录",
            anchor=tk.W
        )
        self.status_label.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=5, pady=2)

        # Word counter
        self.word_count_label = ttk.Label(self.status_bar, text="字数: 0", anchor=tk.E)
        self.word_count_label.pack(side=tk.RIGHT, padx=5, pady=2)

    def _update_transparency(self, value):
        """Update window transparency."""
        try:
            self.transparency = float(value)
            self.root.attributes('-alpha', self.transparency)
            self.transparency_label.config(text=f"{int(self.transparency * 100)}%")
        except Exception as e:
            print(f"Error updating transparency: {e}")

    def _start_recording(self):
        """Start audio recording and transcription."""
        if self.is_recording:
            return

        try:
            # Initialize transcriber
            if StreamWhisper is not None:
                self.transcriber = StreamWhisper(
                    model_size=self.model_size,
                    chunk_duration=self.chunk_duration,
                    overlap=self.overlap
                )

                if self.transcriber.start_streaming(device_id=self.device_id):
                    self.is_recording = True
                    self.is_paused = False

                    # Update UI
                    self.start_button.config(state=tk.DISABLED)
                    self.pause_button.config(state=tk.NORMAL)
                    self.stop_button.config(state=tk.NORMAL)
                    self.pause_button.config(text="暂停")

                    self._update_status("录音中...")
                    self._append_text("\n[开始录音]\n", "timestamp")
                else:
                    self._update_status("错误: 无法启动音频流")
                    self.transcriber = None
            else:
                # Demo mode
                self.is_recording = True
                self.is_paused = False
                self.start_button.config(state=tk.DISABLED)
                self.pause_button.config(state=tk.NORMAL)
                self.stop_button.config(state=tk.NORMAL)
                self._update_status("演示模式: 录音中...")
                self._append_text("\n[演示模式 - 开始录音]\n", "timestamp")

        except Exception as e:
            self._update_status(f"错误: {str(e)}")
            print(f"Error starting recording: {e}")

    def _stop_recording(self):
        """Stop audio recording and transcription."""
        if not self.is_recording:
            return

        self.is_recording = False
        self.is_paused = False

        # Stop transcriber
        if self.transcriber is not None:
            self.transcriber.stop_streaming()
            # Get final transcription
            final_text = self.transcriber.get_full_transcription()
            if final_text:
                self._append_text(f"\n[完整转录]\n{final_text}\n", "timestamp")
            self.transcriber = None

        # Update UI
        self.start_button.config(state=tk.NORMAL)
        self.pause_button.config(state=tk.DISABLED)
        self.stop_button.config(state=tk.DISABLED)
        self.pause_button.config(text="暂停")

        self._update_status("已停止")
        self._append_text("\n[停止录音]\n", "timestamp")

    def _toggle_pause(self):
        """Toggle pause/resume recording."""
        if not self.is_recording:
            return

        self.is_paused = not self.is_paused

        if self.is_paused:
            self.pause_button.config(text="继续")
            self._update_status("已暂停")
            self._append_text("\n[暂停]\n", "timestamp")
        else:
            self.pause_button.config(text="暂停")
            self._update_status("录音中...")
            self._append_text("\n[继续]\n", "timestamp")

    def _clear_text(self):
        """Clear the text display."""
        self.text_display.configure(state=tk.NORMAL)
        self.text_display.delete(1.0, tk.END)
        self.text_display.configure(state=tk.DISABLED)
        self.word_count_label.config(text="字数: 0")

    def _append_text(self, text: str, tag: str = "text"):
        """
        Append text to the display.

        Args:
            text: Text to append
            tag: Text tag for styling
        """
        if not text.strip():
            return

        self.text_display.configure(state=tk.NORMAL)

        # Insert text
        self.text_display.insert(tk.END, text, tag)

        # Auto-scroll to bottom
        self.text_display.see(tk.END)

        # Update word count
        content = self.text_display.get(1.0, tk.END)
        words = len(content.split())
        self.word_count_label.config(text=f"字数: {words}")

        self.text_display.configure(state=tk.DISABLED)

    def _update_status(self, message: str):
        """Update status bar message."""
        self.status_label.config(text=message)

    def _update_transcription(self):
        """Update transcription display from transcriber."""
        if self.is_recording and not self.is_paused and self.transcriber is not None:
            try:
                # Get new transcription
                text = self.transcriber.get_transcription(timeout=0.01)
                if text and text.strip():
                    self._append_text(text + " ", "text")

            except Exception as e:
                print(f"Error getting transcription: {e}")

    def _schedule_update(self):
        """Schedule the next GUI update."""
        # Update transcription
        self._update_transcription()

        # Schedule next update
        self.root.after(self.update_interval, self._schedule_update)

    def _on_closing(self):
        """Handle window closing."""
        if self.is_recording and self.transcriber is not None:
            self._stop_recording()

        self.root.destroy()

    def run(self):
        """Run the GUI application."""
        try:
            self.root.mainloop()
        except Exception as e:
            print(f"GUI error: {e}")
            raise


def main():
    """Main entry point for stream GUI."""
    import argparse

    parser = argparse.ArgumentParser(description="Stream Whisper GUI")
    parser.add_argument("--model", default="tiny",
                       choices=["tiny", "base", "small", "medium", "large"],
                       help="Whisper model size")
    parser.add_argument("--device", type=int,
                       help="Audio input device ID")
    parser.add_argument("--chunk-duration", type=float, default=2.0,
                       help="Chunk duration in seconds")
    parser.add_argument("--overlap", type=float, default=0.5,
                       help="Overlap between chunks in seconds")

    args = parser.parse_args()

    print("启动 Stream Whisper GUI...")
    print(f"配置: 模型={args.model}, 分块={args.chunk_duration}s, 重叠={args.overlap}s")

    if args.device is not None:
        print(f"音频设备: {args.device}")

    # Create and run GUI
    gui = StreamWhisperGUI(
        model_size=args.model,
        device_id=args.device,
        chunk_duration=args.chunk_duration,
        overlap=args.overlap
    )

    try:
        gui.run()
    except KeyboardInterrupt:
        print("\n应用程序被用户中断")
    except Exception as e:
        print(f"应用程序错误: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()