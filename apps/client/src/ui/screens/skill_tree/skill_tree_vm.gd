# 功法图谱 ViewModel
class_name SkillTreeVm
extends ViewModel


func _init() -> void:
	set_prop(&"branch", 0)
	set_prop(&"nodes", [])
	set_prop(&"points", 0)
	set_prop(&"selected", {})


## 拉取某系图谱
func refresh(p_branch: int = -1) -> void:
	if p_branch >= 0:
		set_prop(&"branch", p_branch)
	var res := await rpc_body("skill.tree", {"branch": int(prop(&"branch"))}, true)
	if res.is_empty():
		return
	set_prop(&"nodes", res.get("nodes", []))
	set_prop(&"points", int(res.get("points", 0)))
	# 保持选中
	var sel_id := str(prop(&"selected").get("id", ""))
	if not sel_id.is_empty():
		for n: Variant in res.get("nodes", []):
			if str(n.get("id")) == sel_id:
				set_prop(&"selected", n)


## 选中节点
func select(p_node: Dictionary) -> void:
	set_prop(&"selected", p_node)


## 学习 / 升级
func learn() -> void:
	var sel: Dictionary = prop(&"selected")
	if sel.is_empty():
		return
	var res: Dictionary = await rpc_req("skill.learn", {"skill_id": str(sel["id"])})
	if Rpc.is_ok(res):
		Toast.show_text("功法精进：%s Lv.%d" % [sel.get("name", ""), int(res["body"].get("level", 1))])
		await refresh()
	else:
		Toast.show_text(str(res.get("msg", "无法学习")))
