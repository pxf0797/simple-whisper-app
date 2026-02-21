# Simple Whisper Application - 项目结构与功能说明

## 概述

Simple Whisper 是一个基于 OpenAI Whisper 模型的实时音频录制和转录应用。项目提供完整的语音转文字解决方案，包括命令行工具、交互式界面、GUI 应用和流式处理功能。

## 项目文件结构

```
simple-whper-app/
├── 核心模块 (Python)
│   ├── simple_whisper.py          # 主应用类：录音、转录核心功能
│   ├── interactive_whisper.py     # 交互式命令行界面
│   ├── batch_transcribe.py        # 批量文件转录工具
│   └── test_stream.py             # 流式功能测试脚本
├── 流式处理引擎 (Python)
│   ├── stream_whisper.py          # 流式音频处理核心类
│   ├── transcription_engine.py    # 实时转录引擎（智能文本处理）
│   ├── stream_main.py             # 流式应用主控制器
│   └── stream_gui.py              # Tkinter GUI 界面
├── 工作流控制脚本 (Shell)
│   ├── workflow_control.sh        # 8模式工作流控制器（综合版）
│   ├── workflow_manager.sh        # 高级工作流管理器（JSON配置）
│   ├── workflow_controller.sh     # 简化工作流控制器（基于quick_record.sh）
│   ├── quick_record.sh           # 快速录音脚本（交互式参数选择）
│   ├── record_meeting.sh         # 会议录音专用脚本
│   ├── transcribe_file.sh        # 文件转录脚本
│   └── example_usage.sh          # 使用示例脚本
├── 环境与部署脚本 (Shell)
│   ├── setup.sh                  # 环境安装脚本
│   ├── run.sh                    # 应用运行脚本
│   ├── install_stream_deps.sh    # 流式功能依赖安装
│   └── requirements.txt          # Python依赖列表
├── 配置文件
│   ├── config/
│   │   ├── workflow_config.json     # 工作流配置定义
│   │   └── task_definitions.json    # 任务定义配置
│   └── config_example.json         # 配置示例文件
├── 文档文件
│   ├── README.md                  # 项目主文档
│   ├── README_stream.md           # 流式功能详细文档
│   ├── README_workflow.md         # 工作流控制脚本文档
│   ├── README_workflow_manager.md # 高级工作流管理器文档
│   ├── 使用指南.md                # 中文使用指南
│   ├── 快速入门指南.md            # 快速入门教程
│   ├── 详细教学文档.md           # 详细教学文档
│   └── 详细教学文档_v2.md        # 详细教学文档（V2版）
├── 运行时目录（自动生成）
│   ├── record/                    # 录音文件输出目录
│   ├── logs/                      # 日志文件目录
│   └── __pycache__/               # Python字节码缓存
├── 虚拟环境（自动生成）
│   └── venv/                      # Python虚拟环境
└── Git配置
    ├── .gitignore                # Git忽略规则
    └── .git/                     # Git仓库数据
```

## 核心模块详细说明

### 1. Python 核心模块

#### `simple_whisper.py` - 主应用类
- **功能**：提供完整的录音和转录功能
- **主要特性**：
  - 音频设备检测和选择
  - 实时音频录制（支持时长限制或手动停止）
  - Whisper模型加载和音频转录
  - 多语言支持（自动检测或指定语言）
  - 计算结果设备选择（CPU/MPS/CUDA）
  - 文件输出（音频WAV文件 + 文本转录）
  - 流式处理支持（通过--stream参数）

- **命令行参数**：
  - `--record`：开始录音
  - `--audio FILE`：转录现有音频文件
  - `--stream`：启用流式处理模式
  - `--list-audio-devices`：列出音频设备
  - `--model`：指定模型大小（tiny/base/small/medium/large）
  - `--language`：指定语言代码
  - `--duration`：录音时长（秒）
  - `--input-device`：音频输入设备ID

