# 仙途 · UiView 基类（MVVM 之 View）
# 职责：构建控件树（_build）、绑定 VM 属性（vm.bind）、转发用户输入到 VM 方法。
# 禁止：在本层读写服务端状态、写业务规则。
class_name UiView
extends Control

var vm: ViewModel = null
var panel_id: StringName = &""
var is_modal: bool = false
## 关闭时是否释放节点（面板 true，HUD/全屏 false）
var free_on_close: bool = true


func _init() -> void:
	vm = _make_vm()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 子类指定自己的 ViewModel
func _make_vm() -> ViewModel:
	return ViewModel.new()


func _ready() -> void:
	theme = UiTheme.build()
	_build()


## 子类构建控件树
func _build() -> void:
	pass


## 打开（全屏场景或面板通用）
func open(p_data: Dictionary = {}) -> void:
	visible = true
	_on_open(p_data)


func close() -> void:
	_on_close()
	visible = false
	if free_on_close:
		queue_free()


func _on_open(_p_data: Dictionary) -> void:
	pass


func _on_close() -> void:
	pass


func _exit_tree() -> void:
	if vm != null:
		vm.clear_binds()


## ESC 关闭面板（面板类默认行为；全屏场景可覆写）
func _unhandled_input(p_event: InputEvent) -> void:
	if is_modal and p_event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## 绑定快捷方式：属性变化刷新 Label 文本
func bind_label(p_label: Label, p_prop: StringName, p_fmt: String = "%s") -> void:
	vm.bind(p_prop, func(v: Variant) -> void: p_label.text = p_fmt % str(v))


## 绑定 TextureProgressBar 值（prop 为 [cur, max]）
func bind_bar(p_bar: TextureProgressBar, p_prop: StringName) -> void:
	vm.bind(p_prop, func(v: Variant) -> void:
		if v is Array and v.size() >= 2:
			p_bar.max_value = maxi(1, int(v[1]))
			p_bar.value = clampi(int(v[0]), 0, maxi(1, int(v[1]))))


## 绑定节点可见性
func bind_visible(p_node: CanvasItem, p_prop: StringName) -> void:
	vm.bind(p_prop, func(v: Variant) -> void: p_node.visible = bool(v))
