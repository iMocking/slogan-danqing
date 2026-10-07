# 背包（乾坤袋）ViewModel
class_name InventoryVm
extends ViewModel

const CATEGORIES := ["all", "equip", "pill", "material", "quest"]


func _init() -> void:
	set_prop(&"items", [])
	set_prop(&"wallet", {})
	set_prop(&"capacity", 30)
	set_prop(&"category", "all")
	set_prop(&"selected", {})


## 拉取背包
func refresh() -> void:
	var res := await rpc_body("inventory.list", {"category": str(prop(&"category"))}, true)
	if res.is_empty():
		return
	set_prop(&"items", res.get("items", []))
	set_prop(&"wallet", res.get("wallet", {}))
	set_prop(&"capacity", int(res.get("capacity", 30)))


## 切换分类
func set_category(p_cat: String) -> void:
	set_prop(&"category", p_cat)
	await refresh()


## 选中物品（详情区展示）
func select(p_uid: String) -> void:
	if p_uid.is_empty():
		set_prop(&"selected", {})
		return
	for it: Variant in prop(&"items"):
		if str(it.get("uid")) == p_uid:
			set_prop(&"selected", it)
			return
	set_prop(&"selected", {})


## 使用（消耗品）
func use_selected() -> void:
	var sel: Dictionary = prop(&"selected")
	if sel.is_empty():
		return
	var res := await rpc_body("inventory.use", {"uid": str(sel["uid"])})
	if res.is_empty():
		return
	set_prop(&"items", res.get("items", []))
	set_prop(&"wallet", res.get("wallet", {}))


## 丢弃
func drop_selected(p_count: int = -1) -> void:
	var sel: Dictionary = prop(&"selected")
	if sel.is_empty():
		return
	var body := {"uid": str(sel["uid"])}
	if p_count > 0:
		body["count"] = p_count
	var res := await rpc_body("inventory.drop", body)
	if res.is_empty():
		return
	set_prop(&"items", res.get("items", []))
	set_prop(&"wallet", res.get("wallet", {}))
	set_prop(&"selected", {})


## 整理（品质→类型→名称）
func sort_items() -> void:
	var res := await rpc_body("inventory.sort")
	if res.is_empty():
		return
	set_prop(&"items", res.get("items", []))


## 拆分一半
func split_selected() -> void:
	var sel: Dictionary = prop(&"selected")
	if sel.is_empty():
		return
	var count := maxi(1, int(sel.get("count", 1)) / 2)
	var res := await rpc_body("inventory.split", {"uid": str(sel["uid"]), "count": count})
	if res.is_empty():
		return
	set_prop(&"items", res.get("items", []))
