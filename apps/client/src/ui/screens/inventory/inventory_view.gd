# 背包面板（UI-04 乾坤袋）：5×6 网格 + 详情区 + 操作按钮 + 货币栏
class_name InventoryView
extends UiView

const CAT_NAMES := ["全部", "装备", "消耗品", "材料", "任务"]
const GRID_COLS := 5
const GRID_ROWS := 6

var _slots: Array[ItemSlot] = []
var _grid: GridContainer
var _detail_name: Label
var _detail_type: Label
var _detail_desc: Label
var _detail_stats: Label
var _coin_label: Label
var _stone_label: Label
var _use_btn: Button
var _drop_btn: Button
var _split_btn: Button
var _current_cat: int = 0


func _make_vm() -> ViewModel:
	return InventoryVm.new()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.1, 0.1, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	add_child(center)
	var panel := UiKit.ink_panel()
	panel.custom_minimum_size = Vector2(1010, 680)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	col.add_child(UiKit.title_bar("乾坤袋", close))
	# 分类标签
	var tabs := UiKit.tabs(CAT_NAMES, 0, func(idx: int) -> void: _on_category(idx))
	col.add_child(tabs)
	# 主体：网格 + 详情
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	body.add_child(_grid)
	for i in range(GRID_COLS * GRID_ROWS):
		var slot := ItemSlot.new()
		slot.setup({})
		slot.slot_clicked.connect(_on_slot_click)
		_grid.add_child(slot)
		_slots.append(slot)
	_build_detail(body)

	# 底部操作
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	_use_btn = UiKit.primary_btn("使 用", 18)
	_drop_btn = UiKit.secondary_btn("丢 弃", 18)
	var sort_btn := UiKit.secondary_btn("整 理", 18)
	_split_btn = UiKit.secondary_btn("拆 分", 18)
	_use_btn.custom_minimum_size = Vector2(140, 56)
	_drop_btn.custom_minimum_size = Vector2(140, 56)
	sort_btn.custom_minimum_size = Vector2(140, 56)
	_split_btn.custom_minimum_size = Vector2(140, 56)
	_use_btn.pressed.connect(func() -> void: (vm as InventoryVm).use_selected())
	_drop_btn.pressed.connect(func() -> void: _confirm_drop())
	sort_btn.pressed.connect(func() -> void: (vm as InventoryVm).sort_items())
	_split_btn.pressed.connect(func() -> void: (vm as InventoryVm).split_selected())
	for b: Button in [_use_btn, _drop_btn, sort_btn, _split_btn]:
		actions.add_child(b)
	col.add_child(actions)

	# 货币栏
	var cur := HBoxContainer.new()
	cur.alignment = BoxContainer.ALIGNMENT_END
	cur.add_theme_constant_override("separation", 24)
	_coin_label = UiKit.label("0", 17)
	_stone_label = UiKit.label("0", 17)
	var coin_chip := UiKit.currency_chip("res://assets/ui/icons/currency/currency_coin.png", "")
	coin_chip.add_child(_coin_label)
	var stone_chip := UiKit.currency_chip("res://assets/ui/icons/currency/currency_stone.png", "")
	stone_chip.add_child(_stone_label)
	cur.add_child(coin_chip)
	cur.add_child(stone_chip)
	col.add_child(cur)
	_bind_vm()


func _build_detail(p_body: HBoxContainer) -> void:
	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(320, 0)
	detail.add_theme_constant_override("separation", 8)
	var box := UiKit.ink_panel()
	detail.add_child(box)
	var dcol := VBoxContainer.new()
	dcol.add_theme_constant_override("separation", 8)
	box.add_child(dcol)
	_detail_name = UiKit.label("未选中物品", 22, UiTheme.INK, true)
	dcol.add_child(_detail_name)
	_detail_type = UiKit.label("", 14, UiTheme.INK_GRAY)
	dcol.add_child(_detail_type)
	dcol.add_child(UiKit.divider())
	_detail_stats = UiKit.label("", 15)
	dcol.add_child(_detail_stats)
	_detail_desc = UiKit.label("", 14, UiTheme.INK_GRAY)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dcol.add_child(_detail_desc)
	p_body.add_child(detail)


func _bind_vm() -> void:
	var ivm := vm as InventoryVm
	vm.bind(&"items", func(v: Variant) -> void: _refresh_grid(v))
	vm.bind(&"selected", func(v: Variant) -> void: _refresh_detail(v))
	vm.bind(&"wallet", func(v: Variant) -> void:
		if v is Dictionary:
			_coin_label.text = str(int(v.get("copper", 0)))
			_stone_label.text = str(int(v.get("spirit_stone", 0))))
	ivm.refresh()


## 物品填入前 30 槽，其余置空
func _refresh_grid(p_items: Variant) -> void:
	if not (p_items is Array):
		return
	for i in range(_slots.size()):
		if i < p_items.size():
			_slots[i].setup(p_items[i])
		else:
			_slots[i].setup({})


## 详情区刷新（品质色名称 + 属性行）
func _refresh_detail(p_sel: Variant) -> void:
	var sel: Dictionary = p_sel if p_sel is Dictionary else {}
	var empty := sel.is_empty()
	_use_btn.disabled = empty or str(sel.get("type")) != "pill"
	_drop_btn.disabled = empty
	_split_btn.disabled = empty or int(sel.get("count", 1)) < 2 or int(sel.get("max_stack", 1)) < 2
	if empty:
		_detail_name.text = "未选中物品"
		_detail_name.add_theme_color_override("font_color", UiTheme.INK_FADE)
		_detail_type.text = ""
		_detail_stats.text = ""
		_detail_desc.text = "点选乾坤袋中的物品查看详情。"
		return
	var quality := int(sel.get("quality", 0))
	_detail_name.text = str(sel.get("name", ""))
	_detail_name.add_theme_color_override("font_color", Enums.QUALITY_COLORS[clampi(quality, 0, 5)])
	_detail_type.text = "%s · 品质[%s] · 可叠 %d" % [_type_name(str(sel.get("type"))), Enums.QUALITY_NAMES[quality], int(sel.get("max_stack", 1))]
	var stats: Dictionary = sel.get("stats", {})
	var lines := ""
	for k: String in stats:
		lines += "%s +%d\n" % [k, int(stats[k])]
	_detail_stats.text = lines if not lines.is_empty() else "（无属性加成）"
	_detail_desc.text = str(sel.get("desc", ""))


func _type_name(p_type: String) -> String:
	match p_type:
		"equip": return "装备"
		"pill": return "丹药"
		"material": return "材料"
		"quest": return "任务物"
		_: return "杂项"


func _on_slot_click(p_uid: String) -> void:
	# 再次点击取消选中
	var sel: Dictionary = vm.prop(&"selected")
	if not sel.is_empty() and str(sel.get("uid")) == p_uid:
		(vm as InventoryVm).select("")
	else:
		(vm as InventoryVm).select(p_uid)


func _on_category(p_idx: int) -> void:
	_current_cat = p_idx
	(vm as InventoryVm).set_category(InventoryVm.CATEGORIES[p_idx])


## 丢弃二次确认（破坏性操作）
func _confirm_drop() -> void:
	var sel: Dictionary = vm.prop(&"selected")
	if sel.is_empty():
		return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "确定丢弃「%s ×%d」吗？此操作无法撤销。" % [sel.get("name", ""), int(sel.get("count", 1))]
	dialog.ok_button_text = "确 定"
	dialog.cancel_button_text = "取 消"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void: (vm as InventoryVm).drop_selected())
	dialog.popup_centered()