#### `interactive_whisper.py` - 交互式界面
- **功能**：提供用户友好的交互式命令行界面
- **主要特性**：
  - 逐步引导配置（模式选择、参数设置）
  - 支持三种模式：录音模式、文件转录模式、流式模式
  - 音频设备交互式选择
  - 模型大小选择
  - 语言选择（自动检测、单语言、多语言）
  - 简化中文转换选项（针对中文）

#### `batch_transcribe.py` - 批量处理工具
- **功能**：批量转录目录中的音频文件
- **主要特性**：
  - 支持多种音频格式（.wav, .mp3, .m4a, .flac, .ogg, .aac）
  - 自定义输入/输出目录
  - 进度跟踪和错误处理
  - 批量配置选项

#### `test_stream.py` - 测试脚本
- **功能**：验证流式处理功能的完整性
- **测试项目**：
  - StreamWhisper类初始化
  - 音频流启动/停止
  - RealTimeTranscriber初始化
  - 文本处理功能

### 2. 流式处理引擎

#### `stream_whisper.py` - 流式处理核心
- **功能**：扩展SimpleWhisper，添加实时流式处理能力
- **主要特性**：
  - 分块音频处理（可配置分块时长和重叠）
  - 多线程音频采集和转录
  - 实时音频队列管理
  - 转录结果队列处理
  - 上下文维护和优化

#### `transcription_engine.py` - 智能转录引擎
- **功能**：提供智能文本处理和优化
- **主要特性**：
  - 句子边界检测（支持多种语言）
  - 重叠文本处理（避免重复）
  - 上下文维护和优化
  - 语言特定模式识别
  - 文本拼接和格式化

#### `stream_main.py` - 流式应用控制器
- **功能**：协调流式处理各组件
- **主要特性**：
  - 集成StreamWhisper和RealTimeTranscriber
  - 可选GUI界面集成
  - 信号处理和优雅退出
  - 配置管理和参数传递

#### `stream_gui.py` - GUI界面
- **功能**：提供实时转录的图形界面
- **主要特性**：
  - 置顶显示窗口（always-on-top）
  - 透明度控制（30%-100%）
  - 开始/停止/暂停按钮控制
  - 自动滚动文本显示
  - 实时字数统计
  - 简洁直观的用户界面

### 3. Shell脚本工具

#### 工作流控制脚本

**`workflow_control.sh`** - 综合工作流控制器
- **功能**：8种工作模式的菜单驱动系统
- **支持模式**：
  1. 录音模式（Recording Mode）
  2. 流式模式（Streaming Mode）
  3. GUI模式（GUI Mode）
  4. 批处理模式（Batch Processing Mode）
  5. 交互模式（Interactive Mode）
  6. 测试模式（Test Mode）
  7. 环境设置（Environment Setup）
  8. 快速工具（Quick Tools）

**`workflow_manager.sh`** - 高级工作流管理器
- **功能**：基于JSON配置的工作流管理系统
- **主要特性**：
  - JSON配置文件支持（工作流定义、任务定义）
  - 任务序列化和执行
  - 错误恢复和重试机制
  - 系统监控和资源检查
  - 日志系统和报告生成
  - 配置备份和恢复

**`workflow_controller.sh`** - 简化工作流控制器
- **功能**：基于quick_record.sh的交互式工作流控制
- **支持工作流**：
  1. 快速录音转录（Quick Record & Transcribe）
  2. 实时流式转录（Live Streaming Transcription）
  3. 批量文件处理（Batch File Processing）
  4. 交互式转录（Interactive Transcription）
  5. 系统诊断（System Diagnostics）
  6. 工具实用程序（Tools & Utilities）

#### 专用功能脚本

**`quick_record.sh`** - 快速录音脚本
- **功能**：交互式参数选择的录音工具
- **主要特性**：
  - 模型选择（tiny/base/small/medium/large）
  - 语言模式选择（自动检测/单语言/多语言）
  - 音频设备交互式选择
  - 计算结果设备选择（CPU/MPS/CUDA）
  - 自动生成时间戳文件名
  - 简化中文转换支持

