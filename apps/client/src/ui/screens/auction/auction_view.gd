# 万宝拍卖行面板（UI-09）：四页签 + 筛选 + 表格 + 分页 + 上架
class_name AuctionView
extends UiView

const COLS := ["商品", "品质", "当前价", "卖家", "剩余时间", "操作"]

var _table: Tree
var _tab_btns: Array = []
var _quality_option: OptionButton
var _search_edit: LineEdit
var _search_timer: Timer
var _page_label: Label
var _rows_cache: Array = []


func _make_vm() -> ViewModel:
	return AuctionVm.new()


func _build() -> void:
	add_child(_dim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UiKit.ink_panel()
	panel.custom_minimum_size = Vector2(1180, 690)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for m: String in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(m, 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)
	col.add_child(UiKit.title_bar("万 宝 拍 卖 行", close))
	# 页签
	var tabs := UiKit.tabs(AuctionVm.TABS, 0, func(idx: int) -> void: (vm as AuctionVm).set_tab(idx))
	col.add_child(tabs)
	# 筛选栏
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 10)
	filter_row.add_child(UiKit.label("品质", 15, UiTheme.INK_GRAY))
	_quality_option = OptionButton.new()
	for i in range(AuctionVm.QUALITIES.size()):
		_quality_option.add_item(AuctionVm.QUALITIES[i])
	_quality_option.custom_minimum_size = Vector2(130, 40)
	filter_row.add_child(_quality_option)
	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "搜索物品名…"
	_search_edit.custom_minimum_size = Vector2(280, 40)
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_row.add_child(_search_edit)
	col.add_child(filter_row)
	_search_timer = Timer.new()
	_search_timer.wait_time = 0.3
	_search_timer.one_shot = true
	add_child(_search_timer)
	_search_timer.timeout.connect(func() -> void:
		(vm as AuctionVm).set_filter(_quality_option.selected, _search_edit.text))
	_search_edit.text_changed.connect(func(_t: String) -> void: _search_timer.start())
	_quality_option.item_selected.connect(func(_i: int) -> void:
		(vm as AuctionVm).set_filter(_quality_option.selected, _search_edit.text))
	# 表格
	_table = Tree.new()
	_table.columns = COLS.size()
	_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_table.column_titles_visible = true
	_table.focus_mode = Control.FOCUS_NONE
	for i in range(COLS.size()):
		_table.set_column_title(i, COLS[i])
	_table.set_column_expand(0, true)
	for i in range(1, COLS.size()):
		_table.set_column_expand(i, false)
		_table.set_column_custom_minimum_width(i, 130)
	_table.item_activated.connect(func() -> void: _bid_selected())
	col.add_child(_table)
	# 底部：分页 + 上架
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	var prev := UiKit.secondary_btn("◀", 18)
	var next := UiKit.secondary_btn("▶", 18)
	prev.custom_minimum_size = Vector2(56, 44)
	next.custom_minimum_size = Vector2(56, 44)
	_page_label = UiKit.label("1 / 1", 16, UiTheme.INK_GRAY)
	prev.pressed.connect(func() -> void: (vm as AuctionVm).turn_page(-1))
	next.pressed.connect(func() -> void: (vm as AuctionVm).turn_page(1))
	bottom.add_child(prev)
	bottom.add_child(_page_label)
	bottom.add_child(next)
	bottom.add_child(UiKit.hspace())
	var list_btn := UiKit.primary_btn("上 架 拍 卖", 20, true)
	list_btn.custom_minimum_size = Vector2(280, 72)
	list_btn.pressed.connect(func() -> void: _open_list_dialog())
	bottom.add_child(list_btn)
	col.add_child(bottom)

	vm.bind(&"rows", func(v: Variant) -> void: _refresh_table(v))
	vm.bind(&"page", func(_v: Variant) -> void: _refresh_pager())
	vm.bind(&"pages", func(_v: Variant) -> void: _refresh_pager())
	(vm as AuctionVm).refresh()


func _dim() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(0.1, 0.1, 0.1, 0.45)
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return d


## 表格刷新
func _refresh_table(p_rows: Variant) -> void:
	if not (p_rows is Array):
		return
	_rows_cache = p_rows
	_table.clear()
	var root := _table.create_item()
	var tab := int(vm.prop(&"tab"))
	for row: Variant in p_rows:
		var r: Dictionary = row
		var item := _table.create_item(root)
		var remain := int(r.get("remain_s", 0))
		var remain_text := "%02d:%02d:%02d" % [remain / 3600, (remain % 3600) / 60, remain % 60] if remain > 0 else "已结束"
		item.set_text(0, "%s ×%d" % [r.get("name", ""), int(r.get("count", 1))])
		item.set_text(1, Enums.QUALITY_NAMES[clampi(int(r.get("quality", 0)), 0, 5)])
		item.set_text(2, "%d 灵石%s" % [int(r.get("current_price", 0)), "（我出）" if bool(r.get("my_bid", false)) else ""])
		item.set_text(3, str(r.get("seller", "")))
		item.set_text(4, remain_text)
		if bool(r.get("ended", false)):
			item.set_text(5, "已结束")
			item.set_custom_color(0, UiTheme.INK_FADE)
		elif tab == 1 and not bool(r.get("my_bid", false)):
			item.set_text(5, "下架")
		else:
			item.set_text(5, "出价 / 双击")
		item.set_metadata(0, r)
		item.set_custom_color(1, Enums.QUALITY_COLORS[clampi(int(r.get("quality", 0)), 0, 5)])


func _refresh_pager() -> void:
	_page_label.text = "%d / %d" % [int(vm.prop(&"page")), int(vm.prop(&"pages"))]


## 当前选中行
func _selected_row() -> Dictionary:
	var item := _table.get_selected()
	if item == null:
		return {}
	return item.get_metadata(0) if item.get_metadata(0) is Dictionary else {}


## 双击 / 激活行：出价或下架
func _bid_selected() -> void:
	var r := _selected_row()
	if r.is_empty() or bool(r.get("ended", false)):
		return
	if int(vm.prop(&"tab")) == 1:
		(vm as AuctionVm).cancel(str(r["uid"]))
		return
	var uid := str(r["uid"])
	AuctionDialogs.open_bid(self, r, func(p_price: int) -> void:
		var res: Dictionary = await (vm as AuctionVm).bid(uid, p_price)
		if Rpc.is_ok(res):
			Toast.show_text("出价成功，锁定 %d 灵石" % p_price))


## 上架流程：拉背包 → 弹窗
func _open_list_dialog() -> void:
	var res: Dictionary = await GameServer.request("inventory.list", {"category": "all"})
	if not Rpc.is_ok(res):
		Toast.show_text(str(res.get("msg", "读取背包失败")))
		return
	var items: Array = Rpc.body(res).get("items", [])
	if items.is_empty():
		Toast.show_text("乾坤袋空空如也，无物可拍")
		return
	var avm := vm as AuctionVm
	AuctionDialogs.open_list_item(self, items, func(p_uid: String, p_start: int, p_buyout: int, p_hours: int) -> void:
		avm.list_item(p_uid, p_start, p_buyout, p_hours))
