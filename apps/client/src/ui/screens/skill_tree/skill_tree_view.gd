# 功法图谱面板（UI-10）：四系标签 + 3×5 网状节点 + 墨线前置 + 详情/学习
class_name SkillTreeView
extends UiView

const BRANCH_NAMES := ["剑修", "法修", "丹修", "体修"]
const NODE_SIZE := 72
const COL_GAP := 120
const ROW_GAP := 140

var _graph: GraphCanvas
var _detail_name: Label
var _detail_desc: Label
var _detail_meta: Label
var _level_label: Label
var _learn_btn: Button
var _points_label: Label
var _node_btns: Dictionary = {}     # skill_id -> Button


func _make_vm() -> ViewModel:
	return SkillTreeVm.new()


func _build() -> void:
	add_child(_dim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UiKit.ink_panel()
	panel.custom_minimum_size = Vector2(1120, 700)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for m: String in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(m, 26)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	col.add_child(UiKit.title_bar("功法图谱", close))

	var head := HBoxContainer.new()
	head.add_child(UiKit.tabs(BRANCH_NAMES, 0, func(idx: int) -> void: (vm as SkillTreeVm).refresh(idx)))
	head.add_child(UiKit.hspace())
	_points_label = UiKit.label("剩余修为点：0", 18, UiTheme.GOLD)
	head.add_child(_points_label)
	col.add_child(head)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	# 左：图谱画布（滚动）
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_graph = GraphCanvas.new()
	_graph.custom_minimum_size = Vector2(COL_GAP * 4 + NODE_SIZE + 40, ROW_GAP * 2 + NODE_SIZE + 40)
	scroll.add_child(_graph)
	# 右：详情
	_build_detail(body)

	vm.bind(&"nodes", func(v: Variant) -> void: _refresh_nodes(v))
	vm.bind(&"points", func(v: Variant) -> void: _points_label.text = "剩余修为点：%d" % int(v))
	vm.bind(&"selected", func(v: Variant) -> void: _refresh_detail(v))
	(vm as SkillTreeVm).refresh(0)


func _dim() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(0.1, 0.1, 0.1, 0.45)
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return d


func _build_detail(p_body: HBoxContainer) -> void:
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.add_theme_constant_override("separation", 8)
	p_body.add_child(right)
	var box := UiKit.ink_panel()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	box.add_child(col)
	_detail_name = UiKit.label("未选中功法", 22, UiTheme.INK, true)
	col.add_child(_detail_name)
	_level_label = UiKit.label("", 15, UiTheme.GOLD)
	col.add_child(_level_label)
	_detail_meta = UiKit.label("", 14, UiTheme.INK_GRAY)
	col.add_child(_detail_meta)
	col.add_child(UiKit.divider())
	_detail_desc = UiKit.label("", 14, UiTheme.INK_GRAY)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_detail_desc)
	_learn_btn = UiKit.primary_btn("修 炼", 20)
	_learn_btn.custom_minimum_size = Vector2(0, 60)
	_learn_btn.disabled = true
	_learn_btn.pressed.connect(func() -> void: (vm as SkillTreeVm).learn())
	col.add_child(_learn_btn)


## 节点刷新：按钮复用 + 状态着色
func _refresh_nodes(p_nodes: Variant) -> void:
	if not (p_nodes is Array):
		return
	var new_btns: Dictionary = {}
	for n: Variant in p_nodes:
		var node: Dictionary = n
		var sid := str(node["id"])
		var btn: Button = _node_btns.get(sid)
		if btn == null:
			btn = _make_node_btn(node)
		_style_node(btn, node)
		new_btns[sid] = btn
	# 清理不存在节点
	for k: String in _node_btns:
		if not new_btns.has(k):
			_node_btns[k].free()
	_node_btns = new_btns
	_graph.lines = _collect_lines(p_nodes)
	_graph.queue_redraw()


