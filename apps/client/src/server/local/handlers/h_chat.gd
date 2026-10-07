# 仙途 · 聊天域 Handler：历史 / 发送 / 世界频道模拟
extends "res://src/server/local/handlers/h_base.gd"

const HISTORY_LIMIT := 50
const CHANNEL_ALL := 0


## 聊天历史：channel=0 返回全部频道混合
func _h_history(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var channel := arg_int(p_body, "channel", CHANNEL_ALL)
	var out: Array = []
	for m: Dictionary in p_server.state.chat_all:
		if channel != CHANNEL_ALL and int(m["channel"]) != channel:
			continue
		out.append(m)
	var start := maxi(0, out.size() - HISTORY_LIMIT)
	return Rpc.ok({"messages": out.slice(start), "channel": channel})


## 发送消息：写入并推送（uid 为 ULID）
func _h_send(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var text := arg_str(p_body, "text", "").strip_edges()
	if text.is_empty():
		return Rpc.err(Rpc.BAD_PARAM, "不能发送空消息")
	if text.length() > 120:
		return Rpc.err(Rpc.BAD_PARAM, "消息过长（≤120 字）")
	var channel := arg_int(p_body, "channel", CHANNEL_ALL)
	var msg := {
		"uid": Ulid.new_id(), "sender": p_server.state.char_name,
		"text": text, "ts": int(Time.get_unix_time_from_system()), "channel": channel,
		"self": true,
	}
	p_server.state.chat_all.append(msg)
	_trim(p_server)
	p_server.push("chat.msg", {"message": msg})
	return Rpc.ok({"message": msg})


## 世界频道模拟（由 LocalServer.tick 调用）
func bot_tick(p_server: RefCounted) -> void:
	if p_server.state.account_uid.is_empty():
		return
	var bot: Dictionary = DbMisc.CHAT_BOTS[randi() % DbMisc.CHAT_BOTS.size()]
	var msg := {
		"uid": Ulid.new_id(), "sender": str(bot["sender"]),
		"text": str(bot["text"]), "ts": int(Time.get_unix_time_from_system()),
		"channel": 1, "self": false,
	}
	p_server.state.chat_all.append(msg)
	_trim(p_server)
	p_server.push("chat.msg", {"message": msg})


## 只保留最近 200 条，防膨胀
func _trim(p_server: RefCounted) -> void:
	while p_server.state.chat_all.size() > 200:
		p_server.state.chat_all.pop_front()
