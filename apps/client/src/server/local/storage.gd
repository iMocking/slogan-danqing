# 仙途 · 存档读写（JSON）
# 结构：{"version": int, "body": {...}} —— 数据体一律放 body 字段。
# 损坏时自动备份原文件并重置，保证游戏不崩溃。
extends RefCounted

const SAVE_PATH := "user://saves/slot_1.json"
const SAVE_VERSION := 1
const BACKUP_SUFFIX := ".bak"


## 读取数据体；不存在返回 null，损坏时备份后返回 null
func load_body() -> Variant:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("存档打开失败：%d" % FileAccess.get_open_error())
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		_backup_corrupt()
		return null
	if int(parsed.get("version", -1)) != SAVE_VERSION:
		push_warning("存档版本不匹配，按初始状态处理")
		return null
	var body: Variant = parsed.get("body", {})
	return body if body is Dictionary else null


## 写入数据体，先确保目录存在
func save_body(p_body: Dictionary) -> bool:
	var dir := SAVE_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("存档写入失败：%d" % FileAccess.get_open_error())
		return false
	var envelope := {"version": SAVE_VERSION, "body": p_body}
	f.store_string(JSON.stringify(envelope, "\t"))
	f.close()
	return true


## 备份损坏存档
func _backup_corrupt() -> void:
	push_warning("存档已损坏，备份为 %s 后重置" % BACKUP_SUFFIX)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, SAVE_PATH + BACKUP_SUFFIX)
