# 仙途 · ViewModel 基类（MVVM 之 VM）
# 持有界面可绑定属性；唯一数据来源是 GameServer 的响应 body 与推送 body。
# 绑定采用手写观察者（bind/clear_binds），避免悬空 Callable。
class_name ViewModel
extends RefCounted

var _props: Dictionary = {}
var _binds: Array = []          # [{"prop": StringName, "cb": Callable}]
var _busy: bool = false          # 请求防抖
var _push_handles: Array[int] = []


## 读属性
func prop(p_name: StringName) -> Variant:
	return _props.get(p_name)


## 写属性（值不变不通知）
func set_prop(p_name: StringName, p_value: Variant) -> void:
	if _props.has(p_name) and _props[p_name] == p_value:
		return
	_props[p_name] = p_value
	_notify(p_name, p_value)


## 批量写入
func set_props(p_dict: Dictionary) -> void:
	for k: Variant in p_dict:
		set_prop(StringName(str(k)), p_dict[k])


## 绑定回调：立即回放当前值，之后属性变化时回调 cb(value)
func bind(p_prop: StringName, p_cb: Callable) -> void:
	_binds.append({"prop": p_prop, "cb": p_cb})
	if _props.has(p_prop):
		p_cb.call(_props[p_prop])


## 解除全部绑定（View 退出时必须调用）
func clear_binds() -> void:
	_binds.clear()
	for h: int in _push_handles:
		GameServer.off_push(h)
	_push_handles.clear()


## 订阅服务端推送
func watch_push(p_route: String, p_cb: Callable) -> void:
	_push_handles.append(GameServer.on_push(p_route, p_cb))


## RPC 请求：返回原始信封
func rpc_req(p_route: String, p_body: Dictionary = {}) -> Dictionary:
	return await GameServer.request(p_route, p_body)


## RPC 请求：成功返回 body；失败自动 Toast 并返回空字典
func rpc_body(p_route: String, p_body: Dictionary = {}, p_quiet: bool = false) -> Dictionary:
	if _busy:
		return {}
	_busy = true
	var res: Dictionary = await GameServer.request(p_route, p_body)
	_busy = false
	if Rpc.is_ok(res):
		return Rpc.body(res)
	if not p_quiet:
		Toast.show_text(str(res.get("msg", "操作失败")))
	return {}


## 防抖标记：请求进行中为 true
func is_busy() -> bool:
	return _busy


func _notify(p_name: StringName, p_value: Variant) -> void:
	for b: Dictionary in _binds:
		if b["prop"] == p_name and b["cb"].is_valid():
			b["cb"].call(p_value)
