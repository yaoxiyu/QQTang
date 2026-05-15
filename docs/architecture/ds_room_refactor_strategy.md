# DS Bootstrap 与 RoomApp 渐进治理策略

## 背景

`battle_dedicated_server_bootstrap.gd` 与 `roomapp` 仍有较多共享状态与流程耦合。  
当单次拆分会牵动 10+ 共享字段、显著提升回归风险时，不做低性价比硬拆。

## 本阶段原则

1. 先保边界，再拆文件：先固定输入输出契约、错误码与日志语义。
2. 保留 dev 后门：`dev_mode` 路径保留快速验证能力，但必须与 prod 隔离。
3. 小步收敛：每次只移动一个职责块，并配套最小回归测试。

## 已落地约束

1. DS 启动参数解析集中到 `ds_launch_config.gd`。
2. 生命周期上报集中到 `ds_lifecycle_reporter.gd`。
3. 遗留 `--qqt-battle-ticket-secret` 仅允许 dev/显式开关使用，非 dev 默认阻断。
4. 生产环境（`QQT_RUNTIME_ENV/QQT_ENV/DSM_ENV/ROOM_ENV=production|prod`）禁止使用 dev 弱 secret 启动 DS。
5. room_service 在生产环境强制 `ROOM_DEPLOYMENT_MODE=single_instance` 且 `ROOM_EXPECTED_REPLICAS=1`。

## 后续拆分建议（按收益顺序）

1. 把 battle entry / resume 校验逻辑下沉为独立服务对象（只暴露纯函数接口）。
2. 把 transport message routing 映射表化，避免 bootstrap 持续增长。
3. 把 manifest 适配与 battle runtime 绑定拆成独立 binder。
4. roomapp 继续按 `lifecycle / battle / matchmaking / sync` 维度拆分，保留 `service.go` 门面。
