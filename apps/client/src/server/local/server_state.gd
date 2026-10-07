# 仙途 · 服务器内存状态容器 + 存档序列化
# 持有全部游戏状态；所有 id（uid 字段）均为 ULID。
extends RefCounted

const BAG_SIZE := 30
const REALM_RANGES := [[1, 20], [21, 45], [46, 70], [71, 95], [96, 120], [121, 145], [146, 170], [171, 200], [201, 300]]

var storage: RefCounted = null        # Storage 实例（延迟创建）

# ---- 会话 ----
var account_uid: String = ""
var account_name: String = ""

# ---- 角色 ----
var char_uid: String = ""
var char_name: String = ""
var gender: String = "male"
var sect: String = "青云门"
var level: int = 1
var xp: int = 0
var realm: int = 0
var stage: int = 0
var skill_points: int = 5
var free_attr: int = 0
var title: String = ""
var five: Dictionary = {"筋骨": 10, "灵气": 10, "根骨": 10, "悟性": 10, "幸运": 8}
var attr_alloc: Dictionary = {}       # 属性加点累计（筋骨/灵气/根骨/悟性/幸运 -> int）
var hp: int = 100
var mp: int = 50

# ---- 背包与装备 ----
var items: Array = []                 # [{uid, template_id, count}]
var equips: Dictionary = {}           # 槽位名(weapon/hat/robe/accessory/shoes/necklace) -> 物品 uid

# ---- 任务 / 技能 / 称号 ----
var quests: Array = []                # [{uid, template_id, state, progress:{}, tracked}]
var tracked_quest_uid: String = ""
var learned: Dictionary = {}          # skill_id -> level

# ---- 经济 ----
var copper: int = 5000
var spirit_stone: int = 100
var immortal_jade: int = 20

# ---- 拍卖 / 聊天 / 世界 ----
var auction_entries: Array = []       # 挂单
var auction_records: Array = []       # 成交记录
var chat_all: Array = []              # [{uid, sender, text, ts, channel}]
var current_region: String = "region_zhongyuan"
var unlocked_regions: Array[String] = ["region_zhongyuan", "region_qingyun"]

# ---- 场上战斗（临时状态，不入存档） ----
var battle: Dictionary = {}           # {"monster": {...}, "tpl": {...}}


## 加载存档；无存档则初始化并写入。返回是否成功（文件损坏时重置后仍返回 true，但带告警）
func load_or_init() -> bool:
	if storage == null:
		storage = load("res://src/server/local/storage.gd").new()
	var body: Variant = storage.load_body()
	if body == null:
		return save()
	_apply(body)
	return true


## 序列化并落盘，返回是否成功
func save() -> bool:
	if storage == null:
		storage = load("res://src/server/local/storage.gd").new()
	return storage.save_body(_to_body())


## 应用存档数据体
func _apply(p_body: Dictionary) -> void:
	account_uid = str(p_body.get("account_uid", ""))
	account_name = str(p_body.get("account_name", ""))
	char_uid = str(p_body.get("char_uid", ""))
	char_name = str(p_body.get("char_name", ""))
	gender = str(p_body.get("gender", "male"))
	sect = str(p_body.get("sect", "青云门"))
	level = int(p_body.get("level", 1))
	xp = int(p_body.get("xp", 0))
	realm = int(p_body.get("realm", 0))
	stage = int(p_body.get("stage", 0))
	skill_points = int(p_body.get("skill_points", 5))
	free_attr = int(p_body.get("free_attr", 0))
	title = str(p_body.get("title", ""))
	var five_v: Variant = p_body.get("five", {})
	if five_v is Dictionary and not five_v.is_empty():
		five = five_v
	var alloc: Variant = p_body.get("attr_alloc", {})
	if alloc is Dictionary:
		attr_alloc = alloc
	hp = int(p_body.get("hp", 100))
	mp = int(p_body.get("mp", 50))
	copper = int(p_body.get("copper", 5000))
	spirit_stone = int(p_body.get("spirit_stone", 100))
	immortal_jade = int(p_body.get("immortal_jade", 20))
	current_region = str(p_body.get("current_region", "region_zhongyuan"))
	var unlocked: Variant = p_body.get("unlocked_regions", [])
	if unlocked is Array:
		unlocked_regions.assign(unlocked)
	_copy_array(p_body.get("items"), items)
	var eq: Variant = p_body.get("equips", {})
	if eq is Dictionary:
		equips = eq
	_copy_array(p_body.get("quests"), quests)
	tracked_quest_uid = str(p_body.get("tracked_quest_uid", ""))
	var lr: Variant = p_body.get("learned", {})
	if lr is Dictionary:
		learned = lr
	_copy_array(p_body.get("auction_entries"), auction_entries)
	_copy_array(p_body.get("auction_records"), auction_records)
	_copy_array(p_body.get("chat_all"), chat_all)


## 导出存档数据体（body 字段约定同样适用于存档结构）
func _to_body() -> Dictionary:
	return {
		"version": 1, "account_uid": account_uid, "account_name": account_name,
		"char_uid": char_uid, "char_name": char_name, "gender": gender, "sect": sect,
		"level": level, "xp": xp, "realm": realm, "stage": stage,
		"skill_points": skill_points, "free_attr": free_attr, "title": title,
		"five": five, "attr_alloc": attr_alloc, "hp": hp, "mp": mp,
		"copper": copper, "spirit_stone": spirit_stone, "immortal_jade": immortal_jade,
		"current_region": current_region, "unlocked_regions": unlocked_regions,
		"items": items, "equips": equips, "quests": quests,
		"tracked_quest_uid": tracked_quest_uid, "learned": learned,
		"auction_entries": auction_entries, "auction_records": auction_records,
		"chat_all": chat_all,
	}


## 拷贝 JSON 数组到目标数组（保证元素为字典）
func _copy_array(p_src: Variant, p_dst: Array) -> void:
	p_dst.clear()
	if p_src is Array:
		for it: Variant in p_src:
			if it is Dictionary:
				p_dst.append(it)


## 当前等级升一级所需修为
func xp_need() -> int:
	return int(100.0 * pow(float(level), 1.35))


## 按等级推导境界与段位
func refresh_realm() -> void:
	realm = 0
	for i in range(REALM_RANGES.size()):
		if level >= int(REALM_RANGES[i][0]):
			realm = i
	var lo := int(REALM_RANGES[realm][0])
	var hi := int(REALM_RANGES[realm][1])
	var span := float(hi - lo + 1)
	stage = clampi(int((level - lo) / (span / 4.0)), 0, 3)
