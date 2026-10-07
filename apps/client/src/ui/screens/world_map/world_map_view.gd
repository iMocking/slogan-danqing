# 世界大地图（UI-08）：卷轴全图 + 八区域 + 拖拽/缩放 + 传送
class_name WorldMapView
extends UiView

const MAP_W := 1400.0
const MAP_H := 720.0
const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEP := 1.15

var _map_root: Control
var _map_canvas: MapCanvas
var _zoom := 1.0
var _dragging := false
var _info_card: PanelContainer
var _info_name: Label
var _info_desc: Label
var _travel_btn: Button
var _region_btns: Dictionary = {}


func _make_vm() -> ViewModel:
	return WorldMapVm.new()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.11, 0.10, 0.72)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# 标题
	var title := UiKit.brush_title("修 仙 世 界 全 图", 40)
	title.add_theme_color_override("font_color", UiTheme.PAPER)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 18
	title.offset_left = -200
	title.offset_right = 200
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	_build_map()
	_build_info_card()
	_build_controls()
	vm.bind(&"regions", func(_v: Variant) -> void: _refresh_regions())
	vm.bind(&"selected", func(_v: Variant) -> void: _refresh_info())
	(vm as WorldMapVm).refresh()


## 卷轴地图区（可拖拽 / 缩放）
func _build_map() -> void:
	var clip := Control.new()
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.offset_top = 80
	clip.offset_bottom = -90
	clip.clip_contents = true
	add_child(clip)
	_map_root = Control.new()
	_map_root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_map_root.offset_left = -MAP_W / 2
	_map_root.offset_top = -MAP_H / 2
	_map_root.offset_right = MAP_W / 2
	_map_root.offset_bottom = MAP_H / 2
	clip.add_child(_map_root)
	# 宣纸底图
	var paper := TextureRect.new()
	paper.texture = load("res://assets/bg/bg_paper.png")
	paper.stretch_mode = TextureRect.STRETCH_SCALE
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_root.add_child(paper)
	# 道路画布
	_map_canvas = MapCanvas.new()
	_map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_root.add_child(_map_canvas)
	# 上下木质卷轴杆
	for top: bool in [true, false]:
		var rod := ColorRect.new()
		rod.color = Color("#6B4F2E")
		rod.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		rod.offset_top = -14 if top else 0
		rod.offset_bottom = 0 if top else 14
		rod.offset_left = -30
		rod.offset_right = 30
		_map_root.add_child(rod)
	_map_root.gui_input.connect(_on_map_input)


## 区域按钮与当前位置点
func _refresh_regions() -> void:
	var regions: Array = vm.prop(&"regions")
	for r: Variant in regions:
		var region: Dictionary = r
		var rid := str(region["id"])
		var btn: Button = _region_btns.get(rid)
		if btn == null:
			btn = _make_region_btn(region)
		_refresh_region_state(btn, region)
	_map_canvas.roads = vm.prop(&"roads")
	_map_canvas.regions = regions
	_map_canvas.queue_redraw()
	# 当前位置朱红点（呼吸动画由 _process 驱动）
	_refresh_current_dot()


func _make_region_btn(p_region: Dictionary) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	var pos: Array = p_region["pos"]
	btn.position = Vector2(float(pos[0]) * MAP_W - 52, float(pos[1]) * MAP_H - 52)
	btn.custom_minimum_size = Vector2(104, 60)
	var rid := str(p_region["id"])
	btn.pressed.connect(func() -> void: (vm as WorldMapVm).select(p_region))
	_map_root.add_child(btn)
	_region_btns[rid] = btn
	return btn


func _refresh_region_state(p_btn: Button, p_region: Dictionary) -> void:
	var unlocked := bool(p_region.get("unlocked", false))
	var current := bool(p_region.get("is_current", false))
	p_btn.text = str(p_region.get("name", ""))
	p_btn.tooltip_text = "%s\n推荐境界：%s\n%s" % [p_region.get("name", ""), p_region.get("recommend", ""), p_region.get("desc", "")]
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.bg_color = UiTheme.PAPER_LIGHT if unlocked else Color(0.85, 0.83, 0.78, 0.5)
	sb.border_color = UiTheme.CINNABAR if current else (UiTheme.GOLD if unlocked else UiTheme.INK_FADE)
	sb.set_border_width_all(2 if current else 1)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p_btn.add_theme_stylebox_override("normal", sb)
	p_btn.add_theme_stylebox_override("hover", sb.duplicate())
	p_btn.add_theme_stylebox_override("pressed", sb.duplicate())
	p_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	p_btn.add_theme_color_override("font_color", UiTheme.INK if unlocked else UiTheme.INK_FADE)


## 当前位置点（朱红圆点；先清理旧点防重复）
func _refresh_current_dot() -> void:
	for old: Node in _map_root.get_children():
		if old.name == "CurrentDot":
			old.free()
	var cur := str(vm.prop(&"current"))
	for r: Variant in vm.prop(&"regions"):
		if str(r.get("id")) != cur:
			continue
		var pos: Array = r["pos"]
		var dot := ColorRect.new()
		dot.color = UiTheme.CINNABAR
		dot.custom_minimum_size = Vector2(22, 22)
		dot.size = Vector2(22, 22)
		dot.position = Vector2(float(pos[0]) * MAP_W - 11, float(pos[1]) * MAP_H - 11)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.z_index = 5
		dot.name = "CurrentDot"
		_map_root.add_child(dot)


