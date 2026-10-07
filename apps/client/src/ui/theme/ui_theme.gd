# 仙途 · UI 主题构建器（代码构建 Theme，替代 .tres）
# 色板依据 docs/03-UI设计规范 3.2；九宫格素材来自 assets/ui/。
class_name UiTheme
extends RefCounted

# ---- 色板 ----
const PAPER := Color("#F5F0E8")
const PAPER_LIGHT := Color("#FAF5F0")
const PAPER_DARK := Color("#E8E0D0")
const INK := Color("#2C2C2C")
const INK_GRAY := Color("#6B6762")
const INK_FADE := Color("#B4AEA6")
const CINNABAR := Color("#8B2500")        # 朱红
const CINNABAR_LIGHT := Color("#A8452A")
const CINNABAR_BG := Color("#FDF0E8")
const GOLD := Color("#B8860B")            # 暗金
const HP_GREEN := Color("#4A6B52")
const MP_BLUE := Color("#3D5A7A")
const XP_GOLD := Color("#DAA520")

const FONT_SERIF: Array[String] = ["Noto Serif SC", "Source Han Serif SC", "SimSun", "STSong"]
const FONT_BRUSH: Array[String] = ["Ma Shan Zheng", "STXingkai", "STKaiti", "KaiTi"]

static var _serif: SystemFont
static var _brush: SystemFont


## 衬线正文字体（系统回退链）
static func font_serif() -> SystemFont:
	if _serif == null:
		_serif = SystemFont.new()
		_serif.font_names = FONT_SERIF
	return _serif


## 书法标题字体（系统回退链）
static func font_brush() -> SystemFont:
	if _brush == null:
		_brush = SystemFont.new()
		_brush.font_names = FONT_BRUSH
	return _brush


## 全局 Theme（项目启动时构建一次）
static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font_serif()
	t.default_font_size = 18
	# Label
	t.set_color("font_color", "Label", INK)
	t.set_font("font", "Label", font_serif())
	# Button：宣纸次按钮为默认态
	var normal := tex_box("res://assets/ui/buttons/btn_secondary_md.png", 18, 12)
	var hover := tex_box("res://assets/ui/buttons/btn_secondary_md.png", 18, 12)
	hover.modulate_color = CINNABAR_LIGHT
	var pressed := tex_box("res://assets/ui/buttons/btn_secondary_md.png", 18, 12)
	pressed.modulate_color = CINNABAR
	var disabled := tex_box("res://assets/ui/buttons/btn_secondary_md.png", 18, 12)
	disabled.modulate_color = Color(1, 1, 1, 0.45)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", PAPER)
	t.set_color("font_disabled_color", "Button", INK_FADE)
	# LineEdit：水墨输入框
	var le := tex_box("res://assets/ui/controls/ctrl_input_md.png", 22, 10)
	t.set_stylebox("normal", "LineEdit", le)
	var le_focus := tex_box("res://assets/ui/controls/ctrl_input_md.png", 22, 10)
	le_focus.modulate_color = GOLD
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", CINNABAR)
	t.set_color("placeholder_color", "LineEdit", INK_FADE)
	# PanelContainer / Panel：墨线面板
	var panel := tex_box("res://assets/ui/panels/panel_ink_line.png", 42, 30, 20)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	# ProgressBar
	var bg := sb_flat(PAPER_DARK, INK_FADE, 1, 4)
	var fill := sb_flat(CINNABAR, Color.TRANSPARENT, 0, 4)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)
	# CheckBox
	t.set_stylebox("normal", "CheckBox", sb_flat(Color.TRANSPARENT, INK_FADE, 1, 2))
	t.set_stylebox("pressed", "CheckBox", sb_flat(CINNABAR_BG, CINNABAR, 1, 2))
	t.set_color("font_color", "CheckBox", INK)
	# ScrollBar
	var sb_bar := sb_flat(PAPER_DARK, Color.TRANSPARENT, 0, 4)
	sb_bar.content_margin_left = 4
	sb_bar.content_margin_right = 4
	t.set_stylebox("scroll", "VScrollBar", sb_bar)
	t.set_stylebox("grabber", "VScrollBar", sb_flat(INK_FADE, Color.TRANSPARENT, 0, 4))
	return t


## 纹理九宫格 StyleBox；p_margin 为纹理边距，p_content 为内容边距
static func tex_box(p_path: String, p_margin: int, p_content: int, p_margin_v: int = -1) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	var tex: Texture2D = load(p_path)
	sb.texture = tex
	var mv := p_margin if p_margin_v < 0 else p_margin_v
	sb.texture_margin_left = p_margin
	sb.texture_margin_right = p_margin
	sb.texture_margin_top = mv
	sb.texture_margin_bottom = mv
	sb.content_margin_left = p_content
	sb.content_margin_right = p_content
	sb.content_margin_top = p_content * 0.6
	sb.content_margin_bottom = p_content * 0.6
	return sb


## 纯色扁平 StyleBox
static func sb_flat(p_bg: Color, p_border: Color, p_border_w: int, p_corner: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = p_bg
	sb.border_color = p_border
	sb.set_border_width_all(p_border_w)
	sb.set_corner_radius_all(p_corner)
	return sb
