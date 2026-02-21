# Simple Whisper Application - 文件组织与功能分类

## 概述

本文档按文件类型（Python脚本、Shell脚本、Markdown文档）对项目文件进行分类整理，并提供功能说明和使用指南。

## 一、Python脚本文件 (.py)

### 1.1 核心功能模块

#### `simple_whisper.py` (19.7KB)
- **功能**: 主应用类，提供完整的录音和转录功能
- **主要特性**:
  - 音频设备检测和选择 (`--list-audio-devices`)
  - 实时音频录制 (`--record`)
  - Whisper模型加载和音频转录
  - 多语言支持（自动检测或指定语言）
  - 计算结果设备选择（CPU/MPS/CUDA）
  - 文件输出（音频WAV文件 + 文本转录）
  - 流式处理支持（通过 `--stream` 参数）
- **命令行接口**: 支持所有核心功能的命令行参数
- **依赖**: `whisper`, `sounddevice`, `soundfile`, `numpy`

#### `interactive_whisper.py` (15.5KB)
- **功能**: 用户友好的交互式命令行界面
- **主要特性**:
  - 逐步引导配置（模式选择、参数设置）
  - 支持三种模式：录音模式、文件转录模式、流式模式
  - 音频设备交互式选择
  - 模型大小选择（tiny/base/small/medium/large）
  - 语言选择（自动检测、单语言、多语言）
  - 简化中文转换选项
- **使用方式**: 直接运行 `python interactive_whisper.py`

#### `batch_transcribe.py` (6.0KB)
- **功能**: 批量转录目录中的音频文件
- **主要特性**:
  - 支持多种音频格式（.wav, .mp3, .m4a, .flac, .ogg, .aac）
  - 自定义输入/输出目录
  - 进度跟踪和错误处理
  - 批量配置选项
- **使用场景**: 处理大量历史录音文件

### 1.2 流式处理模块

#### `stream_whisper.py` (13.5KB)
- **功能**: 扩展SimpleWhisper，添加实时流式处理能力
- **主要特性**:
  - 分块音频处理（可配置分块时长和重叠）
  - 多线程音频采集和转录
  - 实时音频队列管理
  - 转录结果队列处理
  - 上下文维护和优化
- **继承**: 继承自 `SimpleWhisper` 类
- **参数**: `chunk_duration`, `overlap`, `sample_rate`

#### `transcription_engine.py` (13.1KB)
- **功能**: 智能文本处理和优化引擎
- **主要特性**:
  - 句子边界检测（支持多种语言）
  - 重叠文本处理（避免重复）
  - 上下文维护和优化
  - 语言特定模式识别
  - 文本拼接和格式化
- **算法**: 基于相似度检测的重叠处理
- **语言支持**: 英语、中文、日语、韩语等

#### `stream_main.py` (13.4KB)
- **功能**: 流式应用主控制器
- **主要特性**:
  - 集成StreamWhisper和RealTimeTranscriber
  - 可选GUI界面集成
  - 信号处理和优雅退出
  - 配置管理和参数传递
- **协调组件**: 音频流 → 转录引擎 → 显示界面

#### `stream_gui.py` (13.8KB)
- **功能**: 实时转录的图形界面
- **主要特性**:
  - 置顶显示窗口（always-on-top）
  - 透明度控制（30%-100%）
  - 开始/停止/暂停按钮控制
  - 自动滚动文本显示
  - 实时字数统计
  - 简洁直观的用户界面
- **技术**: 基于Tkinter的GUI应用

### 1.3 测试模块

#### `test_stream.py` (5.1KB)
- **功能**: 验证流式处理功能的完整性
- **测试项目**:
  - StreamWhisper类初始化
  - 音频流启动/停止
  - RealTimeTranscriber初始化
  - 文本处理功能
- **用途**: 开发测试和功能验证

## 二、Shell脚本文件 (.sh)

### 2.1 工作流控制脚本

#### `workflow_control.sh` (28.9KB) - **综合版**
- **功能**: 8种工作模式的菜单驱动系统
- **支持模式**:
  1. **录音模式** (Recording Mode) - 交互式参数选择
  2. **流式模式** (Streaming Mode) - 实时音频流处理
  3. **GUI模式** (GUI Mode) - 图形界面
  4. **批处理模式** (Batch Processing Mode) - 批量文件处理
  5. **交互模式** (Interactive Mode) - 完整交互体验
  6. **测试模式** (Test Mode) - 系统验证
  7. **环境设置** (Environment Setup) - 环境配置
  8. **快速工具** (Quick Tools) - 实用工具
- **特性**: 环境检查、日志记录、错误处理、彩色输出

