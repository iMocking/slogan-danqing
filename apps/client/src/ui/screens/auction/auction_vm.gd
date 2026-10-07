# 万宝拍卖行 ViewModel
class_name AuctionVm
extends ViewModel

const TABS := ["浏览拍卖", "我的拍卖", "我的出价", "拍卖记录"]
const QUALITIES := ["全部品质", "凡", "灵", "玄", "地", "天", "仙"]


func _init() -> void:
	set_prop(&"tab", 0)
	set_prop(&"rows", [])
	set_prop(&"page", 1)
	set_prop(&"pages", 1)
	set_prop(&"wallet", {})
	set_prop(&"filter_quality", -1)
	set_prop(&"filter_name", "")
	watch_push("auction.updated", func(_route: String, _body: Dictionary) -> void:
		await refresh())


func refresh() -> void:
	var res := await rpc_body("auction.list", {
		"tab": int(prop(&"tab")), "page": int(prop(&"page")),
		"name": str(prop(&"filter_name")), "quality": int(prop(&"filter_quality")),
	}, true)
	if res.is_empty():
		return
	set_prop(&"rows", res.get("rows", []))
	set_prop(&"pages", int(res.get("pages", 1)))
	set_prop(&"page", int(res.get("page", 1)))
	set_prop(&"wallet", res.get("wallet", {}))


func set_tab(p_idx: int) -> void:
	set_prop(&"tab", p_idx)
	set_prop(&"page", 1)
	await refresh()


func set_filter(p_quality: int, p_name: String) -> void:
	set_prop(&"filter_quality", p_quality - 1)   # -1 表示全部
	set_prop(&"filter_name", p_name)
	set_prop(&"page", 1)
	await refresh()


func turn_page(p_delta: int) -> void:
	var target := clampi(int(prop(&"page")) + p_delta, 1, int(prop(&"pages")))
	if target == int(prop(&"page")):
		return
	set_prop(&"page", target)
	await refresh()


## 出价（服务端校验 1.05 倍与灵石）
func bid(p_entry_uid: String, p_price: int) -> Dictionary:
	var res: Dictionary = await rpc_req("auction.bid", {"entry_uid": p_entry_uid, "price": p_price})
	if Rpc.is_ok(res):
		await refresh()
	return res


## 上架（物品已在服务端移出背包）
func list_item(p_uid: String, p_start: int, p_buyout: int, p_hours: int) -> bool:
	var res: Dictionary = await rpc_req("auction.list_item", {
		"uid": p_uid, "start_price": p_start, "buyout": p_buyout, "hours": p_hours,
	})
	if Rpc.is_ok(res):
		Toast.show_text("上架成功，等待有缘人竞价")
		await refresh()
		return true
	Toast.show_text(str(res.get("msg", "上架失败")))
	return false


## 下架（仅无人出价）
func cancel(p_entry_uid: String) -> void:
	var res: Dictionary = await rpc_req("auction.cancel", {"entry_uid": p_entry_uid})
	if Rpc.is_ok(res):
		Toast.show_text("已下架，物品返还乾坤袋")
		await refresh()
	else:
		Toast.show_text(str(res.get("msg", "下架失败")))
