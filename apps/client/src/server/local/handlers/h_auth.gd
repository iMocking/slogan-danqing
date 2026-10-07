# 仙途 · 认证域 Handler：登录 / 服务器列表 / 登出
extends "res://src/server/local/handlers/h_base.gd"


## 登录：单机校验（账号非空、密码 ≥6 位）；首登自动建号（ULID）
func _h_login(p_server: RefCounted, p_body: Dictionary) -> Dictionary:
	var miss := Rpc.check_keys(p_body, ["account", "password"])
	if not miss.is_empty():
		return Rpc.err(Rpc.BAD_PARAM, miss)
	var account := str(p_body["account"]).strip_edges()
	var password := str(p_body["password"])
	if account.is_empty() or account.length() < 2:
		return Rpc.err(Rpc.BAD_PARAM, "账号至少 2 个字符")
	if password.length() < 6:
		return Rpc.err(Rpc.BAD_PARAM, "密码至少 6 位")
	var state: RefCounted = p_server.state
	if state.account_uid.is_empty():
		state.account_uid = Ulid.new_id()
		state.account_name = account
		state.save()
	return Rpc.ok({
		"account_uid": state.account_uid,
		"account_name": state.account_name,
		"has_char": not state.char_uid.is_empty(),
	})


## 服务器列表（联机后由登录服务下发，单机取配置常量）
func _h_server_list(_p_server: RefCounted, _p_body: Dictionary) -> Dictionary:
	return Rpc.ok({"servers": GameConfig.SERVERS})


## 登出：仅清会话标记，保留存档
func _h_logout(p_server: RefCounted, _p_body: Dictionary) -> Dictionary:
	p_server.state.account_uid = ""
	p_server.state.save()
	return Rpc.ok({})
