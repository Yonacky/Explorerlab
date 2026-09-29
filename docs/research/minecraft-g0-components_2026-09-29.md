# G0 现成组件接入记录

本记录按 v2.0 实验方案的 screen-only、低级键鼠和有效 tick 合同评估工程组件。组件能启动不等于 G0 通过，所有实验臂最终必须共享同一冻结版本和调用路径。

世界时钟首选 [Fabric Carpet 1.4.112](https://github.com/gnembon/fabric-carpet/releases/tag/1.4.112)。该官方发布件标注支持 Minecraft 1.20.1、Fabric Loader ≥0.14.18、Java ≥17；本机隔离实例使用 Fabric Loader 0.19.5/JDK 17。已复制发布 JAR 到实例 `mods`，仓库锁定文件记录 SHA-256。Carpet 提供 [`/tick freeze` 与 `/tick step`](https://github.com/gnembon/fabric-carpet/wiki/Commands)，但冻结时玩家可继续自由移动，故仍须验证模型思考时无输入、玩家状态不漂移，以及执行块的实际 tick 与请求 tick 一致。当前尚未启动加载该 JAR，未验收命令权限、客户端动画、异常释放和 1,000 输入块。

截图桥选用 OBS Studio 的[指定窗口采集](https://obsproject.com/kb/window-capture-sources)及内置 obs-websocket [`GetSourceScreenshot`](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md) 作为下一实现目标。OBS 的窗口采集只取指定窗口，即使其他窗口遮挡也可读取；其[游戏采集](https://obsproject.com/kb/game-capture-source)优先针对 OpenGL，但需要在本机实测 Minecraft 焦点切换、菜单暂停和窗口缩放。OBS 尚未安装或配置，不能把 Codex 的开发期窗口截图当成智能体运行接口。旧 `capture-game.py` 只作为交互式诊断工具，不用于确认实验。

键鼠执行器还需选型与实测。现有 `pydirectinput` 对新版本 Minecraft 的视角移动有[公开故障记录](https://github.com/learncodebygaming/pydirectinput/issues/17)，因此不在未测前列为可靠执行器。低级动作合同不放宽为 Mineflayer 语义 API；若采用客户端注入或 Windows `SendInput`，必须以画面反馈、焦点保护、超时释放和重复输入块验收，且不得向 agent 返回隐藏游戏状态。
