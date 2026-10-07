# 仙途 · UI 构建工具箱（静态函数）
# 统一产出符合水墨视觉的基础控件，供各 View 复用，控制单文件行数。
class_name UiKit
extends RefCounted

const BTN_PRIMARY := "res://assets/ui/buttons/btn_primary_md.png"
const BTN_PRIMARY_LG := "res://assets/ui/buttons/btn_primary_lg.png"
const BTN_SECONDARY := "res://assets/ui/buttons/btn_secondary_md.png"
const BTN_SECONDARY_LG := "res://assets/ui/buttons/btn_secondary_lg.png"
const PANEL_INK := "res://assets/ui/panels/panel_ink_line.png"
const PANEL_SCROLL := "res://assets/ui/panels/panel_scroll_md.png"
const BAR_FRAME := "res://assets/ui/bars/bar_frame.png"
const SEAL_IMG := "res://assets/ui/decorations/deco_seal_rect.png"
const CLOUND_STRIP := "res://assets/ui/decorations/deco_cloud_border_strip.png"


## 普通文字
static func label(p_text: String, p_size: int = 18, p_color: Color = UiTheme.INK, p_brush: bool = false) -> Label:
	var l := Label.new()
	l.text = p_text
	l.add_theme_font_size_override("font_size", p_size)
	l.add_theme_color_override("font_color", p_color)
	if p_brush:
		l.add_theme_font_override("font", UiTheme.font_brush())
	return l


## 毛笔标题
static func brush_title(p_text: String, p_size: int = 40) -> Label:
	return label(p_text, p_size, UiTheme.INK, true)


## 印章式文字块（朱红底宣纸字）
static func seal(p_text: String, p_size: int = 16) -> Label:
	var l := label(p_text, p_size, UiTheme.PAPER)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.CINNABAR
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 4
	l.add_theme_stylebox_override("normal", sb)
	return l


## 主按钮（朱红）
static func primary_btn(p_text: String, p_size: int = 22, p_lg: bool = false) -> Button:
	var b := Button.new()
	b.text = p_text
	b.add_theme_font_size_override("font_size", p_size)
	b.add_theme_color_override("font_color", UiTheme.PAPER)
	b.add_theme_color_override("font_hover_color", UiTheme.PAPER)
	b.add_theme_color_override("font_pressed_color", UiTheme.PAPER)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	var sb := tex_sb(BTN_PRIMARY_LG if p_lg else BTN_PRIMARY, 20, 14)
	b.add_theme_stylebox_override("normal", sb)
	var hover := tex_sb(BTN_PRIMARY_LG if p_lg else BTN_PRIMARY, 20, 14)
	hover.modulate_color = Color(1.12, 1.08, 1.05)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := tex_sb(BTN_PRIMARY_LG if p_lg else BTN_PRIMARY, 20, 14)
	pressed.modulate_color = Color(0.85, 0.8, 0.78)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", tex_sb(BTN_SECONDARY_LG if p_lg else BTN_SECONDARY, 18, 14))
	b.add_theme_color_override("font_disabled_color", UiTheme.INK_FADE)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


## 次按钮（宣纸描边）
static func secondary_btn(p_text: String, p_size: int = 20, p_lg: bool = false) -> Button:
	var b := Button.new()
	b.text = p_text
	b.add_theme_font_size_override("font_size", p_size)
	b.add_theme_stylebox_override("normal", tex_sb(BTN_SECONDARY_LG if p_lg else BTN_SECONDARY, 18, 12))
	b.add_theme_stylebox_override("hover", tex_sb(BTN_SECONDARY_LG if p_lg else BTN_SECONDARY, 18, 12))
	b.add_theme_stylebox_override("pressed", tex_sb(BTN_SECONDARY_LG if p_lg else BTN_SECONDARY, 18, 12))
	b.add_theme_stylebox_override("disabled", tex_sb(BTN_SECONDARY_LG if p_lg else BTN_SECONDARY, 18, 12))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# 选中态用朱红字，保证宣纸底上可读
	b.add_theme_color_override("font_pressed_color", UiTheme.CINNABAR)
	b.add_theme_color_override("font_disabled_color", UiTheme.INK_FADE)
	return b


## 墨线面板容器
static func ink_panel(p_scroll: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := tex_sb(PANEL_SCROLL if p_scroll else PANEL_INK, 42, 30, 20)
	p.add_theme_stylebox_override("panel", sb)
	return p


## 九宫格 StyleBox
static func tex_sb(p_path: String, p_margin: int, p_content: int, p_margin_v: int = -1) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(p_path)
	var mv := p_margin if p_margin_v < 0 else p_margin_v
	sb.texture_margin_left = p_margin
	sb.texture_margin_right = p_margin
	sb.texture_margin_top = mv
	sb.texture_margin_bottom = mv
	sb.content_margin_left = p_content
	sb.content_margin_right = p_content
	sb.content_margin_top = p_content * 0.55
	sb.content_margin_bottom = p_content * 0.55
	return sb


## 面板标题栏（毛笔字 + 云纹 + 关闭钮）；返回 HBoxContainer
static func title_bar(p_title: String, p_on_close: Callable, p_size: int = 30) -> HBoxContainer:
	var bar := HBoxContainer.new()
	var t := brush_title(p_title, p_size)
	bar.add_child(t)
	var cloud := TextureRect.new()
	cloud.texture = load("res://assets/ui/decorations/deco_divider_cloud.png")
	cloud.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cloud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cloud.custom_minimum_size = Vector2(0, 24)
	bar.add_child(cloud)
	var close := secondary_btn("✕", 18)
	close.custom_minimum_size = Vector2(44, 44)
	close.pressed.connect(p_on_close)
	bar.add_child(close)
	return bar


## 分类标签条（自绘 HBox + 按钮，替代 TabBar 便于统一风格）；p_on_change(索引)
static func tabs(p_titles: Array, p_current: int, p_on_change: Callable) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	for i in range(p_titles.size()):
		var b := secondary_btn(str(p_titles[i]), 18)
		b.toggle_mode = true
		b.button_pressed = i == p_current
		b.custom_minimum_size = Vector2(96, 40)
		var idx := i
		b.toggled.connect(func(on: bool) -> void:
			if on:
				p_on_change.call(idx))
		box.add_child(b)
	_style_current(box, p_current)
	return box


## 高亮当前标签
static func _style_current(p_box: HBoxContainer, p_current: int) -> void:
	var i := 0
	for c: Node in p_box.get_children():
		if c is Button:
			var b := c as Button
			if i == p_current:
				b.add_theme_color_override("font_pressed_color", UiTheme.CINNABAR)
			i += 1


## 水墨进度条（bar_frame 底 + 纯色填充）
static func ink_bar(p_color: Color, p_min_size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = p_min_size
	var bg := tex_sb(BAR_FRAME, 10, 2)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = p_color
	fill.content_margin_left = 9
	fill.content_margin_right = 9
	fill.content_margin_top = 7
	fill.content_margin_bottom = 7
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


## 货币小组件（图标 + 数值）
static func currency_chip(p_icon: String, p_text: String) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.texture = load(p_icon)
	icon.custom_minimum_size = Vector2(24, 24)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	box.add_child(label(p_text, 17))
	return box


## 分隔线
static func divider() -> HSeparator:
	var s := HSeparator.new()
	return s


## 弹性空隙
static func hspace() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## 竖排文字（加载页印章等）
static func vertical_text(p_text: String, p_size: int = 18, p_color: Color = UiTheme.PAPER) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	for ch: String in p_text:
		box.add_child(label(ch, p_size, p_color))
	return box
