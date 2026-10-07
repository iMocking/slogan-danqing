# 登录界面 ViewModel
# 属性：account / password / server_idx / servers / error / can_submit / logging
class_name LoginVm
extends ViewModel

const ACCOUNT_CFG := "user://settings.cfg"


func _init() -> void:
	set_prop(&"account", "")
	set_prop(&"password", "")
	set_prop(&"server_idx", 0)
	set_prop(&"servers", [])
	set_prop(&"error", "")
	set_prop(&"can_submit", false)
	set_prop(&"logging", false)


## 拉取服务器列表 + 回填记住的账号
func load_init() -> void:
	var res := await rpc_body("auth.server_list")
	if not res.is_empty():
		set_prop(&"servers", res.get("servers", []))
	var cfg := ConfigFile.new()
	if cfg.load(ACCOUNT_CFG) == OK:
		set_prop(&"account", str(cfg.get_value("login", "account", "")))


## 输入变化：刷新可提交状态
func on_input(p_account: String, p_password: String) -> void:
	set_prop(&"account", p_account)
	set_prop(&"password", p_password)
	var ok := not p_account.strip_edges().is_empty() and p_password.length() >= 6
	set_prop(&"can_submit", ok)
	if ok:
		set_prop(&"error", "")


## 记住账号（只存账号，不存密码）
func remember_account(p_account: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("login", "account", p_account)
	cfg.save(ACCOUNT_CFG)


## 提交登录：成功后跳转加载页
func submit(p_server_idx: int) -> void:
	if bool(prop(&"logging")):
		return
	set_prop(&"error", "")
	var res: Dictionary = await rpc_req("auth.login", {
		"account": str(prop(&"account")).strip_edges(),
		"password": str(prop(&"password")),
		"server": p_server_idx,
	})
	if not Rpc.is_ok(res):
		set_prop(&"error", str(res.get("msg", "登录失败")))
		return
	remember_account(str(prop(&"account")).strip_edges())
	set_prop(&"logging", true)
	SceneRouter.goto(&"loading")
