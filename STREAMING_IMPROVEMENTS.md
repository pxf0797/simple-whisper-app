# 流式转录功能改进说明

## 问题背景
用户报告流式转录（Live Streaming Transcription）功能存在以下问题：
1. 转录文本和录音没有保存在 `record/` 文件夹中
2. 保存的转录文本没有包含实时显示的时间戳分段信息

## 解决方案

### 1. 修复文件保存路径问题
**问题**：流式转录文件保存到错误的目录（`scripts/workflow/record/` 而不是项目根目录的 `record/`）

**修改文件**：`scripts/workflow/workflow_controller.sh`

**修改内容**：
- 将相对路径 `record/` 改为绝对路径 `$PROJECT_ROOT/record/`
- 为文件路径添加双引号，防止路径中的空格问题
- 修复了两个工作流的文件保存：
  - `execute_quick_record()` - 快速录制
  - `execute_live_streaming()` - 流式转录

**修改后效果**：
- 音频文件：`/Users/xfpan/claude/simple-whisper-app/record/streaming_YYYYMMDD_HHMMSS.wav`
- 转录文件：`/Users/xfpan/claude/simple-whisper-app/record/streaming_YYYYMMDD_HHMMSS_transcription.txt`

### 2. 添加流式音频录制功能
**问题**：流式转录原本只保存转录文本，不保存录音

**修改文件**：`src/streaming/stream_whisper.py`

**修改内容**：
1. 添加 `soundfile` 库导入
2. 在 `__init__` 方法中添加 `output_audio` 参数
3. 在 `start_streaming()` 中打开音频文件（WAV格式，16位PCM）
4. 在 `_audio_callback()` 中实时写入音频数据
5. 在 `stop_streaming()` 中关闭音频文件并确认保存

**新增功能**：
- 流式转录时实时录制音频到WAV文件
- 音频质量：16位PCM，单声道，16kHz采样率

### 3. 添加时间戳分段保存功能
**问题**：保存的转录文本只有合并后的文本，没有实时显示的时间戳分段信息

**修改文件**：
- `src/streaming/stream_whisper.py`
- `src/core/simple_whisper.py`

**修改内容**：
1. 在 `stream_whisper.py` 中增强 `get_full_transcription()` 方法：
   - 添加 `with_timestamps` 和 `start_time` 参数
   - 当启用时间戳时，返回格式为 `[3.8s] 正在等待中考初分的這個時候` 的分段文本
   - 新增 `get_transcription_context()` 方法获取完整的转录上下文

2. 在 `simple_whisper.py` 中修改流式转录保存逻辑：
   - 保存包含时间戳分段的完整转录文本
   - 创建分段数据（segments）包含开始时间、结束时间和文本
   - 保持与实时显示完全一致的格式

**保存的文件格式**：
```
[3.8s] 正在等待中考初分的這個時候
[5.5s] 不分的这个时候然后反正那个我觉得
[7.6s] 反正那個我覺得孩子也不是不努力吧反正就是
[9.6s] 反正就是現在競爭很殘酷他就上不了
...
```

### 4. 简体中文转换支持
**新增功能**：自动将繁体中文转换为简体中文

**实现方式**：
- 使用 `zhconv` 库进行转换
- 在保存转录文本时自动检测并转换中文文本
- 提供友好的安装提示

**安装依赖**（可选）：
```bash
pip install zhconv
```

## 技术细节

### 文件保存流程
1. 工作流控制器生成带时间戳的文件名
2. 流式转录启动时打开音频文件进行录制
3. 实时转录每个音频块（默认3秒，重叠1秒）
4. 转录结果带时间戳存储到上下文
5. 转录停止后保存带时间戳的完整文本到文件
6. 关闭音频文件并确认保存

### 时间戳计算
- 每个音频块的处理时间戳来自 `time.time()`
- 相对时间基于流式转录开始时间计算
- 分段持续时间基于 `chunk_duration` 参数

### 配置信息显示
流式转录启动时显示完整的配置信息：
```
Streaming configuration:
  Model: medium
  Language: zh
  Simplified Chinese: yes
  Audio device: 5
  Computation device: mps
  Duration: 30 seconds
  Chunk duration: 3.0 seconds
  Overlap: 1.0 seconds
  Text output: /Users/xfpan/claude/simple-whisper-app/record/streaming_20260222_093028_transcription.txt
  Audio output: /Users/xfpan/claude/simple-whisper-app/record/streaming_20260222_093028.wav
```

## 测试验证

### 验证步骤
1. 运行流式转录：`./scripts/workflow/workflow_controller.sh`
2. 选择选项2（Live Streaming Transcription）
3. 选择自定义配置或使用默认配置
4. 观察配置信息中的文件路径
5. 转录完成后检查 `record/` 目录

### 预期结果
1. 正确保存音频文件到项目根目录的 `record/` 文件夹
2. 转录文本文件包含完整的时间戳分段
3. 文件格式与实时显示完全一致
4. 音频文件为有效的WAV格式

## 兼容性说明

### 向后兼容
- 非流式转录功能不受影响
- 现有脚本和命令行参数保持兼容
- 工作流控制器界面保持不变

### 新增参数
- `StreamWhisper.__init__()` 新增 `output_audio` 参数
- `get_full_transcription()` 新增 `with_timestamps` 和 `start_time` 参数

## 已知限制
1. 音频录制会增加少量CPU和磁盘IO开销
2. 长时间录制可能生成较大的WAV文件
3. 简体中文转换需要额外安装 `zhconv` 库
4. 时间戳精度受音频块处理延迟影响

## 后续改进建议
1. 添加音频文件格式选项（MP3、FLAC等）
2. 实现实时分段保存（无需等待转录结束）
3. 添加转录质量评估指标
4. 支持更多语言和方言识别