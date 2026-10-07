# 登录界面（UI-01）：水墨山水 + 卷轴登录面板
class_name LoginView
extends UiView

var _account_edit: LineEdit
var _password_edit: LineEdit
var _server_option: OptionButton
var _error_label: Label
var _enter_btn: Button
var _remember: CheckBox


func _make_vm() -> ViewModel:
	return LoginVm.new()


func _build() -> void:
	_build_background()
	_build_panel()


## 全屏水墨背景（cover 不露白）
func _build_background() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/bg/bg_mountain.png")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# 四角印章与云纹点缀
	var corner := TextureRect.new()
	corner.texture = load("res://assets/ui/decorations/deco_cloud_auspicious.png")
	corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	corner.position = Vector2(24, 24)
	corner.modulate.a = 0.5
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(corner)


## 中央卷轴登录面板（约 717×490）
func _build_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UiKit.ink_panel(true)
	panel.custom_minimum_size = Vector2(720, 560)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(m, 56)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	# 标题「仙途」+ 朱红印章
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 14)
	var title := UiKit.brush_title("仙途", 72)
	title_row.add_child(title)
	var seal := UiKit.seal("仙途\n印", 13)
	seal.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	title_row.add_child(seal)
	col.add_child(title_row)
	var sub := UiKit.label("古风水墨修仙 · 云海翻腾处，自有仙途", 15, UiTheme.INK_GRAY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	# 账号 / 密码
	_account_edit = LineEdit.new()
	_account_edit.placeholder_text = "账号（2 字以上）"
	_account_edit.custom_minimum_size = Vector2(400, 52)
	_account_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_account_edit)
	_password_edit = LineEdit.new()
	_password_edit.placeholder_text = "密码（至少 6 位）"
	_password_edit.secret = true
	_password_edit.custom_minimum_size = Vector2(400, 52)
	_password_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_password_edit)

	# 服务器选择 + 记住账号
	var opt_row := HBoxContainer.new()
	opt_row.add_theme_constant_override("separation", 12)
	opt_row.add_child(UiKit.label("服务器", 16, UiTheme.INK_GRAY))
	_server_option = OptionButton.new()
	_server_option.custom_minimum_size = Vector2(280, 44)
	opt_row.add_child(_server_option)
	_remember = CheckBox.new()
	_remember.text = "记住账号"
	_remember.button_pressed = true
	opt_row.add_child(_remember)
	col.add_child(opt_row)

	# 错误提示（面板内红字，不弹窗）
	_error_label = UiKit.label("", 15, UiTheme.CINNABAR)
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.custom_minimum_size = Vector2(0, 22)
	col.add_child(_error_label)

	# 进入游戏（大主按钮）
	_enter_btn = UiKit.primary_btn("进 入 仙 途", 26, true)
	_enter_btn.custom_minimum_size = Vector2(400, 78)
	_enter_btn.disabled = true
	col.add_child(_enter_btn)

	# 次级链接
	var links := HBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 28)
	for pair: Array in [["注 册", "注册功能即将开放"], ["找回密码", "请联系仙途司契（客服）"], ["用户协议", "大道三千，条款第一"]]:
		var link := UiKit.label(str(pair[0]), 15, UiTheme.INK_GRAY)
		var tip := str(pair[1])
		link.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed:
				Toast.show_text(tip))
		link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		links.add_child(link)
	col.add_child(links)

	# 版本号
	var ver := UiKit.label("v%s" % GameConfig.VERSION, 13, UiTheme.INK_FADE)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -120
	ver.offset_top = -36
	ver.offset_right = -16
	ver.offset_bottom = -12
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)

	_bind_events()


## 输入与 VM 绑定
func _bind_events() -> void:
	var lvm := vm as LoginVm
	_account_edit.text_changed.connect(func(t: String) -> void: lvm.on_input(t, _password_edit.text))
	_password_edit.text_changed.connect(func(t: String) -> void: lvm.on_input(_account_edit.text, t))
	_enter_btn.pressed.connect(func() -> void: lvm.submit(_server_option.selected))
	_password_edit.text_submitted.connect(func(_t: String) -> void: lvm.submit(_server_option.selected))
	vm.bind(&"can_submit", func(v: Variant) -> void: _enter_btn.disabled = not bool(v))
	vm.bind(&"error", func(v: Variant) -> void: _error_label.text = str(v))
	vm.bind(&"servers", func(v: Variant) -> void:
		_server_option.clear()
		for s: Variant in v:
			_server_option.add_item("%s（%s）" % [s["name"], s["state"]]))
	lvm.load_init()
