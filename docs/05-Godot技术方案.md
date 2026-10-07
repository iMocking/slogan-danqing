# 05 · Godot 技术方案

[← 返回文档索引](README.md)　|　界面规格见 [04-界面规格与交互清单](04-界面规格与交互清单.md)　|　素材见 [06-美术资源与素材规范](06-美术资源与素材规范.md)

---

## 5.1 引擎版本与环境

| 项 | 值 |
|---|---|
| 引擎 | **Godot 4.3+**（推荐 4.3 / 4.4 stable） |
| 语言 | GDScript（静态类型），性能热点可选 C# |
| 渲染后端 | Forward+ (PC) / Compatibility (移动端备选) |
| 渲染方式 | 2D（CanvasItem）。**不启用 3D**，除非 Q2 确认采用 3D 角色 |
| 版本控制 | Git + `.gitignore`（忽略 `.godot/`、`*.import`、`export/`） |
| 代码格式化 | `gdformat`（gdtoolkit） |

> ⚠️ 当前工作区**尚无 `project.godot`**，需按 5.2 从零初始化。

---

## 5.2 工程目录结构

```
res://
├── project.godot
├── .gitignore
├── .gdformat
│
├── assets/                       # 美术资源（来源 design/，处理见 06 章）
│   ├── ui/
│   │   ├── panels/               # panel-scroll-*、panel-ink-line …
│   │   ├── buttons/              # btn-primary/secondary/dropdown/hot-sale
│   │   ├── icons/
│   │   │   ├── frames/           # circle-frame、square-frame
│   │   │   ├── function/         # 16 个功能图标（⚠️ 素材缺失，见 06.8）
│   │   │   └── item/             # 6 个物品图标（⚠️ 素材缺失）
│   │   ├── controls/             # input-*、avatar-*、equip-slot-*、tab-bar …
│   │   ├── decorations/          # 云纹、印章、分隔线、太极、八卦 …
│   │   ├── bars/                 # bar-frame、bar-hp/mp/exp
│   │   └── skillbar/             # skillbar-frame、skill-slot-frame
│   ├── backgrounds/              # 06-backgrounds 裁切结果
│   ├── fonts/                    # NotoSerifSC-*.ttf、MaShanZheng-*.ttf
│   └── audio/                    # (待补) bgm / sfx
│
├── data/                         # 数据资源 .tres（策划可改）
│   ├── items/                    # ItemData
│   ├── skills/                   # SkillData
│   ├── quests/                   # QuestData
│   ├── regions/                  # RegionData
│   ├── shop/                     # ShopEntryData
│   └── appearance/               # AppearanceOption
│
├── scenes/
│   ├── boot/                     # Boot.tscn、Loading.tscn
│   ├── ui/                       # 各界面 .tscn
│   │   ├── screens/              # login、character_create、world_map …
│   │   └── panels/               # inventory、character、quest、skill_tree …
│   ├── world/                    # 场景地图
│   └── actors/                   # 角色、NPC、敌人
│
├── src/
│   ├── autoload/                 # 单例（见 5.4）
│   ├── core/                     # 系统服务、数据模型、工具
│   │   ├── model/                # Enums.gd、ItemData.gd、SkillData.gd …
│   │   ├── services/             # InventoryService.gd、QuestService.gd …
│   │   └── util/                 # 工具函数
│   ├── ui/
│   │   ├── theme/                # xian_tu_theme.tres、tokens.gd
│   │   ├── widgets/              # ItemSlot、StatRow、TabBar、SkillSlot …
│   │   └── framework/            # UIScreen.gd、UIManager.gd
│   └── gameplay/                 # 战斗、AI、掉落、交互
│
└── docs/                         # 本套文档
```

---

## 5.3 架构分层

