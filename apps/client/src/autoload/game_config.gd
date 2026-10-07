# 仙途 · 全局配置常量
extends Node

## 版本号
const VERSION := "0.1.0"
## 设计基准分辨率
const DESIGN_WIDTH := 1920
const DESIGN_HEIGHT := 1080
## 存档路径与版本
const SAVE_PATH := "user://saves/slot_1.json"
const SAVE_VERSION := 1
## 服务器列表（单机模拟；联机后由登录服务下发）
const SERVERS: Array = [
	{"id": "s1", "name": "青云山·一区", "state": "流畅"},
	{"id": "s2", "name": "蓬莱岛·新区", "state": "流畅"},
	{"id": "s3", "name": "北荒雪原·二区", "state": "繁忙"},
]
## 加载页修仙小贴士
const LOADING_TIPS: Array[String] = [
	"打坐可恢复气血与真元，灵气充裕时修炼事半功倍。",
	"境界突破需修为圆满，辅以对应突破丹药。",
	"乾坤袋中物品可按品质整理，灵物切勿轻易丢弃。",
	"拍卖行竞价不得低于当前价的百分之一百零五。",
	"功法图谱四系并行，修为点来之不易，慎重点拨。",
	"世界地图八荒齐备，境界不足的区域无法传送。",
	"每日任务勤加完成，铜钱灵石皆从点滴中来。",
	"与同道在/chat 中交流，可结伴降妖。",
]
