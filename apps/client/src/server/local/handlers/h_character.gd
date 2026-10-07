# 仙途 · 角色域 Handler：创建 / 查询 / 加点 / 突破 / 穿脱装备
extends "res://src/server/local/handlers/h_base.gd"

const NAME_MIN := 2
const NAME_MAX := 12
const ATTR_NAMES := ["筋骨", "灵气", "根骨", "悟性", "幸运"]


## 查询角色全量数据（含派生属性 / 装备 / 钱包）
func _h_get(p_server: RefCounted, _p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	return Rpc.ok({"character": char_body(p_server.state)})


## 捏人选项表（性别 / 门派 / 体型 / 面容 / 发型 / 服饰）
func _h_options(_p_server: RefCounted, _p_body: Dictionary) -> Dictionary:
	return Rpc.ok({
		"genders": DbMisc.GENDERS, "sects": DbMisc.SECTS,
		"body_types": DbMisc.BODY_TYPES, "faces": DbMisc.FACES,
		"hairs": DbMisc.HAIRS, "costumes": DbMisc.COSTUMES,
	})


## 创建角色（捏人）：校验名字/门派/外观，初始化背包与任务
func _h_create(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var miss := Rpc.check_keys(p_body, ["name", "gender", "sect"])
	if not miss.is_empty():
		return Rpc.err(Rpc.BAD_PARAM, miss)
	var state: RefCounted = p_server.state
	if not state.char_uid.is_empty():
		return Rpc.rule(Rpc.RULE_STATE, "已拥有角色，不能重复创建")
	var cname := str(p_body["name"]).strip_edges()
	if cname.length() < NAME_MIN or cname.length() > NAME_MAX:
		return Rpc.rule(Rpc.RULE_NAME, "角色名需 %d-%d 个字" % [NAME_MIN, NAME_MAX])
	var sect_info: Dictionary = DbMisc.get_sect(str(p_body["sect"]))
	if sect_info.is_empty():
		return Rpc.err(Rpc.NOT_FOUND, "门派不存在")
	state.char_uid = Ulid.new_id()
	state.char_name = cname
	state.gender = str(p_body["gender"])
	state.sect = str(sect_info["name"])
	# 门派五维加成并入基础五维
	for k: Variant in sect_info["bonus"]:
		state.five[k] = int(state.five.get(k, 0)) + int(sect_info["bonus"][k])
	state.level = 1
	state.xp = 0
	state.refresh_realm()
	# 初始行囊：回气丹 ×5 + 青锋铁剑（并穿上）
	var inv: Variant = p_server._handlers[&"inventory"]
	inv.add_item(p_server, "item_pill_huiqi", 5)
	inv.add_item(p_server, "item_sword_iron", 1)
	for it: Dictionary in state.items:
		if str(it["template_id"]) == "item_sword_iron":
			state.equips["weapon"] = str(it["uid"])
	# 主线任务一自动可接
	state.save()
	return Rpc.ok({"character": char_body(state)})


## 自由属性加点（消耗 free_attr）
func _h_allocate_point(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var attr := arg_str(p_body, "attr", "")
	var points := arg_int(p_body, "points", 1)
	if not ATTR_NAMES.has(attr):
		return Rpc.err(Rpc.BAD_PARAM, "未知属性：%s" % attr)
	var state: RefCounted = p_server.state
	if points <= 0 or points > state.free_attr:
		return Rpc.rule(Rpc.RULE_NO_POINT, "可用属性点不足")
	state.free_attr -= points
	state.attr_alloc[attr] = int(state.attr_alloc.get(attr, 0)) + points
	_push_state(p_server)
	return Rpc.ok({"character": char_body(state)})


## 境界突破：修为圆满 + 对应突破丹；普通升级仅消耗修为
func _h_breakthrough(p_server: RefCounted, _p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var state: RefCounted = p_server.state
	var inv: Variant = p_server._handlers[&"inventory"]
	if state.xp < state.xp_need():
		return Rpc.rule(Rpc.RULE_STATE, "修为尚未圆满，无法突破")
	# 境界边界（各境最后一期）需要突破丹，否则为普通升级
	var range_info: Array = state.REALM_RANGES[state.realm]
	if state.level >= int(range_info[1]):
		var pill_id := "item_pill_zhuji"
		var owner_uid: String = inv.find_item(p_server, pill_id)
		if owner_uid.is_empty():
			return Rpc.rule(Rpc.RULE_PREREQ, "突破需一枚%s" % DbItems.get_template(pill_id)["name"])
		inv.remove_item(p_server, owner_uid, 1)
		state.free_attr += 5
	state.level += 1
	state.xp = maxi(0, state.xp - state.xp_need())
	state.refresh_realm()
	state.hp = char_body(state)["hp_max"]
	state.mp = char_body(state)["mp_max"]
	_push_state(p_server)
	return Rpc.ok({"character": char_body(state)})


## 装备穿戴（uid 为背包物品实例）
func _h_wear(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var uid := arg_str(p_body, "uid", "")
	var state: RefCounted = p_server.state
	var target: Dictionary = {}
	for it: Dictionary in state.items:
		if str(it["uid"]) == uid:
			target = it
			break
	if target.is_empty():
		return Rpc.err(Rpc.NOT_FOUND, "物品不存在")
	var tpl: Dictionary = DbItems.get_template(str(target["template_id"]))
	if str(tpl.get("type")) != "equip":
		return Rpc.rule(Rpc.RULE_STATE, "该物品无法装备")
	state.equips[str(tpl["slot"])] = uid
	_push_state(p_server)
	return Rpc.ok({"character": char_body(state)})


## 卸下装备
func _h_unequip(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var slot := arg_str(p_body, "slot", "")
	var state: RefCounted = p_server.state
	if not state.equips.has(slot):
		return Rpc.err(Rpc.NOT_FOUND, "该槽位没有装备")
	state.equips.erase(slot)
	_push_state(p_server)
	return Rpc.ok({"character": char_body(state)})


## 派生属性计算（唯一数值源，UI 与战斗共用）
static func compute_stats(p_state: RefCounted) -> Dictionary:
	var bonus := {"hp": 0, "mp": 0, "atk": 0, "def": 0, "hit": 0, "dodge": 0}
	for slot: String in p_state.equips:
		var uid: String = p_state.equips[slot]
		for it: Dictionary in p_state.items:
			if str(it["uid"]) != uid:
				continue
			var tpl: Dictionary = DbItems.get_template(str(it["template_id"]))
			for k: String in bonus:
				bonus[k] += int(tpl.get("stats", {}).get(k, 0))
	var jingu := int(p_state.five.get("筋骨", 0)) + int(p_state.attr_alloc.get("筋骨", 0))
	var lingqi := int(p_state.five.get("灵气", 0)) + int(p_state.attr_alloc.get("灵气", 0))
	var gengu := int(p_state.five.get("根骨", 0)) + int(p_state.attr_alloc.get("根骨", 0))
	var wuxing := int(p_state.five.get("悟性", 0)) + int(p_state.attr_alloc.get("悟性", 0))
	return {
		"hp_max": 100 + p_state.level * 20 + jingu * 10 + int(bonus["hp"]),
		"mp_max": 50 + p_state.level * 10 + lingqi * 8 + int(bonus["mp"]),
		"atk": 8 + p_state.level * 2 + jingu / 2 + int(bonus["atk"]),
		"def": 5 + p_state.level + jingu * 2 + int(bonus["def"]),
		"hit": 90 + wuxing + int(bonus["hit"]),
		"dodge": 5 + gengu + int(bonus["dodge"]),
	}


## 角色数据体（响应 body 的 character 字段）
static func char_body(p_state: RefCounted) -> Dictionary:
	var s := compute_stats(p_state)
	var wallet := {"copper": p_state.copper, "spirit_stone": p_state.spirit_stone, "immortal_jade": p_state.immortal_jade}
	var equips: Dictionary = {}
	for slot: String in ["weapon", "hat", "robe", "accessory", "shoes", "necklace"]:
		equips[slot] = null
		if p_state.equips.has(slot):
			for it: Dictionary in p_state.items:
				if str(it["uid"]) == str(p_state.equips[slot]):
					var tpl: Dictionary = DbItems.get_template(str(it["template_id"]))
					equips[slot] = {"uid": it["uid"], "template_id": it["template_id"], "name": tpl.get("name", ""), "icon": tpl.get("icon", ""), "quality": int(tpl.get("quality", 0))}
					break
	var five_total := {}
	for k: String in ATTR_NAMES:
		five_total[k] = int(p_state.five.get(k, 0)) + int(p_state.attr_alloc.get(k, 0))
	return {
		"uid": p_state.char_uid, "name": p_state.char_name, "gender": p_state.gender,
		"sect": p_state.sect, "level": p_state.level, "xp": p_state.xp,
		"xp_need": p_state.xp_need(), "realm": p_state.realm, "stage": p_state.stage,
		"realm_text": Enums.realm_text(p_state.realm, p_state.stage, p_state.level),
		"hp": p_state.hp, "mp": p_state.mp, "title": p_state.title,
		"skill_points": p_state.skill_points, "free_attr": p_state.free_attr,
		"five": five_total, "attr_alloc": p_state.attr_alloc,
		"wallet": wallet, "equips": equips,
		"hp_max": int(s["hp_max"]), "mp_max": int(s["mp_max"]),
		"atk": int(s["atk"]), "def": int(s["def"]),
		"hit": int(s["hit"]), "dodge": int(s["dodge"]),
		"current_region": p_state.current_region,
	}


## 广播角色状态（推送 body）
func _push_state(p_server: RefCounted) -> void:
	p_server.push("char.state", {"character": char_body(p_server.state)})
