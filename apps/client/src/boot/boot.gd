# 仙途 · 启动器：进入登录界面（输入映射由 InputSetup autoload 注册）
extends Node


func _ready() -> void:
	SceneRouter.goto(&"login")
