# 仙途 · 万宝拍卖行域 Handler：浏览 / 出价 / 上架 / 下架 / 到期结算
# 单机模拟：NPC 挂单 + bot_tick 竞争出价；信封与推送为联机预留同构协议。
extends "res://src/server/local/handlers/h_base.gd"

const PAGE_SIZE := 20
const FEE_RATE := 0.05          # 成交手续费 5%
const MIN_BID_RATE := 1.05      # 竞价幅度下限
const VALID_HOURS := [12, 24, 48]
const TAB_BROWSE := 0
const TAB_MINE := 1
const TAB_MY_BID := 2
const TAB_RECORD := 3


## 拍卖列表：tab + 筛选（分类/品质/名称）+ 分页
func _h_list(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	_seed(p_server)
	if not g.is_empty():
		return g
	_settle_due(p_server)
	var tab := arg_int(p_body, "tab", TAB_BROWSE)
	var rows: Array = []
	match tab:
		TAB_MINE:
			for e: Dictionary in p_server.state.auction_entries:
				if str(e["seller_uid"]) == p_server.state.account_uid and str(e["state"]) == "live":
					rows.append(_entry_body(p_server, e))
		TAB_MY_BID:
			for e: Dictionary in p_server.state.auction_entries:
				if str(e["bidder_uid"]) == p_server.state.account_uid and str(e["state"]) == "live":
					rows.append(_entry_body(p_server, e))
		TAB_RECORD:
			for r: Dictionary in p_server.state.auction_records:
				rows.append(_record_body(r))
		_:
			for e: Dictionary in p_server.state.auction_entries:
				if str(e["state"]) == "live":
					rows.append(_entry_body(p_server, e))
	rows = _filter_rows(rows, p_body, tab)
	var pages := maxi(1, int(ceil(rows.size() / float(PAGE_SIZE))))
	var page := mini(maxi(1, arg_int(p_body, "page", 1)), pages)
	return Rpc.ok({"rows": rows.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE), "pages": pages, "page": page, "wallet": _wallet(p_server.state)})


