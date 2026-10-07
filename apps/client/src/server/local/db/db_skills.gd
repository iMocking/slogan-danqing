# 仙途 · 功法图谱模板表：四系各 3 行 5 列共 15 节点
# 节点 id 规则：skill_<系前缀>_<行>_<列>；实例学习进度存于 ServerState.learned。
class_name DbSkills
extends RefCounted

const MAX_LEVEL := 5
const COST_PER_LEVEL := 1          # 每级消耗修为点
const ICON_DIR := "res://assets/ui/skillbar/"

# 四系英文章与中文名
const BRANCHES := [
	{"key": "sword", "name": "剑修"},
	{"key": "spell", "name": "法修"},
	{"key": "alchemy", "name": "丹修"},
	{"key": "body", "name": "体修"},
]

# 每系 15 个技能名（行优先）
const NAMES := {
	"sword": ["基础剑诀", "青云剑气", "剑意凝锋", "斩风式", "流云回雪",
		"破军势", "剑气纵横", "追星逐月", "青冥护体", "剑心通明",
		"万剑诀", "诛邪剑阵", "剑荡八荒", "人剑合一", "御剑飞仙"],
	"spell": ["吐纳诀", "聚灵术", "火弹术", "冰锥咒", "风缠术",
		"雷引术", "玄光盾", "烈焰焚野", "寒霜漫天", "元素共鸣",
		"九霄雷动", "燎原火海", "万里冰封", "法则初悟", "毁天灭地"],
	"alchemy": ["识药篇", "回春术", "清心咒", "止血散方", "聚气丹方",
		"灵草培元", "妙手回春", "清毒散方", "凝露术", "丹火掌控",
		"济世丹方", "百炼成丹", "起死回生", "丹道通神", "九转金丹"],
	"body": ["扎马桩", "铁布衫", "崩拳", "金钟罩", "横练罡气",
		"金刚拳", "怒目金刚", "不动明王", "反击风暴", "体魄如山",
		"罗汉金身", "大日如来掌", "不灭战体", "肉身成圣", "一力破万法"],
}

const DESCS := {
	"sword": "剑修功法：以剑证道，攻伐凌厉。",
	"spell": "法修功法：御元素之力，爆发惊人。",
	"alchemy": "丹修功法：炼丹济世，疗伤增益。",
	"body": "体修功法：肉身成盾，坚不可摧。",
}


## 生成某系的 15 个节点（含前置依赖），pre_prereq 为语义 id 数组
static func nodes(p_branch: int) -> Array:
	var info: Dictionary = BRANCHES[clampi(p_branch, 0, 3)]
	var key: String = info["key"]
	var names: Array = NAMES[key]
	var out: Array = []
	for row in range(3):
		for col in range(5):
			var idx := row * 5 + col
			var prereq: Array = []
			if col > 0:
				prereq.append("%s_%d_%d" % [key, row, col - 1])
			# 制造网状依赖：第 2/4 列的非首行节点额外依赖上一行同列
			if row > 0 and (col == 2 or col == 4):
				prereq.append("%s_%d_%d" % [key, row - 1, col])
			out.append({
				"id": "%s_%d_%d" % [key, row, col],
				"name": str(names[idx]),
				"branch": p_branch,
				"row": row, "col": col,
				"prereq": prereq,
				"max_level": MAX_LEVEL,
				"cost_per_level": COST_PER_LEVEL,
				"mp_cost": 8 + col * 4 + row * 2,
				"cooldown": 2.0 + col * 0.5,
				"icon": ICON_DIR + "skill_icon_%02d.png" % ((idx % 8) + 1),
				"desc": DESCS[key],
			})
	return out


## 按 id 查找节点
static func get_node(p_id: String) -> Dictionary:
	for b in range(4):
		for n: Dictionary in nodes(b):
			if str(n["id"]) == p_id:
				return n
	return {}
