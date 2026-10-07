# 仙途 · 全屏场景路由（autoload）
extends Node

const SCENES := {
	&"boot": "res://src/boot/boot.tscn",
	&"login": "res://src/ui/screens/login/login_view.tscn",
	&"loading": "res://src/ui/screens/loading/loading_view.tscn",
	&"char_create": "res://src/ui/screens/char_create/char_create_view.tscn",
	&"world": "res://src/world/world_scene.tscn",
}

var current_id: StringName = &"boot"


## 切换全屏场景（p_packed 传入已预载的 PackedScene 可免二次加载）
func goto(p_id: StringName, p_packed: PackedScene = null) -> void:
	var path: String = SCENES.get(p_id, "")
	if path.is_empty() and p_packed == null:
		push_warning("未知场景：%s" % p_id)
		return
	current_id = p_id
	if p_packed != null:
		get_tree().change_scene_to_packed(p_packed)
	else:
		get_tree().change_scene_to_file(path)
	EventBus.scene_changed.emit(p_id)
