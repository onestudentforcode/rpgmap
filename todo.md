# RPG 网格地图小游戏 — MVP TODO

**参考玩法**：《边狱巴士》（Limbus Company）章节探索关卡（西西弗百货式室内场景）——
网格贴图的地面、俯视角行走精灵在场景中自由移动、靠近场景物件/NPC 后触发交互与对话、
通过特定图格（门/通道）在地图间移动。

**引擎**：Godot 4.7.2（本机已有：
`C:/Users/88445/Desktop/code/daoyan/.tools/godot-4.7.2/engine/Godot_v4.7.2-stable_win64.exe`，
另有 `_console.exe` 版本适合命令行跑日志）。

**关键决策**（MVP 定调，后续可改）：

- 移动方式：键盘**自由移动**（CharacterBody2D + 碰撞），地面网格只是视觉表现——与边狱巴士一致；
  格子步进 / 鼠标点击寻路（AStarGrid2D）列为后续增强，不进 MVP。
- 美术：**正式资产由 ComfyUI 生成**（大图出图 → 切图/缩放 → 色板清理）。
  MVP 开发阶段先用**临时灰盒/色块占位图**跑通管线，资产规格提前定死，
  ComfyUI 出图后按规格直接替换，不动场景。
- 地图：**两张地图**，通过特定图格（门）双向往返，空间上连贯
  （A 图东侧出口 ↔ B 图西侧入口，门的位置在两张图的世界布局里对得上）；
  **场景树中始终只加载当前地图**，切换时旧图释放、新图实例化。
- 尺寸基准：图块 32×32，角色 32×48（脚底为原点锚），窗口 1280×720 + `canvas_items` 拉伸。

---

## 0. 项目初始化

- [x] `project.godot`：创建 Godot 4.7 项目；目录结构 `assets/`（图片）、`scenes/maps/`（地图）、`scenes/`（角色/UI）、`scripts/`、`tools/`
- [x] 像素清晰设置：`rendering/textures/canvas_textures/default_texture_filter = 0`（Nearest）；像素图导入关 mipmap
- [x] 窗口：1280×720，stretch mode = `canvas_items`（不要用 `aspect=expand`，UI 会非等比变形）
- [x] 输入映射：`move_up/down/left/right`（WASD + 方向键）、`interact`（E / 空格 / 鼠标左键）
- [x] 主场景 `scenes/main.tscn` 设为启动场景

## 1. 占位资产与 ComfyUI 资产规格

- [x] 临时占位图（tools/ 脚本生成，纯为开发跑通，随时可弃）：
  - [x] Tileset 色块图集：地砖（网格感）、地毯、墙、柜台、电梯门、货架等 32×32 图块
  - [x] 行走精灵 sprite sheet：下/左/右/上 ×（idle + 3 帧行走），32×48/帧
  - [x] 可交互物件图：告示牌、柜台立面、1 个 NPC 站立图
- [x] 资产规格文档 `docs/assets-spec.md`（给 ComfyUI 出图对接用）：
  尺寸清单（tile 32×32、角色帧 32×48、sprite sheet 排布方式）、命名规则、目录约定、
  出图后处理要求（缩放用 NEAREST、色板数量限制、alpha 无毛边）
- [ ] （ComfyUI 出图后）按规格接入正式资产：仅替换贴图文件，不改场景与代码

## 2. 地图场景 ×2（网格地面 + 碰撞 + 空间连贯）

- [x] TileSet 资源（两图共用一份）：物理碰撞层（墙/柜台不可走）；可选 terrain/autotile 配置方便铺图
- [x] `TileMapLayer` 分层：地面层 → 地毯/装饰层 → 墙体障碍层
- [x] **地图 A「百货大厅」**：入口、中央柜台、货架区、**东墙出口门**（通地图 B）
- [x] **地图 B「后廊/电梯厅」**：**西墙门**（通回大厅）、电梯门、告示牌，边界用墙封死
- [x] 空间连贯要求：两图的门在世界布局上对应——A 东侧门的走向与 B 西侧门衔接，
      玩家穿门后朝向/位置在空间上说得通（从 A 东门出 → 在 B 西门内侧出现，面朝东）
- [x] Y-sort 伪深度：容器 `y_sort_enabled`，物件/角色以**脚底**为排序锚（sprite `offset.y` 使原点在脚底）；
      地面层放 Y-sort 容器外（z_index = -1）

> 实现说明：地图用 ASCII 字符画定义在 `scripts/map_data.gd`，运行时由 `map_builder.gd`
> 构建 TileMapLayer + 物件（改图 = 改字符画，无需在编辑器里手铺）。

## 3. 地图切换（特定图格传送 + 单地图加载）