## 出价：≥ 当前价 1.05 倍；锁定灵石；触及一口价立即成交
func _h_bid(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	_settle_due(p_server)
	var e := _find_entry(p_server, arg_str(p_body, "entry_uid", ""))
	if e.is_empty() or str(e["state"]) != "live":
		return Rpc.rule(Rpc.RULE_STATE, "该拍卖已结束")
	if str(e["seller_uid"]) == p_server.state.account_uid:
		return Rpc.rule(Rpc.RULE_STATE, "不能竞拍自己的挂单")
	var price := arg_int(p_body, "price", 0)
	var min_price := int(ceil(int(e["current_price"]) * MIN_BID_RATE))
	if price < min_price:
		return Rpc.rule(Rpc.RULE_STATE, "出价不得低于 %d 灵石" % min_price)
	var state: RefCounted = p_server.state
	if state.spirit_stone < price:
		return Rpc.rule(Rpc.RULE_NO_MONEY, "灵石不足")
	state.spirit_stone -= price
	# 上一手若是玩家本人，返还锁定的灵石
	if str(e["bidder_uid"]) == state.account_uid:
		state.spirit_stone += int(e["current_price"])
	e["current_price"] = price
	e["bidder_uid"] = state.account_uid
	e["bidder_name"] = state.char_name
	p_server.push("auction.updated", {"entry": _entry_body(p_server, e)})
	var bought_out := int(e["buyout"]) > 0 and price >= int(e["buyout"])
	if bought_out:
		_settle_one(p_server, e)
	return Rpc.ok({"wallet": _wallet(state), "bought_out": bought_out})


## 上架：从背包移除物品 → 生成挂单（ULID）
func _h_list_item(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var inv: Variant = p_server._handlers[&"inventory"]
	var item_uid := arg_str(p_body, "uid", "")
	var found: Dictionary = inv._find(p_server, item_uid)
	if found.is_empty():
		return Rpc.err(Rpc.NOT_FOUND, "背包中不存在该物品")
	var tpl: Dictionary = DbItems.get_template(str(found["template_id"]))
	if tpl.is_empty():
		return Rpc.err(Rpc.NOT_FOUND, "物品模板不存在")
	var start_price := maxi(1, arg_int(p_body, "start_price", 1))
	var buyout := maxi(0, arg_int(p_body, "buyout", 0))
	var hours := arg_int(p_body, "hours", 24)
	if not VALID_HOURS.has(hours):
		return Rpc.err(Rpc.BAD_PARAM, "上架时长仅支持 12/24/48 小时")
	if not inv.remove_item(p_server, item_uid, int(found["count"])):
		return Rpc.rule(Rpc.RULE_STATE, "物品数量发生变化，请重试")
	p_server.state.auction_entries.append({
		"uid": Ulid.new_id(),
		"item": {"template_id": tpl["id"], "name": tpl["name"], "icon": tpl["icon"], "quality": int(tpl["quality"]), "count": int(found["count"])},
		"seller_uid": p_server.state.account_uid, "seller_name": p_server.state.char_name,
		"start_price": start_price, "current_price": start_price, "buyout": buyout,
		"bidder_uid": "", "bidder_name": "",
		"end_ts": int(Time.get_unix_time_from_system()) + hours * 3600,
		"state": "live",
	})
	p_server.push("auction.updated", {})
	return Rpc.ok({"wallet": _wallet(p_server.state)})


## 下架：仅无人出价时允许
func _h_cancel(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var e := _find_entry(p_server, arg_str(p_body, "entry_uid", ""))
	if e.is_empty() or str(e["seller_uid"]) != p_server.state.account_uid:
		return Rpc.err(Rpc.NOT_FOUND, "挂单不存在")
	if str(e["state"]) != "live":
		return Rpc.rule(Rpc.RULE_STATE, "该拍卖已结束")
	if not str(e["bidder_uid"]).is_empty():
		return Rpc.rule(Rpc.RULE_STATE, "已有玩家出价，无法下架")
	var inv: Variant = p_server._handlers[&"inventory"]
	inv.add_item(p_server, str(e["item"]["template_id"]), int(e["item"]["count"]))
	e["state"] = "settled"
	_add_record(p_server, {"item_name": str(e["item"]["name"]), "kind": "cancel", "price": 0, "seller": p_server.state.char_name, "buyer": ""})
	p_server.push("auction.updated", {})
	return Rpc.ok({})


## 周期驱动：竞争者出价 + 到期结算（由 LocalServer.tick 调用）
func bot_tick(p_server: RefCounted) -> void:
	_settle_due(p_server)
	var live: Array = []
	for e: Dictionary in p_server.state.auction_entries:
		if str(e["state"]) == "live":
			live.append(e)
	if live.is_empty():
		return
	var e: Dictionary = live[randi() % live.size()]
	if str(e["bidder_uid"]) == p_server.state.account_uid or randf() < 0.5:
		var bot_name: String = DbMisc.BID_BOTS[randi() % DbMisc.BID_BOTS.size()]
		if str(e["bidder_name"]) == bot_name:
			return
		if str(e["bidder_uid"]) == p_server.state.account_uid:
			p_server.state.spirit_stone += int(e["current_price"])
			p_server.push("toast", {"text": "「%s」在拍卖行超越了你的出价" % bot_name, "kind": 1})
		var next_price := int(ceil(int(e["current_price"]) * MIN_BID_RATE))
		if int(e["buyout"]) > 0 and next_price >= int(e["buyout"]):
			next_price = int(e["buyout"])
		e["current_price"] = next_price
		e["bidder_uid"] = "bot"
		e["bidder_name"] = bot_name
		p_server.push("auction.updated", {"entry": _entry_body(p_server, e)})


# ============ 结算与数据体 ============

## 到期批量结算
func _settle_due(p_server: RefCounted) -> void:
	var now := int(Time.get_unix_time_from_system())
	for e: Dictionary in p_server.state.auction_entries:
		if str(e["state"]) == "live" and now >= int(e["end_ts"]):
			_settle_one(p_server, e)


## 单笔结算：有出价者成交（卖家得 95%），否则流拍返还
func _settle_one(p_server: RefCounted, p_e: Dictionary) -> void:
	var state: RefCounted = p_server.state
	var is_player_seller: bool = str(p_e["seller_uid"]) == state.account_uid
	p_e["state"] = "ended"
	if str(p_e["bidder_uid"]).is_empty():
		if is_player_seller:
			var inv: Variant = p_server._handlers[&"inventory"]
			inv.add_item(p_server, str(p_e["item"]["template_id"]), int(p_e["item"]["count"]))
			p_server.push("toast", {"text": "「%s」流拍，物品已返还乾坤袋" % str(p_e["item"]["name"]), "kind": 0})
		_add_record(p_server, {"item_name": p_e["item"]["name"], "kind": "expired", "price": 0, "seller": str(p_e["seller_name"]), "buyer": ""})
		return
	var income := int(round(int(p_e["current_price"]) * (1.0 - FEE_RATE)))
	if is_player_seller:
		state.spirit_stone += income
		p_server.push("toast", {"text": "「%s」已售出，入账 %d 灵石" % [str(p_e["item"]["name"]), income], "kind": 0})
	if str(p_e["bidder_uid"]) == state.account_uid:
		var inv2: Variant = p_server._handlers[&"inventory"]
		inv2.add_item(p_server, str(p_e["item"]["template_id"]), int(p_e["item"]["count"]))
		p_server.push("toast", {"text": "竞得「%s」，已放入乾坤袋" % str(p_e["item"]["name"]), "kind": 0})
	_add_record(p_server, {"item_name": p_e["item"]["name"], "kind": "sold", "price": int(p_e["current_price"]), "seller": str(p_e["seller_name"]), "buyer": str(p_e["bidder_name"])})
	p_server.push("auction.updated", {})


## NPC 种子挂单（首次浏览时生成）
func _seed(p_server: RefCounted) -> void:
	if not p_server.state.auction_entries.is_empty():
		return
	var now := int(Time.get_unix_time_from_system())
	for i in range(12):
		var tpl: Dictionary = DbItems.ITEMS[randi() % DbItems.ITEMS.size()]
		var start := 10 + randi() % 200
		var bot_name: String = DbMisc.BID_BOTS[randi() % DbMisc.BID_BOTS.size()]
		p_server.state.auction_entries.append({
			"uid": Ulid.new_id(),
			"item": {"template_id": tpl["id"], "name": tpl["name"], "icon": tpl["icon"], "quality": int(tpl["quality"]), "count": 1},
			"seller_uid": "bot", "seller_name": bot_name,
			"start_price": start, "current_price": start, "buyout": start * 2 if i % 3 == 0 else 0,
			"bidder_uid": "", "bidder_name": "",
			"end_ts": now + 600 + randi() % 140000,
			"state": "live",
		})


func _filter_rows(p_rows: Array, p_body: Dictionary, p_tab: int) -> Array:
	if p_tab == TAB_RECORD:
		return p_rows
	var name_kw := arg_str(p_body, "name", "")
	var quality := arg_int(p_body, "quality", -1)
	var out: Array = []
	for b: Dictionary in p_rows:
		if not name_kw.is_empty() and not str(b["name"]).contains(name_kw):
			continue
		if quality >= 0 and int(b["quality"]) != quality:
			continue
		out.append(b)
	return out


func _find_entry(p_server: RefCounted, p_uid: String) -> Dictionary:
	for e: Dictionary in p_server.state.auction_entries:
		if str(e["uid"]) == p_uid:
			return e
	return {}


func _add_record(p_server: RefCounted, p_rec: Dictionary) -> void:
	var rec := p_rec.duplicate()
	rec["uid"] = Ulid.new_id()
	rec["ts"] = int(Time.get_unix_time_from_system())
	p_server.state.auction_records.push_front(rec)
	if p_server.state.auction_records.size() > 100:
		p_server.state.auction_records.resize(100)


func _entry_body(p_server: RefCounted, p_e: Dictionary) -> Dictionary:
	var remain := maxi(0, int(p_e["end_ts"]) - int(Time.get_unix_time_from_system()))
	return {
		"uid": p_e["uid"], "item": p_e["item"], "name": str(p_e["item"]["name"]),
		"quality": int(p_e["item"]["quality"]), "icon": str(p_e["item"]["icon"]),
		"count": int(p_e["item"]["count"]), "seller": str(p_e["seller_name"]),
		"current_price": int(p_e["current_price"]), "buyout": int(p_e["buyout"]),
		"bidder": str(p_e["bidder_name"]), "is_mine": str(p_e["seller_uid"]) == p_server.state.account_uid,
		"my_bid": str(p_e["bidder_uid"]) == p_server.state.account_uid,
		"remain_s": remain, "ended": str(p_e["state"]) != "live",
	}


func _record_body(p_r: Dictionary) -> Dictionary:
	return {"uid": p_r["uid"], "item_name": p_r["item_name"], "kind": str(p_r["kind"]), "price": int(p_r["price"]), "seller": str(p_r["seller"]), "buyer": str(p_r["buyer"]), "ts": int(p_r["ts"])}


func _wallet(p_state: RefCounted) -> Dictionary:
	return {"copper": p_state.copper, "spirit_stone": p_state.spirit_stone, "immortal_jade": p_state.immortal_jade}
