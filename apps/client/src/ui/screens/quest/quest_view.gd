# 任务录面板（UI-06）：三页签 + 左列表 + 右详情/目标/奖励 + 追踪/交付
class_name QuestView
extends UiView

const TAB_NAMES := ["已接任务", "可接任务", "已完成"]
const TYPE_COLORS := [Color("#8B2500"), Color("#3D5A7A"), Color("#4A6B52"), Color("#B8860B")]

var _list_box: VBoxContainer
var _detail_name: Label
var _detail_type: Label
var _detail_desc: Label
var _goals_box: VBoxContainer
var _rewards_box: HBoxContainer
var _track_btn: Button
var _claim_btn: Button
var _abandon_btn: Button


func _make_vm() -> ViewModel:
	return QuestVm.new()


func _build() -> void:
	add_child(_dim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UiKit.ink_panel()
	panel.custom_minimum_size = Vector2(980, 640)
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
	col.add_child(UiKit.title_bar("任务录", close))
	col.add_child(UiKit.tabs(TAB_NAMES, 0, func(idx: int) -> void: (vm as QuestVm).set_tab(idx)))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	# 左：任务列表（滚动）
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(380, 0)
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(left_scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 6)
	left_scroll.add_child(_list_box)
	# 右：详情
	_build_detail(body)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	_track_btn = UiKit.secondary_btn("追踪任务", 18)
	_claim_btn = UiKit.primary_btn("交付任务", 18)
	_abandon_btn = UiKit.secondary_btn("放弃任务", 18)
	_track_btn.custom_minimum_size = Vector2(170, 56)
	_claim_btn.custom_minimum_size = Vector2(170, 56)
	_abandon_btn.custom_minimum_size = Vector2(170, 56)
	_track_btn.pressed.connect(func() -> void: (vm as QuestVm).track(str((vm.prop(&"selected") as Dictionary).get("uid", ""))))
	_claim_btn.pressed.connect(func() -> void: (vm as QuestVm).claim(str((vm.prop(&"selected") as Dictionary).get("uid", ""))))
	_abandon_btn.pressed.connect(func() -> void: _confirm_abandon())
	for b: Button in [_track_btn, _claim_btn, _abandon_btn]:
		actions.add_child(b)
	col.add_child(actions)

	vm.bind(&"lists", func(_v: Variant) -> void: _refresh_all())
	vm.bind(&"selected", func(_v: Variant) -> void: _refresh_detail())
	vm.bind(&"tab", func(_v: Variant) -> void: _refresh_list())
	(vm as QuestVm).refresh()


func _dim() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.1, 0.1, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return dim


func _build_detail(p_body: HBoxContainer) -> void:
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	p_body.add_child(right)
	_detail_name = UiKit.label("", 24, UiTheme.INK, true)
	right.add_child(_detail_name)
	_detail_type = UiKit.label("", 14)
	right.add_child(_detail_type)
	_detail_desc = UiKit.label("", 15, UiTheme.INK_GRAY)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_detail_desc)
	right.add_child(UiKit.divider())
	right.add_child(UiKit.label("目标", 17, UiTheme.INK, true))
	_goals_box = VBoxContainer.new()
	_goals_box.add_theme_constant_override("separation", 4)
	right.add_child(_goals_box)
	right.add_child(UiKit.label("奖励", 17, UiTheme.INK, true))
	_rewards_box = HBoxContainer.new()
	_rewards_box.add_theme_constant_override("separation", 14)
	right.add_child(_rewards_box)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(filler)


## 列表刷新（当前页签组）
func _refresh_list() -> void:
	for c: Node in _list_box.get_children():
		c.free()
	var tab := int(vm.prop(&"tab"))
	var groups: Array = vm.prop(&"lists")
	var sel_uid := str((vm.prop(&"selected") as Dictionary).get("uid", ""))
	for q: Variant in groups[tab]:
		var row := _build_row(q, str(q.get("uid")) == sel_uid)
		_list_box.add_child(row)
	if groups[tab].is_empty():
		_list_box.add_child(UiKit.label("（暂无任务）", 15, UiTheme.INK_FADE))


