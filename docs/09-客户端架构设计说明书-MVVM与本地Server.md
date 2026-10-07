# 09 · 客户端架构设计说明书 —— MVVM 数据驱动 + 本地数据 Server

> 依据：`design/ui-design-showcase/仙途-UI设计稿.html`（11 界面）、`docs/05-Godot技术方案.md`。
> 本文是 `apps/client` 全部 UI 与服务端代码的设计依据。

---

## 1. 目标与约束

| 约束 | 落地方式 |
|---|---|
| MVVM 数据驱动视图 | View 只绑定 ViewModel 信号；ViewModel 持有界面状态；**UI 禁止直接读服务端状态** |
| 本地数据 Server 层（为联机做准备） | 请求-响应 + 推送的 RPC 模型；传输层接口化（`LocalTransport` / 未来 `RemoteTransport`） |
| 服务层与 UI 分层 | UI 层（`src/ui/**`）与服务层（`src/server/**`）物理隔离，仅通过 `GameServer.request()` 通信 |
| 所有 id 用 ULID | 运行时实体（账号/角色/物品实例/任务实例/挂单/出价/聊天/记录）一律 `Ulid.new_id()` |
| 数据体用 `body` 字段 | RPC 信封 `{code, msg, body}`；推送体、存档体同规；**全工程禁用 `data` 作数据体字段名** |
| 单文件 ≤ 300 行 | 按域拆分：每界面 View+VM 两个文件；服务端按域拆 Handler；模板数据按表拆文件 |

## 2. 分层与数据流

```
┌────────────────────────────────────────────────────────────┐
│ View  src/ui/screens/**.gd                                  │
│   纯展示与输入转发。构建控件树、订阅 VM 信号、调 VM 方法。      │
├────────────────────────────────────────────────────────────┤
│ ViewModel  src/ui/screens/**_vm.gd（基类 framework/view_model.gd）
│   持有可绑定属性；await GameServer.request()；解析 body；     │
│   订阅推送（chat.msg / auction.updated / char.state …）。    │
├────────────────────────────────────────────────────────────┤
│ ServerClient  src/autoload/game_server.gd（autoload）        │
│   request(route, body) -> {code, msg, body}；                │
│   pushed(route, body) 信号；推送订阅管理。                    │
├────────────────────────────────────────────────────────────┤
│ Transport  src/server/transport/                             │
│   LocalTransport：进程内直调 LocalServer（可注入模拟延迟）。   │
│   RemoteTransport（预留）：WebSocket/HTTP，信封协议不变。      │
├────────────────────────────────────────────────────────────┤
│ LocalServer  src/server/local/                               │
│   local_server.gd 路由分发 → handlers/h_*.gd 各域处理；        │
│   server_state.gd 内存状态；storage.gd JSON 存档；db/ 模板表。 │
└────────────────────────────────────────────────────────────┘
```

数据流（单向）：用户输入 → View 方法 → VM 方法 → RPC 请求 → Handler 校验并变更 ServerState → 响应 body → VM 更新属性并发出 `prop_changed` → View 刷新。服务端主动变化（竞拍者出价、世界频道、任务目标推进、属性变化）经 `GameServer.pushed` → VM → View。

## 3. RPC 协议

- 请求：`route: String`（`"域.动作"`），`body: Dictionary`。
- 响应信封：`{"code": int, "msg": String, "body": Dictionary}`，`code == 0` 为成功。
- 推送：`GameServer.pushed(route, body)`，路由约定 `域.事件`。
- 错误码：0 成功；4001 参数非法；4101 未登录；4204 资源不存在；4300 段业务规则（货币不足/背包已满/前置未满足/状态不允许/拍卖已结束/出价过低/境界不足）；5000 内部错误；5002 存档读写失败；5004 未知域；5005 未知动作。

## 4. ULID 约定

