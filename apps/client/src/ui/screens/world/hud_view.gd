# 世界主界面 HUD（UI-03）：状态栏 / 小地图 / 聊天 / 技能栏 / 系统菜单
class_name HudView
extends UiView

const MENU_BTNS := [
	{"icon": "icon_func_backpack", "panel": "inventory", "tip": "乾坤袋(B)"},
	{"icon": "icon_func_character", "panel": "character", "tip": "角色(C)"},
	{"icon": "icon_func_quest", "panel": "quest", "tip": "任务录(Q)"},
	{"icon": "icon_func_shop", "panel": "shop", "tip": "聚宝阁"},
	{"icon": "icon_func_settings", "panel": "", "tip": "打坐恢复"},
]
const SKILL_COUNT := 8

var _name_label: Label
var _realm_label: Label
var _hp_bar: ProgressBar
var _hp_text: Label
var _mp_bar: ProgressBar
var _mp_text: Label
var _slots: Array[SkillSlot] = []
var _chat: ChatBox
var _tracker: Label


func _make_vm() -> ViewModel:
	return HudVm.new()


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_status()
	_build_minimap()
	_build_tracker()
	_build_chat()
	_build_skillbar()
	_build_menu()
	var hvm := vm as HudVm
	vm.bind(&"char", func(v: Variant) -> void: _refresh_char(v))
	vm.bind(&"known_skills", func(v: Variant) -> void: _refresh_skills(v))
	vm.bind(&"messages", func(v: Variant) -> void: _chat.set_messages(v))
	vm.bind(&"tracked_quest", func(v: Variant) -> void: _refresh_tracker(v))
	hvm.load_init()


## 左上：头像 + 名字 + 境界 + 气血/真元
func _build_status() -> void:
	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	box.offset_left = 32
	box.offset_top = 24
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var avatar := TextureRect.new()
	avatar.texture = load("res://assets/ui/controls/ctrl_avatar_md.png")
	avatar.custom_minimum_size = Vector2(72, 72)
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(avatar)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	box.add_child(col)
	_name_label = UiKit.label("", 20, UiTheme.INK, true)
	col.add_child(_name_label)
	_realm_label = UiKit.label("", 14, UiTheme.INK_GRAY)
	col.add_child(_realm_label)
	_hp_bar = UiKit.ink_bar(UiTheme.HP_GREEN, Vector2(298, 26))
	col.add_child(_hp_bar)
	_hp_text = UiKit.label("", 13, UiTheme.PAPER)
	_hp_text.position = Vector2(118, 2)
	_hp_bar.add_child(_hp_text)
	_mp_bar = UiKit.ink_bar(UiTheme.MP_BLUE, Vector2(298, 26))
	col.add_child(_mp_bar)
	_mp_text = UiKit.label("", 13, UiTheme.PAPER)
	_mp_text.position = Vector2(118, 2)
	_mp_bar.add_child(_mp_text)


## 右上：圆形小地图 + 地图/设置按钮
func _build_minimap() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -232
	box.offset_top = 24
	box.offset_right = -32
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_END
	add_child(box)
	var map_btn := TextureButton.new()
	map_btn.texture_normal = load("res://assets/ui/shots/minimap.png")
	map_btn.custom_minimum_size = Vector2(160, 160)
	map_btn.ignore_texture_size = true
	map_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	map_btn.tooltip_text = "世界大地图(M)"
	map_btn.pressed.connect(func() -> void: UiManager.toggle(&"world_map"))
	var wrap := CenterContainer.new()
	wrap.custom_minimum_size = Vector2(200, 160)
	wrap.add_child(map_btn)
	box.add_child(wrap)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for spec: Array in [["icon_func_map", &"world_map"], ["icon_func_settings", &""]]:
		var b := _func_icon(str(spec[0]), 44)
		var pid: StringName = spec[1]
		if pid != &"":
			b.pressed.connect(func() -> void: UiManager.toggle(pid))
		row.add_child(b)
	box.add_child(row)


## 追踪任务条（小地图下方）
func _build_tracker() -> void:
	_tracker = UiKit.label("", 15, UiTheme.INK)
	_tracker.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_tracker.offset_left = -352
	_tracker.offset_top = 224
	_tracker.offset_right = -32
	_tracker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tracker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_tracker)


## 左下：聊天
func _build_chat() -> void:
	_chat = ChatBox.new()
	_chat.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_chat.offset_left = 32
	_chat.offset_top = -272
	_chat.offset_right = 512
	_chat.offset_bottom = -32
	add_child(_chat)
	_chat.send_text.connect(func(t: String) -> void: (vm as HudVm).send_chat(t))
	_chat.channel_changed.connect(func(c: int) -> void: (vm as HudVm).switch_channel(c))


