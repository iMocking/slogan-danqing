# 仙途 · 世界域 Handler：地图 / 传送 / 战斗演示（击杀驱动任务进度）
extends "res://src/server/local/handlers/h_base.gd"

const REST_FREE := true    # 打坐恢复免费（单机演示）


## 世界大地图：八区域 + 道路 + 当前位置
func _h_map(p_server: RefCounted, _p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var state: RefCounted = p_server.state
	var regions: Array = []
	for r: Dictionary in DbWorld.REGIONS:
		regions.append({
			"id": r["id"], "name": r["name"], "pos": r["pos"],
			"unlock_realm": int(r["unlock_realm"]), "recommend": str(r["recommend"]),
			"boss": str(r["boss"]), "desc": str(r["desc"]),
			"unlocked": state.unlocked_regions.has(str(r["id"])) or state.realm >= int(r["unlock_realm"]),
			"is_current": str(r["id"]) == state.current_region,
		})
	return Rpc.ok({"regions": regions, "roads": DbWorld.ROADS, "current": state.current_region})


## 传送：境界达到解锁要求；首达自动解锁
func _h_travel(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var region: Dictionary = DbWorld.get_region(arg_str(p_body, "region_id", ""))
	if region.is_empty():
		return Rpc.err(Rpc.NOT_FOUND, "区域不存在")
	var state: RefCounted = p_server.state
	if state.realm < int(region["unlock_realm"]):
		return Rpc.rule(Rpc.RULE_PREREQ, "境界不足，需达到 %s 期" % Enums.REALM_NAMES[int(region["unlock_realm"])])
	if not state.unlocked_regions.has(str(region["id"])):
		state.unlocked_regions.append(str(region["id"]))
	state.current_region = str(region["id"])
	p_server.push("toast", {"text": "已抵达 %s" % str(region["name"]), "kind": 0})
	return Rpc.ok({"current": state.current_region})


## 普通攻击 / 释放技能（演示战斗：伤害结算 + 击杀奖励 + 任务推进）
func _h_fight(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var state: RefCounted = p_server.state
	var battle: Dictionary = _ensure_battle(state)
	var ch := load("res://src/server/local/handlers/h_character.gd")
	var stats: Dictionary = ch.compute_stats(state)
	# 技能结算：真元不足则回落普攻
	var skill_id := arg_str(p_body, "skill_id", "")
	var dmg := int(stats["atk"])
	var mp_cost := 0
	if not skill_id.is_empty():
		var node: Dictionary = DbSkills.get_node(skill_id)
		var lvl := int(state.learned.get(skill_id, 0))
		if node.is_empty() or lvl < 1:
			return Rpc.rule(Rpc.RULE_PREREQ, "尚未修成该功法")
		mp_cost = int(node["mp_cost"]) * lvl
		if state.mp < mp_cost:
			return Rpc.rule(Rpc.RULE_NO_MONEY, "真元不足")
		state.mp -= mp_cost
		dmg = int(stats["atk"]) * (2 + lvl) / 2
	# 怪物反击：固定 6~14 点
	var hurt := 6 + randi() % 9
	state.hp = maxi(0, state.hp - hurt)
	var monster: Dictionary = battle["monster"]
	monster["hp"] = int(monster["hp"]) - dmg
	var killed := int(monster["hp"]) <= 0
	var rewards := {}
	if killed:
		var tpl: Dictionary = battle["tpl"]
		rewards = {"xp": int(tpl["xp"]), "copper": int(tpl["copper"]), "drops": _roll_drops(p_server, tpl)}
		state.copper += int(tpl["copper"])
		var qh: Variant = p_server._handlers[&"quest"]
		qh.on_kill(p_server, str(tpl["name"]))
		qh.gain_xp(p_server, int(tpl["xp"]))
		state.battle = {}
	var body := {
		"damage": dmg, "hurt": hurt, "killed": killed, "rewards": rewards,
		"skill_id": skill_id, "mp_cost": mp_cost,
		"monster": battle.get("monster", {}),
		"character": ch.char_body(state),
	}
	p_server.push("char.state", {"character": body["character"]})
	return Rpc.ok(body)


## 打坐恢复气血真元
func _h_rest(p_server: RefCounted, _p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var ch := load("res://src/server/local/handlers/h_character.gd")
	var stats: Dictionary = ch.compute_stats(p_server.state)
	p_server.state.hp = int(stats["hp_max"])
	p_server.state.mp = int(stats["mp_max"])
	p_server.push("char.state", {"character": ch.char_body(p_server.state)})
	return Rpc.ok({"character": ch.char_body(p_server.state)})


## 场上怪物（无则从区域怪表随机）
func _ensure_battle(p_state: RefCounted) -> Dictionary:
	if not p_state.battle.is_empty():
		return p_state.battle
	var tpl: Dictionary = DbWorld.MONSTERS[randi() % DbWorld.MONSTERS.size()]
	p_state.battle = {
		"monster": {"name": tpl["name"], "hp": int(tpl["hp"]), "max_hp": int(tpl["hp"])},
		"tpl": tpl,
	}
	return p_state.battle


## 掉落：60% 概率掉 1 件（可再追加）
func _roll_drops(p_server: RefCounted, p_tpl: Dictionary) -> Array:
	var drops: Array = []
	var inv: Variant = p_server._handlers[&"inventory"]
	var table: Array = p_tpl.get("drops", [])
	if table.is_empty():
		return drops
	if randf() < 0.6:
		var tid := str(table[randi() % table.size()])
		var count := 1 if randf() > 0.2 else 2
		if inv.add_item(p_server, tid, count):
			var t: Dictionary = DbItems.get_template(tid)
			drops.append({"name": str(t["name"]), "icon": str(t["icon"]), "count": count, "quality": int(t["quality"])})
	return drops
