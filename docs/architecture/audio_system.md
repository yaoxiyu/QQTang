# 音频子系统

## 分层

```text
external/assets/audio/
  bgm/{event,map,result,scene}/  (OGG Vorbis, 29 文件)
  sfx/{battle,event,item,ui,voice,_audit_numbered}/  (WAV PCM/OGG, 55 文件)
    -> content_source/csv/audio/audio_assets.csv
    -> tools/content_pipeline/generators/generate_audio_assets.gd
    -> content/audio/data/{bgm,sfx}/*.tres
    -> content/audio/catalog/audio_catalog.gd
    -> AudioManager (autoload)
    -> 业务代码
```

## 运行期边界

- 业务代码只能通过 `AudioManager` autoload 播放音频，不得直接 `load()` 音频资源。
- `AudioCatalog` 负责 id→资源路径映射和别名解析，业务代码不应直接调用。
- `_audit_numbered/` 下 36 个编号音效 (X05-X40) 的语义未确认，暂不直接绑定正式玩法。
- gameplay/simulation 层不应依赖音频播放，音频调用限 presentation 层。

## AudioManager 核心 API

AudioManager 是项目唯一的 autoload 单例，注册在 `project.godot` 的 `[autoload]` 节。
业务代码通过全局变量 `AudioManager` 直接调用，无需手动获取节点或依赖注入。

### BGM 控制

```gdscript
# 播放并循环 BGM，fade_in 为淡入秒数（默认 0.5s）
AudioManager.play_bgm(audio_id: String, fade_in: float = 0.5)

# 停止当前 BGM，fade_out 为淡出秒数
AudioManager.stop_bgm(fade_out: float = 0.5)

# 交叉淡入淡出到新 BGM
AudioManager.crossfade_bgm(audio_id: String, duration: float = 1.0)

# 查询当前 BGM 状态
AudioManager.is_bgm_playing() -> bool
AudioManager.get_current_bgm_id() -> String
```

### SFX 播放

```gdscript
# 单次 SFX，走 SFX 总线（16 通道池，支持同帧多实例）
AudioManager.play_sfx(audio_id: String, volume_offset_db: float = 0.0)

# 空间化 SFX（位置相关衰减）
AudioManager.play_sfx_at(audio_id: String, position: Vector2, volume_offset_db: float = 0.0)

# UI 音效，强制走 UI 总线（独立通道，低延迟）
AudioManager.play_ui_sfx(audio_id: String)
```

### 音量与静音

```gdscript
# 按总线独立控制音量
AudioManager.set_bus_volume_db(bus: AudioTypes.Bus, volume_db: float)
AudioManager.get_bus_volume_db(bus: AudioTypes.Bus) -> float

# 主音量
AudioManager.set_master_volume_db(volume_db: float)

# 全局静音
AudioManager.set_muted(muted: bool)
```

### 预加载

```gdscript
# 按 Category 预加载（提前 load 避免首次播放卡顿）
AudioManager.preload_category(category: AudioTypes.Category)

# 快捷预加载方法
AudioManager.preload_battle_sfx()   # SFX_BATTLE
AudioManager.preload_ui_sfx()       # SFX_UI
```

### 音频 ID 与别名

```gdscript
# 音频 ID 来自 content_source/csv/audio/audio_assets.csv 的 audio_id 列
AudioManager.play_bgm("desert")      # 沙漠地图 BGM
AudioManager.play_sfx("bomb_sfx")    # 炸弹爆炸 SFX
AudioManager.play_ui_sfx("uimain")   # 主按钮点击 UI 反馈

# 别名自动解析，无需关心底层文件
AudioManager.play_ui_sfx("x01")      # 等价于 play_ui_sfx("uimain")
AudioManager.play_bgm("m17")         # 等价于 play_bgm("sculpture")
```

## AudioTypes 枚举

