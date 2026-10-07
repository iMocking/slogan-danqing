# 仙途 · 杂项模板表：门派 / 捏人外观选项 / 世界氛围话术
class_name DbMisc
extends RefCounted

## 门派（影响初始属性加成）
const SECTS: Array = [
	{"id": "sect_qingyun", "name": "青云门", "desc": "均衡近战，剑修正统。", "bonus": {"筋骨": 2, "灵气": 2}},
	{"id": "sect_xuantian", "name": "玄天宗", "desc": "远程爆发，法修圣地。", "bonus": {"灵气": 4}},
	{"id": "sect_yaowang", "name": "药王谷", "desc": "悬壶济世，丹修传承。", "bonus": {"根骨": 2, "悟性": 2}},
	{"id": "sect_jingang", "name": "金刚寺", "desc": "高血高防，体修泰斗。", "bonus": {"筋骨": 4}},
]

## 性别选项
const GENDERS: Array = [
	{"id": "male", "name": "男"},
	{"id": "female", "name": "女"},
]

## 体型 / 面容 / 发型 / 服饰（单机占位：名称 + 立绘基调）
const BODY_TYPES: Array = [{"id": "slim", "name": "清瘦"}, {"id": "normal", "name": "匀称"}, {"id": "sturdy", "name": "健硕"}]
const FACES: Array = [{"id": "face_yingqi", "name": "英气"}, {"id": "face_wenrun", "name": "温润"}, {"id": "face_lengjun", "name": "冷峻"}, {"id": "face_jiaohao", "name": "姣好"}]
const HAIRS: Array = [{"id": "hair_shu", "name": "束发"}, {"id": "hair_pi", "name": "披发"}, {"id": "hair_gao", "name": "高髻"}, {"id": "hair_bian", "name": "垂辫"}]
const COSTUMES: Array = [{"id": "cost_qingyun", "name": "青云弟子服"}, {"id": "cost_yuebai", "name": "月白道袍"}, {"id": "cost_xuanhei", "name": "玄黑劲装"}, {"id": "cost_yanhong", "name": "焰红法衣"}]

## 世界频道机器人话术（模拟联机氛围）
const CHAT_BOTS: Array = [
	{"sender": "云游子", "text": "北荒雪原掉落了天阶功法残页，速去！"},
	{"sender": "月下无影", "text": "收灵芝草，价格公道，万宝拍卖行见。"},
	{"sender": "酒剑仙", "text": "今日妖狼头目刷新在青云山北坡。"},
	{"sender": "青云小师妹", "text": "有人一起下万妖谷吗？差一个奶妈～"},
	{"sender": "老君炉", "text": "代炼筑基丹，材料自备，手续费五成灵石。"},
	{"sender": "无名剑客", "text": "拍卖行那把青云剑谁来与我竞价？"},
	{"sender": "采药童子", "text": "南疆沼泽瘴气重，记得带足回气丹。"},
]

## 竞争出价机器人名字
const BID_BOTS: Array = ["云游子", "月下无影", "无名剑客", "老君炉", "风清扬"]


## 按 id 查找门派
static func get_sect(p_id: String) -> Dictionary:
	for s: Dictionary in SECTS:
		if str(s["id"]) == p_id:
			return s
	return {}
