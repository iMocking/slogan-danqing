# 仙途 · 全局提示层（Toast / 飘字，autoload）
extends CanvasLayer

const SHOW_SECONDS := 2.4
const MAX_VISIBLE := 4

var _box: VBoxContainer


func _ready() -> void:
	layer = 50
	_box = VBoxContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_box.offset_top = 80
	_box.offset_left = -280
	_box.offset_right = 280
	_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_box.add_theme_constant_override("separation", 8)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	# 服务端推送的 toast 直通显示
	GameServer.pushed.connect(func(route: String, body: Dictionary) -> void:
		if route == "toast" and body.has("body"):
			var b: Dictionary = body["body"]
			show_text(str(b.get("text", "")), int(b.get("kind", 0))))


## 显示一条提示：kind 0=普通墨色 1=警示朱红
func show_text(p_text: String, p_kind: int = 0) -> void:
	if p_text.is_empty():
		return
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.17, 0.17, 0.88) if p_kind == 0 else Color(0.55, 0.15, 0.0, 0.92)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var label := Label.new()
	label.text = p_text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", UiTheme.PAPER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	_box.add_child(panel)
	# 超出数量时移除最旧
	while _box.get_child_count() > MAX_VISIBLE:
		_box.get_child(0).free()
	var tween := create_tween()
	panel.modulate.a = 0.0
	tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	tween.tween_interval(SHOW_SECONDS)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_callback(panel.queue_free)