## 底部中央：8 技能槽 + 普攻
func _build_skillbar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -320
	bar.offset_right = 320
	bar.offset_top = -104
	bar.offset_bottom = -28
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 6)
	add_child(bar)
	for i in range(SKILL_COUNT):
		var slot := SkillSlot.new()
		slot.style_with_frame()
		var idx := i
		slot.skill_cast.connect(func(sid: String) -> void: _cast(idx, sid))
		bar.add_child(slot)
		_slots.append(slot)
	var atk := Button.new()
	atk.custom_minimum_size = Vector2(64, 64)
	atk.tooltip_text = "普攻(Space)"
	atk.focus_mode = Control.FOCUS_NONE
	var tex := StyleBoxTexture.new()
	tex.texture = load("res://assets/ui/shots/btn_attack.png")
	atk.add_theme_stylebox_override("normal", tex)
	atk.add_theme_stylebox_override("hover", tex)
	atk.add_theme_stylebox_override("pressed", tex)
	atk.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	atk.pressed.connect(func() -> void: (vm as HudVm).attack())
	bar.add_child(atk)


## 右下：系统菜单五图标
func _build_menu() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	row.offset_left = -360
	row.offset_top = -104
	row.offset_right = -32
	row.offset_bottom = -32
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for spec: Dictionary in MENU_BTNS:
		var b := _func_icon(str(spec["icon"]), 56)
		b.tooltip_text = str(spec["tip"])
		var pid := StringName(str(spec["panel"]))
		b.pressed.connect(func() -> void:
			if pid == &"":
				(vm as HudVm).rest()
			else:
				(vm as HudVm).open_panel(pid))
		row.add_child(b)


## 圆形功能图标按钮
func _func_icon(p_name: String, p_size: int) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load("res://assets/ui/icons/function/%s.png" % p_name)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(p_size, p_size)
	b.focus_mode = Control.FOCUS_NONE
	return b


## 刷新角色状态
func _refresh_char(p_char: Variant) -> void:
	if not (p_char is Dictionary) or p_char.is_empty():
		return
	var c: Dictionary = p_char
	var title := str(c.get("title", ""))
	_name_label.text = "%s · %s" % [c.get("name", ""), title] if not title.is_empty() else str(c.get("name", ""))
	_realm_label.text = "%s  攻%d 防%d" % [c.get("realm_text", ""), c.get("atk", 0), c.get("def", 0)]
	var hp_cur := int(c.get("hp", 0))
	var hp_max := maxi(1, int(c.get("hp_max", 1)))
	_hp_bar.max_value = hp_max
	_hp_bar.value = hp_cur
	_hp_text.text = "%d / %d" % [hp_cur, hp_max]
	var mp_cur := int(c.get("mp", 0))
	var mp_max := maxi(1, int(c.get("mp_max", 1)))
	_mp_bar.max_value = mp_max
	_mp_bar.value = mp_cur
	_mp_text.text = "%d / %d" % [mp_cur, mp_max]


## 刷新技能槽
func _refresh_skills(p_known: Variant) -> void:
	if not (p_known is Array):
		return
	for i in range(_slots.size()):
		if i < p_known.size():
			_slots[i].setup(p_known[i])
		else:
			_slots[i].setup({})


func _refresh_tracker(p_quest: Variant) -> void:
	if not (p_quest is Dictionary) or p_quest.is_empty():
		_tracker.text = ""
		return
	var goals := ""
	for g: Variant in p_quest.get("goals", []):
		goals += "　%s %d/%d\n" % [g["text"], int(g["cur"]), int(g["need"])]
	_tracker.text = "【追踪】%s\n%s（点此打开任务录）" % [p_quest.get("name", ""), goals]


## 技能释放：冷却由槽位自己驱动
func _cast(p_idx: int, p_skill_id: String) -> void:
	if p_skill_id.is_empty():
		Toast.show_text("该槽位尚未装配功法")
		return
	var slot := _slots[p_idx]
	if slot._cool_left > 0.0:
		Toast.show_text("功法尚在冷却")
		return
	(vm as HudVm).cast_skill(p_skill_id)
	slot.start_cooldown()


## HUD 快捷键（面板打开时 UiManager 先消费 ESC；此处仅处理功能键）
func _unhandled_input(p_event: InputEvent) -> void:
	if p_event is InputEventKey and p_event.pressed and not p_event.echo:
		var key := (p_event as InputEventKey).physical_keycode
		match key:
			KEY_B:
				UiManager.toggle(&"inventory")
			KEY_C:
				UiManager.toggle(&"character")
			KEY_Q:
				UiManager.toggle(&"quest")
			KEY_K:
				UiManager.toggle(&"skill_tree")
			KEY_M:
				UiManager.toggle(&"world_map")
			KEY_SPACE:
				(vm as HudVm).attack()
			KEY_1: _cast_hotkey(0)
			KEY_2: _cast_hotkey(1)
			KEY_3: _cast_hotkey(2)
			KEY_4: _cast_hotkey(3)
			KEY_5: _cast_hotkey(4)
			KEY_6: _cast_hotkey(5)
			KEY_7: _cast_hotkey(6)
			KEY_8: _cast_hotkey(7)


func _cast_hotkey(p_idx: int) -> void:
	if p_idx < _slots.size():
		_cast(p_idx, _slots[p_idx].skill_id)