## 列表行：朱红点 + 名称 + 进度/状态
func _build_row(p_q: Variant, p_active: bool) -> Button:
	var q: Dictionary = p_q
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 54)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.CINNABAR_BG if p_active else UiTheme.PAPER_LIGHT
	sb.border_color = UiTheme.CINNABAR if p_active else UiTheme.INK_FADE
	sb.set_border_width_all(1)
	sb.content_margin_left = 14
	btn.add_theme_stylebox_override("normal", sb)
	var sb2 := sb.duplicate()
	sb2.bg_color = UiTheme.PAPER_DARK
	btn.add_theme_stylebox_override("hover", sb2)
	btn.add_theme_stylebox_override("pressed", sb2)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var text := str(q.get("name", ""))
	var state := int(q.get("state", 0))
	if state == 2:
		text += "　● 可交付"
	elif state == 1:
		var done := 0
		var total := 0
		for g: Variant in q.get("goals", []):
			total += 1
			if int(g["cur"]) >= int(g["need"]):
				done += 1
		text += "　%d/%d 目标" % [done, total]
	elif state == 0:
		text += "　（可接）"
	btn.text = text
	var uid := str(q.get("uid", ""))
	var tid := str(q.get("template_id", ""))
	var is_avail := state == 0
	btn.pressed.connect(func() -> void:
		if is_avail:
			(vm as QuestVm).select("")
		else:
			(vm as QuestVm).select(uid)
		# 可接任务双击接取：单击选中详情即可接
		if is_avail:
			(vm as QuestVm).accept(tid))
	return btn


## 详情刷新
func _refresh_detail() -> void:
	var sel: Dictionary = vm.prop(&"selected")
	var empty := sel.is_empty()
	for b: Button in [_track_btn, _claim_btn, _abandon_btn]:
		b.disabled = empty
	_claim_btn.visible = int(sel.get("state", 0)) == 2
	if empty:
		_detail_name.text = "未选中任务"
		_detail_type.text = ""
		_detail_desc.text = "从左侧选择任务查看详情。"
		_clear(_goals_box)
		_clear(_rewards_box)
		return
	_detail_name.text = str(sel.get("name", ""))
	var t := int(sel.get("type", 0))
	_detail_type.text = str(sel.get("type_name", ""))
	_detail_type.add_theme_color_override("font_color", TYPE_COLORS[clampi(t, 0, 3)])
	_detail_desc.text = str(sel.get("desc", ""))
	_clear(_goals_box)
	var state := int(sel.get("state", 0))
	if sel.get("goals", []).is_empty():
		_goals_box.add_child(UiKit.label("（接取后显示目标）", 14, UiTheme.INK_FADE))
	for g: Variant in sel.get("goals", []):
		var done := int(g["cur"]) >= int(g["need"])
		var mark := "✓" if done else "○"
		var color := UiTheme.CINNABAR if done else UiTheme.INK_GRAY
		_goals_box.add_child(UiKit.label("%s %s　%d/%d" % [mark, g["text"], int(g["cur"]), int(g["need"])], 15, color))
	_clear(_rewards_box)
	var rewards: Dictionary = sel.get("rewards", {})
	if int(rewards.get("copper", 0)) > 0:
		_rewards_box.add_child(UiKit.currency_chip("res://assets/ui/icons/currency/currency_coin.png", "%d 铜钱" % int(rewards["copper"])))
	if int(rewards.get("stone", 0)) > 0:
		_rewards_box.add_child(UiKit.currency_chip("res://assets/ui/icons/currency/currency_stone.png", "%d 灵石" % int(rewards["stone"])))
	if int(rewards.get("xp", 0)) > 0:
		_rewards_box.add_child(UiKit.label("修为 +%d" % int(rewards["xp"]), 15, UiTheme.GOLD))
	for it: Variant in rewards.get("items", []):
		_rewards_box.add_child(UiKit.currency_chip(str(it.get("icon", "")), "%s ×%d" % [it.get("name", ""), int(it["count"])]))
	_track_btn.disabled = state != 1 or bool(sel.get("tracked", false))
	_abandon_btn.disabled = state != 1


func _clear(p_box: Node) -> void:
	for c: Node in p_box.get_children():
		c.free()


func _refresh_all() -> void:
	_refresh_list()
	_refresh_detail()


func _confirm_abandon() -> void:
	var sel: Dictionary = vm.prop(&"selected")
	if sel.is_empty():
		return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "确定放弃「%s」吗？进度将清空。" % sel.get("name", "")
	dialog.ok_button_text = "确 定"
	dialog.cancel_button_text = "再想想"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void: (vm as QuestVm).abandon(str(sel.get("uid", ""))))
	dialog.popup_centered()
