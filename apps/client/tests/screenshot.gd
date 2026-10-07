# 仙途 · 界面截图自检脚本（带渲染运行）
# 用法：godot --path . res://tests/screenshot.tscn
# 产出：user://shots/*.png
extends Node

const SHOTS_DIR := "user://shots"

var _save_path := "user://saves/slot_1.json"
var _backup_path := "user://saves/screenshot_backup.json"

var _panel_ids: Array[StringName] = [&"inventory", &"character", &"quest", &"skill_tree", &"shop", &"auction", &"world_map"]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS_DIR)
	LoadingVm.auto_advance = false
	_backup_save()
	await _prepare_session()
	await _shot_script("res://src/ui/screens/login/login_view.gd", "01_login", 0.9)
	await _shot_script("res://src/ui/screens/char_create/char_create_view.gd", "03_char_create", 1.0)
	# 世界场景（实例化为子节点，保持本 runner 存活）
	var world: Node = load("res://src/world/world_scene.gd").new()
	add_child(world)
	await _wait(1.4)
	await _capture("04_world_hud")
	# HUD 之上逐个打开面板截图
	for pid: StringName in _panel_ids:
		UiManager.open(pid)
		await _wait(0.9)
		await _capture("panel_%s" % pid)
		UiManager.close(pid)
		await _wait(0.2)
	world.queue_free()
	# 加载页（auto_advance 已关闭）
	await _shot_script("res://src/ui/screens/loading/loading_view.gd", "02_loading", 0.8)
	print("SCREENSHOTS_DONE")
	_restore_save()
	get_tree().quit(0)


# ---------- 存档保护 ----------
func _backup_save() -> void:
	if FileAccess.file_exists(_save_path):
		DirAccess.copy_absolute(_save_path, _backup_path)
		DirAccess.remove_absolute(_save_path)
		GameServer.reset_local()


func _restore_save() -> void:
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)
	if FileAccess.file_exists(_backup_path):
		DirAccess.copy_absolute(_backup_path, _save_path)
		DirAccess.remove_absolute(_backup_path)


## 准备登录 + 角色（已有则跳过创建）
func _prepare_session() -> void:
	await GameServer.request("auth.login", {"account": "shooter", "password": "123456"})
	var res: Dictionary = await GameServer.request("character.create", {
		"name": "截图仙人", "gender": "male", "sect": "sect_qingyun",
		"body": "normal", "face": "face_yingqi", "hair": "hair_shu", "costume": "cost_qingyun",
	})
	print("prepare: ", res.get("code"))


## 实例化一个 UiView 脚本截图后销毁
func _shot_script(p_path: String, p_name: String, p_wait: float) -> void:
	var view: Control = load(p_path).new()
	add_child(view)
	await _wait(p_wait)
	await _capture(p_name)
	view.queue_free()
	await _wait(0.15)


func _capture(p_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [SHOTS_DIR, p_name])
	print("shot: ", p_name)


func _wait(p_sec: float) -> void:
	await Engine.get_main_loop().create_timer(p_sec).timeout
