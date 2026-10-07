# 加载界面 ViewModel：真实资源线程加载 + 进度 + 小贴士轮换
class_name LoadingVm
extends ViewModel

const STEP_INTERVAL := 0.08   # 进度采样间隔（秒）

## 截图/测试模式置 false：加载完成不自动跳转
static var auto_advance: bool = true

var _target: StringName = &"char_create"
var _packed: PackedScene = null


func _init() -> void:
	set_prop(&"progress", 0.0)
	set_prop(&"tip", GameConfig.LOADING_TIPS[0])
	set_prop(&"target_text", "正在入世…")


## 小贴士轮换（由 View 的 Timer 驱动）
func next_tip() -> void:
	var idx := randi() % GameConfig.LOADING_TIPS.size()
	set_prop(&"tip", GameConfig.LOADING_TIPS[idx])


## 启动：探测角色 → 线程加载目标场景 → 完成跳转
func start() -> void:
	set_prop(&"progress", 0.05)
	var has_char := true
	var res: Dictionary = await rpc_req("character.get")
	if int(res.get("code", Rpc.NOT_LOGIN)) == Rpc.NOT_LOGIN:
		SceneRouter.goto(&"login")
		return
	has_char = Rpc.is_ok(res)
	_target = &"world" if has_char else &"char_create"
	set_prop(&"target_text", "正在前往 %s…" % ("仙界" if has_char else "捏人台"))
	var path: String = SceneRouter.SCENES[_target]
	ResourceLoader.load_threaded_request(path, "", true)
	var fake := 0.05
	while true:
		var arr: Array = []
		var status := ResourceLoader.load_threaded_get_status(path, arr)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				_packed = ResourceLoader.load_threaded_get(path)
				set_prop(&"progress", 1.0)
				break
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				var real: float = float(arr[0]) if arr.size() > 0 else 0.0
				fake = minf(fake + 0.02, 0.95)
				set_prop(&"progress", clampf(maxf(real, fake), 0.0, 0.99))
			_:
				# 加载失败：直接常规切换兜底
				_packed = null
				break
		await _delay(STEP_INTERVAL)
	await _delay(0.25)
	if auto_advance:
		SceneRouter.goto(_target, _packed)


func _delay(p_sec: float) -> void:
	await Engine.get_main_loop().create_timer(p_sec).timeout
