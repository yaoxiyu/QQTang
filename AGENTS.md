# QQTang 仓库规则

## 编码风格
- 无论是写新需求，还是修改bug，都要从系统化、工程化、架构化、一致性的角度来思考，而不是打补丁、绕过错误。
- 任何代码都要考虑性能、安全性、可拓展性

## 文档语言

- Codex 新生成的项目文档默认必须使用中文。
- 既有英文文档在用户要求翻译或重写时，应翻译为中文。

## GDScript 强制预检

- 在运行任何基于 GDScript 的管线、契约测试、集成测试或临时 Godot 脚本前，必须先运行 GDScript 语法预检。
- 如果语法预检报告任何 parse/load 错误，必须立即停止。修复语法错误前，不得继续运行管线或 GDScript 测试。
- 这是一条硬门禁，不是 best-effort 检查。

## 必需命令

- 语法预检：
  - `powershell -ExecutionPolicy Bypass -File tests/scripts/check_gdscript_syntax.ps1`
- 内容管线：
  - `powershell -ExecutionPolicy Bypass -File scripts/content/run_content_pipeline.ps1`
- 内容校验：
  - `powershell -ExecutionPolicy Bypass -File scripts/content/validate_content_pipeline.ps1`

## 执行顺序

1. 运行 GDScript 语法预检。
2. 只有语法预检通过后，才能运行被请求的 Godot 管线或测试命令。
3. 如果命令失败，需要说明失败属于语法、内容数据、运行时脚本还是环境问题。

## 下载和安装审批

- 以后任何下载或安装前，必须先告诉用户需要下载/安装什么，以及为什么需要。
- 必须询问用户选择由 Codex 执行下载/安装，还是由用户手动处理。
- 在用户确认选择前，不得开始下载或安装。