- [x] 传送点注册表 `scripts/transitions.gd`（数据表）：
      `{ 触发格坐标, 当前地图, 目标地图, 目标出生格, 出生朝向 }`，双向两条记录
      （实际落在 `map_data.gd` 的 `TRANSITIONS` 表中）
- [x] 触发实现：门图格上放 `Area2D` 触发区，玩家进入即请求切换
- [x] 切换流程：淡入遮罩（ColorRect + Tween）→ 释放当前地图节点 →
      实例化目标地图（清空并重填 Ground/Walls/Objects 容器）→ 玩家放到目标出生格 → 淡出
- [x] 加载策略：玩家节点常驻 `main.tscn`（不随地图释放），场景树中**只有一张地图**；
      地图间共享状态（如已对话标记）MVP 先不持久化，回切换地图即重置，可接受
- [x] 防重触发：出生格放在门内侧一格（不压在触发区上），切换后短暂冷却，避免进门瞬间来回横跳

## 4. 玩家行走精灵

- [x] `CharacterBody2D` + `CollisionShape2D`（碰撞盒比格子略窄，便于贴墙走）
- [x] `AnimatedSprite2D` + `SpriteFrames`：四方向行走动画，按移动方向切换；停止即回 idle
- [x] 移动：`move_and_slide()`，速度约 4 格/秒；斜向输入归一化
- [x] 验证：走不出墙、贴墙滑行不卡、动画方向正确

## 5. 相机

- [x] `Camera2D` 挂玩家下，`position_smoothing_enabled = true`
- [x] `limit_*` 随当前地图设置边界（切图时更新），防止看到地图外黑边

## 6. 可交互物件与对话

- [x] `Interactable` 基类（`Area2D`）：`interact_text` 字段 + `interacted` 信号
      （实现为 `display_name`/`pages` 字段，对话由 Main 状态机驱动）
- [x] 交互提示：玩家进入范围时头顶显示 "E" 气泡/物件高亮
- [x] 玩家侧：每帧找范围内最近的可交互物，按 `interact` 触发（移动中不触发）
- [x] 对话框 UI（CanvasLayer）：底部文本框、打字机效果、多页对话（按交互键翻页/关闭）；
      对话时锁玩家移动
- [x] 内容：大厅（告示牌 / 柜台 / NPC）+ 后廊（电梯门 / 告示牌）各有至少 1 段多页对话

## 7. 组装与验收

- [x] `main.tscn` 组装：玩家 + 相机 + UI + 地图容器；进场淡入（简单 ColorRect 动画，加氛围）
- [x] 验收清单：
  - [x] 窗口拉到 960/1400/1920 宽，像素无拉伸变形、UI 位置稳定（`canvas_items`+`keep` 等比拉伸保证；截图 1280×720 已核对）
  - [x] 玩家走不到墙外，四向行走动画正确，停下回 idle
  - [x] 走到物件后被遮挡 / 遮挡物件（Y-sort 生效）
  - [x] 大厅东门 ↔ 后廊西门双向往返正常：出生位置正确、朝向正确、不回弹、不重复触发（自测 + 截图核对）
  - [x] 切图有淡入淡出，切换后场景树中只有当前地图（自测比对两图 tile 数）
  - [x] 两图所有交互点均可触发、可翻页、可关闭，对话中角色不动
  - [x] 相机不出地图边界（两张图各自验证）
- [x] 无头逻辑自测 17 项全过（`--headless -- --selftest`）+ 窗口截图 4 张人工核对（大厅/交互提示/对话/后廊）

---

## MVP 明确不做（Out of scope）

战斗系统、剧情分支、存档、音效/音乐、第三张及更多地图、跨图状态持久化、
鼠标点击寻路、格子步进移动、手柄支持、NPC 巡逻 AI。

## 里程碑顺序

`0 初始化 → 1 占位资产 → 2 双地图 → 3 地图切换 → 4 玩家 → 5 相机 → 6 交互对话 → 7 组装验收`
（1 可与 2/4 并行：先用色块占位跑通场景与切换，ComfyUI 正式图到位后只换贴图）

---

## 构建产物速览（MVP 已完成）

- 运行：Godot 4.7 打开项目按 F5，或 `Godot_v4.7.2-stable_win64_console.exe --path .`
- 操作：WASD/方向键移动，E/空格/左键交互与翻页；走进大厅东门 → 后廊西门往返
- 代码：`scripts/`（main 主控 / map_data 数据 / map_builder 构建器 / player / dialogue_ui / interactable）
- 自测：`--headless -- --selftest`；截图验收：`-- --shots=目录`
- 下一批候选：ComfyUI 正式资产接入 → 第三张地图（二层施工区）→ 交互状态持久化 → 音效