**`record_meeting.sh`** - 会议录音脚本
- **功能**：针对会议场景优化的录音工具
- **主要特性**：
  - 长时间录音支持
  - 会议专用配置预设
  - 进度指示和状态显示

**`transcribe_file.sh`** - 文件转录脚本
- **功能**：转录现有音频文件的专用工具
- **主要特性**：
  - 支持多种音频格式
  - 交互式文件选择
  - 转录参数配置

**`example_usage.sh`** - 使用示例脚本
- **功能**：展示各种使用场景的命令示例
- **包含示例**：
  - 基本使用方式
  - 音频设备选择
  - 模型选择
  - 语言设置
  - 流式处理
  - 批量处理

### 4. 环境与部署脚本

**`setup.sh`** - 环境安装脚本
- **功能**：一键安装Python虚拟环境和依赖
- **执行步骤**：
  1. 检查Python版本
  2. 创建虚拟环境（venv）
  3. 激活虚拟环境
  4. 升级pip
  5. 安装requirements.txt中的依赖

**`run.sh`** - 应用运行脚本
- **功能**：自动激活虚拟环境并运行主应用
- **特性**：如果虚拟环境不存在，自动运行setup.sh

**`install_stream_deps.sh`** - 流式功能依赖安装
- **功能**：专门安装流式处理所需的依赖包
- **安装项目**：
  - torch 和 torchaudio（PyTorch）
  - openai-whisper（Whisper模型）
  - sounddevice 和 soundfile（音频处理）
  - numpy 和 scipy（科学计算）
  - 可选的OpenCC（中文简繁转换）

**`requirements.txt`** - Python依赖列表
- **核心依赖**：torch, torchaudio, openai-whisper, sounddevice, soundfile, numpy
- **可选依赖**：opencc（中文转换）, scipy（信号处理）

### 5. 配置文件

**`config/workflow_config.json`** - 工作流配置
- **功能**：定义工作流结构和默认设置
- **配置项**：
  - 工作流定义（quick_record, stream_live, batch_process, system_test）
  - 任务序列（每个工作流的任务列表）
  - 默认设置（模型、语言、音频设备、日志级别等）

**`config/task_definitions.json`** - 任务定义
- **功能**：定义可用任务及其属性
- **任务类型**：
  - 环境检查（check_env）
  - 参数选择（select_params）
  - 录音执行（record_audio）
  - 转录执行（transcribe）
  - 流式设置（stream_setup）
  - 监控任务（monitor_stream）

**`config_example.json`** - 配置示例
- **功能**：配置文件示例模板

### 6. 文档文件

#### 主文档
- **`README.md`** - 项目主文档（英文）
  - 项目概述和特性
  - 环境要求
  - 安装和使用指南
  - 基本使用示例

#### 功能专项文档
- **`README_stream.md`** - 流式功能详细文档
  - 流式处理架构说明
  - 组件功能介绍
  - 性能优化策略
  - 故障排除指南

- **`README_workflow.md`** - 工作流控制脚本文档
  - workflow_control.sh使用指南
  - 8种工作模式详解
  - 环境检查和错误处理

- **`README_workflow_manager.md`** - 高级工作流管理器文档
  - workflow_manager.sh完整指南
  - JSON配置系统说明
  - 任务序列和监控功能

#### 中文文档
- **`使用指南.md`** - 中文使用指南
- **`快速入门指南.md`** - 快速入门教程
- **`详细教学文档.md`** - 详细教学文档
- **`详细教学文档_v2.md`** - 详细教学文档（V2版）

### 7. 运行时目录

**`record/`** - 录音文件目录
- **功能**：存储录音和转录输出文件
- **文件命名**：`recording_YYYYMMDD_HHMMSS.wav` 和对应转录文本

