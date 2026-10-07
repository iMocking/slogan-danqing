# 仙途 · 世界区域表（八大区域，与设计稿 ui-08 一致）
# pos 为归一化坐标（0~1，对应卷轴底图），unlock_realm 为传送所需境界（Enums.Realm）
class_name DbWorld
extends RefCounted

const REGIONS: Array = [
	{"id": "region_zhongyuan", "name": "中原皇城", "pos": [0.50, 0.42], "unlock_realm": 0, "recommend": "练气", "boss": "无", "desc": "人族主城，商旅云集，任务中枢所在。"},
	{"id": "region_qingyun", "name": "青云山", "pos": [0.32, 0.58], "unlock_realm": 0, "recommend": "练气", "boss": "妖狼头目", "desc": "青云门所在，新手修行的起点。"},
	{"id": "region_nanjiang", "name": "南疆沼泽", "pos": [0.42, 0.78], "unlock_realm": 1, "recommend": "筑基", "boss": "万毒蟾君", "desc": "瘴气弥漫，毒虫遍地，亦多奇药。"},
	{"id": "region_beihuang", "name": "北荒雪原", "pos": [0.52, 0.18], "unlock_realm": 2, "recommend": "结丹", "boss": "雪魔狼王", "desc": "千里冰封，寒妖出没无常。"},
	{"id": "region_wanyao", "name": "万妖谷", "pos": [0.72, 0.52], "unlock_realm": 2, "recommend": "结丹", "boss": "九尾妖狐", "desc": "群妖聚居之地，机缘与凶险并存。"},
	{"id": "region_donghai", "name": "东海蓬莱", "pos": [0.86, 0.40], "unlock_realm": 3, "recommend": "元婴", "boss": "蛟龙王", "desc": "海外仙山，仙家福地，凡人难渡。"},
	{"id": "region_ximo", "name": "西漠流沙", "pos": [0.20, 0.34], "unlock_realm": 4, "recommend": "化神", "boss": "沙暴古魔", "desc": "大漠深处有古修士洞府，秘境入口。"},
	{"id": "region_moyu", "name": "魔域深渊", "pos": [0.66, 0.86], "unlock_realm": 5, "recommend": "炼虚", "boss": "深渊魔主", "desc": "魔气冲天的禁地，终局试炼之所。"},
]

## 相邻区域的虚线道路（按区域 id 对）
const ROADS: Array = [
	["region_zhongyuan", "region_qingyun"],
	["region_zhongyuan", "region_beihuang"],
	["region_zhongyuan", "region_wanyao"],
	["region_zhongyuan", "region_nanjiang"],
	["region_qingyun", "region_ximo"],
	["region_qingyun", "region_nanjiang"],
	["region_nanjiang", "region_moyu"],
	["region_wanyao", "region_donghai"],
	["region_beihuang", "region_donghai"],
	["region_beihuang", "region_ximo"],
]


## 按 id 查找区域
static func get_region(p_id: String) -> Dictionary:
	for r: Dictionary in REGIONS:
		if str(r["id"]) == p_id:
			return r
	return {}


## 世界场景中的野怪（供任务 kill 目标与演示战斗）
const MONSTERS: Array = [
	{"name": "山魈", "hp": 60, "xp": 8, "copper": 15, "drops": ["item_herb_lingzhi", "item_wood_chenxiang"]},
	{"name": "妖狼", "hp": 90, "xp": 12, "copper": 22, "drops": ["item_hide_yaoshou", "item_herb_xueshen", "item_ore_xuantie"]},
	{"name": "妖狼头目", "hp": 300, "xp": 60, "copper": 120, "drops": ["item_talisman_fu", "item_hide_yaoshou", "item_wine_guihua"]},
]
