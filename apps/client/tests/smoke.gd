# 仙途 · 冒烟测试（headless 运行测试场景）
# 用法：godot --headless --path . res://tests/smoke.tscn
# 覆盖：ULID、各域 handler 主路径与错误路径、存档读写。
# 开始前备份已有存档，结束后恢复，不污染真实存档。
extends Node

var _fails := 0
var _count := 0
var _save_path := "user://saves/slot_1.json"
var _backup_path := "user://saves/smoke_backup.json"


func _ready() -> void:
	_backup_save()
	GameServer.reset_local()
	await _test_ulid()
	await _test_auth()
	await _test_character()
	await _test_inventory()
	await _test_quest_and_fight()
	await _test_skill()
	await _test_shop()
	await _test_auction()
	await _test_chat_world()
	_report()
	_restore_save()
	get_tree().quit(1 if _fails > 0 else 0)


# ---------- 断言 ----------
func _check(p_name: String, p_cond: bool, p_detail: String = "") -> void:
	_count += 1
	if p_cond:
		print("  [通过] %s" % p_name)
	else:
		_fails += 1
		printerr("  [失败] %s  %s" % [p_name, p_detail])


func _req(p_route: String, p_body: Dictionary = {}) -> Dictionary:
	return await GameServer.request(p_route, p_body)


# ---------- 用例 ----------
func _test_ulid() -> void:
	print("[ULID]")
	var seen := {}
	var ok_order := true
	var last := ""
	for i in range(2000):
		var id := Ulid.new_id()
		if not Ulid.is_valid(id) or seen.has(id):
			ok_order = false
		if last != "" and id < last:
			ok_order = false
		seen[id] = true
		last = id
	_check("2000 次生成全部合法且单调唯一", ok_order)


func _test_auth() -> void:
	print("[认证]")
	var bad := await _req("auth.login", {"account": "tester", "password": "123"})
	_check("短密码被拒绝", int(bad["code"]) == Rpc.BAD_PARAM)
	var good := await _req("auth.login", {"account": "tester", "password": "123456"})
	_check("正常登录成功", Rpc.is_ok(good), str(good))
	var no_char := await _req("character.get")
	_check("未建角色时查询返回业务错误", not Rpc.is_ok(no_char))
	var bad_domain := await _req("foo.bar")
	_check("未知域返回 5004", int(bad_domain["code"]) == Rpc.UNKNOWN_DOMAIN)
	var bad_action := await _req("auth.nope")
	_check("未知动作返回 5005", int(bad_action["code"]) == Rpc.UNKNOWN_ACTION)


func _test_character() -> void:
	print("[角色]")
	var short_name := await _req("character.create", {"name": "云", "gender": "male", "sect": "sect_qingyun"})
	_check("名字过短被拒", int(short_name["code"]) == Rpc.RULE_BASE + Rpc.RULE_NAME)
	var bad_sect := await _req("character.create", {"name": "青云子", "gender": "male", "sect": "sect_none"})
	_check("门派不存在被拒", int(bad_sect["code"]) == Rpc.NOT_FOUND)
	var ok := await _req("character.create", {"name": "青云子", "gender": "male", "sect": "sect_qingyun"})
	_check("创建角色成功且返回 ULID", Rpc.is_ok(ok) and Ulid.is_valid(str(Rpc.body(ok).get("character", {}).get("uid", ""))))
	var dup := await _req("character.create", {"name": "二次元", "gender": "female", "sect": "sect_xuantian"})
	_check("重复创建被拒", int(dup["code"]) == Rpc.RULE_BASE + Rpc.RULE_STATE)
	var detail := await _req("character.get")
	var ch: Dictionary = Rpc.body(detail).get("character", {})
	_check("境界文本正确", str(ch.get("realm_text", "")) == "练气初期 1 级", str(ch.get("realm_text")))
	_check("装备栏 6 槽齐备", (ch.get("equips", {}) as Dictionary).size() == 6)


