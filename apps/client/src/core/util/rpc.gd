# 仙途 · 数据信封与错误码
# 所有网络（本地/远程）数据体一律放在 body 字段，禁止使用 data 字段。
class_name Rpc
extends RefCounted

# ---- 全局错误码 ----
const OK := 0                  # 成功
const BAD_PARAM := 4001        # 入参缺失或非法
const NOT_LOGIN := 4101        # 未登录 / 会话无效
const NOT_FOUND := 4204        # 资源不存在
const RULE_BASE := 4300        # 业务规则错误基址（+ 偏移细分）
const INTERNAL := 5000         # 内部错误
const STORAGE_FAIL := 5002     # 存档读写失败
const UNKNOWN_DOMAIN := 5004   # 未知路由域
const UNKNOWN_ACTION := 5005   # 未知路由动作
const TRANSPORT_TIMEOUT := 5100  # 传输超时（远程预留）
const TRANSPORT_DOWN := 5101     # 连接不可用（远程预留）

# ---- 业务规则错误细分（RULE_BASE + 偏移） ----
const RULE_NO_MONEY := 1       # 货币不足
const RULE_BAG_FULL := 2       # 背包已满
const RULE_STATE := 3          # 当前状态不允许该操作
const RULE_PREREQ := 4         # 前置条件未满足
const RULE_NO_POINT := 5       # 点数不足
const RULE_NAME := 6           # 名字校验失败


## 构造成功信封
static func ok(p_body: Dictionary = {}) -> Dictionary:
	return {"code": OK, "msg": "ok", "body": p_body}


## 构造失败信封（p_msg 为面向玩家的中文提示）
static func err(p_code: int, p_msg: String) -> Dictionary:
	return {"code": p_code, "msg": p_msg, "body": {}}


## 构造业务规则错误
static func rule(p_offset: int, p_msg: String) -> Dictionary:
	return err(RULE_BASE + p_offset, p_msg)


## 判断信封是否成功
static func is_ok(p_res: Dictionary) -> bool:
	return int(p_res.get("code", INTERNAL)) == OK


## 取信封数据体（永远返回字典，避免空值崩溃）
static func body(p_res: Dictionary) -> Dictionary:
	var b: Variant = p_res.get("body", {})
	return b if b is Dictionary else {}


## 参数存在性校验：缺失时返回错误信封，否则返回空串
static func check_keys(p_body: Dictionary, p_keys: Array) -> String:
	for k: Variant in p_keys:
		if not p_body.has(k):
			return "缺少参数：%s" % str(k)
	return ""
