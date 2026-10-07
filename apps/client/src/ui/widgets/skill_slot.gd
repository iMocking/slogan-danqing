# 仙途 · 技能槽控件（HUD 技能栏）
# 展示：图标 + 等级角标 + 冷却扇形遮罩 + 剩余秒数；数据由 skill.known 条目驱动。
class_name SkillSlot
extends Button

signal skill_cast(p_skill_id: String)

var skill_id: String = ""
var mp_cost: int = 0
var cooldown: float = 0.0
var _cool_left: float = 0.0
var _mask: TextureProgressBar
var _seconds: Label
var _level: Label
var _icon: TextureRect


func _init() -> void:
	custom_minimum_size = Vector2(54, 54)
	focus_mode = Control.FOCUS_NONE
	tooltip_text = "空技能槽"
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 6
	_icon.offset_top = 6
	_icon.offset_right = -6
	_icon.offset_bottom = -6
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	# 冷却扇形遮罩（顺时针恢复）
	_mask = TextureProgressBar.new()
	_mask.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	_mask.tint_progress = Color(0, 0, 0, 0.55)
	_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask.visible = false
	add_child(_mask)
	_seconds = Label.new()
	_seconds.add_theme_font_size_override("font_size", 14)
	_seconds.add_theme_color_override("font_color", UiTheme.PAPER)
	_seconds.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_seconds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seconds.visible = false
	add_child(_seconds)
	_level = Label.new()
	_level.add_theme_font_size_override("font_size", 12)
	_level.add_theme_color_override("font_color", UiTheme.GOLD)
	_level.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_level.offset_left = -30
	_level.offset_top = -20
	_level.offset_right = -4
	_level.offset_bottom = -2
	_level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_level)
	pressed.connect(func() -> void:
		if _cool_left <= 0.0:
			skill_cast.emit(skill_id))


## 用 skill.known 条目填充
func setup(p_data: Dictionary) -> void:
	skill_id = str(p_data.get("skill_id", ""))
	mp_cost = int(p_data.get("mp_cost", 0))
	cooldown = float(p_data.get("cooldown", 0.0))
	var level := int(p_data.get("level", 0))
	var path := str(p_data.get("icon", ""))
	_icon.texture = load(path) if ResourceLoader.exists(path) else null
	_level.text = str(level) if level > 0 else ""
	tooltip_text = "%s Lv.%d\n消耗真元 %d · 冷却 %.1f 秒" % [p_data.get("name", ""), level, mp_cost, cooldown]


## 触发冷却动画
func start_cooldown() -> void:
	if cooldown <= 0.0:
		return
	_cool_left = cooldown
	_mask.max_value = cooldown
	_mask.value = cooldown
	_mask.visible = true
	_seconds.visible = true


func _process(p_delta: float) -> void:
	if _cool_left <= 0.0:
		return
	_cool_left = maxf(0.0, _cool_left - p_delta)
	_mask.value = _cool_left
	_seconds.text = str(int(ceil(_cool_left)))
	if _cool_left <= 0.0:
		_mask.visible = false
		_seconds.visible = false


## 槽位外观（金色槽底）
func style_with_frame() -> void:
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/skillbar/skill_slot.png")
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sb)
	add_theme_stylebox_override("pressed", sb)
	add_theme_stylebox_override("disabled", sb)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
