# 仙途 · 物品格子控件（背包 / 详情 / 奖励共用）
# 展示：图标 + 堆叠数 + 品质描边；数据由 item_body 字典驱动。
class_name ItemSlot
extends Button

signal slot_clicked(p_uid: String)

var uid: String = ""
var template_id: String = ""
var item_data: Dictionary = {}

var _icon: TextureRect
var _count: Label


func _init() -> void:
	custom_minimum_size = Vector2(84, 84)
	focus_mode = Control.FOCUS_NONE
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 10
	_icon.offset_top = 10
	_icon.offset_right = -10
	_icon.offset_bottom = -10
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 15)
	_count.add_theme_color_override("font_color", UiTheme.INK)
	_count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_count.offset_left = -66
	_count.offset_top = -26
	_count.offset_right = -8
	_count.offset_bottom = -4
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)
	pressed.connect(func() -> void: slot_clicked.emit(uid))


## 用 item_body 数据填充；空字典 = 空槽
func setup(p_data: Dictionary) -> void:
	item_data = p_data
	uid = str(p_data.get("uid", ""))
	template_id = str(p_data.get("template_id", ""))
	var quality := int(p_data.get("quality", -1))
	_apply_quality_border(quality)
	if p_data.is_empty():
		_icon.texture = null
		_count.text = ""
		tooltip_text = ""
		return
	var path := str(p_data.get("icon", ""))
	_icon.texture = load(path) if ResourceLoader.exists(path) else null
	var count := int(p_data.get("count", 1))
	_count.text = str(count) if count > 1 else ""
	var qname := ""
	if quality >= 0:
		qname = "  [%s]" % Enums.QUALITY_NAMES[quality]
	tooltip_text = "%s%s\n%s" % [p_data.get("name", ""), qname, p_data.get("desc", "")]


## 按品质着色边框
func _apply_quality_border(p_quality: int) -> void:
	var border: Color = UiTheme.INK_FADE if p_quality < 0 else Enums.QUALITY_COLORS[clampi(p_quality, 0, 5)]
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.PAPER_DARK
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate()
	hover.bg_color = UiTheme.CINNABAR_BG
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	var disabled := sb.duplicate()
	disabled.bg_color = Color(UiTheme.PAPER_DARK.r, UiTheme.PAPER_DARK.g, UiTheme.PAPER_DARK.b, 0.5)
	add_theme_stylebox_override("disabled", disabled)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
