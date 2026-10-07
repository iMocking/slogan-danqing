# 仙途 · 聚宝阁（商城）域 Handler：商品列表 / 购买
extends "res://src/server/local/handlers/h_base.gd"

const PAGE_SIZE := 12
const CURRENCY_FIELDS := {"copper": "copper", "stone": "spirit_stone", "jade": "immortal_jade"}


## 商品列表：分类 + 分页；限时商品附加剩余秒数
func _h_list(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var category := arg_int(p_body, "category", 0)
	var page := maxi(1, arg_int(p_body, "page", 1))
	var all: Array = []
	for gd: Dictionary in DbShop.GOODS:
		if int(gd["category"]) != category:
			continue
		all.append(_goods_body(gd))
	var pages := maxi(1, int(ceil(all.size() / float(PAGE_SIZE))))
	page = mini(page, pages)
	var rows: Array = []
	for i in range((page - 1) * PAGE_SIZE, mini(page * PAGE_SIZE, all.size())):
		rows.append(all[i])
	return Rpc.ok({"rows": rows, "pages": pages, "page": page, "wallet": _wallet_body(p_server.state)})


## 购买：扣货币 → 入包 / 展开礼包 / 佩戴称号
func _h_buy(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var g := guard_login(p_server)
	if not g.is_empty():
		return g
	var gd: Dictionary = DbShop.get_goods(arg_str(p_body, "goods_id", ""))
	if gd.is_empty():
		return Rpc.err(Rpc.NOT_FOUND, "商品不存在")
	var count := maxi(1, arg_int(p_body, "count", 1))
	var state: RefCounted = p_server.state
	var price := int(gd["price"]) * count
	var cur_key: String = CURRENCY_FIELDS.get(str(gd["currency"]), "copper")
	if int(state.get(cur_key)) < price:
		return Rpc.rule(Rpc.RULE_NO_MONEY, "%s不足，还差 %d" % [DbShop.currency_name(str(gd["currency"])), price - int(state.get(cur_key))])
	state.set(cur_key, int(state.get(cur_key)) - price)
	var got: Array = []
	match str(gd.get("goods_type", "item")):
		"item":
			var inv: Variant = p_server._handlers[&"inventory"]
			if not inv.add_item(p_server, str(gd["template_id"]), count):
				state.set(cur_key, int(state.get(cur_key)) + price)
				return Rpc.rule(Rpc.RULE_BAG_FULL, "乾坤袋已满，购买失败")
			var tpl: Dictionary = DbItems.get_template(str(gd["template_id"]))
			got.append({"name": str(tpl["name"]), "count": count})
		"pack":
			var inv2: Variant = p_server._handlers[&"inventory"]
			for it: Variant in gd.get("contains", []):
				inv2.add_item(p_server, str(it["template_id"]), int(it["count"]) * count)
				var t2: Dictionary = DbItems.get_template(str(it["template_id"]))
				got.append({"name": str(t2["name"]), "count": int(it["count"]) * count})
		"title":
			state.title = str(gd["name"]).replace("称号·", "")
			got.append({"name": str(gd["name"]), "count": 1})
	return Rpc.ok({"wallet": _wallet_body(state), "got": got, "character_title": state.title})


## 商品展示体
func _goods_body(p_gd: Dictionary) -> Dictionary:
	var body := {
		"goods_id": p_gd["id"], "goods_type": str(p_gd.get("goods_type", "item")),
		"category": int(p_gd["category"]), "currency": str(p_gd["currency"]),
		"price": int(p_gd["price"]), "hot": bool(p_gd.get("hot", false)),
		"remains_s": 0, "name": "", "icon": "", "quality": 0, "count": 1,
	}
	if str(p_gd.get("goods_type", "item")) == "item":
		var tpl: Dictionary = DbItems.get_template(str(p_gd["template_id"]))
		body["name"] = str(tpl.get("name", ""))
		body["icon"] = str(tpl.get("icon", ""))
		body["quality"] = int(tpl.get("quality", 0))
	else:
		body["name"] = str(p_gd.get("name", ""))
		# 非物品商品用卷轴/书册占位图标
		var icon_id := "bag_scroll.png" if str(p_gd.get("goods_type")) == "pack" else "bag_book.png"
		body["icon"] = "res://assets/ui/icons/bag/" + icon_id
	if p_gd.has("remains_h"):
		body["remains_s"] = int(p_gd["remains_h"]) * 3600 - int(Time.get_ticks_msec() / 1000.0) % (int(p_gd["remains_h"]) * 3600)
	return body


func _wallet_body(p_state: RefCounted) -> Dictionary:
	return {"copper": p_state.copper, "spirit_stone": p_state.spirit_stone, "immortal_jade": p_state.immortal_jade}
