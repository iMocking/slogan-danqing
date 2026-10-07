# 仙途 · 功法图谱域 Handler：图谱查询 / 学习升级
extends "res://src/server/local/handlers/h_base.gd"


## 某系图谱：节点 + 状态（learned/available/locked）+ 剩余修为点
func _h_tree(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var branch := arg_int(p_body, "branch", 0)
	var state: RefCounted = p_server.state
	var nodes: Array = []
	for n: Dictionary in DbSkills.nodes(branch):
		nodes.append(_node_body(state, n))
	return Rpc.ok({"branch": branch, "nodes": nodes, "points": state.skill_points, "max_level": DbSkills.MAX_LEVEL})


## 学习/升级：前置满足 + 点数足够
func _h_learn(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var sid := arg_str(p_body, "skill_id", "")
	var node: Dictionary = DbSkills.get_node(sid)
	if node.is_empty():
		return Rpc.err(Rpc.NOT_FOUND, "功法不存在")
	var state: RefCounted = p_server.state
	var level := int(state.learned.get(sid, 0))
	if level >= int(node["max_level"]):
		return Rpc.rule(Rpc.RULE_STATE, "该功法已修炼至圆满")
	for pre: Variant in node["prereq"]:
		if int(state.learned.get(str(pre), 0)) < 1:
			return Rpc.rule(Rpc.RULE_PREREQ, "需先修成前置功法")
	var cost := int(node["cost_per_level"])
	if state.skill_points < cost:
		return Rpc.rule(Rpc.RULE_NO_POINT, "修为点不足")
	state.skill_points -= cost
	state.learned[sid] = level + 1
	p_server.push("char.state", {"character": load("res://src/server/local/handlers/h_character.gd").char_body(state)})
	return Rpc.ok({"skill_id": sid, "level": level + 1, "points": state.skill_points})


## 已学功法摘要（供 HUD 技能栏装配）
func _h_known(p_server: RefCounted, _p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var known: Array = []
	for sid: String in p_server.state.learned:
		var node: Dictionary = DbSkills.get_node(sid)
		if node.is_empty():
			continue
		known.append({
			"skill_id": sid, "name": node["name"], "icon": node["icon"],
			"level": int(p_server.state.learned[sid]), "mp_cost": int(node["mp_cost"]),
			"cooldown": float(node["cooldown"]),
		})
	return Rpc.ok({"known": known})


## 节点展示体：附加状态与等级
func _node_body(p_state: RefCounted, p_node: Dictionary) -> Dictionary:
	var sid := str(p_node["id"])
	var level := int(p_state.learned.get(sid, 0))
	var prereq_ok := true
	for pre: Variant in p_node["prereq"]:
		if int(p_state.learned.get(str(pre), 0)) < 1:
			prereq_ok = false
			break
	var status := "locked"
	if level >= 1:
		status = "learned"
	elif prereq_ok and p_state.skill_points >= int(p_node["cost_per_level"]):
		status = "available"
	return {
		"id": sid, "name": p_node["name"], "row": int(p_node["row"]), "col": int(p_node["col"]),
		"prereq": p_node["prereq"], "max_level": int(p_node["max_level"]),
		"level": level, "status": status, "mp_cost": int(p_node["mp_cost"]),
		"cooldown": float(p_node["cooldown"]), "icon": p_node["icon"], "desc": p_node["desc"],
	}