#### `workflow_manager.sh` (32.9KB) - **高级版**
- **功能**: 基于JSON配置的工作流管理系统
- **主要特性**:
  - JSON配置文件支持 (`config/workflow_config.json`, `config/task_definitions.json`)
  - 任务序列化和执行
  - 错误恢复和重试机制
  - 系统监控和资源检查
  - 日志系统和报告生成
  - 配置备份和恢复
- **预定义工作流**:
  - `quick_record`: 快速录音工作流
  - `stream_live`: 实时流式工作流
  - `batch_process`: 批处理工作流
  - `system_test`: 系统测试工作流

#### `workflow_controller.sh` (19.9KB) - **简化版**
- **功能**: 基于quick_record.sh的交互式工作流控制
- **支持工作流**:
  1. **快速录音转录** - 交互式参数选择 → 录音 → 转录 → 保存
  2. **实时流式转录** - 流式参数配置 → 启动流式 → 监控
  3. **批量文件处理** - 选择目录 → 批量处理 → 进度跟踪
  4. **交互式转录** - 完整交互式体验
  5. **系统诊断** - 环境测试 → 音频测试 → 模型测试
  6. **工具实用程序** - 设备列表、磁盘检查、日志查看
- **设计理念**: 保持与 `quick_record.sh` 一致的交互体验

### 2.2 专用功能脚本

#### `quick_record.sh` (13.7KB)
- **功能**: 交互式参数选择的录音工具
- **主要特性**:
  - 模型选择（tiny/base/small/medium/large）
  - 语言模式选择（自动检测/单语言/多语言）
  - 音频设备交互式选择
  - 计算结果设备选择（CPU/MPS/CUDA）
  - 自动生成时间戳文件名
  - 简化中文转换支持
- **使用方式**: `./quick_record.sh` 或带参数执行

#### `record_meeting.sh` (5.3KB)
- **功能**: 针对会议场景优化的录音工具
- **主要特性**:
  - 长时间录音支持
  - 会议专用配置预设
  - 进度指示和状态显示
  - 友好的用户界面
- **适用场景**: 会议记录、讲座录音

#### `transcribe_file.sh` (4.4KB)
- **功能**: 转录现有音频文件的专用工具
- **主要特性**:
  - 支持多种音频格式
  - 交互式文件选择
  - 转录参数配置
  - 自动输出文件命名
- **使用方式**: `./transcribe_file.sh [音频文件]`

#### `example_usage.sh` (4.8KB)
- **功能**: 展示各种使用场景的命令示例
- **包含示例**:
  - **基本使用**: 录音、转录现有文件
  - **音频设备选择**: 列出设备、选择特定设备
  - **模型选择**: 不同模型大小的使用
  - **语言设置**: 单语言、多语言、自动检测
  - **流式处理**: 实时流式转录
  - **批量处理**: 批量转录音频文件
- **用途**: 快速参考和学习工具

### 2.3 环境管理脚本

#### `setup.sh` (826B)
- **功能**: 一键安装Python虚拟环境和依赖
- **执行步骤**:
  1. 检查Python版本
  2. 创建虚拟环境（venv）
  3. 激活虚拟环境
  4. 升级pip
  5. 安装requirements.txt中的依赖
- **使用方式**: `./setup.sh`

#### `run.sh` (495B)
- **功能**: 自动激活虚拟环境并运行主应用
- **特性**: 如果虚拟环境不存在，自动运行setup.sh
- **使用方式**: `./run.sh [参数]` (参数传递给simple_whisper.py)

#### `install_stream_deps.sh` (1.6KB)
- **功能**: 专门安装流式处理所需的依赖包
- **安装项目**:
  - torch 和 torchaudio（PyTorch）
  - openai-whisper（Whisper模型）
  - sounddevice 和 soundfile（音频处理）
  - numpy 和 scipy（科学计算）
  - 可选的OpenCC（中文简繁转换）
- **使用场景**: 仅安装流式处理功能所需依赖

## 三、Markdown文档文件 (.md)

### 3.1 英文文档

#### `README.md` (5.9KB) - **项目主文档**
- **内容**:
  - 项目概述和特性
  - 环境要求
  - 安装和使用指南
  - 基本使用示例
  - 命令行参数说明
- **用途**: GitHub仓库的主页文档

#### `README_stream.md` (5.1KB) - **流式功能文档**
- **内容**:
  - 流式处理架构说明
  - 组件功能介绍（StreamWhisper, RealTimeTranscriber等）
  - 性能优化策略
  - 故障排除指南
  - 使用示例和最佳实践
- **用途**: 流式处理功能的专门文档

#### `README_workflow.md` (6.7KB) - **工作流控制文档**
- **内容**:
  - workflow_control.sh使用指南
  - 8种工作模式详解
  - 环境检查和错误处理
  - 使用场景示例
  - 故障排除和常见问题
