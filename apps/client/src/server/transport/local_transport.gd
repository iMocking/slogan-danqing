# 仙途 · 本地传输层：进程内直连 LocalServer
# 与未来 RemoteTransport（WebSocket/HTTP）实现同一约定：
#   send(route, body) -> await {code, msg, body}
#   push_delegate: Callable(route, body)  由 LocalServer 反向调用
extends RefCounted

## 推送回调，由 GameServer 注入
var push_delegate: Callable
## 模拟网络延迟（毫秒），0 为直调；联机调试时可调大观察 loading 表现
var fake_latency_ms: int = 0

var _server: RefCounted = null


func _init() -> void:
	var server_script := load("res://src/server/local/local_server.gd")
	_server = server_script.new()
	_server.bind_push(Callable(self, "_on_server_push"))


## 发送请求：转交 LocalServer 路由分发
func send(p_route: String, p_body: Dictionary) -> Dictionary:
	if fake_latency_ms <= 0:
		return _server.handle(p_route, p_body)
	await _sleep(fake_latency_ms)
	return _server.handle(p_route, p_body)


## LocalServer 推送出口
func _on_server_push(p_route: String, p_body: Dictionary) -> void:
	if push_delegate.is_valid():
		push_delegate.call(p_route, p_body)


## 周期驱动转发（由 GameServer 定时器调用，模拟世界活跃度）
func tick(p_delta: float) -> void:
	_server.tick(p_delta)


## 重置本地服务器（测试/调试用：丢弃内存状态重建）
func reset() -> void:
	var server_script := load("res://src/server/local/local_server.gd")
	_server = server_script.new()
	_server.bind_push(Callable(self, "_on_server_push"))


## 毫秒级等待（用于模拟网络延迟）
func _sleep(p_ms: int) -> void:
	await Engine.get_main_loop().create_timer(p_ms / 1000.0).timeout