```
┌──────────────────────────────────────────────────────────┐
│  表现层  scenes/ui/**  (UIScreen 子类)                     │
│          - 只负责展示与输入，不含业务规则                     │
├──────────────────────────────────────────────────────────┤
│  框架层  src/ui/framework/  (UIManager、UIScreen 基类)      │
│          src/ui/widgets/    (可复用控件)                    │
├──────────────────────────────────────────────────────────┤
│  服务层  src/core/services/ (背包、角色、任务、经济…)         │
│          - 唯一持有游戏状态，暴露方法 + 信号                  │
├──────────────────────────────────────────────────────────┤
│  数据层  src/core/model/    (Resource 定义)                 │
│          data/**/*.tres     (策划数据)                      │
├──────────────────────────────────────────────────────────┤
│  基础设施 EventBus、SaveSystem、Database、AudioManager       │
└──────────────────────────────────────────────────────────┘
```

**核心纪律**

1. UI **不直接读写**服务内部状态，只调方法 + 订阅信号。
2. 服务之间**不互相直接调用**，通过 `EventBus` 解耦（避免循环依赖）。
3. 所有数值来自 `data/**` 或服务，**禁止在 `.tscn` 中硬编码**.

---

## 5.4 Autoload 单例

在 `project.godot` 中注册，**顺序即依赖顺序**：

| 顺序 | 名称 | 脚本 | 职责 |
|---|---|---|---|
| 1 | `EventBus` | `src/autoload/event_bus.gd` | 全局信号总线（无逻辑） |
| 2 | `GameConfig` | `src/autoload/game_config.gd` | 版本、分辨率常量、开关 |
| 3 | `Database` | `src/autoload/database.gd` | 预加载并索引全部 `data/**` 资源 |
| 4 | `SaveSystem` | `src/autoload/save_system.gd` | 存档读写、版本迁移 |
| 5 | `GameState` | `src/autoload/game_state.gd` | 当前角色、当前场景、游玩状态 |
| 6 | `SceneRouter` | `src/autoload/scene_router.gd` | 场景切换 + 加载页 |
| 7 | `UIManager` | `src/autoload/ui_manager.gd` | 界面栈、按 3.9 分层 |
| 8 | `NotificationBus` | `src/autoload/notification_bus.gd` | Toast / 飘字 |
| 9 | `AudioManager` | `src/autoload/audio_manager.gd` | BGM / SFX |
| 10 | `Services` | `src/autoload/services.gd` | 服务定位器，统一持有下列服务 |

**业务服务**（由 `Services` 持有，便于替换与测试）：

`InventoryService`、`CharacterService`、`CultivationService`、`SkillTreeService`、
`QuestService`、`ShopService`、`AuctionService`、`WorldMapService`、`ChatService`

> 为什么不让每个服务都 autoload？——autoload 数量膨胀会导致启动慢、依赖顺序难维护。
> 用 `Services` 定位器：`Services.inventory.add_item(...)`。

```gdscript
# src/autoload/services.gd
extends Node

var inventory: InventoryService
var character: CharacterService
var cultivation: CultivationService
var quest: QuestService

func _ready() -> void:
inventory   = InventoryService.new()
character   = CharacterService.new()
cultivation = CultivationService.new()
quest       = QuestService.new()
for s in [inventory, character, cultivation, quest]:
add_child(s)          # 让服务成为节点，可 await / 用 Timer
```

---

## 5.5 EventBus（信号总线）

```gdscript
# src/autoload/event_bus.gd
extends Node

# —— 背包 ——
signal inventory_changed()
signal item_gained(item_id: StringName, amount: int)
signal item_used(item_id: StringName)

# —— 角色 ——
signal stats_changed()
signal hp_changed(current: int, max_value: int)
signal mp_changed(current: int, max_value: int)
signal realm_changed(realm: int, stage: int, level: int)

# —— 任务 ——
signal quest_accepted(quest_id: StringName)
signal quest_progress(quest_id: StringName)
signal quest_completed(quest_id: StringName)

# —— 经济 ——
signal wallet_changed(currency: int, amount: int)
signal shop_refreshed()

# —— UI ——
signal ui_opened(screen_id: StringName)
signal ui_closed(screen_id: StringName)
signal toast_requested(text: String, kind: int)
```

---

## 5.6 UI 框架

### UIScreen 基类

