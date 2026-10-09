# handoff — 跨机器开发交接

> 最后更新：2026-10-08 @ dev（灵植经营模块立项，总规划落地）。
> 交接对象：新机器上的开发者或 AI 会话。
> **开工前必读：§2 新机器清单 → §6 命令自检；现行主线是种植模块，先读 [docs/farming/master-plan.md](docs/farming/master-plan.md)；改 demo 地图前必读 [docs/map-schema.md](docs/map-schema.md)。**

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
5. 首次运行 `test.bat`：仅执行当前种植模块的资产QC、工具测试和农场流程测试；
   **预期输出 FARMING TEST SUITE OK**；`play.bat --selftest`可只跑农场逻辑。
6. 运行 `play.bat`或Godot F5默认主场景进入当前农场；旧演示通过`play.bat demo`显式进入。

## 3. 当前状态

- **P0–P4 全部完成**（阶段详情与验收记录见 [docs/demo-phases.md](docs/demo-phases.md) §3）：
  - P0 内核 MVP（网格地图/行走精灵/对话/双图切换）
  - P1 数据外置 + 烘焙管线（JSON 源数据 → bake 校验/规范化/manifest → 运行时只读）
  - P2 主题包换肤（palette_overrides + per-tile 绘制风格；同布局多主题已验证）
  - P3 类型化交互点（dialogue/menu/chest/battle/save；接缝信号 menu_command、battle_requested）
  - P4 野外场景（wilds 主题 + 40×30 滚动图 + 明雷遭遇 + 跨主题门户/换装）
- 内核需求 **R1–R9 全部验证**（demo-phases.md §2 的表格）
- 内容规模：3 主题 × 5 地图（大厅/后廊/储物间/坊市/荒地）、14 门户
- **2026-10-08 立项转向：灵植经营模块（种植系统）从零重构**，总规划见
  [docs/farming/master-plan.md](docs/farming/master-plan.md)（唯一权威）：
  - 完全放弃旧经营地基（最近一次提交的 Blender 管线实验）——**已于 2026-10-08 归档至
    `archive/old-farming/`**（Phase 0 任务 0.1 完成：引用复核零依赖、selftest 复核通过），
    **禁止作为新模块依赖**；新模块规范见 phase-00 §4
  - 保留复用：bake 纪律、自测/截图基建、QC 铁律、地图内核（作为「游戏侧」对接面）
  - **Phase 0 已完成（2026-10-08 关闭）**：D1=tile 64×64 冻结、美术规范冻结
    （phase-00 §4）、拼接验证场景落地；详情与已知坑见
    [phase-00](docs/farming/phase-00-技术基线与重构准备.md) §7/§8
  - **Phase 1 已完成（2026-10-08 关闭）**：地形分层栈（草/泥/石板 + 动态耕地）+
    LandGrid 状态/原子占用模型 + 增量渲染 + 纯逻辑存档；过渡边缘观感问题挂起
    （P1-C，待 AI 素材替换时统一处理）
  - **Phase 2 已完成（2026-10-08 关闭）**：时间体系（24 时节×15 天×24 行动点，
    AP 归零自动次日）+ 作物生命周期（GROWING/MATURE/REGROWING/EXHAUSTED，
    有限次再生+枯竭清理）+ 多素材产出（确定性掷量）+ 库存 + 存档 v2；
    farmtest 40 项全过（详见 [phase-02](docs/farming/phase-02-核心种植系统.md)）
  - 当前：**Phase 3 第一阶段工具完成，待正式图回传** → [phase-03-AI作物资产管线.md](docs/farming/phase-03-AI作物资产管线.md)
    （资产契约/采购单 manifest 协议/QC 工具/AI 生成工作流/正式素材替换 + P1-C 处理；
    执行前提：ComfyUI 出图机可用）
- demo 实验的 P5/P6 **暂缓**（P5 跨机器出图协作模式由种植模块 Phase 3 继承）
- 开放问题（命名/持久化深度/战斗桩深度）见 demo-phases.md §6，均给了默认值，不阻塞

## 4. 文档地图

| 文档 | 内容 | 何时读 |
|------|------|--------|
| [docs/farming/master-plan.md](docs/farming/master-plan.md) | **灵植经营模块总 Phase 规划（现行主线）** | **开工先读** |
| [docs/demo-phases.md](docs/demo-phases.md) | demo 实验阶段规划与验收记录（P0–P4） | 内核/工作流背景 |
| [docs/map-schema.md](docs/map-schema.md) | 地图/主题数据格式 + bake 流程 | **改 demo 地图/改主题前** |
| [docs/assets-spec.md](docs/assets-spec.md) | 美术资产规格（ComfyUI 对接） | demo 美术回填时；种植模块美术规范以 Phase 0/3 新产出为准 |
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
play.bat                        # 当前农场（默认主场景）
test.bat                        # 当前农场：资产QC + 工具测试 + 游戏流程（不运行旧内容）
play.bat --selftest             # 仅农场逻辑测试（headless）
play.bat --shots=DIR            # 当前农场截图
play.bat demo wilds             # 旧商场/野外演示，显式入口
play.bat demo --selftest         # 旧演示测试，按需单独运行