func _make_node_btn(p_node: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	btn.focus_mode = Control.FOCUS_NONE
	var icon_path := str(p_node.get("icon", ""))
	if ResourceLoader.exists(icon_path):
		btn.icon = load(icon_path)
		btn.expand_icon = true
	btn.pressed.connect(func() -> void: (vm as SkillTreeVm).select(p_node))
	var pos := Vector2(20 + int(p_node["col"]) * COL_GAP, 20 + int(p_node["row"]) * ROW_GAP)
	btn.position = pos
	_graph.add_child(btn)
	return btn


func _style_node(p_btn: Button, p_node: Dictionary) -> void:
	var status := str(p_node.get("status"))
	var level := int(p_node.get("level", 0))
	var sname := str(p_node.get("name", ""))
	p_btn.tooltip_text = "%s  Lv.%d/%d\n%s" % [sname, level, int(p_node.get("max_level", 5)), p_node.get("desc", "")]
	p_btn.text = "%d/%d" % [level, int(p_node.get("max_level", 5))] if level > 0 else ""
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(NODE_SIZE / 2)
	match status:
		"learned":
			sb.bg_color = UiTheme.CINNABAR
			sb.border_color = UiTheme.INK
		"available":
			sb.bg_color = UiTheme.PAPER_LIGHT
			sb.border_color = UiTheme.GOLD
		_:
			sb.bg_color = UiTheme.PAPER_DARK
			sb.border_color = UiTheme.INK_FADE
	sb.set_border_width_all(3 if status == "available" else 2)
	p_btn.add_theme_stylebox_override("normal", sb)
	p_btn.add_theme_stylebox_override("hover", sb.duplicate())
	p_btn.add_theme_stylebox_override("pressed", sb.duplicate())
	p_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	p_btn.add_theme_color_override("font_color", UiTheme.PAPER if status == "learned" else UiTheme.INK_GRAY)


func _collect_lines(p_nodes: Variant) -> Array:
	var lines: Array = []
	var map: Dictionary = {}
	for n: Variant in p_nodes:
		map[str(n["id"])] = n
	for n: Variant in p_nodes:
		var node: Dictionary = n
		for pre: Variant in node.get("prereq", []):
			var p: Dictionary = map.get(str(pre), {})
			if p.is_empty():
				continue
			var ok := int(map[str(pre)]["level"]) >= 1
			lines.append({
				"from": _node_center(p), "to": _node_center(node), "active": ok,
			})
	return lines


func _node_center(p_node: Dictionary) -> Vector2:
	return Vector2(20 + int(p_node["col"]) * COL_GAP + NODE_SIZE / 2.0, 20 + int(p_node["row"]) * ROW_GAP + NODE_SIZE / 2.0)


func _refresh_detail(p_sel: Variant) -> void:
	var sel: Dictionary = p_sel if p_sel is Dictionary else {}
	if sel.is_empty():
		_detail_name.text = "未选中功法"
		_detail_desc.text = "点击图谱中的节点查看功法详情。"
		_detail_meta.text = ""
		_level_label.text = ""
		_learn_btn.disabled = true
		return
	_detail_name.text = str(sel.get("name", ""))
	_level_label.text = "Lv.%d / %d" % [int(sel.get("level", 0)), int(sel.get("max_level", 5))]
	_detail_meta.text = "消耗真元 %d · 冷却 %.1f 秒 · 每级 1 修为点" % [int(sel.get("mp_cost", 0)), float(sel.get("cooldown", 0))]
	_detail_desc.text = str(sel.get("desc", ""))
	_learn_btn.disabled = str(sel.get("status")) == "locked" or int(sel.get("level", 0)) >= int(sel.get("max_level", 5))


## 图谱画布：绘制前置墨线（实线已满足 / 虚线未满足）
class GraphCanvas extends Control:
	var lines: Array = []

	func _draw() -> void:
		for l: Dictionary in lines:
			var from: Vector2 = l["from"]
			var to: Vector2 = l["to"]
			if bool(l["active"]):
				draw_line(from, to, Color(0.17, 0.17, 0.17, 0.7), 2.0)
				draw_circle(to, 3.0, UiTheme.CINNABAR)
			else:
				draw_dashed_line(from, to, Color(0.42, 0.40, 0.38, 0.5), 1.5, 6.0)
