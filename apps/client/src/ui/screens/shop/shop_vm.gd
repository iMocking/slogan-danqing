# 聚宝阁（商城）ViewModel
class_name ShopVm
extends ViewModel


func _init() -> void:
	set_prop(&"category", 0)
	set_prop(&"page", 1)
	set_prop(&"pages", 1)
	set_prop(&"rows", [])
	set_prop(&"wallet", {})


## 拉取商品
func refresh() -> void:
	var res := await rpc_body("shop.list", {"category": int(prop(&"category")), "page": int(prop(&"page"))}, true)
	if res.is_empty():
		return
	set_prop(&"rows", res.get("rows", []))
	set_prop(&"pages", int(res.get("pages", 1)))
	set_prop(&"page", int(res.get("page", 1)))
	set_prop(&"wallet", res.get("wallet", {}))


## 切换分类（重置到第 1 页）
func set_category(p_idx: int) -> void:
	set_prop(&"category", p_idx)
	set_prop(&"page", 1)
	await refresh()


## 翻页
func turn_page(p_delta: int) -> void:
	var target := clampi(int(prop(&"page")) + p_delta, 1, int(prop(&"pages")))
	if target == int(prop(&"page")):
		return
	set_prop(&"page", target)
	await refresh()


## 购买（服务端校验货币与背包）
func buy(p_goods_id: String, p_count: int = 1) -> void:
	var res: Dictionary = await rpc_req("shop.buy", {"goods_id": p_goods_id, "count": p_count})
	if Rpc.is_ok(res):
		var body: Dictionary = Rpc.body(res)
		set_prop(&"wallet", body.get("wallet", {}))
		var got: Array = body.get("got", [])
		var text := "、".join(PackedStringArray(got.map(func(g: Variant) -> String: return "%s×%d" % [g["name"], int(g["count"])])))
		Toast.show_text("购得：%s" % text)
		await refresh()
	else:
		Toast.show_text(str(res.get("msg", "购买失败")))
