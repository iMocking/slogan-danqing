# 创建角色（捏人）ViewModel
class_name CharCreateVm
extends ViewModel

const GROUPS := [
	{"key": "sel_gender", "options": "genders", "title": "性别"},
	{"key": "sel_sect", "options": "sects", "title": "门派"},
	{"key": "sel_body", "options": "body_types", "title": "体型"},
	{"key": "sel_face", "options": "faces", "title": "面容"},
	{"key": "sel_hair", "options": "hairs", "title": "发型"},
	{"key": "sel_costume", "options": "costumes", "title": "服饰"},
]

const DEFAULT_SELS := {
	"sel_gender": "male", "sel_sect": "sect_qingyun", "sel_body": "normal",
	"sel_face": "face_yingqi", "sel_hair": "hair_shu", "sel_costume": "cost_qingyun",
}


func _init() -> void:
	set_prop(&"cname", "")
	set_prop(&"options", {})
	set_prop(&"error", "")
	set_prop(&"can_submit", false)
	for k: String in DEFAULT_SELS:
		set_prop(StringName(k), DEFAULT_SELS[k])


## 拉取捏人选项表
func load_options() -> void:
	var res := await rpc_body("character.options")
	set_prop(&"options", res)


## 输入名字 / 选项变化 → 刷新可提交
func on_input(p_name: String) -> void:
	set_prop(&"cname", p_name)
	_refresh()


func select(p_key: StringName, p_id: String) -> void:
	set_prop(p_key, p_id)


## 重设：恢复默认外观与名字
func reset() -> void:
	set_prop(&"cname", "")
	for k: String in DEFAULT_SELS:
		set_prop(StringName(k), DEFAULT_SELS[k])
	_refresh()


## 踏入仙途：创建角色 → 进世界
func submit() -> void:
	if bool(prop(&"submitting")):
		return
	set_prop(&"error", "")
	var body := {
		"name": str(prop(&"cname")).strip_edges(),
		"gender": str(prop(&"sel_gender")),
		"sect": str(prop(&"sel_sect")),
		"body": str(prop(&"sel_body")), "face": str(prop(&"sel_face")),
		"hair": str(prop(&"sel_hair")), "costume": str(prop(&"sel_costume")),
	}
	var res: Dictionary = await rpc_req("character.create", body)
	if not Rpc.is_ok(res):
		set_prop(&"error", str(res.get("msg", "创建失败")))
		return
	set_prop(&"submitting", true)
	SceneRouter.goto(&"world")


func _refresh() -> void:
	var cname := str(prop(&"cname")).strip_edges()
	set_prop(&"can_submit", cname.length() >= 2 and cname.length() <= 12)
