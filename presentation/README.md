# presentation

## 目录定位
表现层与 bridge 层。

## 职责范围
- HUD
- 地图显示
- actor view
- presentation bridge

## 允许放入
- battle 表现脚本
- 运行时 bridge
- HUD 控制器

## 禁止放入
- 修改仿真真相
- 直接决定 battle 规则
- 网络 transport 行为

## 对外依赖
- 可依赖 gameplay runtime 输出与 content 资源
- 不反向定义 simulation 真相

## 维护约束
- 表现层只消费真相
- bridge 与具体 view 分层明确
- 不用 UI 代码篡改玩法规则
