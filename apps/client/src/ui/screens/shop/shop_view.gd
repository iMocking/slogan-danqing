# 聚宝阁面板（UI-07）：左分类导航 + 4×3 商品卡 + 热卖角标 + 货币充值
class_name ShopView
extends UiView

const CATS := ["推荐", "限时特惠", "装备", "丹药", "材料", "外观", "礼包"]

var _grid: GridContainer
var _page_label: Label
var _stone_label: Label
var _jade_label: Label
var _card_cache: Array = []


func _make_vm() -> ViewModel:
	return ShopVm.new()


func _build() -> void:
	add_child(_dim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UiKit.ink_panel()
	panel.custom_minimum_size = Vector2(1220, 700)
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
	col.add_child(UiKit.title_bar("聚 宝 阁", close))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	# 左：分类导航
	var nav := VBoxContainer.new()
	nav.custom_minimum_size = Vector2(190, 0)
	nav.add_theme_constant_override("separation", 6)
	body.add_child(nav)
	for i in range(CATS.size()):
		var idx := i
		var b := UiKit.secondary_btn(CATS[i], 18)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 52)
		if i == 0:
			b.button_pressed = true
		b.pressed.connect(func() -> void:
			(vm as ShopVm).set_category(idx))
		nav.add_child(b)
	nav.add_child(UiKit.hspace())
	# 右：货币区 + 商品网格 + 分页
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_END
	top_row.add_theme_constant_override("separation", 20)
	_stone_label = UiKit.label("0", 17)
	_jade_label = UiKit.label("0", 17)
	var stone_chip := UiKit.currency_chip("res://assets/ui/icons/currency/currency_stone.png", "")
	stone_chip.add_child(_stone_label)
	var jade_chip := UiKit.currency_chip("res://assets/ui/icons/currency/currency_coin.png", "")
	jade_chip.add_child(_jade_label)
	top_row.add_child(stone_chip)
	top_row.add_child(jade_chip)
	var recharge := UiKit.primary_btn("充 值", 16)
	recharge.custom_minimum_size = Vector2(110, 44)
	recharge.pressed.connect(func() -> void: Toast.show_text("单机版暂未开通充值，仙玉可通过历练获得"))
	top_row.add_child(recharge)
	right.add_child(top_row)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_grid)
	# 分页
	var pager := HBoxContainer.new()
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	pager.add_theme_constant_override("separation", 16)
	var prev := UiKit.secondary_btn("◀ 上一页", 16)
	var next := UiKit.secondary_btn("下一页 ▶", 16)
	_page_label = UiKit.label("1 / 1", 16, UiTheme.INK_GRAY)
	prev.custom_minimum_size = Vector2(130, 44)
	next.custom_minimum_size = Vector2(130, 44)
	prev.pressed.connect(func() -> void: (vm as ShopVm).turn_page(-1))
	next.pressed.connect(func() -> void: (vm as ShopVm).turn_page(1))
	pager.add_child(prev)
	pager.add_child(_page_label)
	pager.add_child(next)
	right.add_child(pager)

	vm.bind(&"rows", func(v: Variant) -> void: _refresh_goods(v))
	vm.bind(&"page", func(_v: Variant) -> void: _refresh_pager())
	vm.bind(&"pages", func(_v: Variant) -> void: _refresh_pager())
	vm.bind(&"wallet", func(v: Variant) -> void:
		if v is Dictionary:
			_stone_label.text = str(int(v.get("spirit_stone", 0)))
			_jade_label.text = str(int(v.get("immortal_jade", 0))))
	(vm as ShopVm).refresh()


func _dim() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(0.1, 0.1, 0.1, 0.45)
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return d


## 商品卡片刷新（复用缓存卡片）
func _refresh_goods(p_rows: Variant) -> void:
	if not (p_rows is Array):
		return
	var rows: Array = p_rows
	# 不足 12 格的页不显示空卡片
	while _card_cache.size() < 12:
		var card := _make_card()
		_card_cache.append(card)
		_grid.add_child(card)
	for i in range(12):
		var card: Control = _card_cache[i]
		card.visible = i < rows.size()
		if i < rows.size():
			_fill_card(card, rows[i])


## 单张商品卡：图标 + 名称 + 价格 + 热卖角标 + 购买
func _make_card() -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 190)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.PAPER_LIGHT
	sb.border_color = UiTheme.INK_FADE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", sb)
	card.pivot_offset = Vector2(120, 95)
	card.mouse_entered.connect(func() -> void: card.scale = Vector2(1.03, 1.03))
	card.mouse_exited.connect(func() -> void: card.scale = Vector2.ONE)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var icon_wrap := Control.new()
	icon_wrap.custom_minimum_size = Vector2(0, 64)
	col.add_child(icon_wrap)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_wrap.add_child(icon)
	var hot := UiKit.seal("热卖", 12)
	hot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hot.offset_left = -46
	hot.offset_top = -6
	hot.offset_right = -2
	hot.visible = false
	icon_wrap.add_child(hot)
	var name_label := UiKit.label("", 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	col.add_child(name_label)
	var price := UiKit.label("", 15, UiTheme.CINNABAR)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(price)
	var timer := UiKit.label("", 12, UiTheme.INK_FADE)
	timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(timer)
	var buy := UiKit.primary_btn("购 买", 15)
	buy.custom_minimum_size = Vector2(0, 36)
	col.add_child(buy)
	card.set_meta("icon", icon)
	card.set_meta("name", name_label)
	card.set_meta("price", price)
	card.set_meta("hot", hot)
	card.set_meta("timer", timer)
	card.set_meta("buy", buy)
	return card


func _fill_card(p_card: Control, p_gd: Variant) -> void:
	var gd: Dictionary = p_gd
	var icon: TextureRect = p_card.get_meta("icon")
	var name_label: Label = p_card.get_meta("name")
	var price: Label = p_card.get_meta("price")
	var hot: Label = p_card.get_meta("hot")
	var timer: Label = p_card.get_meta("timer")
	var buy: Button = p_card.get_meta("buy")
	var path := str(gd.get("icon", ""))
	icon.texture = load(path) if ResourceLoader.exists(path) else null
	name_label.text = str(gd.get("name", ""))
	name_label.add_theme_color_override("font_color", Enums.QUALITY_COLORS[clampi(int(gd.get("quality", 0)), 0, 5)])
	price.text = "%d %s" % [int(gd.get("price", 0)), _cur_name(str(gd.get("currency", "copper")))]
	hot.visible = bool(gd.get("hot", false))
	var remains := int(gd.get("remains_s", 0))
	timer.text = "限时 %02d:%02d:%02d" % [remains / 3600, (remains % 3600) / 60, remains % 60] if remains > 0 else ""
	buy.disabled = false
	var gid := str(gd.get("goods_id", ""))
	buy.pressed.connect(func() -> void: _confirm_buy(gid, name_label.text, price.text))


func _cur_name(p_key: String) -> String:
	match p_key:
		"stone": return "灵石"
		"jade": return "仙玉"
		_: return "铜钱"


func _refresh_pager() -> void:
	_page_label.text = "%d / %d" % [int(vm.prop(&"page")), int(vm.prop(&"pages"))]


## 购买二次确认
func _confirm_buy(p_gid: String, p_name: String, p_price: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "确定购买「%s」（%s）吗？" % [p_name, p_price]
	dialog.ok_button_text = "确 定"
	dialog.cancel_button_text = "取 消"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void: (vm as ShopVm).buy(p_gid))
	dialog.popup_centered()
