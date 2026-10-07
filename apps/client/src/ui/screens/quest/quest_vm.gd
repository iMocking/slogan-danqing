# 任务录 ViewModel：已接 / 可接 / 已完成
class_name QuestVm
extends ViewModel


func _init() -> void:
	set_prop(&"tab", 0)
	set_prop(&"lists", [{}, {}, {}])   # accepted / available / done（条目数组）
	set_prop(&"selected", {})
	watch_push("quest.changed", func(_route: String, _body: Dictionary) -> void:
		await refresh())


## 拉取三组任务
func refresh() -> void:
	var res := await rpc_body("quest.list", {}, true)
	if res.is_empty():
		return
	var lists: Array = [res.get("accepted", []), res.get("available", []), res.get("done", [])]
	set_prop(&"lists", lists)
	# 尽量保持选中项（空 uid 视为未选中，避免与可接任务的空 uid 误匹配）
	var sel_uid := str(prop(&"selected").get("uid", ""))
	var found := {}
	if not sel_uid.is_empty():
		for group: Array in lists:
			for q: Variant in group:
				if str(q.get("uid")) == sel_uid:
					found = q
	if found.is_empty() and not lists[0].is_empty():
		found = lists[0][0]
	set_prop(&"selected", found)


## 切换页签
func set_tab(p_idx: int) -> void:
	set_prop(&"tab", p_idx)


## 选中任务
func select(p_uid: String) -> void:
	for group: Array in prop(&"lists"):
		for q: Variant in group:
			if str(q.get("uid")) == p_uid:
				set_prop(&"selected", q)
				return


## 接取 / 追踪 / 放弃 / 交付（按选中任务状态分发）
func accept(p_template_id: String) -> void:
	var res := await rpc_body("quest.accept", {"template_id": p_template_id})
	if not res.is_empty():
		await refresh()


func track(p_uid: String) -> void:
	var res := await rpc_body("quest.track", {"uid": p_uid})
	if not res.is_empty():
		await refresh()


func abandon(p_uid: String) -> void:
	var res := await rpc_body("quest.abandon", {"uid": p_uid})
	if not res.is_empty():
		await refresh()


func claim(p_uid: String) -> void:
	var res: Dictionary = await rpc_req("quest.claim", {"uid": p_uid})
	if Rpc.is_ok(res):
		Toast.show_text("任务奖励已入账")
		await refresh()
