# 角色档案 ViewModel
class_name CharacterVm
extends ViewModel


func _init() -> void:
	set_prop(&"char", {})


func _ready_watch() -> void:
	watch_push("char.state", func(_route: String, body: Dictionary) -> void:
		set_prop(&"char", body.get("character", {})))


## 拉取角色
func refresh() -> void:
	var res := await rpc_body("character.get", {}, true)
	if not res.is_empty():
		set_prop(&"char", res.get("character", {}))
	_ready_watch()


## 穿装备（uid 为背包物品实例）
func wear(p_uid: String) -> void:
	var res := await rpc_body("equip.wear", {"uid": p_uid})
	if not res.is_empty():
		set_prop(&"char", res.get("character", {}))


## 卸下装备
func unequip(p_slot: String) -> void:
	var res := await rpc_body("equip.unequip", {"slot": p_slot})
	if not res.is_empty():
		set_prop(&"char", res.get("character", {}))


## 五维加点（每次 1 点）
func allocate(p_attr: String) -> void:
	var res := await rpc_body("character.allocate_point", {"attr": p_attr, "points": 1})
	if not res.is_empty():
		set_prop(&"char", res.get("character", {}))


## 突破 / 升级（修为满时）
func breakthrough() -> void:
	var res: Dictionary = await rpc_req("character.breakthrough")
	if Rpc.is_ok(res):
		set_prop(&"char", Rpc.body(res).get("character", {}))
		Toast.show_text("修为精进，境界更上一层！")
	else:
		Toast.show_text(str(res.get("msg", "无法突破")))


## 可穿的装备列表（供装备槽选择）
func list_equippable(p_slot: String) -> Array:
	var out: Array = []
	var res := await rpc_body("inventory.list", {"category": "equip"})
	for it: Variant in res.get("items", []):
		if str(it.get("slot")) == p_slot:
			out.append(it)
	return out