- **用途**: 工作流控制脚本的完整文档

#### `README_workflow_manager.md` (9.8KB) - **高级工作流管理器文档**
- **内容**:
  - workflow_manager.sh完整指南
  - JSON配置系统说明
  - 任务序列和监控功能
  - 配置管理和备份
  - 系统监控和维护工具
- **用途**: 高级工作流管理器的详细文档

### 3.2 中文文档

#### `使用指南.md` (5.8KB)
- **内容**: 中文使用指南，覆盖基本功能和使用方法
- **用途**: 中文用户快速入门

#### `快速入门指南.md` (6.6KB)
- **内容**: 快速入门教程，步骤详细说明
- **用途**: 新手用户的快速上手指南

#### `详细教学文档.md` (24.3KB)
- **内容**: 详细教学文档，覆盖所有功能
- **用途**: 完整的功能教学和参考

#### `详细教学文档_v2.md` (16.2KB)
- **内容**: 详细教学文档的V2版本
- **用途**: 更新版的教学文档

### 3.3 参考文档

#### `PROJECT_STRUCTURE.md` (15.3KB) - **项目结构文档**
- **内容**:
  - 完整的文件结构树形图
  - 每个模块的功能详细说明
  - 技术架构和流程说明
  - 使用场景和扩展指南
  - 维护和故障排除信息
- **用途**: 项目结构和功能的完整参考

## 四、配置文件 (.json)

### 4.1 工作流配置

#### `config/workflow_config.json` (1.0KB)
- **功能**: 定义工作流结构和默认设置
- **配置项**:
  - **工作流定义**: quick_record, stream_live, batch_process, system_test
  - **任务序列**: 每个工作流的任务执行顺序
  - **默认设置**: default_model, default_language, audio_device, log_level等
- **用途**: workflow_manager.sh的配置文件

#### `config/task_definitions.json` (1.4KB)
- **功能**: 定义可用任务及其属性
- **任务类型**:
  - **内部任务**: check_env（环境检查）
  - **交互任务**: select_params（参数选择）, stream_setup（流式设置）
  - **执行任务**: record_audio（录音）, transcribe（转录）, start_stream（启动流式）
  - **监控任务**: monitor_stream（监控流式）
- **用途**: 任务定义的配置文件

#### `config_example.json` (243B)
- **功能**: 配置文件示例模板
- **用途**: 配置参考示例

## 五、依赖文件

#### `requirements.txt` (273B)
- **功能**: Python依赖包列表
- **核心依赖**:
  - torch, torchaudio（PyTorch深度学习框架）
  - openai-whisper（Whisper语音识别模型）
  - sounddevice, soundfile（音频处理）
  - numpy（数值计算）
- **用途**: pip安装依赖的清单

## 六、文件分类总结

### 按功能分类

| 功能类别 | Python脚本 | Shell脚本 | 文档文件 |
|----------|------------|-----------|----------|
| **核心录音转录** | simple_whisper.py | quick_record.sh | README.md, 使用指南.md |
| **流式处理** | stream_whisper.py, transcription_engine.py, stream_gui.py | workflow_*.sh (流式模式) | README_stream.md |
| **批量处理** | batch_transcribe.py | workflow_*.sh (批处理模式) |  |
| **交互界面** | interactive_whisper.py, stream_gui.py | workflow_controller.sh | 详细教学文档.md |
| **工作流管理** |  | workflow_control.sh, workflow_manager.sh | README_workflow.md, README_workflow_manager.md |
| **环境管理** |  | setup.sh, run.sh, install_stream_deps.sh | 快速入门指南.md |
| **测试验证** | test_stream.py | workflow_*.sh (测试模式) |  |
| **工具实用** |  | transcribe_file.sh, record_meeting.sh, example_usage.sh |  |

### 按用户角色分类

| 用户角色 | 推荐使用的文件 | 说明 |
|----------|----------------|------|
| **初学者** | quick_record.sh, interactive_whisper.py, 快速入门指南.md | 简单易用的交互式工具 |
| **常规用户** | workflow_controller.sh, simple_whisper.py, 使用指南.md | 平衡功能和易用性 |
| **高级用户** | workflow_manager.sh, stream_whisper.py, README_stream.md | 完整功能和控制权 |
| **开发者** | 所有Python脚本, test_stream.py, PROJECT_STRUCTURE.md | 开发和定制功能 |
| **系统管理员** | setup.sh, workflow_control.sh (测试模式), requirements.txt | 环境部署和维护 |

### 按使用场景分类