python tools/bake_maps.py               # 烘焙（改 content/ 后必跑；校验失败即退出）
python tools/gen_placeholder_assets.py  # 重新生成占位美术（读 themes/*.json 色板）

# —— 种植模块（farming）——
python tools/farming/bake_farm.py          # 种植数据烘焙（改 content/farming/ 后必跑）
python tools/farming/gen_farm_terrains.py  # 重生成地形占位纹理（--verify 只校验）
python tools/farming/gen_farm_crops.py     # 重生成作物占位阶段图（--verify 只校验）
python tools/farming/gen_asset_manifest.py # 资产采购单（改数据/交付资产后重跑；--missing 查缺）
python tools/farming/gen_farm_terrains.py --transitions-only # 正式地面回传后仅重建 atlas（不覆盖 ground）
python tools/farming/qc_assets.py --target all # 正式资产统一检查（占位差异见 art-pipeline.md）
python tools/farming/build_art_handoff.py --batch ground --output .art-work/handoff/ground # 空输出目录
play.bat farm                              # 主农场场景（开垦/种植/采收/存档）
play.bat farm --farmtest                   # 种植逻辑自测（40 项）
play.bat farm0                             # Phase 0 拼接验证场景（历史回归）
```

**纪律：改 `content/` 源数据后先 bake 再跑自测/游戏**（自测读的是烘焙产物）。
改 `assets/` 贴图后，编辑器打开会自动重导入；纯命令行场景跑一次
`godot --headless --path . --import`。

## 7. 下一步：种植模块 Phase 3（AI 作物资产管线）

**Phase 0/1/2 均已于 2026-10-08 关闭**（验收记录见
[phase-00](docs/farming/phase-00-技术基线与重构准备.md) /
[phase-01](docs/farming/phase-01-地形与土地系统.md) /
[phase-02](docs/farming/phase-02-核心种植系统.md)）。下一步按总规划
[master-plan §六](docs/farming/master-plan.md) 展开
`docs/farming/phase-03-AI作物资产管线.md`（资产契约 / manifest 采购单协议 /
`qc_assets.py` / AI 生成工作流与 style-sheet / 正式素材替换——**含 P1-C 过渡观感
挂起项**；跨机器 ComfyUI 出图协作模式在本阶段落地，继承 demo P5 设想）。

已冻结基线（后续阶段直接遵守）：

- tile **64×64**；分层地形栈 + 自研 bitmask 过渡（`trans_upper_*`）；美术规范
  phase-00 §4 + 素材替换契约 phase-01 §2.6（**占位图将被 AI 正式图同名替换**；
  逻辑零像素依赖；替换后必跑 QC → farmtest → 截图核对）
- `LandGrid`（WILD/TILLED/PLANTED/OCCUPIED-prev/UNAVAILABLE + 原子多格占用 +
  增量信号）与 `CropManager`（GROWING/MATURE/REGROWING/EXHAUSTED、
  harvest_items 多产出、max_harvests 有限采收、(uid,count) 确定性掷量）+
  `FarmClock`（24 时节×15 天×24AP，day_changed 离散推进）
- 数据纪律：`content/farming/` 源 JSON → `bake_farm.py` → `baked/`（运行时唯一读取）

原 demo P5（美术回填演练）暂缓；其跨机器出图协作模式
（manifest → ComfyUI 出图 → 本机 QC → 零代码替换）由种植模块 Phase 3 资产管线继承，
届时在 `docs/farming/` 下另立资产规范文档。

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

1. 先读本文档 + docs/farming/master-plan.md（现行主线），然后跑 `test.bat` 确认种植模块基线；详见`docs/farming/testing.md`
2. 一切地图/主题修改走「源 JSON → bake → 验证」流程，禁止手改 `content/baked/`
3. 保持实验边界：不接 daoyan、不做存档完整方案、不部署本地 ComfyUI（见 demo-phases §5）
4. 提交纪律：**每个小阶段（任务级）完成即 git 提交**，不等整个 Phase 收尾；
   Phase 级收尾另加：自测全过 + 截图人工核对 + 验收记录勾选
5. 种植模块一切以 master-plan.md 为准：一次只展开当前 Phase；旧经营地基
   （Blender 管线实验文件，见 master-plan 附录 A.3）仅作参考，禁止作为新模块依赖
