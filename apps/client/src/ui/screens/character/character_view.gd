# 角色档案面板（UI-05）：立绘 + 六装备槽 + 修为 + 双列属性 + 五维
class_name CharacterView
extends UiView

const SLOTS := [
	{"slot": "weapon", "name": "武器"}, {"slot": "hat", "name": "帽子"},
	{"slot": "robe", "name": "衣服"}, {"slot": "necklace", "name": "项链"},
	{"slot": "shoes", "name": "鞋子"}, {"slot": "accessory", "name": "饰品"},
]
const BASE_STATS := [["hp", "气血"], ["mp", "真元"], ["atk", "攻击"], ["def", "防御"], ["hit", "命中"], ["dodge", "闪避"]]
const FIVE_ATTRS := ["筋骨", "灵气", "根骨", "悟性", "幸运"]

var _equip_cells: Dictionary = {}     # slot -> {icon, name}
var _identity: Label
var _xp_bar: ProgressBar
var _xp_text: Label
var _stat_labels: Dictionary = {}     # key -> Label
var _five_labels: Dictionary = {}     # attr -> Label
var _title_btn: Button
var _break_btn: Button


func _make_vm() -> ViewModel:
	return CharacterVm.new()


func _build() -> void:
	add_child(_dim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UiKit.ink_panel()
	panel.custom_minimum_size = Vector2(1080, 700)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for m: String in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(m, 28)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	col.add_child(UiKit.title_bar("角色档案", close))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	_build_left(body)
	_build_middle(body)
	_build_five(body)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	var change_btn := UiKit.secondary_btn("换 装", 18)
	var xp_btn := UiKit.secondary_btn("修 为", 18)
	_title_btn = UiKit.secondary_btn("称 号", 18)
	_break_btn = UiKit.primary_btn("突 破", 18)
	_break_btn.visible = false
	change_btn.custom_minimum_size = Vector2(150, 56)
	xp_btn.custom_minimum_size = Vector2(150, 56)
	_title_btn.custom_minimum_size = Vector2(150, 56)
	_break_btn.custom_minimum_size = Vector2(150, 56)
	change_btn.pressed.connect(func() -> void: UiManager.toggle(&"inventory"))
	xp_btn.pressed.connect(func() -> void: (vm as CharacterVm).breakthrough())
	_title_btn.pressed.connect(func() -> void:
		var t := str((vm.prop(&"char") as Dictionary).get("title", ""))
		Toast.show_text("当前称号：" + (t if not t.is_empty() else "无（可于聚宝阁购得）")))
	_break_btn.pressed.connect(func() -> void: (vm as CharacterVm).breakthrough())
	for b: Button in [change_btn, xp_btn, _title_btn, _break_btn]:
		actions.add_child(b)
	col.add_child(actions)

	_bind_vm()


func _dim() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.1, 0.1, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return dim


## 左：立绘 + 环绕装备槽
func _build_left(p_body: HBoxContainer) -> void:
	var left := Control.new()
	left.custom_minimum_size = Vector2(460, 520)
	p_body.add_child(left)
	var halo := TextureRect.new()
	halo.texture = load("res://assets/ui/icons/frames/frame_circle.png")
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(halo)
	var portrait := TextureRect.new()
	portrait.texture = load("res://assets/ui/shots/portrait_main.png")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.offset_left = 80
	portrait.offset_right = -80
	portrait.offset_top = 24
	portrait.offset_bottom = -24
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(portrait)
	# 六槽环绕：左列 3 / 右列 3
	var pos_map := {"weapon": Vector2(10, 60), "hat": Vector2(10, 230), "robe": Vector2(10, 400), "necklace": Vector2(360, 60), "shoes": Vector2(360, 230), "accessory": Vector2(360, 400)}
	for spec: Dictionary in SLOTS:
		var cell := _build_equip_cell(str(spec["slot"]), str(spec["name"]))
		cell.position = pos_map[str(spec["slot"])]
		left.add_child(cell)


func _build_equip_cell(p_slot: String, p_title: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(88, 88)
	btn.tooltip_text = "点击更换%s" % p_title
	btn.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/controls/ctrl_equip_slot_lg.png")
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 12
	icon.offset_top = 12
	icon.offset_right = -12
	icon.offset_bottom = -12
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	btn.pressed.connect(func() -> void: _on_equip_click(p_slot))
	col.add_child(btn)
	var name_label := UiKit.label(p_title, 13, UiTheme.INK_GRAY)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_label)
	_equip_cells[p_slot] = {"icon": icon, "name": name_label}
	return col


## 中：身份区 + 修为条 + 双列属性
func _build_middle(p_body: HBoxContainer) -> void:
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	p_body.add_child(mid)
	_identity = UiKit.label("", 26, UiTheme.INK, true)
	mid.add_child(_identity)
	var sect_label := UiKit.label("", 17, UiTheme.INK_GRAY)
	mid.add_child(sect_label)
	_stat_labels[&"sect"] = sect_label
	_xp_bar = UiKit.ink_bar(UiTheme.XP_GOLD, Vector2(0, 26))
	mid.add_child(_xp_bar)
	_xp_text = UiKit.label("", 13, UiTheme.PAPER)
	_xp_text.position = Vector2(120, 2)
	_xp_bar.add_child(_xp_text)
	mid.add_child(UiKit.divider())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 10)
	mid.add_child(grid)
	for pair: Array in BASE_STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(UiKit.label(str(pair[1]), 17, UiTheme.INK_GRAY))
		var v := UiKit.label("-", 17)
		row.add_child(v)
		_stat_labels[StringName(str(pair[0]))] = v
		grid.add_child(row)


