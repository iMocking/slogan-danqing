# 加载界面（UI-02）：水墨长卷 + 太极进度 + 修仙小贴士
class_name LoadingView
extends UiView

const TIP_INTERVAL := 3.0
const TAIJI_RPM := 0.5          # 每秒转半圈

var _taiji: TextureRect
var _tip_label: Label
var _tip_timer: Timer


func _make_vm() -> ViewModel:
	return LoadingVm.new()


func _build() -> void:
	# 背景长卷
	var bg := TextureRect.new()
	bg.texture = load("res://assets/bg/bg_pavilion.png")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 右上竖排朱红印章
	var seal := TextureRect.new()
	seal.texture = load("res://assets/ui/decorations/deco_seal_vertical.png")
	seal.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	seal.offset_left = -88
	seal.offset_top = 40
	seal.offset_right = -40
	seal.offset_bottom = 200
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(seal)

	# 左下八卦装饰
	var bagua := TextureRect.new()
	bagua.texture = load("res://assets/ui/decorations/deco_bagua.png")
	bagua.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bagua.offset_left = 36
	bagua.offset_top = -150
	bagua.offset_right = 164
	bagua.offset_bottom = -22
	bagua.modulate.a = 0.85
	bagua.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bagua)

	# 中央：太极 + 进度条 + 贴士
	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.offset_left = -320
	center.offset_right = 320
	center.offset_top = -40
	center.offset_bottom = 160
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 18)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_taiji = TextureRect.new()
	_taiji.texture = load("res://assets/ui/decorations/deco_taiji.png")
	_taiji.custom_minimum_size = Vector2(96, 96)
	_taiji.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_taiji.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_taiji.pivot_offset = Vector2(48, 48)
	center.add_child(_taiji)

	var bar := UiKit.ink_bar(UiTheme.XP_GOLD, Vector2(600, 32))
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(bar)

	_tip_label = UiKit.label("", 18, UiTheme.INK)
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size = Vector2(620, 0)
	center.add_child(_tip_label)

	# 贴士轮换定时器
	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_INTERVAL
	_tip_timer.autostart = true
	add_child(_tip_timer)
	_tip_timer.timeout.connect(func() -> void: (vm as LoadingVm).next_tip())

	# 绑定
	vm.bind(&"tip", func(v: Variant) -> void: _tip_label.text = "道语：%s" % str(v))
	vm.bind(&"progress", func(v: Variant) -> void: bar.value = float(v) * 100.0)
	(vm as LoadingVm).start()


func _process(p_delta: float) -> void:
	if _taiji != null:
		_taiji.rotation += TAIJI_RPM * TAU * p_delta
