# 仙途 · 任务域 Handler：接取 / 进度 / 交付 / 追踪 / 放弃
extends "res://src/server/local/handlers/h_base.gd"

const S_ACCEPTED := 1
const S_READY := 2
const S_DONE := 3


## 任务列表：已接 / 可接 / 已完成 三组
func _h_list(p_server: RefCounted, _p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var accepted: Array = []
	var done: Array = []
	var accepted_tpl: Dictionary = {}
	for q: Dictionary in p_server.state.quests:
		var body := _quest_body(p_server, q)
		if int(q["state"]) == S_DONE:
			done.append(body)
		else:
			accepted.append(body)
			accepted_tpl[str(q["template_id"])] = true
	var available: Array = []
	for tpl: Dictionary in DbQuests.QUESTS:
		var qid := str(tpl["id"])
		if accepted_tpl.has(qid):
			continue
		if _has_active_or_done(p_server, qid):
			continue
		if _prereq_done(p_server, tpl):
			available.append(_template_body(tpl))
	return Rpc.ok({"accepted": accepted, "available": available, "done": done, "tracked": p_server.state.tracked_quest_uid})


## 接取任务
func _h_accept(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var tpl: Dictionary = DbQuests.get_template(arg_str(p_body, "template_id", ""))
	if tpl.is_empty():
		return Rpc.err(Rpc.NOT_FOUND, "任务不存在")
	if _has_active_or_done(p_server, str(tpl["id"])):
		return Rpc.rule(Rpc.RULE_STATE, "该任务已接取或已完成")
	if not _prereq_done(p_server, tpl):
		return Rpc.rule(Rpc.RULE_PREREQ, "前置任务尚未完成")
	var state: RefCounted = p_server.state
	state.quests.append({
		"uid": Ulid.new_id(), "template_id": str(tpl["id"]),
		"state": S_ACCEPTED, "progress": {}, "tracked": false,
	})
	_check_ready(p_server, state.quests.back())
	p_server.push("quest.changed", {})
	return Rpc.ok({"quests": _refresh_list(p_server)})


## 放弃任务（仅进行中）
func _h_abandon(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var q := _find(p_server, arg_str(p_body, "uid", ""))
	if q.is_empty() or int(q["state"]) == S_DONE:
		return Rpc.rule(Rpc.RULE_STATE, "该任务无法放弃")
	p_server.state.quests.erase(q)
	if p_server.state.tracked_quest_uid == str(q["uid"]):
		p_server.state.tracked_quest_uid = ""
	p_server.push("quest.changed", {})
	return Rpc.ok({"quests": _refresh_list(p_server)})


## 追踪（同时仅一条）
func _h_track(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var uid := arg_str(p_body, "uid", "")
	var q := _find(p_server, uid)
	if q.is_empty() or int(q["state"]) == S_DONE:
		return Rpc.rule(Rpc.RULE_STATE, "该任务无法追踪")
	p_server.state.tracked_quest_uid = "" if p_server.state.tracked_quest_uid == uid else uid
	p_server.push("quest.changed", {})
	return Rpc.ok({"quests": _refresh_list(p_server), "tracked": p_server.state.tracked_quest_uid})


## 交付：状态须为可交付（READY），发放奖励
func _h_claim(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var q := _find(p_server, arg_str(p_body, "uid", ""))
	if q.is_empty() or int(q["state"]) != S_READY:
		return Rpc.rule(Rpc.RULE_STATE, "任务目标尚未完成，无法交付")
	var tpl: Dictionary = DbQuests.get_template(str(q["template_id"]))
	var state: RefCounted = p_server.state
	var rewards: Dictionary = tpl.get("rewards", {})
	state.copper += int(rewards.get("copper", 0))
	state.spirit_stone += int(rewards.get("stone", 0))
	var xp_gain := int(rewards.get("xp", 0))
	var inv: Variant = p_server._handlers[&"inventory"]
	for it: Variant in rewards.get("items", []):
		inv.add_item(p_server, str(it["template_id"]), int(it["count"]))
	q["state"] = S_DONE
	if state.tracked_quest_uid == str(q["uid"]):
		state.tracked_quest_uid = ""
	if xp_gain > 0:
		gain_xp(p_server, xp_gain)
	p_server.push("quest.changed", {})
	return Rpc.ok({"quests": _refresh_list(p_server), "rewards": rewards, "wallet": load("res://src/server/local/handlers/h_inventory.gd").wallet_body(state)})


# ============ 进度联动（由背包/战斗域回调） ============

## 击杀推进（由 h_world 调用）
func on_kill(p_server: RefCounted, p_monster: String) -> void:
	var changed := false
	for q: Dictionary in p_server.state.quests:
		if int(q["state"]) == S_DONE:
			continue
		var tpl: Dictionary = DbQuests.get_template(str(q["template_id"]))
		for i in range(tpl.get("goals", []).size()):
			var goal: Dictionary = tpl["goals"][i]
			if str(goal["kind"]) == "kill" and str(goal["target"]) == p_monster:
				var cur := int(q["progress"].get(str(i), 0))
				q["progress"][str(i)] = mini(cur + 1, int(goal["need"]))
				changed = true
		if _check_ready(p_server, q):
			changed = true
	if changed:
		p_server.push("quest.changed", {})


## 收集推进（由 h_inventory 变更后调用：以背包数量为准）
func check_collect(p_server: RefCounted) -> void:
	var changed := false
	for q: Dictionary in p_server.state.quests:
		if int(q["state"]) == S_DONE:
			continue
		var tpl: Dictionary = DbQuests.get_template(str(q["template_id"]))
		for i in range(tpl.get("goals", []).size()):
			var goal: Dictionary = tpl["goals"][i]
			if str(goal["kind"]) != "collect":
				continue
			var owned := _count_item(p_server, str(goal["template_id"]))
			var need := int(goal["need"])
			var cur := mini(owned, need)
			if int(q["progress"].get(str(i), 0)) != cur:
				q["progress"][str(i)] = cur
				changed = true
		if _check_ready(p_server, q):
			changed = true
	if changed:
		p_server.push("quest.changed", {})


# ============ 内部 ============

## 目标全满足则置为可交付；返回是否发生状态变化
func _check_ready(p_server: RefCounted, p_q: Dictionary) -> bool:
	if p_q.is_empty() or int(p_q["state"]) != S_ACCEPTED:
		return false
	var tpl: Dictionary = DbQuests.get_template(str(p_q["template_id"]))
	var goals: Array = tpl.get("goals", [])
	for i in range(goals.size()):
		if int(p_q["progress"].get(str(i), 0)) < int(goals[i]["need"]):
			return false
	p_q["state"] = S_READY
	return true


func _prereq_done(p_server: RefCounted, p_tpl: Dictionary) -> bool:
	for pre: Variant in p_tpl.get("prereq", []):
		if not _state_of(p_server, str(pre), S_DONE):
			return false
	return true


func _state_of(p_server: RefCounted, p_tpl_id: String, p_state_flag: int) -> bool:
	for q: Dictionary in p_server.state.quests:
		if str(q["template_id"]) == p_tpl_id and int(q["state"]) >= p_state_flag:
			return true
	return false


func _has_active_or_done(p_server: RefCounted, p_tpl_id: String) -> bool:
	return _state_of(p_server, p_tpl_id, S_ACCEPTED)


func _find(p_server: RefCounted, p_uid: String) -> Dictionary:
	for q: Dictionary in p_server.state.quests:
		if str(q["uid"]) == p_uid:
			return q
	return {}


func _count_item(p_server: RefCounted, p_tpl_id: String) -> int:
	var n := 0
	for it: Dictionary in p_server.state.items:
		if str(it["template_id"]) == p_tpl_id:
			n += int(it["count"])
	return n


## 修为入账 + 升级链（公开：供战斗等域复用）
func gain_xp(p_server: RefCounted, p_xp: int) -> void:
	var state: RefCounted = p_server.state
	var ch := load("res://src/server/local/handlers/h_character.gd")
	state.xp += p_xp
	while state.xp >= state.xp_need() and state.level < int(state.REALM_RANGES[state.realm][1]):
		state.xp -= state.xp_need()
		state.level += 1
		state.refresh_realm()
		state.free_attr += 1
	p_server.push("char.state", {"character": ch.char_body(state)})


## 任务实例展示体（含模板信息 + 目标进度）
func _quest_body(p_server: RefCounted, p_q: Dictionary) -> Dictionary:
	var tpl: Dictionary = DbQuests.get_template(str(p_q["template_id"]))
	var goals: Array = []
	for i in range(tpl.get("goals", []).size()):
		var goal: Dictionary = tpl["goals"][i]
		var body := {"kind": goal["kind"], "need": int(goal["need"]), "cur": int(p_q["progress"].get(str(i), 0)), "text": ""}
		match str(goal["kind"]):
			"kill":
				body["text"] = "击杀 %s" % str(goal["target"])
			"collect":
				var t: Dictionary = DbItems.get_template(str(goal["template_id"]))
				body["text"] = "收集 %s" % str(t.get("name", goal["template_id"]))
		goals.append(body)
	var rewards: Dictionary = tpl.get("rewards", {})
	var reward_items: Array = []
	for it: Variant in rewards.get("items", []):
		var t2: Dictionary = DbItems.get_template(str(it["template_id"]))
		reward_items.append({"name": t2.get("name", ""), "icon": t2.get("icon", ""), "count": int(it["count"]), "quality": int(t2.get("quality", 0))})
	return {
		"uid": p_q["uid"], "template_id": p_q["template_id"], "name": str(tpl["name"]),
		"type": int(tpl["type"]), "type_name": DbQuests.type_name(int(tpl["type"])),
		"desc": str(tpl["desc"]), "state": int(p_q["state"]),
		"ready": int(p_q["state"]) == S_READY, "tracked": p_server.state.tracked_quest_uid == str(p_q["uid"]),
		"goals": goals, "rewards": {"copper": int(rewards.get("copper", 0)), "stone": int(rewards.get("stone", 0)), "xp": int(rewards.get("xp", 0)), "items": reward_items},
	}


## 可接任务展示体
func _template_body(p_tpl: Dictionary) -> Dictionary:
	return {
		"uid": "", "template_id": p_tpl["id"], "name": str(p_tpl["name"]),
		"type": int(p_tpl["type"]), "type_name": DbQuests.type_name(int(p_tpl["type"])),
		"desc": str(p_tpl["desc"]), "state": 0, "ready": false, "tracked": false,
		"goals": [], "rewards": _template_rewards(p_tpl),
	}


func _template_rewards(p_tpl: Dictionary) -> Dictionary:
	var rewards: Dictionary = p_tpl.get("rewards", {})
	var reward_items: Array = []
	for it: Variant in rewards.get("items", []):
		var t: Dictionary = DbItems.get_template(str(it["template_id"]))
		reward_items.append({"name": t.get("name", ""), "icon": t.get("icon", ""), "count": int(it["count"]), "quality": int(t.get("quality", 0))})
	return {"copper": int(rewards.get("copper", 0)), "stone": int(rewards.get("stone", 0)), "xp": int(rewards.get("xp", 0)), "items": reward_items}


func _refresh_list(p_server: RefCounted) -> Dictionary:
	var res := _h_list(p_server, {})
	return Rpc.body(res)
