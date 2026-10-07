# 世界 HUD ViewModel：角色状态 / 聊天 / 技能 / 任务追踪
class_name HudVm
extends ViewModel


func _init() -> void:
	set_prop(&"char", {})
	set_prop(&"messages", [])
	set_prop(&"known_skills", [])
	set_prop(&"tracked_quest", {})
	set_prop(&"channel", 0)


## 订阅推送 + 首轮拉取
func load_init() -> void:
	watch_push("char.state", func(_route: String, body: Dictionary) -> void:
		set_prop(&"char", body.get("character", {})))
	watch_push("chat.msg", func(_route: String, body: Dictionary) -> void:
		var list: Array = prop(&"messages").duplicate()
		list.append(body.get("message", {}))
		set_prop(&"messages", list))
	watch_push("quest.changed", func(_route: String, _body: Dictionary) -> void:
		_refresh_tracked())
	await _pull_all()


func _pull_all() -> void:
	var ch := await rpc_body("character.get", {}, true)
	if not ch.is_empty():
		set_prop(&"char", ch.get("character", {}))
	var skills := await rpc_body("skill.known")
	set_prop(&"known_skills", skills.get("known", []))
	var chat := await rpc_body("chat.history", {"channel": int(prop(&"channel"))})
	set_prop(&"messages", chat.get("messages", []))
	await _refresh_tracked()


## 刷新追踪任务
func _refresh_tracked() -> void:
	var tracked_uid := ""
	var quest_list := await rpc_body("quest.list", {}, true)
	for q: Variant in quest_list.get("accepted", []):
		if bool(q.get("tracked", false)):
			tracked_uid = str(q["uid"])
			set_prop(&"tracked_quest", q)
	if tracked_uid.is_empty():
		set_prop(&"tracked_quest", {})


## 切换聊天频道（重新拉历史）
func switch_channel(p_channel: int) -> void:
	set_prop(&"channel", p_channel)
	var chat := await rpc_body("chat.history", {"channel": p_channel})
	set_prop(&"messages", chat.get("messages", []))


## 发送聊天
func send_chat(p_text: String) -> void:
	await rpc_body("chat.send", {"text": p_text, "channel": int(prop(&"channel"))})


## 普攻 / 释放技能：经 world.fight 结算，结果由 char.state 推送刷新
func attack() -> void:
	if _busy:
		return
	await rpc_body("world.fight", {})


func cast_skill(p_skill_id: String) -> void:
	if _busy or p_skill_id.is_empty():
		return
	await rpc_body("world.fight", {"skill_id": p_skill_id})


## 打坐恢复
func rest() -> void:
	await rpc_body("world.rest")


## 打开系统面板
func open_panel(p_id: StringName) -> void:
	UiManager.toggle(p_id)