func _test_inventory() -> void:
	print("[背包]")
	var list := await _req("inventory.list", {"category": "all"})
	var items: Array = Rpc.body(list).get("items", [])
	_check("初始背包含回气丹与铁剑", items.size() >= 2, str(items.size()))
	var pill_uid := ""
	var sword_uid := ""
	for it: Variant in items:
		if str(it["template_id"]) == "item_pill_huiqi":
			pill_uid = str(it["uid"])
		if str(it["template_id"]) == "item_sword_iron":
			sword_uid = str(it["uid"])
	var no_item := await _req("inventory.use", {"uid": "00000000000000000000000000"})
	_check("使用不存在物品返回 4204", int(no_item["code"]) == Rpc.NOT_FOUND)
	var used := await _req("inventory.use", {"uid": pill_uid})
	_check("使用回气丹成功", Rpc.is_ok(used))
	var split := await _req("inventory.split", {"uid": pill_uid, "count": 2})
	_check("堆叠拆分成功", Rpc.is_ok(split))
	var equip := await _req("equip.wear", {"uid": sword_uid})
	_check("穿戴武器成功", Rpc.is_ok(equip), str(equip))
	var ch: Dictionary = Rpc.body(equip).get("character", {})
	_check("穿戴后攻击力提升", int(ch.get("atk", 0)) > 8, str(ch.get("atk")))
	var unequip := await _req("equip.unequip", {"slot": "weapon"})
	_check("卸下装备成功", Rpc.is_ok(unequip))
	await _req("equip.wear", {"uid": sword_uid})
	var sorted := await _req("inventory.sort")
	_check("整理成功", Rpc.is_ok(sorted))
	var filtered := await _req("inventory.list", {"category": "equip"})
	_check("装备分类过滤生效", Rpc.is_ok(filtered))


func _test_quest_and_fight() -> void:
	print("[任务与战斗]")
	var list := await _req("quest.list")
	var avail: Array = Rpc.body(list).get("available", [])
	var has_main := false
	for q: Variant in avail:
		if str(q.get("template_id")) == "q_main_1":
			has_main = true
	_check("可接任务含主线一", has_main)
	var locked := await _req("quest.accept", {"template_id": "q_main_2"})
	_check("前置未满足接取被拒", int(locked["code"]) == Rpc.RULE_BASE + Rpc.RULE_PREREQ)
	var acc := await _req("quest.accept", {"template_id": "q_main_1"})
	_check("接取主线一成功", Rpc.is_ok(acc))
	var acc_dup := await _req("quest.accept", {"template_id": "q_main_1"})
	_check("重复接取被拒", not Rpc.is_ok(acc_dup))
	# 交付前先追踪（进行中任务可追踪，已交付任务不可）
	var accepted_list := await _req("quest.list")
	var main_uid_early := ""
	for q: Variant in Rpc.body(accepted_list).get("accepted", []):
		if str(q.get("template_id")) == "q_main_1":
			main_uid_early = str(q["uid"])
	var track_early := await _req("quest.track", {"uid": main_uid_early})
	_check("追踪任务成功", Rpc.is_ok(track_early), str(track_early))
	# 战斗推进：击杀 5 只山魈（随机遇怪，穿插打坐防倒地）
	var ready := false
	var main_uid := ""
	for i in range(120):
		var fight := await _req("world.fight", {})
		if not Rpc.is_ok(fight):
			await _req("world.rest")
			continue
		if bool(Rpc.body(fight).get("killed", false)):
			await _req("world.rest")
		var ql := await _req("quest.list")
		for q: Variant in Rpc.body(ql).get("accepted", []):
			if str(q.get("template_id")) == "q_main_1":
				main_uid = str(q["uid"])
				if int(q.get("state", 0)) == 2:
					ready = true
		if ready:
			break
	_check("战斗推进任务至可交付", ready)
	var claim := await _req("quest.claim", {"uid": main_uid})
	_check("交付任务成功", Rpc.is_ok(claim), str(claim))


func _test_skill() -> void:
	print("[功法]")
	var tree := await _req("skill.tree", {"branch": 0})
	var nodes: Array = Rpc.body(tree).get("nodes", [])
	_check("剑修 15 节点", nodes.size() == 15, str(nodes.size()))
	var locked_learn := await _req("skill.learn", {"skill_id": "sword_1_2"})
	_check("无前置学习被拒", int(locked_learn["code"]) == Rpc.RULE_BASE + Rpc.RULE_PREREQ)
	var learn1 := await _req("skill.learn", {"skill_id": "sword_0_0"})
	_check("学习首个节点成功", Rpc.is_ok(learn1))
	var learn2 := await _req("skill.learn", {"skill_id": "sword_0_1"})
	_check("前置满足后可学下一节点", Rpc.is_ok(learn2))
	var cast := await _req("world.fight", {"skill_id": "sword_0_0"})
	_check("已学功法可释放", Rpc.is_ok(cast), str(cast))


