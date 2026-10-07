# 仙途 · 任务模板表
# 目标 kind：kill（击杀怪名）/ collect（收集物品 template_id）
# 奖励：copper 铜钱 / stone 灵石 / xp 修为 / items[{template_id, count}]
class_name DbQuests
extends RefCounted

const QUESTS: Array = [
	{"id": "q_main_1", "name": "初入仙门", "type": 0, "desc": "新晋弟子听令：青云山外山魈作乱，去山道斩杀 5 只山魈，以证道心。",
		"goals": [{"kind": "kill", "target": "山魈", "need": 5}],
		"rewards": {"copper": 500, "xp": 100, "items": [{"template_id": "item_pill_huiqi", "count": 3}]}, "prereq": []},
	{"id": "q_main_2", "name": "青云试炼", "type": 0, "desc": "妖狼群夜袭山门。猎杀 10 头妖狼，并采集 3 株灵芝草交予药堂。",
		"goals": [{"kind": "kill", "target": "妖狼", "need": 10}, {"kind": "collect", "template_id": "item_herb_lingzhi", "need": 3}],
		"rewards": {"stone": 20, "items": [{"template_id": "item_sword_qingyun", "count": 1}]}, "prereq": ["q_main_1"]},
	{"id": "q_main_3", "name": "妖乱之始", "type": 0, "desc": "妖狼头目现世，啸聚群狼。斩其首级，平此波妖乱。",
		"goals": [{"kind": "kill", "target": "妖狼头目", "need": 3}],
		"rewards": {"stone": 50, "xp": 300, "items": [{"template_id": "item_pill_zhuji", "count": 1}]}, "prereq": ["q_main_2"]},
	{"id": "q_side_1", "name": "药庐帮忙", "type": 1, "desc": "药堂师兄需要 5 株血参炼制伤药。",
		"goals": [{"kind": "collect", "template_id": "item_herb_xueshen", "need": 5}],
		"rewards": {"copper": 300, "items": [{"template_id": "item_pill_ningshen", "count": 2}]}, "prereq": []},
	{"id": "q_side_2", "name": "铁匠的委托", "type": 1, "desc": "锻炉连日开炉，玄铁矿告罄，帮铁匠收集 4 块。",
		"goals": [{"kind": "collect", "template_id": "item_ore_xuantie", "need": 4}],
		"rewards": {"copper": 350, "items": [{"template_id": "item_boots_cloud", "count": 1}]}, "prereq": []},
	{"id": "q_side_3", "name": "失落的符箓", "type": 1, "desc": "巡山弟子遗失了 2 张驱邪符，寻回它们。",
		"goals": [{"kind": "collect", "template_id": "item_talisman_fu", "need": 2}],
		"rewards": {"stone": 15}, "prereq": []},
	{"id": "q_side_4", "name": "酒香也怕巷深", "type": 1, "desc": "后厨刘师傅想尝尝山下的桂花酿，收集 3 坛。",
		"goals": [{"kind": "collect", "template_id": "item_wine_guihua", "need": 3}],
		"rewards": {"copper": 280}, "prereq": []},
	{"id": "q_daily_1", "name": "每日除妖", "type": 2, "desc": "妖物侵扰山场，击杀 8 头妖狼以护山门。",
		"goals": [{"kind": "kill", "target": "妖狼", "need": 8}],
		"rewards": {"stone": 10, "xp": 50}, "prereq": []},
	{"id": "q_daily_2", "name": "每日采药", "type": 2, "desc": "药堂每日例务：采集 3 株灵芝草。",
		"goals": [{"kind": "collect", "template_id": "item_herb_lingzhi", "need": 3}],
		"rewards": {"copper": 200}, "prereq": []},
	{"id": "q_enc_1", "name": "山中老人", "type": 3, "desc": "山路偶遇白发老者，托你取回被妖狼头目叼走的酒葫芦。",
		"goals": [{"kind": "kill", "target": "妖狼头目", "need": 1}],
		"rewards": {"stone": 88, "xp": 120}, "prereq": []},
]

const TYPE_NAMES := ["主线", "支线", "日常", "奇遇"]


## 按 id 查找任务模板
static func get_template(p_id: String) -> Dictionary:
	for q: Dictionary in QUESTS:
		if str(q["id"]) == p_id:
			return q
	return {}


## 任务类型中文名
static func type_name(p_type: int) -> String:
	return TYPE_NAMES[clampi(p_type, 0, TYPE_NAMES.size() - 1)]