```gdscript
# src/ui/framework/ui_screen.gd
class_name UIScreen
extends Control

@export var screen_id: StringName
@export var is_modal: bool = false
@export var layer: int = 20          # 对应 03 章 3.9 层级

func open(data: Dictionary = {}) -> void:
visible = true
_on_open(data)
EventBus.ui_opened.emit(screen_id)

func close() -> void:
_on_close()
visible = false
EventBus.ui_closed.emit(screen_id)

func _on_open(_data: Dictionary) -> void: pass
func _on_close() -> void: pass
func _unhandled_input(event: InputEvent) -> void:
if event.is_action_pressed("ui_cancel"):
close()
get_viewport().set_input_as_handled()
```

### UIManager

```gdscript
# src/autoload/ui_manager.gd
extends Node

const SCREENS := {
&"inventory": preload("res://scenes/ui/panels/inventory_panel.tscn"),
&"character": preload("res://scenes/ui/panels/character_panel.tscn"),
&"quest":     preload("res://scenes/ui/panels/quest_panel.tscn"),
&"skill_tree":preload("res://scenes/ui/panels/skill_tree_panel.tscn"),
&"shop":      preload("res://scenes/ui/panels/shop_panel.tscn"),
&"auction":   preload("res://scenes/ui/panels/auction_panel.tscn"),
&"world_map": preload("res://scenes/ui/screens/world_map_screen.tscn"),
}

var _stack: Array[UIScreen] = []

func open(id: StringName, data: Dictionary = {}) -> UIScreen:
var scr: UIScreen = _stack.filter(func(s): return s.screen_id == id).front() \
if _stack.any(func(s): return s.screen_id == id) else null
if scr == null:
scr = SCREENS[id].instantiate()
_attach(scr)
scr.open(data)
_push(scr)
return scr

func close_top() -> void:
if _stack.is_empty(): return
_stack.pop_back().close()
```

### UI 场景树模板

```
InventoryPanel (Control, 脚本 extends UIScreen)
├── Dim            (ColorRect, 仅模态)  → rgba(44,44,44,0.5)
├── Panel          (NinePatchRect / PanelContainer)
│   ├── TitleBar   (HBoxContainer)
│   │   ├── Label  「乾坤袋」
│   │   └── CloseButton
│   ├── TabBar     (TabBarWidget)
│   ├── Body       (HBoxContainer)
│   │   ├── GridContainer  (columns=5)   ← 30 × ItemSlot
│   │   └── DetailPanel    (VBoxContainer)
│   ├── Actions    (HBoxContainer)       ← 使用/丢弃/整理/拆分
│   └── Currency   (HBoxContainer)       ← 铜钱/灵石
└── Tooltip        (PopupPanel)
```

### 可复用控件（`src/ui/widgets/`）

| 控件 | 说明 |
|---|---|
| `item_slot.gd` | 物品格子：图标 + 堆叠数 + 品质边框 + 选中态 + 拖拽源/目标 |
| `skill_slot.gd` | 技能槽：图标 + 冷却扇形遮罩 + 快捷键角标 |
| `stat_row.gd` | 属性行：名称 + 数值 + 加成（绿色） |
| `tab_bar.gd` | 标签页：Normal/Selected/Disabled |
| `currency_label.gd` | 货币：图标 + 数字（自动千分位） |
| `progress_bar_ink.gd` | 水墨进度条：NinePatch 底 + 填充 + 数值动画 |
| `modal_dialog.gd` | 通用二次确认弹窗 |
| `quantity_picker.gd` | 数量选择（拆分 / 购买） |
| `tooltip_panel.gd` | 统一 Tooltip |

---

## 5.7 数据层：Resource 定义

所有策划数据用 `Resource` + `.tres`，可在编辑器里改、可热重载、可做校验。

```gdscript
# src/core/model/item_data.gd
class_name ItemData
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var quality: Enums.Quality = Enums.Quality.COMMON
@export_multiline var description: String
@export var max_stack: int = 1
@export var sell_price: int = 0
@export var stats: Dictionary = {}        # {"attack": 10, "constitution": 2}
@export var equip_slot: Enums.EquipSlot = Enums.EquipSlot.NONE
```

