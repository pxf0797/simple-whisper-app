# 工作流控制脚本 - workflow_control.sh

## 概述

`workflow_control.sh` 是一个全面的工作流控制脚本，用于管理和自动化 Simple Whisper 应用的各种功能。它提供了统一的界面来访问所有录音、转录和流式处理功能。

## 主要特性

- **8种工作模式**：录音、流式、GUI、批处理、交互式、测试、环境设置、快速工具
- **环境自动检查**：自动检测Python环境、虚拟环境和依赖
- **日志记录**：所有操作都有详细的日志记录
- **错误处理**：完善的错误检测和恢复机制
- **用户友好**：彩色输出和清晰的菜单系统

## 安装与使用

### 1. 添加执行权限
```bash
chmod +x workflow_control.sh
```

### 2. 运行方式

#### 交互式菜单模式（推荐）
```bash
./workflow_control.sh
```

#### 直接指定模式
```bash
./workflow_control.sh record      # 录音模式
./workflow_control.sh stream      # 流式模式
./workflow_control.sh gui         # GUI模式
./workflow_control.sh batch       # 批处理模式
./workflow_control.sh interactive # 交互模式
./workflow_control.sh test        # 测试模式
./workflow_control.sh setup       # 环境设置
./workflow_control.sh tools       # 快速工具
```

#### 查看帮助
```bash
./workflow_control.sh --help
```

## 详细模式说明

### 1. 录音模式 (Recording Mode)
- 交互式参数选择
- 支持多种语言和语言模式
- 音频设备和计算设备选择
- 自动生成时间戳文件名

**使用场景**：录制会议、讲座、访谈等

### 2. 流式模式 (Streaming Mode)
- 实时音频流处理
- 可配置的分块大小和重叠
- 低延迟转录（3-5秒）
- 支持命令行和GUI流式

**使用场景**：实时字幕、语音转文字直播

### 3. GUI模式 (GUI Mode)
- 置顶显示窗口
- 透明度调节（30%-100%）
- 开始/停止/暂停按钮
- 自动滚动文本显示
- 字数统计

**使用场景**：需要可视化界面的实时转录

### 4. 批处理模式 (Batch Processing Mode)
- 批量处理音频文件
- 支持多种音频格式（.wav, .mp3, .m4a）
- 进度跟踪和错误处理
- 自定义输出目录

**使用场景**：处理大量录音文件

### 5. 交互模式 (Interactive Mode)
- 完全交互式体验
- 逐步引导配置
- 适合初学者使用
- 整合所有功能

**使用场景**：第一次使用或不熟悉命令行参数

### 6. 测试模式 (Test Mode)
- 环境验证
- 音频设备测试
- 模型加载测试
- 流式功能测试

**使用场景**：故障排除和系统验证

### 7. 环境设置模式 (Environment Setup)
- 安装所有依赖
- 创建虚拟环境
- 更新软件包
- 下载Whisper模型
- 音频设备配置

**使用场景**：初始设置和系统维护

### 8. 快速工具模式 (Quick Tools)
- 列出音频设备
- 查看可用模型
- 检查磁盘空间
- 查看日志文件
- 清理临时文件
- 系统信息查看

**使用场景**：日常维护和故障排除

## 环境要求

### 必需依赖
- Python 3.8+
- 虚拟环境（推荐）
- 以下Python包：
  - torch
  - torchaudio
  - openai-whisper
  - sounddevice
  - soundfile
  - numpy

### 可选依赖
- CUDA（NVIDIA GPU加速）
- MPS（Apple Silicon GPU加速）

## 自动环境检查

脚本启动时会自动执行以下检查：

1. **Python版本检查**：确保Python 3.8+
2. **虚拟环境检查**：自动激活或创建venv
3. **依赖检查**：检测缺失的Python包
4. **模块检查**：验证流式和GUI模块
5. **日志初始化**：创建日志文件用于跟踪

## 日志系统

脚本会自动创建日志文件，格式：`workflow_YYYYMMDD_HHMMSS.log`

日志级别：
- **INFO**：常规操作信息
- **WARN**：警告信息
- **ERROR**：错误信息
- **DEBUG**：调试信息

## 错误处理

脚本包含多层错误处理：

1. **环境错误**：缺失依赖时提供安装选项
2. **模块错误**：模块缺失时提供替代方案
3. **用户输入错误**：无效输入时重新提示
4. **执行错误**：命令失败时显示错误信息

## 示例使用场景

### 场景1：快速会议录音
```bash
./workflow_control.sh record
# 选择：模型(base)，时长(3600秒)，语言(自动)，设备(默认)
```

### 场景2：实时讲座转录
```bash
./workflow_control.sh stream
# 选择：模型(tiny)，分块(3.0秒)，重叠(1.0秒)，测试时长(7200秒)
```

### 场景3：批量处理历史录音
```bash
./workflow_control.sh batch
# 选择：输入目录(recordings/)，输出目录(transcripts/)，模型(base)
```

### 场景4：系统验证
```bash
./workflow_control.sh test
# 运行完整测试套件，验证所有功能
```

## 与现有脚本的集成

### 与 quick_record.sh 的关系
- `workflow_control.sh` 的录音模式会调用 `quick_record.sh`
- 如果 `quick_record.sh` 不存在，会使用内置功能
- 提供了更丰富的错误处理和用户界面

### 与其它脚本的关系
- **流式模式**：使用 `stream_whisper.py` 和 `simple_whisper.py --stream`
- **GUI模式**：使用 `stream_gui.py`
- **批处理模式**：使用 `batch_transcribe.py` 或内置批处理
- **交互模式**：使用 `interactive_whisper.py`

## 自定义配置

### 环境变量
```bash
# 指定Python解释器
export PYTHON=python3.9

# 指定虚拟环境路径
export VENV_PATH=/path/to/venv
```

### 参数传递
```bash
# 传递参数给底层脚本
./workflow_control.sh record --duration 60 --model base
```

## 故障排除

### 常见问题

1. **"Python not found"**
   ```bash
   # 安装Python 3.8+
   brew install python@3.9  # macOS
   sudo apt install python3.9  # Ubuntu
   ```

2. **"Module not found"**
   ```bash
   ./workflow_control.sh setup
   # 选择选项1安装所有依赖
   ```

3. **"No audio devices found"**
   ```bash
   ./workflow_control.sh tools
   # 选择选项1查看音频设备
   ```

4. **"Model download failed"**
   ```bash
   ./workflow_control.sh setup
   # 选择选项4下载模型
   ```

### 获取帮助
```bash
# 查看详细帮助
./workflow_control.sh --help

# 查看日志文件
tail -f workflow_*.log
```

## 更新日志

### v1.0 (2026-02-21)
- 初始版本发布
- 支持8种工作模式
- 完整的错误处理和日志系统
- 环境自动检查
- 与现有脚本集成

## 贡献指南

1. Fork 仓库
2. 创建功能分支
3. 提交更改
4. 推送到分支
5. 创建 Pull Request

## 许可证

与 Simple Whisper 应用相同（MIT许可证）。

## 技术支持

- 查看详细日志：`cat workflow_*.log`
- 运行测试模式：`./workflow_control.sh test`
- 检查环境：`./workflow_control.sh setup`

---

**提示**：首次使用建议运行测试模式验证所有功能！