## 右：五维 + 加点
func _build_five(p_body: HBoxContainer) -> void:
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(220, 0)
	right.add_theme_constant_override("separation", 8)
	p_body.add_child(right)
	right.add_child(UiKit.label("深层根骨", 20, UiTheme.CINNABAR, true))
	right.add_child(UiKit.divider())
	for attr: String in FIVE_ATTRS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(UiKit.label(attr, 17, UiTheme.INK_GRAY))
		var v := UiKit.label("0", 17)
		row.add_child(v)
		_five_labels[attr] = v
		var plus := UiKit.secondary_btn("+", 14)
		plus.custom_minimum_size = Vector2(34, 34)
		plus.tooltip_text = "消耗 1 属性点"
		plus.pressed.connect(func() -> void: (vm as CharacterVm).allocate(attr))
		row.add_child(plus)
		right.add_child(row)
	var free_tip := UiKit.label("", 13, UiTheme.GOLD)
	right.add_child(free_tip)
	_stat_labels[&"free_tip"] = free_tip


func _bind_vm() -> void:
	var cvm := vm as CharacterVm
	vm.bind(&"char", func(v: Variant) -> void: _refresh(v))
	cvm.refresh()


## 全面板刷新
func _refresh(p_char: Variant) -> void:
	if not (p_char is Dictionary) or p_char.is_empty():
		return
	var c: Dictionary = p_char
	var title := str(c.get("title", ""))
	_identity.text = "%s · %s" % [c.get("name", ""), title] if not title.is_empty() else str(c.get("name", ""))
	_stat_labels[&"sect"].text = "%s · %s" % [c.get("sect", ""), c.get("realm_text", "")]
	_xp_bar.max_value = maxi(1, int(c.get("xp_need", 1)))
	_xp_bar.value = int(c.get("xp", 0))
	_xp_text.text = "修为 %d / %d" % [int(c.get("xp", 0)), int(c.get("xp_need", 1))]
	for pair: Array in BASE_STATS:
		var key := StringName(str(pair[0]))
		if _stat_labels.has(key):
			var cur := int(c.get(str(key), 0))
			var max_v := int(c.get(str(key) + "_max", 0))
			_stat_labels[key].text = ("%d / %d" % [cur, max_v]) if max_v > 0 else str(cur)
	for attr: String in FIVE_ATTRS:
		var five: Dictionary = c.get("five", {})
		var alloc: Dictionary = c.get("attr_alloc", {})
		var base := int(five.get(attr, 0)) - int(alloc.get(attr, 0))
		var bonus := int(alloc.get(attr, 0))
		_five_labels[attr].text = "%d (+%d)" % [base, bonus] if bonus > 0 else str(base)
	_stat_labels[&"free_tip"].text = "可用属性点：%d" % int(c.get("free_attr", 0))
	_break_btn.visible = int(c.get("xp", 0)) >= int(c.get("xp_need", 1))
	for slot: String in _equip_cells:
		var eq: Variant = c.get("equips", {}).get(slot)
		var icon: TextureRect = _equip_cells[slot]["icon"]
		var name_label: Label = _equip_cells[slot]["name"]
		if eq == null or not (eq is Dictionary):
			icon.texture = null
			name_label.text = "空"
			name_label.add_theme_color_override("font_color", UiTheme.INK_FADE)
		else:
			var path := str(eq.get("icon", ""))
			icon.texture = load(path) if ResourceLoader.exists(path) else null
			name_label.text = str(eq.get("name", ""))
			name_label.add_theme_color_override("font_color", Enums.QUALITY_COLORS[clampi(int(eq.get("quality", 0)), 0, 5)])


## 装备槽点击：卸下或从背包选装备
func _on_equip_click(p_slot: String) -> void:
	var c: Dictionary = vm.prop(&"char")
	var eq: Variant = c.get("equips", {}).get(p_slot)
	if eq != null and eq is Dictionary:
		(vm as CharacterVm).unequip(p_slot)
		return
	var menu := PopupMenu.new()
	add_child(menu)
	var items: Array = await (vm as CharacterVm).list_equippable(p_slot)
	if items.is_empty():
		Toast.show_text("乾坤袋中没有可穿%s" % p_slot)
		menu.queue_free()
		return
	for i in range(items.size()):
		menu.add_item("%s ×%d" % [items[i]["name"], int(items[i]["count"])], i)
	var chosen := [items]
	menu.index_pressed.connect(func(idx: int) -> void:
		(vm as CharacterVm).wear(str(chosen[0][idx]["uid"])))
	menu.popup(Rect2i(Vector2i(get_global_mouse_position()) - Vector2i(60, 20), Vector2i(240, 40 * mini(items.size(), 8) + 16)))