```gdscript
# src/core/model/skill_data.gd
class_name SkillData
extends Resource

@export var id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var branch: Enums.Branch            # 剑修/法修/丹修/体修
@export var max_level: int = 5
@export var mp_cost: int = 10
@export var cooldown: float = 3.0
@export var damage_ratio: float = 1.2
@export var prerequisites: Array[StringName] = []
```

```gdscript
# src/core/model/enums.gd
class_name Enums

enum Quality  { COMMON, SPIRIT, MYSTIC, EARTH, HEAVEN, IMMORTAL }
enum EquipSlot{ NONE, WEAPON, HAT, ARMOR, ACCESSORY, SHOES, NECKLACE }
enum Branch   { SWORD, SPELL, ALCHEMY, BODY }
enum QuestType{ MAIN, SIDE, DAILY, ENCOUNTER }
enum Currency { COPPER, SPIRIT_STONE, IMMORTAL_JADE }
```

### Database（资源索引）

```gdscript
# src/autoload/database.gd
extends Node

var items: Dictionary = {}      # StringName -> ItemData

func _ready() -> void:
_load_dir("res://data/items", items)
# 校验：id 唯一、图标非空

func _load_dir(path: String, target: Dictionary) -> void:
for f in DirAccess.get_files_at(path):
if f.ends_with(".tres"):
var res := load(path.path_join(f))
target[res.id] = res
```

---

## 5.8 存档与"伪联网"

### SaveSystem

```gdscript
const SAVE_PATH := "user://saves/slot_%d.json"
const SAVE_VERSION := 1

func save(slot: int) -> void:
var data := {
"version": SAVE_VERSION,
"player": Services.character.serialize(),
"inventory": Services.inventory.serialize(),
"quests": Services.quest.serialize(),
"cultivation": Services.cultivation.serialize(),
"world": Services.world_map.serialize(),
}
var f := FileAccess.open(SAVE_PATH % slot, FileAccess.WRITE)
f.store_string(JSON.stringify(data, "\t"))
```

- 格式：JSON（便于调试）；敏感字段可加校验和。
- **版本迁移**：`_migrate(data)` 按 `version` 逐级升级，禁止直接改字段名。
- 自动存档：切换场景、完成任务、境界突破时。

### 单机版的"联网"服务

拍卖行 / 商城 / 聊天在单机版需**本地模拟**，但接口必须按联网设计，方便后续替换：

```gdscript
# src/core/services/backend.gd
class_name Backend
extends RefCounted

func fetch_auctions() -> Array:       return []      # 返回 AuctionEntry 列表
func place_bid(entry_id: int, price: int) -> bool: return false
func list_item(item_uid: int, price: int, hours: int) -> bool: return false

# --- src/core/services/local_backend.gd ---  单机模拟
# --- src/core/services/remote_backend.gd --- 未来 HTTP/WebSocket 实现
```

`LocalBackend` 定时器每 30–90 秒伪造一条竞争者出价，按 02 章 2.10 规则结算。

---

## 5.9 输入映射

在 `project.godot` 的 `InputMap` 中定义（禁止在代码里硬编码键位）：

| Action | 默认键位 | 说明 |
|---|---|---|
| `move_up/down/left/right` | `W A S D` + 方向键 | 移动 |
| `attack` | `Space` / 鼠标左键 | 普攻 |
| `skill_1` … `skill_8` | `1` … `8` | 技能 |
| `interact` | `F` | 交互 / 拾取 |
| `ui_inventory` | `B` | 背包 |
| `ui_character` | `C` | 角色 |
| `ui_quest` | `Q` | 任务 |
| `ui_skill` | `K` | 功法 |
| `ui_map` | `M` | 大地图 |
| `ui_cancel` | `Esc` | 关闭 / 暂停 |

> 技能快捷键与文本输入冲突：打开输入框时 `UIManager` 需把 `skill_*` 置为 disabled。

---

## 5.10 分辨率适配

