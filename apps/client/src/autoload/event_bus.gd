# 仙途 · 全局事件总线（仅承载 UI 层信号，业务事件走 GameServer 推送）
extends Node

## 请求发出前（用于全局 loading 指示）
signal rpc_started(route: String)
## 请求结束
signal rpc_finished(route: String)
## 面板栈变化（供 HUD 高亮等）
signal panel_opened(panel_id: StringName)
signal panel_closed(panel_id: StringName)
## 全屏场景切换完成
signal scene_changed(scene_id: StringName)
