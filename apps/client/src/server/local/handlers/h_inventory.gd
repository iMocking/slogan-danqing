# 仙途 · 背包域 Handler：增删改查 / 堆叠 / 整理 / 拆分
extends "res://src/server/local/handlers/h_base.gd"

const CATEGORY_MAP := {
	"all": "", "equip": "equip", "pill": "pill", "material": "material", "quest": "quest",
}


## 背包列表：items(展开模板) + wallet + 容量
func _h_list(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var cat := arg_str(p_body, "category", "all")
	var filter: String = CATEGORY_MAP.get(cat, "")
	var out: Array = []
	for it: Dictionary in p_server.state.items:
		var tpl: Dictionary = DbItems.get_template(str(it["template_id"]))
		if not filter.is_empty() and str(tpl.get("type")) != filter:
			continue
		out.append(item_body(it, tpl))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["uid"]) < str(b["uid"]))
	return Rpc.ok({"items": out, "wallet": wallet_body(p_server.state), "capacity": p_server.state.BAG_SIZE})


## 使用消耗品：回气血/真元
func _h_use(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var found := _find(p_server, arg_str(p_body, "uid", ""))
	if found.is_empty():
		return Rpc.err(Rpc.NOT_FOUND, "物品不存在")
	var tpl: Dictionary = DbItems.get_template(str(found["template_id"]))
	if str(tpl.get("type")) != "pill":
		return Rpc.rule(Rpc.RULE_STATE, "该物品无法直接使用")
	var state: RefCounted = p_server.state
	var ch: Dictionary = load("res://src/server/local/handlers/h_character.gd").compute_stats(state)
	match str(found["template_id"]):
		"item_pill_huiqi", "item_wine_guihua":
			state.hp = mini(int(ch["hp_max"]), state.hp + (150 if str(found["template_id"]) == "item_pill_huiqi" else 30))
		"item_pill_ningshen":
			state.mp = mini(int(ch["mp_max"]), state.mp + 100)
		_:
			return Rpc.rule(Rpc.RULE_STATE, "此丹药暂无药效")
	remove_item(p_server, str(found["uid"]), 1)
	p_server.push("char.state", {"character": load("res://src/server/local/handlers/h_character.gd").char_body(state)})
	return Rpc.ok({"items": _list_all(p_server), "wallet": wallet_body(state)})


## 丢弃（可选 count，默认整组）
func _h_drop(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var uid := arg_str(p_body, "uid", "")
	var found := _find(p_server, uid)
	if found.is_empty():
		return Rpc.err(Rpc.NOT_FOUND, "物品不存在")
	var count := arg_int(p_body, "count", int(found["count"]))
	if count >= int(found["count"]):
		p_server.state.items.erase(found)
	else:
		found["count"] = int(found["count"]) - count
	_on_items_changed(p_server)
	return Rpc.ok({"items": _list_all(p_server), "wallet": wallet_body(p_server.state)})


## 整理：品质降序 → 类型 → 名称，并合并同模板堆叠
func _h_sort(p_server: RefCounted, _p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	_compact(p_server)
	p_server.state.items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: Dictionary = DbItems.get_template(str(a["template_id"]))
		var tb: Dictionary = DbItems.get_template(str(b["template_id"]))
		if int(ta.get("quality", 0)) != int(tb.get("quality", 0)):
			return int(ta.get("quality", 0)) > int(tb.get("quality", 0))
		if str(ta.get("type")) != str(tb.get("type")):
			return str(ta.get("type")) < str(tb.get("type"))
		return str(ta.get("name")) < str(tb.get("name")))
	_on_items_changed(p_server)
	return Rpc.ok({"items": _list_all(p_server), "wallet": wallet_body(p_server.state)})


## 拆分：从一组中拆出 count 个为新实例（ULID）
func _h_split(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var found := _find(p_server, arg_str(p_body, "uid", ""))
	if found.is_empty():
		return Rpc.err(Rpc.NOT_FOUND, "物品不存在")
	var count := arg_int(p_body, "count", 1)
	if count <= 0 or count >= int(found["count"]):
		return Rpc.err(Rpc.BAD_PARAM, "拆分数量非法")
	var tpl: Dictionary = DbItems.get_template(str(found["template_id"]))
	if int(tpl.get("max_stack", 1)) <= 1:
		return Rpc.rule(Rpc.RULE_STATE, "该物品不可堆叠，无需拆分")
	found["count"] = int(found["count"]) - count
	p_server.state.items.append({"uid": Ulid.new_id(), "template_id": found["template_id"], "count": count})
	_on_items_changed(p_server)
	return Rpc.ok({"items": _list_all(p_server), "wallet": wallet_body(p_server.state)})


# ============ 供其他域调用的内部服务 ============

## 新增物品（自动堆叠；背包满返回 false 并丢弃溢出）
func add_item(p_server: RefCounted, p_template_id: String, p_count: int) -> bool:
	var tpl: Dictionary = DbItems.get_template(p_template_id)
	if tpl.is_empty() or p_count <= 0:
		return false
	var state: RefCounted = p_server.state
	var left := p_count
	var max_stack := maxi(1, int(tpl.get("max_stack", 1)))
	if max_stack > 1:
		for it: Dictionary in state.items:
			if str(it["template_id"]) == p_template_id and int(it["count"]) < max_stack:
				var take := mini(max_stack - int(it["count"]), left)
				it["count"] = int(it["count"]) + take
				left -= take
				if left <= 0:
					_on_items_changed(p_server)
					return true
	while left > 0 and state.items.size() < state.BAG_SIZE:
		var put := mini(max_stack, left)
		state.items.append({"uid": Ulid.new_id(), "template_id": p_template_id, "count": put})
		left -= put
	_on_items_changed(p_server)
	return left <= 0


## 按模板找第一个实例 uid（供消耗类逻辑）
func find_item(p_server: RefCounted, p_template_id: String) -> String:
	for it: Dictionary in p_server.state.items:
		if str(it["template_id"]) == p_template_id:
			return str(it["uid"])
	return ""


## 扣减物品；不足或不存在返回 false
func remove_item(p_server: RefCounted, p_uid: String, p_count: int) -> bool:
	var found := _find(p_server, p_uid)
	if found.is_empty() or int(found["count"]) < p_count:
		return false
	if int(found["count"]) == p_count:
		p_server.state.items.erase(found)
	else:
		found["count"] = int(found["count"]) - p_count
	_on_items_changed(p_server)
	return true


## 物品展示体（实例 + 模板合并）
static func item_body(p_it: Dictionary, p_tpl: Dictionary) -> Dictionary:
	return {
		"uid": p_it["uid"], "template_id": p_it["template_id"], "count": int(p_it["count"]),
		"name": str(p_tpl.get("name", "未知")), "icon": str(p_tpl.get("icon", "")),
		"quality": int(p_tpl.get("quality", 0)), "type": str(p_tpl.get("type", "")),
		"desc": str(p_tpl.get("desc", "")), "sell_price": int(p_tpl.get("sell_price", 0)),
		"stats": p_tpl.get("stats", {}), "slot": str(p_tpl.get("slot", "")),
		"max_stack": int(p_tpl.get("max_stack", 1)),
	}


## 钱包数据体
static func wallet_body(p_state: RefCounted) -> Dictionary:
	return {"copper": p_state.copper, "spirit_stone": p_state.spirit_stone, "immortal_jade": p_state.immortal_jade}


## 通知任务域检查收集类目标
func _on_items_changed(p_server: RefCounted) -> void:
	var q: Variant = p_server._handlers.get(&"quest")
	if q != null:
		q.check_collect(p_server)


## 全量列表（不过滤）
func _list_all(p_server: RefCounted) -> Array:
	var out: Array = []
	for it: Dictionary in p_server.state.items:
		out.append(item_body(it, DbItems.get_template(str(it["template_id"]))))
	return out


## 按 uid 查实例
func _find(p_server: RefCounted, p_uid: String) -> Dictionary:
	for it: Dictionary in p_server.state.items:
		if str(it["uid"]) == p_uid:
			return it
	return {}


## 合并同模板堆叠
func _compact(p_server: RefCounted) -> void:
	var merged: Dictionary = {}
	var keep: Array = []
	for it: Dictionary in p_server.state.items:
		var tpl: Dictionary = DbItems.get_template(str(it["template_id"]))
		var key := str(it["template_id"])
		if int(tpl.get("max_stack", 1)) <= 1:
			keep.append(it)
			continue
		if merged.has(key):
			var base: Dictionary = merged[key]
			base["count"] = int(base["count"]) + int(it["count"])
		else:
			merged[key] = it
			keep.append(it)
	p_server.state.items = keep