```ini
# project.godot
[display]
window/size/viewport_width      = 1920
window/size/viewport_height     = 1080
window/stretch/mode             = "canvas_items"
window/stretch/aspect           = "expand"
window/stretch/scale_mode       = "fractional"
```

- `canvas_items` + `expand`：UI 跟随分辨率缩放，宽屏多出的空间交给锚点（见 04 章分区）。
- 所有 UI 根节点使用 `anchors_preset` + `offset`，**禁止使用绝对 position 写死坐标**。
- 字体：`FontFile` 开启 `msdf` 或 `multichannel_signed_distance_field` 以保证任意缩放清晰；
  小字号（≤20px）使用普通位图渲染以避免 MSDF 发虚。

---

## 5.11 性能预算

| 指标 | 目标（PC） | 说明 |
|---|---|---|
| 帧率 | 60 FPS（战斗）/ 30 FPS（安全） | 2D 场景应轻松达标 |
| UI Draw Call | ≤ 60 | 合图集 + 复用材质 |
| 单屏节点数 | ≤ 1500 | 背包 30 格 + 详情，注意 `Container` 嵌套 |
| 纹理内存 | ≤ 256 MB | 素材按需加载，非当前界面 `unload` |
| 场景切换 | ≤ 2s | 异步加载 + 加载页 |
| 启动到登录 | ≤ 3s | autoload 不要做重活 |

**优化要点**

- 物品格子、任务列表等重复元素用**对象池**复用（`ItemSlot` 池化）。
- 拍卖行等长列表：分页（≤20 行/页）而非一次性实例化 1000 行。
- 界面关闭时 `queue_free()` 而不只是 `hide()`，避免常驻内存（HUD 除外）。

---

## 5.12 代码规范

| 项 | 约定 |
|---|---|
| 文件命名 | `snake_case.gd`，与 `class_name` 分离（`inventory_service.gd` → `InventoryService`） |
| 类命名 | `PascalCase` |
| 变量 / 函数 | `snake_case` |
| 常量 / 枚举 | `UPPER_SNAKE` |
| 信号 | 过去式或名词：`item_gained`、`inventory_changed` |
| 私有成员 | 前缀 `_` |
| 类型 | **必须显式标注**（`var a: int = 0`、`func f() -> void:`） |
| 空实现 | 用 `pass`，不留空块 |
| 断言 | 参数校验用 `assert()`，用户输入错误用 `push_warning` |

```gdscript
# 推荐
func add_item(item_id: StringName, amount: int = 1) -> bool:
assert(amount > 0, "amount must be positive")
var data: ItemData = Database.items.get(item_id)
if data == null:
push_warning("unknown item: %s" % item_id)
return false
...
```

---

## 5.13 与文档的对应关系

| 本文档章节 | 对应开发动作 | 关联文档 |
|---|---|---|
| 5.2 目录结构 | 初始化工程 | 07 阶段 P0 |
| 5.4 Autoload | `src/autoload/*` | 08 通用任务 |
| 5.6 UI 框架 | `src/ui/framework/*`、`widgets/*` | 08 通用任务 |
| 5.7 数据层 | `src/core/model/*`、`data/*` | 02 各系统 |
| 5.8 存档 | `SaveSystem` | 08 通用任务 |
| 5.10 适配 | `project.godot` 配置 | 04 各界面验收 |

---

## 5.14 待确认的技术风险

| # | 风险 | 影响 | 对策 |
|---|---|---|---|
| T1 | 素材无透明通道（见 06.8） | 无法直接使用 | 二值化/抠图预处理，或向设计方索要带 alpha 的导出 |
| T2 | `icons/function`、`icons/item` 目录为空 | 16+6 个图标缺失 | 从 `raw-png/` 重裁，或补齐素材 |
| T3 | 是否联网 | 架构差异大 | 先做 `Backend` 抽象层（5.8），延迟决策 |
| T4 | `progress_bar_ink` 在低分辨率下九宫格变形 | 视觉走样 | 03.7 边距需逐张实测 |
| T5 | 字体 MSDF 在小字号发虚 | 可读性 | 小字号用位图渲染，或改用更大字号 |