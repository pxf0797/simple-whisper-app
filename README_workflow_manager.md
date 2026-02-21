# Advanced Workflow Manager - workflow_manager.sh

## 概述

`workflow_manager.sh` 是一个高级工作流管理脚本，基于 `quick_record.sh` 的设计理念，提供了全面的工作流控制功能。它支持任务序列化、条件执行、错误恢复、配置管理和系统监控。

## 设计理念

- **基于 `quick_record.sh` 的交互式体验**：保留了直观的参数选择和菜单系统
- **工作流自动化**：支持预定义工作流和自定义任务序列
- **配置驱动**：JSON配置文件管理，支持工作流和任务定义
- **全面的错误处理**：多层错误检测和恢复机制
- **监控和诊断**：内置系统监控和诊断工具

## 主要特性

### 1. 预定义工作流
- **快速录音工作流**：交互式参数选择 → 录音 → 转录 → 保存输出
- **实时流式工作流**：流式参数配置 → 启动流式转录 → 监控
- **批处理工作流**：选择输入目录 → 批量处理 → 生成报告
- **系统测试工作流**：环境检查 → 音频测试 → 模型测试 → 诊断报告

### 2. 配置管理
- **工作流配置**：JSON格式的工作流定义
- **任务定义**：可扩展的任务库
- **自动备份**：配置文件的自动备份和恢复

### 3. 监控工具
- **日志查看**：实时日志监控和历史日志查询
- **资源监控**：CPU、内存、磁盘使用情况
- **系统诊断**：音频设备检测、模型加载测试
- **清理工具**：临时文件和日志清理

### 4. 错误处理
- **环境检测**：自动检测和修复环境问题
- **依赖检查**：缺失依赖的自动安装
- **任务重试**：失败任务的可配置重试机制
- **优雅降级**：模块缺失时的替代方案

## 安装与使用

### 1. 添加执行权限
```bash
chmod +x workflow_manager.sh
```

### 2. 运行方式

#### 交互式菜单模式（推荐）
```bash
./workflow_manager.sh
```

#### 直接执行工作流
```bash
./workflow_manager.sh quick_record      # 快速录音工作流
./workflow_manager.sh stream_live       # 实时流式工作流
./workflow_manager.sh batch_process     # 批处理工作流
./workflow_manager.sh system_test       # 系统测试工作流
```

#### 工具选项
```bash
./workflow_manager.sh --config          # 查看配置
./workflow_manager.sh --logs            # 查看日志
./workflow_manager.sh --cleanup         # 清理临时文件
./workflow_manager.sh --test            # 运行快速测试
./workflow_manager.sh --help            # 查看帮助
```

## 工作流详解

### 快速录音工作流 (quick_record)
```
1. 环境检查 → 2. 参数选择 → 3. 录音 → 4. 转录 → 5. 保存输出
```

**特点**：
- 交互式参数选择（模型、语言、时长等）
- 自动生成时间戳文件名
- 完整的错误处理和恢复
- 生成执行报告

**使用场景**：会议录音、访谈记录、讲座录制

### 实时流式工作流 (stream_live)
```
1. 环境检查 → 2. 流式配置 → 3. 启动流式 → 4. 监控
```

**特点**：
- 实时音频流处理
- 可配置的分块大小和重叠
- 低延迟转录（3-5秒）
- 长时间运行支持

**使用场景**：实时字幕、语音转文字直播、会议实时转录

### 批处理工作流 (batch_process)
```
1. 环境检查 → 2. 目录选择 → 3. 批量处理 → 4. 生成报告
```

**特点**：
- 支持多种音频格式（.wav, .mp3, .m4a）
- 自定义输入/输出目录
- 进度跟踪和错误处理
- 批量处理报告

**使用场景**：处理历史录音、批量转录、数据整理

### 系统测试工作流 (system_test)
```
1. 环境检查 → 2. 音频测试 → 3. 模型测试 → 4. 诊断报告
```

**特点**：
- 全面的系统验证
- 环境、音频、模型测试
- 详细的诊断报告
- 问题识别和建议

**使用场景**：故障排除、系统验证、性能测试

## 配置系统

### 配置文件结构
```
simple-whisper-app/config/
├── workflow_config.json     # 工作流定义
├── task_definitions.json    # 任务定义
└── backup_*/               # 配置备份
```

### 工作流配置示例
```json
{
    "workflows": {
        "quick_record": {
            "description": "Quick recording workflow",
            "tasks": ["check_env", "select_params", "record_audio", "transcribe", "save_outputs"]
        }
    },
    "settings": {
        "default_model": "base",
        "default_language": "auto",
        "max_retries": 3,
        "retry_delay": 5
    }
}
```

### 任务定义示例
```json
{
    "tasks": {
        "check_env": {
            "description": "Check environment and dependencies",
            "command": "check_environment",
            "type": "internal"
        },
        "record_audio": {
            "description": "Record audio",
            "command": "record_audio_task",
            "type": "execution"
        }
    }
}
```

## 日志系统

### 日志文件位置
```
simple-whisper-app/logs/
└── workflow_manager_YYYYMMDD_HHMMSS.log
```