func _test_shop() -> void:
	print("[商城]")
	var list := await _req("shop.list", {"category": 3, "page": 1})
	var rows: Array = Rpc.body(list).get("rows", [])
	_check("丹药分类有商品", rows.size() > 0)
	var poor := await _req("shop.buy", {"goods_id": "g_lim_armor", "count": 1})
	_check("仙玉不足购买被拒", int(poor["code"]) == Rpc.RULE_BASE + Rpc.RULE_NO_MONEY)
	var ok := await _req("shop.buy", {"goods_id": "g_pill_hp", "count": 2})
	_check("铜钱购买成功", Rpc.is_ok(ok))
	var pack := await _req("shop.buy", {"goods_id": "g_pack_newbie", "count": 1})
	_check("礼包购买并展开", Rpc.is_ok(pack))


func _test_auction() -> void:
	print("[拍卖行]")
	var list := await _req("auction.list", {"tab": 0, "page": 1})
	var rows: Array = Rpc.body(list).get("rows", [])
	_check("浏览页有种子挂单", rows.size() >= 5, str(rows.size()))
	# 挑当前价最低的挂单出价（避免初始灵石不足）
	var entry_uid := ""
	var cur_price := 1 << 30
	for r: Variant in rows:
		if int(r["current_price"]) < cur_price:
			cur_price = int(r["current_price"])
			entry_uid = str(r["uid"])
	var low_bid := await _req("auction.bid", {"entry_uid": entry_uid, "price": cur_price})
	_check("低于 1.05 倍出价被拒", int(low_bid["code"]) == Rpc.RULE_BASE + Rpc.RULE_STATE)
	var ok_bid := await _req("auction.bid", {"entry_uid": entry_uid, "price": cur_price * 2})
	_check("合理出价成功", Rpc.is_ok(ok_bid), str(ok_bid))
	# 上架：取背包一件物品
	var inv := await _req("inventory.list", {"category": "all"})
	var items: Array = Rpc.body(inv).get("items", [])
	if items.is_empty():
		await _req("shop.buy", {"goods_id": "g_pill_hp", "count": 1})
		inv = await _req("inventory.list", {"category": "all"})
		items = Rpc.body(inv).get("items", [])
	var uid := str(items[0]["uid"])
	var listed := await _req("auction.list_item", {"uid": uid, "start_price": 10, "buyout": 100, "hours": 24})
	_check("上架成功", Rpc.is_ok(listed), str(listed))
	var mine := await _req("auction.list", {"tab": 1, "page": 1})
	var mine_rows: Array = Rpc.body(mine).get("rows", [])
	var found := false
	var mine_entry := ""
	for r: Variant in mine_rows:
		if str(r.get("name")) == str(items[0]["name"]):
			found = true
			mine_entry = str(r["uid"])
	_check("我的拍卖可见挂单", found)
	var cancel := await _req("auction.cancel", {"entry_uid": mine_entry})
	_check("无出价可下架", Rpc.is_ok(cancel), str(cancel))


func _test_chat_world() -> void:
	print("[聊天与世界]")
	var sent := await _req("chat.send", {"text": "问道于途，何以为仙？"})
	_check("发送消息成功且带 ULID", Rpc.is_ok(sent) and Ulid.is_valid(str(Rpc.body(sent).get("message", {}).get("uid", ""))))
	var empty := await _req("chat.send", {"text": "  "})
	_check("空消息被拒", int(empty["code"]) == Rpc.BAD_PARAM)
	var hist := await _req("chat.history", {"channel": 0})
	_check("历史可查", Rpc.body(hist).get("messages", []).size() > 0)
	var map := await _req("world.map")
	_check("地图含八区域", Rpc.body(map).get("regions", []).size() == 8)
	var far := await _req("world.travel", {"region_id": "region_moyu"})
	_check("境界不足传送被拒", int(far["code"]) == Rpc.RULE_BASE + Rpc.RULE_PREREQ)
	var near := await _req("world.travel", {"region_id": "region_qingyun"})
	_check("境界足够传送成功", Rpc.is_ok(near))


func _report() -> void:
	print("========================================")
	if _fails == 0:
		print("冒烟测试全部通过：%d 项断言" % _count)
	else:
		printerr("冒烟测试失败：%d / %d 项未通过" % [_fails, _count])


# ---------- 存档保护 ----------
func _backup_save() -> void:
	if FileAccess.file_exists(_save_path):
		DirAccess.copy_absolute(_save_path, _backup_path)
		DirAccess.remove_absolute(_save_path)


func _restore_save() -> void:
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(_save_path)
	if FileAccess.file_exists(_backup_path):
		DirAccess.copy_absolute(_backup_path, _save_path)
		DirAccess.remove_absolute(_backup_path)