| 使用场景 | 主要工具 | 备用工具 |
|----------|----------|----------|
| **快速录音** | quick_record.sh | simple_whisper.py --record |
| **会议记录** | record_meeting.sh | workflow_controller.sh (快速录音) |
| **文件转录** | transcribe_file.sh | simple_whisper.py --audio |
| **实时转录** | stream_gui.py | workflow_controller.sh (实时流式) |
| **批量处理** | batch_transcribe.py | workflow_manager.sh batch_process |
| **系统测试** | workflow_control.sh (测试模式) | test_stream.py |
| **环境设置** | setup.sh | install_stream_deps.sh |

## 七、建议的文件组织结构

基于当前文件分析，建议的目录结构：

```
simple-whisper-app/
├── src/                    # Python源代码
│   ├── core/              # 核心功能模块
│   │   ├── __init__.py
│   │   ├── simple_whisper.py      # 主应用类
│   │   └── transcription_engine.py # 智能转录引擎
│   ├── streaming/         # 流式处理模块
│   │   ├── __init__.py
│   │   ├── stream_whisper.py      # 流式处理核心
│   │   ├── stream_main.py         # 流式控制器
│   │   └── stream_gui.py          # GUI界面
│   ├── batch/            # 批量处理模块
│   │   └── batch_transcribe.py    # 批量转录
│   ├── interactive/      # 交互式模块
│   │   └── interactive_whisper.py # 交互界面
│   └── tests/           # 测试模块
│       └── test_stream.py         # 流式测试
├── scripts/              # Shell脚本
│   ├── workflows/       # 工作流控制
│   │   ├── workflow_control.sh     # 综合版
│   │   ├── workflow_manager.sh     # 高级版
│   │   └── workflow_controller.sh  # 简化版
│   ├── recording/       # 录音相关
│   │   ├── quick_record.sh         # 快速录音
│   │   ├── record_meeting.sh       # 会议录音
│   │   └── transcribe_file.sh      # 文件转录
│   ├── setup/          # 环境设置
│   │   ├── setup.sh               # 环境安装
│   │   ├── run.sh                 # 应用运行
│   │   └── install_stream_deps.sh # 流式依赖
│   └── examples/       # 使用示例
│       └── example_usage.sh       # 示例脚本
├── docs/               # 文档
│   ├── en/            # 英文文档
│   │   ├── README.md              # 主文档
│   │   ├── streaming.md           # 流式文档
│   │   ├── workflows.md           # 工作流文档
│   │   └── workflow_manager.md    # 工作流管理器文档
│   ├── zh/            # 中文文档
│   │   ├── guide.md               # 使用指南
│   │   ├── quickstart.md          # 快速入门
│   │   ├── tutorial.md            # 详细教学
│   │   └── tutorial_v2.md         # 详细教学V2
│   └── reference/     # 参考文档
│       └── structure.md           # 项目结构
├── config/            # 配置文件
│   ├── workflow_config.json      # 工作流配置
│   └── task_definitions.json     # 任务定义
├── requirements.txt   # Python依赖
├── config_example.json # 配置示例
└── README.md          # 根目录README（链接到docs/en/README.md）
```

## 八、下一步建议

### 8.1 立即可做的整理
1. **创建docs目录**，将现有Markdown文件移动到相应子目录
2. **创建scripts目录**，按功能分类Shell脚本
3. **更新根目录README.md**，提供清晰的导航链接

### 8.2 中期整理
1. **重构Python导入路径**，创建src目录结构
2. **更新脚本中的路径引用**，适应新的目录结构
3. **创建统一的入口脚本**，提供一致的用户体验

### 8.3 长期优化
1. **创建安装包**，支持pip安装
2. **添加配置管理**，支持用户自定义配置
3. **开发Web界面**，提供远程访问能力

## 九、使用建议

### 9.1 新用户入门路径
1. 阅读 `快速入门指南.md` 或 `docs/zh/quickstart.md`
2. 运行 `./setup.sh` 安装环境
3. 使用 `./quick_record.sh` 进行第一次录音转录
4. 探索 `./workflow_controller.sh` 的其他功能

### 9.2 常规用户工作流
1. 会议记录：`./record_meeting.sh`
2. 文件转录：`./transcribe_file.sh [文件]`
3. 实时转录：`./workflow_controller.sh --workflow 2`
4. 批量处理：`./workflow_manager.sh batch_process`

### 9.3 开发者扩展
1. 研究 `src/core/simple_whisper.py` 核心类
2. 参考 `src/streaming/` 模块实现新功能
3. 使用 `src/tests/test_stream.py` 验证功能
4. 贡献到 `docs/` 文档

---

**文档版本**: 1.0
**更新日期**: 2026-02-21
**维护者**: Simple Whisper 开发团队