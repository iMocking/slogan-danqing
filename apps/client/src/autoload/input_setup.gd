# 仙途 · 输入映射注册（autoload，启动即生效）
extends Node

const BINDINGS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"attack": [KEY_SPACE],
	"interact": [KEY_F],
	"ui_inventory": [KEY_B],
	"ui_character": [KEY_C],
	"ui_quest": [KEY_Q],
	"ui_skill": [KEY_K],
	"ui_map": [KEY_M],
	"skill_1": [KEY_1], "skill_2": [KEY_2], "skill_3": [KEY_3], "skill_4": [KEY_4],
	"skill_5": [KEY_5], "skill_6": [KEY_6], "skill_7": [KEY_7], "skill_8": [KEY_8],
}


func _ready() -> void:
	for action: String in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: Key in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
