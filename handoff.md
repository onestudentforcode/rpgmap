# handoff — 跨机器开发交接

> 最后更新：2026-10-05 @ `fdbf9c7`（main，已推送 origin）。
> 交接对象：新机器上的开发者或 AI 会话。
> **开工前必读：§2 新机器清单 → §6 命令自检；改地图前必读 [docs/map-schema.md](docs/map-schema.md)。**

## 1. 项目定位（三句话）

1. **rpgmap 是实验沙盒**：验证「tile 网格内核 + 确定性地图工作流」能否支撑两类复用场景——
   星露谷式多城镇（单镇多张功能地图 + 特殊交互点）和野外战斗触发图（地图只抛事件不承载战斗）。
2. **daoyan 接入不是现阶段任务**：`docs/daoyan-reuse-plan.md` + `-answers.md` 是背景资料
   （将来移植的目标形态与接口摸底），实验期间**只读不改** daoyan 仓库。
3. **正式美术由 ComfyUI 生成（另一台机器）**：本机负责规格制定、资产清单（manifest）、
   占位图生成与 QC 验收；美术到位后零代码替换。

## 2. 新机器快速上手（checklist）

1. `git clone https://github.com/onestudentforcode/rpgmap.git`（Windows 环境；脚本为 .bat）
2. 安装 **Godot 4.7.2 stable**（标准版即可；另有 `_console.exe` 后缀版用于看输出，可选）
3. 安装 **Python 3 + Pillow**（仅 `tools/` 脚本需要；无 Pillow 时除资产生成外均可正常开发）
4. 告诉启动脚本引擎路径（二选一）：
   - 设环境变量 `GODOT_EXE` / `GODOT_EXE_CONSOLE` 指向 Godot 可执行文件（推荐）
   - 或直接改 `play.bat` 顶部的默认路径
5. 首次运行 `play.bat --selftest`：Godot 会自动重建 `*.import`（被 gitignore，属正常）；
   **预期输出 SELFTEST OK（35 项）**——这就是基线健全的证明
6. 跑起来看一眼：`play.bat`（暖色百货）、`play.bat dusk`（暮色换肤）、`play.bat wilds`（野外）

## 3. 当前状态

- **P0–P4 全部完成**（阶段详情与验收记录见 [docs/demo-phases.md](docs/demo-phases.md) §3）：
  - P0 内核 MVP（网格地图/行走精灵/对话/双图切换）
  - P1 数据外置 + 烘焙管线（JSON 源数据 → bake 校验/规范化/manifest → 运行时只读）
  - P2 主题包换肤（palette_overrides + per-tile 绘制风格；同布局多主题已验证）
  - P3 类型化交互点（dialogue/menu/chest/battle/save；接缝信号 menu_command、battle_requested）
  - P4 野外场景（wilds 主题 + 40×30 滚动图 + 明雷遭遇 + 跨主题门户/换装）
- 内核需求 **R1–R9 全部验证**（demo-phases.md §2 的表格）
- 内容规模：3 主题 × 5 地图（大厅/后廊/储物间/坊市/荒地）、14 门户
- 待做：**P5 美术回填演练**（见 §7）、**P6 结题**（实验报告 + 移植备忘）
- 开放问题（命名/持久化深度/战斗桩深度）见 demo-phases.md §6，均给了默认值，不阻塞

## 4. 文档地图

| 文档 | 内容 | 何时读 |
|------|------|--------|
| [docs/demo-phases.md](docs/demo-phases.md) | 阶段规划、验收状态、开放问题 | **开工先读** |
| [docs/map-schema.md](docs/map-schema.md) | 地图/主题数据格式 + bake 流程 | **改地图/改主题前** |
| [docs/assets-spec.md](docs/assets-spec.md) | 美术资产规格（ComfyUI 对接） | P5 美术回填时 |
| docs/daoyan-reuse-plan(-answers).md | daoyan 背景与接口摸底 | 仅背景，勿据此实施 |
| [todo.md](todo.md) | P0 历史清单（已全部完成） | 考古 |

## 5. 架构速览

