# 仙途 · 物品模板表（服务器侧静态配置）
# 实例（背包物品）由 handler 生成，实例 uid 为 ULID，template_id 引用本表。
class_name DbItems
extends RefCounted

const ICON_DIR := "res://assets/ui/icons/item/"
const BAG_DIR := "res://assets/ui/icons/bag/"
const EQUIP_DIR := "res://assets/ui/icons/equip/"

# 字段：id, name, icon, quality(Enums.Quality), type(equip/pill/material/quest),
#       max_stack, sell_price, slot(Enums.EquipSlot 文本), stats{hp,mp,atk,def,hit,dodge}, desc
const ITEMS: Array = [
	{"id": "item_sword_iron", "name": "青锋铁剑", "icon": ICON_DIR + "icon_item_sword.png", "quality": 2, "type": "equip", "slot": "weapon", "max_stack": 1, "sell_price": 120, "stats": {"atk": 15}, "desc": "青云门弟子入门佩剑，剑身泛青，可斩三尺妖气。"},
	{"id": "item_sword_qingyun", "name": "青云剑", "icon": BAG_DIR + "bag_sword.png", "quality": 3, "type": "equip", "slot": "weapon", "max_stack": 1, "sell_price": 500, "stats": {"atk": 32, "mp": 20}, "desc": "青云门镇门剑器之一，剑气如虹，非凡品可比。"},
	{"id": "item_hat_tao", "name": "混元道冠", "icon": EQUIP_DIR + "equip_hat.png", "quality": 1, "type": "equip", "slot": "hat", "max_stack": 1, "sell_price": 60, "stats": {"def": 6}, "desc": "寻常道冠，绣有混元纹，聊胜于无。"},
	{"id": "item_robe_ink", "name": "墨色道袍", "icon": EQUIP_DIR + "equip_robe.png", "quality": 2, "type": "equip", "slot": "robe", "max_stack": 1, "sell_price": 200, "stats": {"def": 12, "hp": 50}, "desc": "以墨玉蚕丝织就，轻若无物，暖如春阳。"},
	{"id": "item_necklace_yangqi", "name": "养气玉佩", "icon": EQUIP_DIR + "equip_necklace.png", "quality": 2, "type": "equip", "slot": "necklace", "max_stack": 1, "sell_price": 180, "stats": {"mp": 40}, "desc": "温养真元之玉佩，佩之经脉通达。"},
	{"id": "item_ring_lingyu", "name": "灵玉指环", "icon": BAG_DIR + "bag_jade_ring.png", "quality": 3, "type": "equip", "slot": "accessory", "max_stack": 1, "sell_price": 420, "stats": {"hit": 15, "atk": 5}, "desc": "环身刻聚灵纹，出手更添三分准头。"},
	{"id": "item_boots_cloud", "name": "踏云靴", "icon": BAG_DIR + "bag_boots.png", "quality": 1, "type": "equip", "slot": "shoes", "max_stack": 1, "sell_price": 90, "stats": {"def": 4, "dodge": 8}, "desc": "鞋底绣云纹，行路生风，闪避轻灵。"},
	{"id": "item_pill_huiqi", "name": "回气丹", "icon": ICON_DIR + "icon_item_pill.png", "quality": 1, "type": "pill", "max_stack": 99, "sell_price": 15, "stats": {}, "desc": "服之恢复 150 点气血，丹香扑鼻。"},
	{"id": "item_pill_ningshen", "name": "凝神丹", "icon": BAG_DIR + "bag_pill_trio.png", "quality": 1, "type": "pill", "max_stack": 99, "sell_price": 15, "stats": {}, "desc": "服之恢复 100 点真元，凝神静气。"},
	{"id": "item_pill_zhuji", "name": "筑基丹", "icon": BAG_DIR + "bag_gourd_gold.png", "quality": 4, "type": "pill", "max_stack": 9, "sell_price": 800, "stats": {}, "desc": "突破筑基所需丹药，一丹难求。"},
	{"id": "item_wine_guihua", "name": "桂花酿", "icon": BAG_DIR + "bag_wine_jar.png", "quality": 0, "type": "pill", "max_stack": 20, "sell_price": 8, "stats": {}, "desc": "山间野酿，微醺即止，回复 30 点气血。"},
	{"id": "item_herb_lingzhi", "name": "灵芝草", "icon": ICON_DIR + "icon_item_herb.png", "quality": 1, "type": "material", "max_stack": 99, "sell_price": 20, "stats": {}, "desc": "青云山常见灵药，炼丹基础材料。"},
	{"id": "item_herb_xueshen", "name": "血参", "icon": BAG_DIR + "bag_herb.png", "quality": 2, "type": "material", "max_stack": 99, "sell_price": 45, "stats": {}, "desc": "生于阴崖，参须赤红，药性刚猛。"},
	{"id": "item_ore_xuantie", "name": "玄铁矿", "icon": BAG_DIR + "bag_ore.png", "quality": 1, "type": "material", "max_stack": 99, "sell_price": 25, "stats": {}, "desc": "锻器良材，玄色沉手。"},
	{"id": "item_wood_chenxiang", "name": "沉香木", "icon": BAG_DIR + "bag_wood.png", "quality": 1, "type": "material", "max_stack": 99, "sell_price": 22, "stats": {}, "desc": "香可入药，亦可制符。"},
	{"id": "item_hide_yaoshou", "name": "妖兽皮", "icon": BAG_DIR + "bag_hide.png", "quality": 1, "type": "material", "max_stack": 99, "sell_price": 30, "stats": {}, "desc": "剥自低阶妖兽，韧劲十足。"},
	{"id": "item_crystal_ling", "name": "灵石原晶", "icon": ICON_DIR + "icon_item_crystal.png", "quality": 2, "type": "material", "max_stack": 99, "sell_price": 60, "stats": {}, "desc": "灵气凝结之晶，可打磨为灵石。"},
	{"id": "item_jade_yanghun", "name": "养魂玉", "icon": ICON_DIR + "icon_item_jade.png", "quality": 3, "type": "material", "max_stack": 20, "sell_price": 260, "stats": {}, "desc": "温养神魂的宝玉，炼器至宝。"},
	{"id": "item_letter_mi", "name": "密信", "icon": BAG_DIR + "bag_scroll.png", "quality": 0, "type": "quest", "max_stack": 1, "sell_price": 0, "stats": {}, "desc": "火漆封口，似有要事相托。"},
	{"id": "item_talisman_fu", "name": "驱邪符", "icon": BAG_DIR + "bag_talisman.png", "quality": 1, "type": "quest", "max_stack": 10, "sell_price": 12, "stats": {}, "desc": "朱砂绘制的符箓，隐有灵光流转。"},
	{"id": "item_book_jianpu", "name": "剑法残页", "icon": BAG_DIR + "bag_book.png", "quality": 2, "type": "quest", "max_stack": 1, "sell_price": 100, "stats": {}, "desc": "残缺剑谱，字迹苍劲，惜不完整。"},
	{"id": "item_armor_buxiu", "name": "不朽宝甲", "icon": ICON_DIR + "icon_item_armor.png", "quality": 5, "type": "equip", "slot": "robe", "max_stack": 1, "sell_price": 3000, "stats": {"def": 45, "hp": 300}, "desc": "传说中的仙家宝甲，刀枪不入。"},
]


## 按 id 查找模板，找不到返回空字典
static func get_template(p_id: String) -> Dictionary:
	for it: Dictionary in ITEMS:
		if str(it["id"]) == p_id:
			return it
	return {}


## 模板图标资源加载（失败返回 null）
static func icon_of(p_template: Dictionary) -> Texture2D:
	var path := str(p_template.get("icon", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)