**`logs/`** - 日志文件目录
- **功能**：存储工作流执行日志
- **文件命名**：`workflow_*_YYYYMMDD_HHMMSS.log`

**`__pycache__/`** - Python字节码缓存
- **功能**：Python解释器生成的字节码缓存文件

**`venv/`** - 虚拟环境目录
- **功能**：Python虚拟环境，包含所有安装的依赖包

## 功能特性总结

### 核心功能
1. **实时音频录制**：支持麦克风录制，可配置时长和设备
2. **语音转录**：基于Whisper模型的语音转文字
3. **多语言支持**：自动语言检测或指定语言
4. **多模型支持**：tiny/base/small/medium/large五种模型

### 高级功能
1. **流式处理**：实时音频流转录，低延迟（3-5秒）
2. **批量处理**：批量转录音频文件
3. **GUI界面**：图形化实时转录显示
4. **智能文本处理**：句子边界检测、重叠处理、上下文优化

### 工作流管理
1. **交互式工作流**：基于quick_record.sh的直观交互
2. **菜单驱动系统**：8种工作模式的完整菜单
3. **配置驱动系统**：JSON配置的工作流管理
4. **错误恢复机制**：多层错误检测和恢复

### 系统工具
1. **环境管理**：虚拟环境自动安装和激活
2. **依赖管理**：核心依赖和流式依赖分别管理
3. **系统诊断**：环境测试、音频设备测试、模型测试
4. **监控工具**：资源使用监控、日志查看、清理工具

## 使用场景

### 个人使用
- **会议记录**：使用record_meeting.sh录制和转录会议
- **讲座笔记**：使用stream_gui.py实时显示讲座内容
- **语音备忘录**：使用quick_record.sh快速录音和转录

### 专业使用
- **批量处理**：使用batch_transcribe.py处理历史录音文件
- **实时字幕**：使用stream_whisper.py生成实时字幕
- **系统集成**：通过simple_whisper.py API集成到其他应用

### 开发测试
- **功能验证**：使用test_stream.py测试流式功能
- **系统诊断**：使用工作流控制脚本的诊断模式
- **性能测试**：测试不同模型大小的性能和准确性

## 技术架构

### 音频处理流程
```
麦克风输入 → 音频采集 → 分块处理 → Whisper转录 → 文本优化 → 输出显示
```

### 流式处理架构
```
音频流 → StreamWhisper（分块） → RealTimeTranscriber（优化） → GUI/CLI显示
```

### 工作流系统架构
```
用户输入 → 工作流控制器 → 任务序列 → 执行引擎 → 结果输出 + 日志记录
```

## 扩展与定制

### 添加新工作流
1. 编辑 `config/workflow_config.json` 添加工作流定义
2. 在 `config/task_definitions.json` 中添加任务定义
3. 在对应脚本中实现任务函数

### 添加新功能
1. 扩展 `simple_whisper.py` 中的SimpleWhisper类
2. 创建新的Python模块或Shell脚本
3. 更新文档和使用示例

### 配置自定义
1. 修改 `config/workflow_config.json` 中的默认设置
2. 通过环境变量覆盖配置
3. 创建自定义配置文件和脚本

## 维护与支持

### 常规维护
1. **依赖更新**：定期更新requirements.txt中的依赖版本
2. **日志清理**：定期清理logs目录中的旧日志文件
3. **临时文件清理**：清理record目录中的旧录音文件

### 故障排除
1. **环境问题**：使用setup.sh或install_stream_deps.sh重新安装
2. **音频设备问题**：使用--list-audio-devices检查设备
3. **模型加载问题**：使用系统诊断模式测试模型加载
4. **流式处理问题**：使用test_stream.py验证流式功能

### 获取帮助
1. 查看相关README文档
2. 运行example_usage.sh查看使用示例
3. 检查日志文件获取详细错误信息

---

**版本信息**：当前项目包含完整的工作流控制系统，支持从简单录音到复杂流式处理的全方位语音转文字功能。

**更新日期**：2026-02-21