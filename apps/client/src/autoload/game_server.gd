# 仙途 · 数据服务客户端入口（autoload）
# UI/ViewModel 只与本节点通信：request(route, body) + pushed 信号。
# 传输层可替换：本地为 LocalTransport（进程内直调），未来联机换成 RemoteTransport 即可。
extends Node

## 服务端主动推送：路由 + 数据体
signal pushed(route: String, body: Dictionary)

var _transport: RefCounted = null      # LocalTransport 实例（RefCounted，鸭子类型调用 send/tick）
var _push_subs: Dictionary = {}        # 自增 id -> {"route": String, "cb": Callable}
var _sub_seq: int = 0


func _ready() -> void:
	var transport_script := load("res://src/server/transport/local_transport.gd")
	_transport = transport_script.new()
	# 注入推送回调：LocalServer -> GameServer.pushed
	_transport.push_delegate = Callable(self, "_emit_push")
	# 世界模拟定时器：拍卖到期结算 / 竞争出价 / 世界频道
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(func() -> void: _transport.tick(5.0))
	add_child(timer)


## 发起一次 RPC 请求，await 返回信封 {code, msg, body}
func request(p_route: String, p_body: Dictionary = {}) -> Dictionary:
	EventBus.rpc_started.emit(p_route)
	var res: Dictionary = await _transport.send(p_route, p_body)
	EventBus.rpc_finished.emit(p_route)
	return res


## 订阅服务端推送，返回订阅句柄（用于退订）
func on_push(p_route: String, p_cb: Callable) -> int:
	_sub_seq += 1
	_push_subs[_sub_seq] = {"route": p_route, "cb": p_cb}
	return _sub_seq


## 按句柄退订推送
func off_push(p_handle: int) -> void:
	_push_subs.erase(p_handle)


## 供 LocalTransport 注入的推送入口
func _emit_push(p_route: String, p_body: Dictionary) -> void:
	pushed.emit(p_route, p_body)
	for h: Variant in _push_subs.values():
		var route: String = h["route"]
		var cb: Callable = h["cb"]
		if route == "*" or route == p_route:
			# 推送体统一走 body 字段
			cb.call(p_route, p_body.get("body", {}))


## 重置本地服务器并清除存档（测试/调试用）
func reset_local() -> void:
	var save_path := "user://saves/slot_1.json"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	_transport.reset()