```
content/maps/*.json + content/themes/*.json     ← 唯一事实源（手工维护，进 git）
        │  python tools/bake_maps.py（校验 + 规范化 + manifest）
        ▼
content/baked/<theme>/…                          ← 烘焙产物（生成物，进 git，运行时唯一读取物）
        │  scripts/map_host.gd（加载/构建 TileMapLayer/物件/交互区）
        ▼
scripts/main.gd（状态机：移动/对话/菜单/战斗桩/切图）
```

- `scripts/`：`main.gd` 主控与状态机 + 两条接缝信号（`menu_command`/`battle_requested`，
  正式实现时分别桥接宿主命令分发与战斗入口）；`map_host.gd` 烘焙加载器；
  `player.gd`（含主题换装 retheme）；`dialogue_ui.gd`；`menu_panel.gd`；
  `interactable.gd`（靠近交互区）；`game_state.gd`（消费型状态，进程内，
  **移植时替换为引擎快照字段**）
- `tools/`：`bake_maps.py`（烘焙）；`gen_placeholder_assets.py`（按主题生成占位美术，含 QC）
- `assets/themes/<id>/`：各主题贴图（图集布局全主题一致，只有色板/风格差异）

## 6. 常用命令

```
play.bat                        # 启动（默认主题）
play.bat <theme>                # 主题：placeholder | dusk | wilds
play.bat --selftest             # 35 项逻辑自测（headless 逻辑 + 窗口自绘）
play.bat --shots=DIR            # 窗口截图验收（7 张/城镇主题，4 张/野外主题）

python tools/bake_maps.py               # 烘焙（改 content/ 后必跑；校验失败即退出）
python tools/gen_placeholder_assets.py  # 重新生成占位美术（读 themes/*.json 色板）
```

**纪律：改 `content/` 源数据后先 bake 再跑自测/游戏**（自测读的是烘焙产物）。
改 `assets/` 贴图后，编辑器打开会自动重导入；纯命令行场景跑一次
`godot --headless --path . --import`。

## 7. 下一步：P5 美术回填演练（跨机器协作）

1. **本机（开发机）**：产出移交包——`content/baked/<theme>/manifest.json` 已是现成采购单
   （列出该主题全部图块/物件/区域/尺寸）；补一份逐资产 ComfyUI 提示词建议
2. **ComfyUI 机器**：按 manifest + assets-spec.md 出图（要点：PNG/RGBA、**alpha 只允许
   0/255**、NEAREST 缩放、图集布局与区域坐标严格一致、行走图四方向行脚底对齐）
3. **回到开发机**：覆盖 `assets/themes/<id>/` 同名文件 → 跑自测 + 截图人工核对 →
   零代码零重烘完成替换
4. 待写工具：`tools/qc_assets.py`（对回填图做尺寸/alpha 二值/逐行不透明度/色板检查；
   参考 `gen_placeholder_assets.py` 的 qc 函数）

## 8. 机器相关差异与已知坑

- **引擎路径**：本仓库历史路径（daoyan/.tools/...）只属于旧机器——新机器务必配置 §2.4
- **gitignore 的三类文件**：`*.import`（首次运行自动重建）、`.godot/`（引擎缓存）、
  `.shots/`（截图产物）——clone 后缺失都是正常的
- **占位美术 QC 铁律**（历史上右向行走整行空帧导致"角色凭空消失"的事故，
  见 demo-phases.md P1 修复记录）：alpha 二值、NEAREST、逐行不透明度检查已内置在
  生成器 QC 里；回填正式图时 QC 工具必须同等强度
- **双主题布局一致性自检**（selftest 内）：同一布局被多个主题共享时，改布局会影响
  所有引用主题——这是设计使然，自检失败通常意味着烘焙未重跑
- 对话防误触冷却 60ms、切图门户冷却 400ms：调手感时别把防回弹机制调没（出生格
  必须不压触发格，bake 有校验）

## 9. 新 AI 会话交接边界

1. 先读本文档 + demo-phases.md，然后跑 `play.bat --selftest` 确认基线
2. 一切地图/主题修改走「源 JSON → bake → 验证」流程，禁止手改 `content/baked/`
3. 保持实验边界：不接 daoyan、不做存档完整方案、不部署本地 ComfyUI（见 demo-phases §5）
4. 每个阶段收尾：自测全过 + 截图人工核对 + git 提交（文档同步勾选）
