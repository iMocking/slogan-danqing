# 拍卖行弹窗集合：出价弹窗 / 上架弹窗（从背包选物）
class_name AuctionDialogs
extends RefCounted

const QUALITY_NAMES := ["凡", "灵", "玄", "地", "天", "仙"]


## 出价弹窗：校验 ≥ 当前价 ×1.05 由服务端做，此处给提示
static func open_bid(p_parent: Node, p_row: Dictionary, p_on_ok: Callable) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "竞拍「%s」" % p_row.get("name", "")
	dialog.ok_button_text = "出 价"
	dialog.cancel_button_text = "取 消"
	var min_price := int(ceil(int(p_row.get("current_price", 0)) * 1.05))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var tip := UiKit.label("当前价 %d 灵石\n最低出价 %d 灵石\n%s" % [int(p_row.get("current_price", 0)), min_price, "一口价 %d 灵石" % int(p_row.get("buyout", 0)) if int(p_row.get("buyout", 0)) > 0 else "无一口价"], 16)
	col.add_child(tip)
	var input := LineEdit.new()
	input.placeholder_text = "输入出价灵石数"
	input.custom_minimum_size = Vector2(280, 44)
	col.add_child(input)
	dialog.add_child(col)
	var vm_hint := [min_price]
	dialog.confirmed.connect(func() -> void:
		var price := input.text.strip_edges().to_int()
		if price < int(vm_hint[0]):
			Toast.show_text("出价不得低于 %d 灵石" % int(vm_hint[0]))
			return
		p_on_ok.call(price))
	p_parent.add_child(dialog)
	dialog.popup_centered()


## 上架弹窗：左背包选物 + 右起拍价/一口价/时长
static func open_list_item(p_parent: Node, p_items: Array, p_on_ok: Callable) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "上架拍卖"
	dialog.ok_button_text = "确 定"
	dialog.cancel_button_text = "取 消"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.add_child(UiKit.label("选择要拍卖的物品（背包）", 16, UiTheme.INK, true))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	col.add_child(grid)
	var selected: Array = [""]
	for it: Variant in p_items:
		var slot := ItemSlot.new()
		slot.setup(it)
		var uid := str(it.get("uid", ""))
		slot.slot_clicked.connect(func(_u: String) -> void:
			selected[0] = uid
			_highlight(grid, uid))
		grid.add_child(slot)
	col.add_child(UiKit.divider())
	var start_row := HBoxContainer.new()
	start_row.add_theme_constant_override("separation", 8)
	start_row.add_child(UiKit.label("起拍价", 15))
	var start_input := LineEdit.new()
	start_input.placeholder_text = "灵石"
	start_input.custom_minimum_size = Vector2(120, 40)
	start_row.add_child(start_input)
	var buyout_row := HBoxContainer.new()
	buyout_row.add_theme_constant_override("separation", 8)
	buyout_row.add_child(UiKit.label("一口价", 15))
	var buyout_input := LineEdit.new()
	buyout_input.placeholder_text = "0 为不设"
	buyout_input.custom_minimum_size = Vector2(120, 40)
	buyout_row.add_child(buyout_input)
	var hours_row := HBoxContainer.new()
	hours_row.add_theme_constant_override("separation", 8)
	hours_row.add_child(UiKit.label("时长", 15))
	var hours := OptionButton.new()
	for h: int in [12, 24, 48]:
		hours.add_item("%d 小时" % h)
	hours.selected = 1
	hours_row.add_child(hours)
	for row: HBoxContainer in [start_row, buyout_row, hours_row]:
		col.add_child(row)
	dialog.add_child(col)
	dialog.confirmed.connect(func() -> void:
		var uid := str(selected[0])
		if uid.is_empty():
			Toast.show_text("请先选择要拍卖的物品")
			return
		var start_price := start_input.text.strip_edges().to_int()
		if start_price <= 0:
			Toast.show_text("起拍价必须大于 0")
			return
		var buyout_price := buyout_input.text.strip_edges().to_int()
		var hours_v: int = [12, 24, 48][hours.selected]
		p_on_ok.call(uid, start_price, buyout_price, int(hours_v)))
	p_parent.add_child(dialog)
	dialog.popup_centered()


## 高亮选中槽位
static func _highlight(p_grid: GridContainer, p_uid: String) -> void:
	for c: Node in p_grid.get_children():
		if c is ItemSlot:
			var slot := c as ItemSlot
			var is_sel := slot.uid == p_uid
			slot.modulate = Color(1.0, 0.85, 0.8) if is_sel else Color.WHITE
