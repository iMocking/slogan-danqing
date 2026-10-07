# 世界大地图 ViewModel
class_name WorldMapVm
extends ViewModel


func _init() -> void:
	set_prop(&"regions", [])
	set_prop(&"roads", [])
	set_prop(&"current", "")
	set_prop(&"selected", {})


func refresh() -> void:
	var res := await rpc_body("world.map", {}, true)
	if res.is_empty():
		return
	set_prop(&"regions", res.get("regions", []))
	set_prop(&"roads", res.get("roads", []))
	set_prop(&"current", str(res.get("current", "")))
	# 刷新选中（保持引用最新数据）
	var sel_id := str(prop(&"selected").get("id", ""))
	if not sel_id.is_empty():
		for r: Variant in res.get("regions", []):
			if str(r.get("id")) == sel_id:
				set_prop(&"selected", r)


## 选中区域
func select(p_region: Dictionary) -> void:
	set_prop(&"selected", p_region)


## 传送（境界校验失败时服务端报错，UI Toast）
func travel() -> void:
	var sel: Dictionary = prop(&"selected")
	if sel.is_empty():
		return
	var res: Dictionary = await rpc_req("world.travel", {"region_id": str(sel["id"])})
	if Rpc.is_ok(res):
		Toast.show_text("传送阵光华一闪，已抵达 %s" % sel.get("name", ""))
		await refresh()
	else:
		Toast.show_text(str(res.get("msg", "无法传送")))