### 日志级别
- **INFO**：常规操作信息
- **WARN**：警告信息
- **ERROR**：错误信息
- **DEBUG**：调试信息
- **TASK**：任务执行信息

### 日志查看
```bash
# 查看最新日志
tail -f logs/workflow_manager_*.log

# 通过脚本查看
./workflow_manager.sh --logs
```

## 错误处理与恢复

### 自动恢复机制
1. **环境错误**：缺失依赖时提供安装选项
2. **模块错误**：模块缺失时提供替代方案
3. **执行错误**：失败任务的重试机制
4. **资源错误**：资源不足时的清理建议

### 手动恢复
```bash
# 查看错误详情
tail -50 logs/workflow_manager_*.log

# 运行系统测试
./workflow_manager.sh system_test

# 清理临时文件
./workflow_manager.sh --cleanup
```

## 监控与维护

### 系统监控
```bash
# 查看资源使用
./workflow_manager.sh
# 选择选项6 → 选项2

# 检查磁盘空间
./workflow_manager.sh
# 选择选项6 → 选项3

# 测试音频设备
./workflow_manager.sh
# 选择选项6 → 选项5
```

### 定期维护
1. **日志清理**：自动保留最近10个日志文件
2. **临时文件清理**：自动清理旧的临时文件
3. **配置备份**：配置更改时自动备份
4. **依赖更新**：定期检查依赖更新

## 与现有脚本的集成

### 与 quick_record.sh 的关系
- 保留了 `quick_record.sh` 的交互式参数选择
- 扩展了错误处理和恢复机制
- 添加了工作流自动化功能

### 与其它脚本的关系
- **录音功能**：调用 `simple_whisper.py --record`
- **流式功能**：调用 `stream_whisper.py`
- **批处理功能**：调用 `batch_transcribe.py` 或内置批处理
- **测试功能**：集成各种测试脚本的功能

## 性能优化

### 环境优化
- 虚拟环境自动激活
- 依赖的懒加载
- 模型缓存利用

### 执行优化
- 任务并行化（未来版本）
- 增量处理
- 资源使用监控

## 使用示例

### 示例1：快速会议录音
```bash
./workflow_manager.sh quick_record
# 交互式选择：模型(base)，语言(自动)，时长(3600秒)
# 自动执行：录音 → 转录 → 保存 → 生成报告
```

### 示例2：实时讲座转录
```bash
./workflow_manager.sh stream_live
# 配置：模型(tiny)，时长(7200秒)，分块(3.0秒)，重叠(1.0秒)
# 启动实时流式转录
```

### 示例3：批量处理历史录音
```bash
./workflow_manager.sh batch_process
# 选择输入目录：recordings/
# 选择输出目录：transcripts/
# 选择模型：base
# 开始批量处理
```

### 示例4：系统故障排除
```bash
./workflow_manager.sh system_test
# 运行完整的系统测试套件
# 生成诊断报告
# 根据建议修复问题
```

## 故障排除

### 常见问题

1. **"Configuration file not found"**
   ```bash
   # 脚本会自动创建默认配置
   ./workflow_manager.sh --config
   ```

2. **"Python dependencies missing"**
   ```bash
   # 运行系统测试工作流会自动修复
   ./workflow_manager.sh system_test
   ```

3. **"No audio devices detected"**
   ```bash
   ./workflow_manager.sh
   # 选择选项6 → 选项5
   ```

4. **"Model loading failed"**
   ```bash
   ./workflow_manager.sh
   # 选择选项6 → 选项6
   ```

5. **"Disk space low"**
   ```bash
   ./workflow_manager.sh
   # 选择选项6 → 选项3
   # 选择选项6 → 选项4 清理临时文件
   ```

### 获取帮助
```bash
# 查看详细帮助
./workflow_manager.sh --help

# 查看配置
./workflow_manager.sh --config

# 查看日志
./workflow_manager.sh --logs
```

## 扩展与定制

### 添加新工作流
1. 编辑 `config/workflow_config.json`
2. 添加新的工作流定义
3. 在脚本中添加对应的执行函数
4. 更新任务定义（可选）

### 添加新任务
1. 编辑 `config/task_definitions.json`
2. 添加新的任务定义
3. 在脚本中实现任务函数
4. 更新工作流定义（可选）

### 自定义配置
```bash
# 环境变量覆盖
export DEFAULT_MODEL="small"
export LOG_LEVEL="DEBUG"

# 配置文件编辑
vim config/workflow_config.json
```

## 更新日志

### v1.0 (2026-02-21)
- 初始版本发布
- 4个预定义工作流
- JSON配置系统
- 全面的监控工具
- 错误处理和恢复机制
- 与现有脚本集成

## 未来计划

### 短期计划
- 更多预定义工作流
- 任务并行执行
- 实时进度显示
- 电子邮件通知

### 长期计划
- Web控制界面
- 远程监控
- 机器学习优化
- 云集成

## 技术支持

- **文档**：查看本README文件
- **日志**：`tail -f logs/workflow_manager_*.log`
- **测试**：`./workflow_manager.sh system_test`
- **配置**：`./workflow_manager.sh --config`

## 许可证

与 Simple Whisper 应用相同（MIT许可证）。

---

**提示**：首次使用建议运行系统测试工作流验证所有功能！