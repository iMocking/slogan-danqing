# 仙途 · 玩家化身（世界场景内）：WASD 移动 + 简笔水墨小人 + 名牌
class_name PlayerAvatar
extends Node2D

const SPEED := 320.0
const COLOR_ROBE := Color("#3D5A7A")
const COLOR_SKIN := Color("#F0E0D0")

var char_name: String = "无名修士"
var _name_label: Label
var _bounds: Vector2 = Vector2(1280, 720)


func _ready() -> void:
	_name_label = UiKit.label(char_name, 15, UiTheme.INK, true)
	_name_label.position = Vector2(-40, -78)
	_name_label.custom_minimum_size = Vector2(80, 20)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_label)
	z_index = 10


## 设置活动边界（视口尺寸）
func set_bounds(p_size: Vector2) -> void:
	_bounds = p_size


func _process(p_delta: float) -> void:
	var dir := Vector2.ZERO
	dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	position += dir * SPEED * p_delta
	position.x = clampf(position.x, 40, _bounds.x - 40)
	position.y = clampf(position.y, 40, _bounds.y - 40)
	# 面向：水平翻转由 scale.x 控制
	if absf(dir.x) > 0.01:
		_name_label.scale.x = 1.0


## 简笔水墨小人（斗笠 + 长袍）
func _draw() -> void:
	# 长袍（三角）
	var robe := PackedVector2Array([Vector2(-16, 40), Vector2(16, 40), Vector2(0, -12)])
	draw_colored_polygon(robe, COLOR_ROBE)
	# 头
	draw_circle(Vector2(0, -22), 11, COLOR_SKIN)
	# 斗笠
	var hat := PackedVector2Array([Vector2(-18, -28), Vector2(18, -28), Vector2(0, -42)])
	draw_colored_polygon(hat, Color("#8B7355"))
	# 腰带
	draw_line(Vector2(-13, 6), Vector2(13, 6), UiTheme.CINNABAR, 3.0)
	# 剑（背后斜插）
	draw_line(Vector2(10, -30), Vector2(22, 30), Color("#6B6762"), 2.5)


## 改名刷新名牌
func rename(p_name: String) -> void:
	char_name = p_name
	if _name_label != null:
		_name_label.text = p_name
