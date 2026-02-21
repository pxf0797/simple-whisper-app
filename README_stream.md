# 流式Whisper处理与实时前端显示

## 概述

已成功实现流式Whisper处理与实时前端显示方案，满足用户需求：
- **流式Whisper处理**：边录边转，目标延迟3-5秒
- **前端显示窗口**：置顶显示、透明度调节、快捷控制按钮
- **兼容性**：完全保留现有批处理功能

## 实现文件

### 新文件
1. **stream_whisper.py** - 流式处理核心类
   - 继承SimpleWhisper，添加流式处理能力
   - 3秒分块，1秒重叠（可配置）
   - 音频流管理、分块处理、重叠去重

2. **transcription_engine.py** - 智能转录引擎
   - 高级文本处理：重叠去重、句子边界检测
   - 实时语言检测更新
   - 上下文管理和统计

3. **stream_gui.py** - Tkinter前端界面
   - 窗口置顶显示（always-on-top）
   - 透明度调节滑块（30%-100%）
   - 快捷控制按钮（开始/停止/暂停）
   - 自动滚动文本显示
   - 状态反馈和字数统计

4. **stream_main.py** - 主控制器
   - 协调音频流、转录引擎和GUI组件
   - 提供统一的应用程序接口

5. **test_stream.py** - 测试脚本
   - 验证所有组件功能
   - 检查CLI选项

### 修改的现有文件
1. **simple_whisper.py** - 扩展CLI参数
   - 添加 `--stream` 标志启用流式模式
   - 添加 `--chunk-duration` 和 `--overlap` 参数
   - 保持向后兼容性

2. **interactive_whisper.py** - 扩展交互界面
   - 添加"流式模式"选项
   - 集成StreamWhisper
   - 添加分块参数配置

## 功能特性

### 流式处理
- **低延迟**：3秒分块处理，目标延迟3-5秒
- **智能拼接**：重叠区域去重，流畅文本拼接
- **实时语言检测**：自动检测并适应语言变化
- **多线程处理**：音频采集、转录处理、GUI更新分离

### GUI功能
- **置顶显示**：窗口始终在最前
- **透明度控制**：滑块调节窗口透明度（30%-100%）
- **控制按钮**：开始、暂停、停止、清空文本
- **实时更新**：自动滚动，实时显示转录结果
- **状态反馈**：显示录音状态、字数统计

### 兼容性
- **向后兼容**：所有现有批处理功能不受影响
- **灵活配置**：支持多种模型（tiny/base/small/medium/large）
- **设备选择**：支持选择音频输入设备和计算设备

## 使用方法

### 1. 命令行流式模式
```bash
# 基本流式转录
python simple_whisper.py --stream --model tiny

# 自定义分块参数
python simple_whisper.py --stream --model base --chunk-duration 2.0 --overlap 0.5

# 指定音频设备
python simple_whisper.py --stream --model tiny --input-device 1
```

### 2. 交互式流式模式
```bash
python interactive_whisper.py
```
选择模式时选择"stream"，然后配置分块参数。

### 3. 独立GUI应用
```bash
python stream_gui.py --model tiny
```
启动独立GUI应用程序，具有完整的控制界面。

### 4. 主控制器
```bash
python stream_main.py --model tiny --gui
```
使用主控制器协调所有组件。

## 配置参数

### 流式参数
- `--chunk-duration`：分块时长（秒，默认3.0）
- `--overlap`：重叠时长（秒，默认1.0）
- `--model`：Whisper模型大小（tiny/base/small/medium/large）

### GUI参数
- 透明度：通过滑块实时调节
- 窗口位置：可拖动调整
- 文本显示：自动滚动，可清空

## 性能优化

1. **模型选择**：默认使用tiny模型以实现最低延迟
2. **分块策略**：3秒分块平衡延迟和准确性
3. **并行处理**：多线程流水线设计
4. **内存管理**：环形缓冲区限制历史长度
5. **GPU加速**：自动使用CUDA/MPS（如果可用）

## 技术要求

### 依赖项
```
torch
torchaudio
openai-whisper
sounddevice
soundfile
numpy
```

### 可选依赖
```
zhconv（中文简繁转换）
```

### 安装
```bash
pip install torch torchaudio openai-whisper sounddevice soundfile numpy
```

## 测试验证

运行测试脚本检查功能：
```bash
python test_stream.py
```

## 故障排除

### 常见问题
1. **无音频输入**：检查音频设备是否正确连接
2. **高延迟**：尝试使用更小的模型（tiny）或减少分块时长
3. **内存不足**：减少上下文长度或使用更小的模型
4. **导入错误**：确保所有依赖项已安装

### 日志查看
- 控制台输出显示处理状态和错误信息
- GUI状态栏显示当前状态

## 架构设计

```
音频输入 → AudioStreamManager → 3秒分块 → TranscriptionEngine →
→ ResultAggregator → GUI显示 (Tkinter)
```

### 组件职责
- **AudioStreamManager**：音频流采集和分块
- **TranscriptionEngine**：智能文本处理和拼接
- **ResultAggregator**：结果聚合和上下文管理
- **GUI**：用户界面和交互控制

## 未来扩展

1. **更多GUI主题**：支持深色/浅色主题
2. **导出功能**：实时保存转录结果
3. **多语言界面**：支持中英文界面切换
4. **云端同步**：转录结果云存储
5. **API接口**：提供REST API供其他应用调用

## 许可证

与原有Simple Whisper应用相同。