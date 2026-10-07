# 仙途 · 游戏客户端（apps/client）

古风水墨修仙 MMO 的 Godot 4.7 客户端。依据 `design/ui-design-showcase/仙途-UI设计稿.html` 全套 11 个界面实现，
架构遵循 **MVVM 数据驱动 + 本地数据 Server 分层**（设计说明书见 `docs/09-客户端架构设计说明书-MVVM与本地Server.md`）。

## 运行

```bash
# 编辑器打开
godot --path apps/client

# 直接运行游戏（登录 → 加载 → 捏人 → 世界）
godot --path apps/client
```

## 测试

```bash
# 服务端全域冒烟测试（49 项断言，headless）
godot --headless --path apps/client res://tests/smoke.tscn

# 11 个界面截图自检（输出 user://shots/*.png）
godot --path apps/client res://tests/screenshot.tscn
```

两个脚本均自动备份/恢复真实存档（user://saves/slot_1.json），不会污染游戏进度。

## 架构分层（自上而下）

```
View        src/ui/screens/**_view.gd     纯展示与输入转发，绑定 VM 属性
ViewModel   src/ui/screens/**_vm.gd       界面状态 + rpc_body() 调服务端
ServerClient src/autoload/game_server.gd  request(route, body) + pushed 信号
Transport   src/server/transport/         LocalTransport（进程内）｜RemoteTransport（云端预留）
LocalServer src/server/local/             路由分发 → 9 域 Handler → ServerState → JSON 存档
```

- **数据体一律用 `body` 字段**：RPC 信封 `{code, msg, body}`、推送体、存档 `{version, body}`，全工程禁用 `data` 字段。
- **运行时实体 id 一律 ULID**（`src/core/util/ulid.gd`，26 位 Crockford Base32，同毫秒单调）：账号/角色/物品实例/任务实例/挂单/聊天消息；静态模板表用语义 id（策划内容键）。
- **联机准备**：未来实现 `RemoteTransport`（WebSocket 同信封协议）替换 `LocalTransport` 即可，UI 与 ViewModel 零改动；拍卖行/聊天已带 `bot_tick` 世界模拟与推送。

## 界面清单（对应设计稿）

| 界面 | 路径 | 要点 |
|---|---|---|
| UI-01 登录 | `src/ui/screens/login/` | 卷轴面板、服务器下拉、记住账号、面板内红字报错 |
| UI-02 加载 | `src/ui/screens/loading/` | 线程加载真实进度、太极旋转、贴士轮换 |
| UI-11 捏人 | `src/ui/screens/char_create/` | 性别/门派/体型/面容/发型/服饰、重设二次确认 |
| UI-03 世界 HUD | `src/ui/screens/world/` | 状态栏/小地图/聊天/8 格技能栏(冷却扇形)/系统菜单 |
| UI-04 乾坤袋 | `src/ui/screens/inventory/` | 5×6 网格、品质边框、使用/丢弃/整理/拆分 |
| UI-05 角色档案 | `src/ui/screens/character/` | 立绘+6 装备槽、修为条、双列属性、五维加点 |
| UI-06 任务录 | `src/ui/screens/quest/` | 三页签、目标勾选、追踪(单条)、交付 |
| UI-10 功法图谱 | `src/ui/screens/skill_tree/` | 四系 3×5 节点、前置墨线(实/虚)、修炼 |
| UI-08 世界地图 | `src/ui/screens/world_map/` | 卷轴全图、拖拽/滚轮缩放(鼠标锚点)、传送确认 |
| UI-07 聚宝阁 | `src/ui/screens/shop/` | 7 分类、4×3 分页、热卖角标、限时倒计时 |
| UI-09 拍卖行 | `src/ui/screens/auction/` | 四页签、筛选搜索防抖、出价(≥1.05 倍)、上架/下架、到期结算 |

## 操作键位

`WASD` 移动 · `1-8` 技能 · `Space` 普攻 · `B/C/Q/K/M` 背包/角色/任务/功法/地图 · `ESC` 逐层关闭面板

## 已知边界

- 素材来自 `design/ui-assets-pack/extracted/`（114 张，已拷贝至 `assets/`）；`icons/bag` 数量角标为烘焙内容，仅作展示。
- 字体使用系统字体回退链（Noto Serif SC → SimSun；书法标题 Ma Shan Zheng → KaiTi），未内嵌字体文件。
- 拍卖 NPC 种子挂单/世界频道机器人由 `LocalServer.tick` 每 5 秒模拟；单机存档为 JSON（`user://saves/slot_1.json`）。
