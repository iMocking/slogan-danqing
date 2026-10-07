# 仙途 · 面板管理器（世界 HUD 之上的面板栈，autoload CanvasLayer）
# 打开方式：UiManager.open(&"inventory")；ESC 按栈顶逐层关闭。
extends CanvasLayer

const PANELS := {
	&"inventory": "res://src/ui/screens/inventory/inventory_view.gd",
	&"character": "res://src/ui/screens/character/character_view.gd",
	&"quest": "res://src/ui/screens/quest/quest_view.gd",
	&"skill_tree": "res://src/ui/screens/skill_tree/skill_tree_view.gd",
	&"shop": "res://src/ui/screens/shop/shop_view.gd",
	&"auction": "res://src/ui/screens/auction/auction_view.gd",
	&"world_map": "res://src/ui/screens/world_map/world_map_view.gd",
}

var _stack: Array[UiView] = []
var _scripts: Dictionary = {}


func _ready() -> void:
	layer = 20
	for id: StringName in PANELS:
		_scripts[id] = load(PANELS[id])


func _unhandled_input(p_event: InputEvent) -> void:
	if p_event.is_action_pressed("ui_cancel") and not _stack.is_empty():
		close_top()
		get_viewport().set_input_as_handled()


## 打开面板（已打开则忽略）；data 传给 _on_open
func open(p_id: StringName, p_data: Dictionary = {}) -> void:
	if _find(p_id) != null:
		return
	var script: GDScript = _scripts.get(p_id)
	if script == null:
		push_warning("未知面板：%s" % p_id)
		return
	var view: UiView = script.new()
	view.panel_id = p_id
	view.is_modal = true
	add_child(view)
	view.open(p_data)
	_stack.append(view)
	EventBus.panel_opened.emit(p_id)


## 关闭栈顶面板
func close_top() -> void:
	if _stack.is_empty():
		return
	var top: UiView = _stack.pop_back()
	EventBus.panel_closed.emit(top.panel_id)
	top.close()


## 关闭指定面板
func close(p_id: StringName) -> void:
	var v := _find(p_id)
	if v != null:
		_stack.erase(v)
		EventBus.panel_closed.emit(p_id)
		v.close()


## 切换面板（HUD 图标点击用）
func toggle(p_id: StringName, p_data: Dictionary = {}) -> void:
	if _find(p_id) != null:
		close(p_id)
	else:
		open(p_id, p_data)


func is_open(p_id: StringName) -> bool:
	return _find(p_id) != null


func _find(p_id: StringName) -> UiView:
	for v: UiView in _stack:
		if is_instance_valid(v) and v.panel_id == p_id:
			return v
	return null