func _build_info_card() -> void:
	var card := UiKit.ink_panel()
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	card.offset_left = -220
	card.offset_right = 220
	card.offset_top = -320
	card.offset_bottom = -110
	add_child(card)
	_info_card = card
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	_info_name = UiKit.label("", 22, UiTheme.INK, true)
	_info_desc = UiKit.label("", 14, UiTheme.INK_GRAY)
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_travel_btn = UiKit.primary_btn("启 动 传 送 阵", 18)
	_travel_btn.custom_minimum_size = Vector2(0, 52)
	_travel_btn.disabled = true
	_travel_btn.pressed.connect(func() -> void: _confirm_travel())
	col.add_child(_info_name)
	col.add_child(_info_desc)
	col.add_child(_travel_btn)


func _build_controls() -> void:
	# 左下：指南针（复位）
	var compass := Button.new()
	compass.text = "北"
	compass.custom_minimum_size = Vector2(84, 84)
	compass.tooltip_text = "复位视角"
	compass.focus_mode = Control.FOCUS_NONE
	compass.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	compass.offset_left = 40
	compass.offset_top = -130
	compass.offset_right = 124
	compass.offset_bottom = -46
	compass.pressed.connect(func() -> void:
		_zoom = 1.0
		_map_root.scale = Vector2.ONE
		_map_root.position = Vector2.ZERO)
	add_child(compass)
	# 右下：缩放 + 关闭
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	row.offset_left = -220
	row.offset_top = -76
	row.offset_right = -40
	row.offset_bottom = -24
	row.add_theme_constant_override("separation", 10)
	for pair: Array in [["＋", 1.0 / ZOOM_STEP], ["－", ZOOM_STEP]]:
		var b := UiKit.secondary_btn(str(pair[0]), 22)
		b.custom_minimum_size = Vector2(64, 52)
		var factor := float(pair[1])
		b.pressed.connect(func() -> void: _apply_zoom(factor, _map_root.get_parent().size / 2.0))
		row.add_child(b)
	var close := UiKit.secondary_btn("收起地图", 18)
	close.custom_minimum_size = Vector2(140, 52)
	close.pressed.connect(close_view)
	row.add_child(close)
	add_child(row)


func close_view() -> void:
	close()


func _refresh_info() -> void:
	var sel: Dictionary = vm.prop(&"selected")
	if sel.is_empty():
		_info_name.text = "点选区域查看详情"
		_info_desc.text = "八大秘境，任君行止。未解锁区域无法传送。"
		_travel_btn.disabled = true
		return
	_info_name.text = "%s（推荐 %s）" % [sel.get("name", ""), sel.get("recommend", "")]
	_info_desc.text = "%s\n此地 Boss：%s" % [sel.get("desc", ""), sel.get("boss", "无")]
	_travel_btn.disabled = not bool(sel.get("unlocked", false)) or bool(sel.get("is_current", false))
	_travel_btn.text = "已在 此 处" if bool(sel.get("is_current", false)) else ("启 动 传 送 阵" if bool(sel.get("unlocked", false)) else "境 界 不 足")


func _confirm_travel() -> void:
	var sel: Dictionary = vm.prop(&"selected")
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "确定传送至「%s」吗？" % sel.get("name", "")
	dialog.ok_button_text = "传 送"
	dialog.cancel_button_text = "取 消"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void: (vm as WorldMapVm).travel())
	dialog.popup_centered()


## 地图拖拽与滚轮缩放（鼠标锚点）
func _on_map_input(p_event: InputEvent) -> void:
	if p_event is InputEventMouseButton:
		var mb := p_event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_apply_zoom(ZOOM_STEP, _map_root.get_parent().get_local_mouse_position())
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_apply_zoom(1.0 / ZOOM_STEP, _map_root.get_parent().get_local_mouse_position())
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
	elif p_event is InputEventMouseMotion and _dragging:
		_map_root.position += (p_event as InputEventMouseMotion).relative


## 以锚点缩放：缩放前后保持锚点下的内容位置不变
func _apply_zoom(p_factor: float, p_anchor: Vector2) -> void:
	var parent_ctrl := _map_root.get_parent() as Control
	var old_scale := _map_root.scale.x
	var new_scale := clampf(old_scale * p_factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(old_scale, new_scale):
		return
	var anchor_content := (p_anchor - _map_root.position) / old_scale
	_map_root.scale = Vector2(new_scale, new_scale)
	_map_root.position = p_anchor - anchor_content * new_scale
	_zoom = new_scale


## 道路虚线画布
class MapCanvas extends Control:
	var roads: Array = []
	var regions: Array = []

	func _draw() -> void:
		if regions.is_empty():
			return
		var map_w := 1400.0
		var map_h := 720.0
		var by_id: Dictionary = {}
		for r: Variant in regions:
			by_id[str(r["id"])] = r
		for road: Variant in roads:
			var pair: Array = road
			if not (by_id.has(str(pair[0])) and by_id.has(str(pair[1]))):
				continue
			var a: Array = by_id[str(pair[0])]["pos"]
			var b: Array = by_id[str(pair[1])]["pos"]
			var pa := Vector2(float(a[0]) * map_w, float(a[1]) * map_h)
			var pb := Vector2(float(b[0]) * map_w, float(b[1]) * map_h)
			draw_dashed_line(pa, pb, Color(0.42, 0.40, 0.38, 0.6), 2.0, 10.0)
