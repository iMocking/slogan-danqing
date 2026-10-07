# 仙途 · 聊天窗口控件（HUD 左下）
# 频道切换 + 消息流 + 输入发送；数据全部由外部注入（MVVM：控件不持有业务状态）。
class_name ChatBox
extends PanelContainer

signal send_text(p_text: String)
signal channel_changed(p_channel: int)
signal toggled_fold(p_folded: bool)

const CHANNELS := ["全部", "世界", "门派", "队伍", "私聊"]
const MAX_LINES := 60

var _log: RichTextLabel
var _input: LineEdit
var _channel: int = 0
var _folded: bool = false
var _full_height: int = 240


func _init() -> void:
	var sb := UiKit.tex_sb("res://assets/ui/panels/panel_ink_line.png", 42, 20, 14)
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(480, _full_height)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)

	# 标题行：频道标签 + 折叠
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var chan_label := UiKit.label("传音", 17, UiTheme.CINNABAR, true)
	head.add_child(chan_label)
	for i in range(3):
		var c := UiKit.secondary_btn(CHANNELS[i], 14)
		c.toggle_mode = true
		c.custom_minimum_size = Vector2(56, 30)
		var idx := i
		c.toggled.connect(func(on: bool) -> void:
			if on:
				_channel = idx
				channel_changed.emit(idx))
		if i == 0:
			c.button_pressed = true
		head.add_child(c)
	var spacer := UiKit.hspace()
	head.add_child(spacer)
	var fold := UiKit.secondary_btn("─", 14)
	fold.custom_minimum_size = Vector2(34, 30)
	fold.pressed.connect(func() -> void: _toggle_fold())
	head.add_child(fold)
	col.add_child(head)

	# 消息流
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 15)
	_log.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(_log)

	# 输入行
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 6)
	_input = LineEdit.new()
	_input.placeholder_text = "传音入密…（回车发送）"
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.custom_minimum_size = Vector2(0, 36)
	input_row.add_child(_input)
	var send := UiKit.primary_btn("发送", 15)
	send.custom_minimum_size = Vector2(64, 36)
	input_row.add_child(send)
	col.add_child(input_row)

	send.pressed.connect(_do_send)
	_input.text_submitted.connect(func(_t: String) -> void: _do_send())


## 整体刷新消息（历史拉取）
func set_messages(p_list: Array) -> void:
	_log.clear()
	for m: Variant in p_list:
		append_message(m)


## 追加一条消息（{sender, text, self})
func append_message(p_msg: Dictionary) -> void:
	var color := "#8B2500" if bool(p_msg.get("self", false)) else "#2C2C2C"
	var sender := str(p_msg.get("sender", ""))
	var text := str(p_msg.get("text", "")).replace("[", "［")
	_log.append_text("[color=%s][b]%s：[/b]%s[/color]\n" % [color, sender, text])
	while _log.get_paragraph_count() > MAX_LINES:
		_log.remove_paragraph(0)


func _do_send() -> void:
	var text := _input.text.strip_edges()
	if text.is_empty():
		return
	_input.clear()
	send_text.emit(text)


## 折叠 / 展开
func _toggle_fold() -> void:
	_folded = not _folded
	custom_minimum_size.y = 52 if _folded else _full_height
	toggled_fold.emit(_folded)