- `src/core/util/ulid.gd`：Crockford Base32，26 字符 = 48bit 毫秒时间戳（10 字符）+ 80bit 随机（16 字符，低 16bit 同毫秒内单调递增，保证字典序单调）。
- 运行时实体 id 字段统一命名 `uid`：账号、角色、物品实例、任务实例、挂单、出价、聊天消息、交易记录。
- 静态模板（物品/技能/任务/区域/商品）为策划内容键，用语义 id（如 `item_sword_iron`）；实例持有 `template_id` 引用模板，自身 `uid` 为 ULID。

## 5. 路由表（摘要）

| 域.动作 | 请求 body | 响应 body |
|---|---|---|
| auth.login | account, password | {account_uid, servers} |
| auth.server_list | - | {servers} |
| character.create | name, gender, sect | {character} |
| character.get / character.allocate_point | - / attr | {character} |
| character.breakthrough | - | {character} |
| equip.wear / equip.unequip | uid / slot | {character} |
| inventory.list | category | {items, wallet} |
| inventory.use / drop / split | uid[, count] | {items, wallet} |
| inventory.sort | - | {items} |
| quest.list | - | {accepted, available, done} |
| quest.accept / abandon / track / claim | uid | {…} |
| skill.tree | branch | {nodes, points} |
| skill.learn | skill_id | {nodes, points} |
| shop.list | category, page | {goods, pages} |
| shop.buy | goods_uid, count | {items, wallet} |
| auction.list | tab, filters, page | {rows, pages} |
| auction.bid / list_item / cancel | … | {…} |
| chat.history / chat.send | channel[, text] | {messages} |
| world.map | - | {regions, current} |
| world.travel | region_id | {current} |
| world.kill | monster_name | {quest_push} |

推送：`char.state`、`chat.msg`、`quest.changed`、`auction.updated`、`toast`。

## 6. MVVM 绑定机制

- `ViewModel（RefCounted）`：`_props` 字典 + `prop_changed(prop, value)` 信号；`set_prop` 去重；`watch(prop, callable)` 订阅并立即回放当前值；`request(route, body)` 转发 `GameServer`。
- `UiView（Control）`：持有 VM；`_build()` 构建控件；绑定辅助 `_bind_label / _bind_bar / _bind_visible` 自动连接/断开，View 关闭时统一 `unwatch` 防泄漏。
- 屏幕流转：`SceneRouter` 管理全屏（登录→加载→捏人→世界）；`UiManager` 管理世界之上的面板栈（背包/角色/任务/功法/商城/拍卖/大地图），ESC 按栈顶逐层关闭。

## 7. 错误场景（Error-First）

| 场景 | 处理 |
|---|---|
| Handler 入参缺失/非法 | 4001，msg 带字段名 |
| 未登录调用受保护路由 | 4101 |
| 资源不存在（模板/实例/挂单） | 4204 |
| 业务规则不满足 | 4300 段细分，msg 面向玩家（中文） |
| 存档损坏 | Storage 迁移失败则备份后重置，5002 |
| 远程传输超时/断线（预留） | Transport 抛信封 5100/5101，UI 统一 Toast |
| 客户端重复点击 | VM 侧 `_busy` 防抖，按钮置灰 |

## 8. 素材与主题

- 素材源：`design/ui-assets-pack/extracted/` → 拷贝至 `res://assets/ui/**`、`res://assets/bg/**`。
- `ui_theme.gd` 代码构建 Theme：SystemFont 衬线字体链（Noto Serif SC → SimSun）+ 书法链（Ma Shan Zheng → KaiTi）；色板取 docs/03（宣纸 #F5F0E8、墨 #2C2C2C、朱红 #8B2500、暗金 #B8860B…）。
- 长条素材以 `StyleBoxTexture` 九宫格接入 Button/Panel/LineEdit；品质色六档（凡灵玄地天仙）。

## 9. 测试

- `tests/smoke.gd`：headless 冒烟——逐域调用 handler 主路径与错误路径，断言信封 code。
- `tests/screenshot.gd`：逐界面渲染截图到 `user://shots/`，供人工/自动视觉复核。
