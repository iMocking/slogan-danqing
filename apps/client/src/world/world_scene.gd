# 仙途 · 世界主场景：水墨山水 + 玩家化身 + 常驻 HUD
# 背景与 HUD 置于 CanvasLayer，保证 Control 锚点相对视口生效。
extends Node2D

var _avatar: PlayerAvatar


func _ready() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	_build_background(bg_layer)
	_avatar = PlayerAvatar.new()
	_avatar.char_name = "青云子"
	add_child(_avatar)
	_avatar.position = Vector2(640, 420)
	_avatar.set_bounds(Vector2(1920, 1080))
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 0
	add_child(ui_layer)
	var hud: UiView = load("res://src/ui/screens/world/hud_view.gd").new()
	ui_layer.add_child(hud)
	# 拉取角色名（异步覆盖默认名）
	_load_char_name()


## 全屏水墨背景 + 古道装饰
func _build_background(p_layer: CanvasLayer) -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/bg/bg_mountain.png")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = Vector2(1920, 1080)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_layer.add_child(bg)
	# 地面古道路径装饰
	var road := Line2D.new()
	road.points = PackedVector2Array([Vector2(140, 940), Vector2(520, 840), Vector2(960, 900), Vector2(1560, 760)])
	road.width = 56
	road.default_color = Color(0.62, 0.55, 0.45, 0.5)
	road.z_index = -1
	add_child(road)


func _load_char_name() -> void:
	var res: Dictionary = await GameServer.request("character.get")
	if Rpc.is_ok(res):
		var c: Dictionary = Rpc.body(res).get("character", {})
		_avatar.rename(str(c.get("name", "青云子")))
		_avatar.position = Vector2(960, 620)
