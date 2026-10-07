# 创建角色界面（UI-11）：左预览 + 右卷轴定制面板
class_name CharCreateView
extends UiView

const NAME_MAX := 12

var _name_edit: LineEdit
var _opt_rows: Dictionary = {}       # group_key -> Array[Button]
var _error_label: Label
var _submit_btn: Button


func _make_vm() -> ViewModel:
	return CharCreateVm.new()


func _build() -> void:
	_build_background()
	# 左上返回
	var back := UiKit.secondary_btn("〈 返 回", 18)
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	back.offset_left = 32
	back.offset_top = 28
	back.offset_right = 160
	back.offset_bottom = 76
	back.pressed.connect(func() -> void: SceneRouter.goto(&"login"))
	add_child(back)
	# 主布局：左预览 55% + 右面板 45%
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 40
	row.offset_right = -40
	row.offset_top = 40
	row.offset_bottom = -30
	add_child(row)
	_build_preview(row)
	_build_panel(row)

	var ccvm := vm as CharCreateVm
	_name_edit.text_changed.connect(func(t: String) -> void: ccvm.on_input(t))
	_submit_btn.pressed.connect(func() -> void: ccvm.submit())
	vm.bind(&"can_submit", func(v: Variant) -> void: _submit_btn.disabled = not bool(v))
	vm.bind(&"error", func(v: Variant) -> void: _error_label.text = str(v))
	vm.bind(&"options", func(_v: Variant) -> void: _fill_groups())
	vm.bind(&"cname", func(v: Variant) -> void:
		if _name_edit.text != str(v):
			_name_edit.text = str(v))
	for k: String in CharCreateVm.DEFAULT_SELS:
		var key := k
		vm.bind(StringName(k), func(_v: Variant) -> void: _refresh_group_buttons(StringName(key)))
	ccvm.load_options()


## 水墨底 + 圆形光晕角色预览
func _build_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/bg/bg_cloud.png")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _build_preview(p_row: HBoxContainer) -> void:
	var left := CenterContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_row.add_child(left)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(640, 720)
	left.add_child(stack)
	var halo := TextureRect.new()
	halo.texture = load("res://assets/ui/icons/frames/frame_circle.png")
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	halo.modulate.a = 0.9
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(halo)
	var portrait := TextureRect.new()
	portrait.texture = load("res://assets/ui/shots/portrait_main.png")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 110
	portrait.offset_right = -110
	portrait.offset_top = 30
	portrait.offset_bottom = -50
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(portrait)
	var hint := UiKit.label("（预览形象 · 云雾缭绕）", 15, UiTheme.INK_GRAY)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -40
	hint.offset_left = -160
	hint.offset_right = 160
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(hint)


## 右侧卷轴定制面板
func _build_panel(p_row: HBoxContainer) -> void:
	var right := CenterContainer.new()
	right.custom_minimum_size = Vector2(620, 0)
	p_row.add_child(right)
	var panel := UiKit.ink_panel(true)
	panel.custom_minimum_size = Vector2(580, 880)
	right.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	col.add_child(UiKit.brush_title("捏 人 · 塑 仙 躯", 34))
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	name_row.add_child(UiKit.label("道号", 18, UiTheme.INK_GRAY))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "2-12 字道号"
	_name_edit.max_length = NAME_MAX
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.custom_minimum_size = Vector2(0, 48)
	name_row.add_child(_name_edit)
	col.add_child(name_row)

	# 六组选项：由 VM options 驱动填充
	for g: Dictionary in CharCreateVm.GROUPS:
		col.add_child(_build_option_group(g))

	_error_label = UiKit.label("", 15, UiTheme.CINNABAR)
	_error_label.custom_minimum_size = Vector2(0, 20)
	col.add_child(_error_label)

	# 底部：重设 + 踏入仙途
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	var reset_btn := UiKit.secondary_btn("重 设", 20)
	reset_btn.custom_minimum_size = Vector2(160, 72)
	reset_btn.pressed.connect(func() -> void:
		# 二次确认（模态确认弹窗）
		_confirm_reset())
	btn_row.add_child(reset_btn)
	_submit_btn = UiKit.primary_btn("踏 入 仙 途", 24, true)
	_submit_btn.custom_minimum_size = Vector2(300, 72)
	_submit_btn.disabled = true
	btn_row.add_child(_submit_btn)
	col.add_child(btn_row)


func _build_option_group(p_g: Dictionary) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(UiKit.label(str(p_g["title"]), 17, UiTheme.INK_GRAY))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	_opt_rows[StringName(str(p_g["key"]))] = {"row": row, "options": StringName(str(p_g["options"]))}
	return col


## options 数据到达后生成各组的选项按钮
func _fill_groups() -> void:
	var opts: Dictionary = vm.prop(&"options")
	for key: StringName in _opt_rows:
		var info: Dictionary = _opt_rows[key]
		var row: HBoxContainer = info["row"]
		for c: Node in row.get_children():
			c.free()
		var list: Array = opts.get(str(info["options"]), [])
		for opt: Variant in list:
			var oid := str(opt["id"])
			var b := UiKit.secondary_btn(str(opt["name"]), 16)
			b.toggle_mode = true
			b.custom_minimum_size = Vector2(0, 42)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var prop_key := key
			b.pressed.connect(func() -> void:
				# 手动单选：按下即选中
				(vm as CharCreateVm).select(prop_key, oid)
				_refresh_group_buttons(prop_key))
			row.add_child(b)
		_refresh_group_buttons(key)


## 刷新某组按钮选中态
func _refresh_group_buttons(p_key: StringName) -> void:
	if not _opt_rows.has(p_key):
		return
	var info: Dictionary = _opt_rows[p_key]
	var current := str(vm.prop(p_key))
	var i := 0
	for c: Node in (info["row"] as HBoxContainer).get_children():
		if c is Button:
			(c as Button).set_pressed_no_signal(str(vm.prop(p_key)) == _option_id(p_key, i))
		i += 1


## 该组第 i 个按钮的选项 id
func _option_id(p_key: StringName, p_idx: int) -> String:
	var info: Dictionary = _opt_rows[p_key]
	var list: Array = (vm.prop(&"options") as Dictionary).get(str(info["options"]), [])
	if p_idx >= list.size():
		return ""
	return str(list[p_idx]["id"])


func _confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "确定要重设全部捏人选项吗？"
	dialog.ok_button_text = "确 定"
	dialog.cancel_button_text = "取 消"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void: (vm as CharCreateVm).reset())
	dialog.popup_centered()