```gdscript
AudioTypes.Bus.MASTER   # 0
AudioTypes.Bus.BGM      # 1
AudioTypes.Bus.SFX      # 2
AudioTypes.Bus.UI       # 3
AudioTypes.Bus.VOICE    # 4
AudioTypes.Bus.EVENT    # 5

AudioTypes.Category.BGM_MAP          # 地图主题 BGM
AudioTypes.Category.BGM_SCENE        # 场景/大厅 BGM
AudioTypes.Category.BGM_RESULT       # 结算 BGM
AudioTypes.Category.BGM_EVENT        # 活动 BGM
AudioTypes.Category.SFX_BATTLE       # 战斗 SFX
AudioTypes.Category.SFX_UI           # UI SFX
AudioTypes.Category.SFX_ITEM         # 道具 SFX
AudioTypes.Category.SFX_VOICE        # 角色语音 SFX
AudioTypes.Category.SFX_EVENT        # 活动 SFX
AudioTypes.Category.SFX_NUMBERED_*   # 未命名编号（审计中，暂不绑定正式逻辑）
```

## 音频总线布局

```
Master (0)
  ├── BGM (1)   — 双 AudioStreamPlayer 交替，支持无缝交叉淡入淡出
  ├── SFX (2)   — 16 通道 round-robin 池，支持同帧多实例（爆炸）
  ├── UI (3)    — 独立通道，UI 反馈低延迟
  ├── Voice (4) — 角色语音/表情
  └── Event (5) — 活动/婚礼等特殊音效
```

总线和 AudioStreamPlayer 节点由 `AudioManager._ready()` 动态创建，不在场景中放置。

## 已知 BGM ID 速查（MapTheme 对应）

| MapTheme theme_id | BGM audio_id |
|---|---|
| bomb | bomb_bgm |
| bun | bun |
| desert | desert |
| field | field |
| machine | machine |
| mine | mine |
| sculpture | sculpture |
| snow | snow |
| tank | tank |
| town | town |
| water | water |
| match | match |
| common/default | scene1 |

> `MapThemeDef.bgm_key` 字段已存在但当前为死字段。后续接入 BGM 时将 `bgm_key` 值传入 `AudioManager.play_bgm()`。

## 已知 SFX ID 速查（按用途）

| 用途 | audio_id |
|---|---|
| 炸弹爆炸 | bomb_sfx |
| 战斗开始 | ready_go |
| 眩晕状态 | xuanyun |
| 火花出现 | sparkcome |
| 火花失败 | sparkfail |
| 割裂/受击 | gelie |
| 飞行/投射 | fly |
| UI 主点击 | uimain |
| UI 普通点击 | uinormal |
| UI 返回 | uileave |
| UI 错误 | uifail |
| 合药/合成 | heyao |
| 卷轴使用 | juanzhou |
| 驱散/净化 | qusan |
| 哭泣表情 | cry |
| 笑声表情 | laugh |
| 婚礼爱心火 | lovefire |
| 婚礼结束 | weddingover |
| 离婚确认 | divorceok |

## 添加新音频资产的流程

1. 将音频文件放入 `external/assets/audio/` 下对应子目录
2. 在 `content_source/csv/audio/audio_assets.csv` 添加一行
3. 运行内容管线重新生成 `.tres`
4. 业务代码通过 `AudioManager.play_xxx(audio_id)` 调用

## 验证入口

```powershell
# 语法预检
powershell -ExecutionPolicy Bypass -File tests/scripts/check_gdscript_syntax.ps1

# 内容管线（含音频 .tres 生成）
powershell -ExecutionPolicy Bypass -File scripts/content/run_content_pipeline.ps1
```

## 风险与债务

| 项 | 说明 |
|---|---|
| BGM loop 点未验证 | 29 首 BGM 的 OGG 无缝循环点需在编辑器中逐首检查 |
| 编号音效语义未确认 | 36 个 X05-X40 音效需试听审计后赋予语义 id |
| WAV 体积 | 高频短 SFX 保持 WAV；长音效后续可转 OGG 减小包体 |
| 音频授权 | 原始 QQTang 音频仅用于学习研究，商业发布需替换或取得授权 |
