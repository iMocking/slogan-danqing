# 仙途 · 本地数据服务器（进程内）
# 职责：路由分发到各域 Handler；持有 ServerState；周期 tick 驱动模拟（拍卖到期/竞拍/世界频道）。
# 与 UI 完全解耦：只被 LocalTransport 调用，推送经 bind_push 注入的回调外发。
extends RefCounted

const HANDLER_PATHS := {
	&"auth": "res://src/server/local/handlers/h_auth.gd",
	&"character": "res://src/server/local/handlers/h_character.gd",
	&"equip": "res://src/server/local/handlers/h_character.gd",
	&"inventory": "res://src/server/local/handlers/h_inventory.gd",
	&"quest": "res://src/server/local/handlers/h_quest.gd",
	&"skill": "res://src/server/local/handlers/h_skill.gd",
	&"shop": "res://src/server/local/handlers/h_shop.gd",
	&"auction": "res://src/server/local/handlers/h_auction.gd",
	&"chat": "res://src/server/local/handlers/h_chat.gd",
	&"world": "res://src/server/local/handlers/h_world.gd",
}

## tick 周期（秒）：模拟世界活跃度
const TICK_INTERVAL := 5.0
## 竞争者出价概率（每次 tick，已登录且有竞拍时）
const BID_BOT_PROB := 0.25
## 世界频道冒泡概率
const CHAT_BOT_PROB := 0.3

var state: RefCounted = null          # ServerState
var _handlers: Dictionary = {}
var _push: Callable = Callable()
var _acc: float = 0.0


func _init() -> void:
	var state_script := load("res://src/server/local/server_state.gd")
	state = state_script.new()
	if not state.load_or_init():
		push_warning("存档加载失败，已重置为初始状态")
	for route: StringName in HANDLER_PATHS:
		_handlers[route] = load(HANDLER_PATHS[route]).new()


## 注入推送回调：签名 (route: String, body: Dictionary)
func bind_push(p_cb: Callable) -> void:
	_push = p_cb


## 路由分发入口：route 形如 "域.动作"
func handle(p_route: String, p_body: Dictionary) -> Dictionary:
	var parts := p_route.split(".")
	if parts.size() != 2 or parts[0].is_empty() or parts[1].is_empty():
		return Rpc.err(Rpc.BAD_PARAM, "路由格式非法：%s" % p_route)
	var handler: Variant = _handlers.get(StringName(parts[0]))
	if handler == null:
		return Rpc.err(Rpc.UNKNOWN_DOMAIN, "未知服务域：%s" % parts[0])
	var res: Dictionary = handler.handle(self, parts[1], p_body)
	_save_after_mutation(p_route, res)
	return res


## 周期驱动：由 GameServer 定时调用，模拟多人世界
func tick(p_delta: float) -> void:
	if state.account_uid.is_empty():
		return
	_acc += p_delta
	if _acc < TICK_INTERVAL:
		return
	_acc = 0.0
	var bot: Variant = _handlers.get(&"auction")
	if bot != null and randf() < BID_BOT_PROB:
		bot.bot_tick(self)
	var chat_bot: Variant = _handlers.get(&"chat")
	if chat_bot != null and randf() < CHAT_BOT_PROB:
		chat_bot.bot_tick(self)
	_save_after_mutation("", {"code": Rpc.OK})


## 服务端主动推送（body 包裹，与响应信封同构）
func push(p_route: String, p_body: Dictionary) -> void:
	if _push.is_valid():
		_push.call(p_route, {"body": p_body})


## 变更类请求成功后自动落盘；查询类（get/list/tree/map/history）跳过
func _save_after_mutation(p_route: String, p_res: Dictionary) -> void:
	var read_only := ["get", "list", "tree", "map", "history", "server_list", "detail"]
	if p_route.is_empty():
		state.save()
		return
	var action := p_route.get_slice(".", 1)
	for r: String in read_only:
		if action == r:
			return
	if Rpc.is_ok(p_res):
		state.save()
