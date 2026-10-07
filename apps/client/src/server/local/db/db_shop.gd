# 仙途 · 聚宝阁商品表
# goods_type：item（物品）/ pack（礼包：contains 展开）/ title（称号）
# currency：stone 灵石 / jade 仙玉 / copper 铜钱
class_name DbShop
extends RefCounted

const CATEGORY_NAMES := ["推荐", "限时特惠", "装备", "丹药", "材料", "外观", "礼包"]

const GOODS: Array = [
	{"id": "g_hot_pill", "goods_type": "item", "template_id": "item_pill_zhuji", "category": 0, "currency": "stone", "price": 88, "hot": true},
	{"id": "g_hot_sword", "goods_type": "item", "template_id": "item_sword_qingyun", "category": 0, "currency": "stone", "price": 120, "hot": true},
	{"id": "g_hot_crystal", "goods_type": "item", "template_id": "item_crystal_ling", "category": 0, "currency": "stone", "price": 25, "hot": false},
	{"id": "g_lim_armor", "goods_type": "item", "template_id": "item_armor_buxiu", "category": 1, "currency": "jade", "price": 68, "hot": true, "remains_h": 6},
	{"id": "g_lim_ring", "goods_type": "item", "template_id": "item_ring_lingyu", "category": 1, "currency": "stone", "price": 66, "hot": false, "remains_h": 12},
	{"id": "g_equip_sword", "goods_type": "item", "template_id": "item_sword_iron", "category": 2, "currency": "stone", "price": 30, "hot": false},
	{"id": "g_equip_robe", "goods_type": "item", "template_id": "item_robe_ink", "category": 2, "currency": "stone", "price": 45, "hot": true},
	{"id": "g_equip_hat", "goods_type": "item", "template_id": "item_hat_tao", "category": 2, "currency": "copper", "price": 300, "hot": false},
	{"id": "g_equip_boots", "goods_type": "item", "template_id": "item_boots_cloud", "category": 2, "currency": "stone", "price": 22, "hot": false},
	{"id": "g_pill_hp", "goods_type": "item", "template_id": "item_pill_huiqi", "category": 3, "currency": "copper", "price": 40, "hot": false},
	{"id": "g_pill_mp", "goods_type": "item", "template_id": "item_pill_ningshen", "category": 3, "currency": "copper", "price": 40, "hot": false},
	{"id": "g_pill_zhuji", "goods_type": "item", "template_id": "item_pill_zhuji", "category": 3, "currency": "stone", "price": 88, "hot": false},
	{"id": "g_pill_wine", "goods_type": "item", "template_id": "item_wine_guihua", "category": 3, "currency": "copper", "price": 20, "hot": false},
	{"id": "g_mat_herb", "goods_type": "item", "template_id": "item_herb_lingzhi", "category": 4, "currency": "copper", "price": 50, "hot": false},
	{"id": "g_mat_ore", "goods_type": "item", "template_id": "item_ore_xuantie", "category": 4, "currency": "copper", "price": 60, "hot": false},
	{"id": "g_mat_jade", "goods_type": "item", "template_id": "item_jade_yanghun", "category": 4, "currency": "stone", "price": 30, "hot": false},
	{"id": "g_fash_title1", "goods_type": "title", "name": "称号·云游散人", "category": 5, "currency": "jade", "price": 18, "hot": false},
	{"id": "g_fash_title2", "goods_type": "title", "name": "称号·扫地神僧", "category": 5, "currency": "jade", "price": 88, "hot": true},
	{"id": "g_pack_newbie", "goods_type": "pack", "name": "新人修行礼包", "category": 6, "currency": "stone", "price": 6, "hot": true,
		"contains": [{"template_id": "item_pill_huiqi", "count": 10}, {"template_id": "item_pill_ningshen", "count": 10}, {"template_id": "item_hat_tao", "count": 1}]},
	{"id": "g_pack_alch", "goods_type": "pack", "name": "炼丹材料包", "category": 6, "currency": "copper", "price": 800, "hot": false,
		"contains": [{"template_id": "item_herb_lingzhi", "count": 10}, {"template_id": "item_herb_xueshen", "count": 5}, {"item": "item_wood_chenxiang", "template_id": "item_wood_chenxiang", "count": 5}]},
]


## 按 id 查找商品
static func get_goods(p_id: String) -> Dictionary:
	for g: Dictionary in GOODS:
		if str(g["id"]) == p_id:
			return g
	return {}


## 商品结算货币中文名
static func currency_name(p_key: String) -> String:
	match p_key:
		"stone": return "灵石"
		"jade": return "仙玉"
		"copper": return "铜钱"
		_: return "铜钱"
