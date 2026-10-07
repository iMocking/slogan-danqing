# 仙途 · 全局枚举
# 与 docs/02-GDD、docs/03-UI设计规范 保持一致。
class_name Enums
extends RefCounted

## 物品品质（六档，对应品质色）
enum Quality { FAN, LING, XUAN, DI, TIAN, XIAN }

## 装备槽位
enum EquipSlot { NONE, WEAPON, HAT, ROBE, ACCESSORY, SHOES, NECKLACE }

## 功法四系
enum Branch { SWORD, SPELL, ALCHEMY, BODY }

## 任务类型
enum QuestType { MAIN, SIDE, DAILY, ENCOUNTER }

## 任务实例状态
enum QuestState { AVAILABLE, ACCEPTED, READY, DONE }

## 货币
enum Currency { COPPER, SPIRIT_STONE, IMMORTAL_JADE }

## 聊天频道
enum ChatChannel { ALL, WORLD, SECT, TEAM, PRIVATE }

## 商城分类
enum ShopCategory { HOT, LIMITED, EQUIP, PILL, MATERIAL, FASHION, GIFT }

## 拍卖页签
enum AuctionTab { BROWSE, MINE, MY_BID, RECORD }

## 境界（九境）
enum Realm { LIANQI, ZHUJI, JIEDAN, YUANYING, HUASHEN, LIANXU, HETI, DACHENG, DUJIE }

## 境界内段位
enum RealmStage { CHU, ZHONG, HOU, YUANMAN }

## 境界中文名
const REALM_NAMES := ["练气", "筑基", "结丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫"]

## 段位中文名
const STAGE_NAMES := ["初期", "中期", "后期", "圆满"]

## 品质中文名与品质色（顺序与 Quality 对齐）
const QUALITY_NAMES := ["凡", "灵", "玄", "地", "天", "仙"]
const QUALITY_COLORS := [
	Color("#6B6762"), Color("#4A6B52"), Color("#3D5A7A"),
	Color("#7A5A86"), Color("#B8860B"), Color("#8B2500"),
]


## 拼接境界文本：如「筑基中期 45 级」
static func realm_text(p_realm: int, p_stage: int, p_level: int) -> String:
	return "%s%s %d 级" % [_realm_name(p_realm, REALM_NAMES), _stage_name(p_stage, STAGE_NAMES), p_level]


static func _realm_name(p_realm: int, p_names: Array) -> String:
	return p_names[clampi(p_realm, 0, p_names.size() - 1)]


static func _stage_name(p_stage: int, p_names: Array) -> String:
	return p_names[clampi(p_stage, 0, p_names.size() - 1)]
