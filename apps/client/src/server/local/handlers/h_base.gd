# 仙途 · 域 Handler 基类
# 约定：子类实现 _h_<动作名>(server, body) -> 信封；未实现的动作返回 5005。
extends RefCounted


## 动作分发入口（由 LocalServer 调用）
func handle(p_server: RefCounted, p_action: String, p_body: Dictionary) -> Dictionary:
	var fn := "_h_" + p_action
	if not has_method(fn):
		return Rpc.err(Rpc.UNKNOWN_ACTION, "未知动作：%s" % p_action)
	return call(fn, p_server, p_body)


## 登录守卫：未登录返回 4101，否则返回空信封
func guard_login(p_server: RefCounted) -> Dictionary:
	if p_server.state.account_uid.is_empty():
		return Rpc.err(Rpc.NOT_LOGIN, "尚未登录")
	if p_server.state.char_uid.is_empty():
		return Rpc.rule(Rpc.RULE_STATE, "尚未创建角色")
	return {}


## 通用取值：带类型默认值
static func arg_int(p_body: Dictionary, p_key: String, p_def: int) -> int:
	return int(p_body.get(p_key, p_def))


static func arg_str(p_body: Dictionary, p_key: String, p_def: String) -> String:
	return str(p_body.get(p_key, p_def))
