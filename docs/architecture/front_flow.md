# Front Flow

## 目的
定义前台流程解释权：Boot/Login/Lobby/Room/Loading/Battle 的职责边界与编排顺序。  
本文件不定义底层仿真规则与服务端协议细节。

## 场景职责
- `boot_scene`：runtime 初始化与注入。
- `login_scene`：认证与端点输入，不承载 loadout 逻辑。
- `lobby_scene`：大厅入口、Practice/Online/Create/Join 流程编排。
- `room_scene`：房间状态消费、成员/配置交互、进入 loading。
- `loading_scene`：普通开局与 resume/battle-entry 的中转状态机。
- `battle_main`：战斗表现入口与 runtime 消费。

## 正式流程
1. Boot 初始化 runtime。
2. Login 完成认证。
3. Lobby 选择进入房间路径（practice/private/public/match）。
4. Room 消费权威快照并发起开始/匹配/重连动作。
5. Loading 处理提交、resume 或 battle-entry ticket。
6. Battle 进入正式战斗流程；结算后按策略返回源房间或 lobby。

## 关键约束
- Room UI 只消费权威房间状态，不伪造 `mode_id/map/rule` 真相。
- Resume 流程必须显式区分 `normal_start` 与 `resume_match`。
- 进入 battle 的 ticket/request 逻辑必须集中在 use case 层，不散落 UI 控制器。
- 前台调试能力必须显式开关，不得默认污染正式流程。
