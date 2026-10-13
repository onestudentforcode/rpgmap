# 当前农场测试与历史入口

> 2026-10-13：P8本地测试阶段已完成；默认`play.bat`/F5为`farm_p8.tscn`。P8使用独立三槽`user://farm_demo_p8_slots`、schema16，V2/V1/V0及历史场景均显式进入。原应用标识保持，旧档不迁移到P8。用户确认页面验收通过，Windows独立包后置。

## 日常流程

```powershell
.\play.bat                        # P8生态经营、新手手册、独立三槽
.\play.bat --selftest             # P8源码隔离冒烟（20项）
.\test-p8.bat                      # P8编译/配数/模型/手册/源码检查
.\test.bat                        # 资产、工具及V0/V1/V2/P8完整回归
.\play.bat v2                     # 历史V2及其独立档案
.\play.bat v1                     # 历史V1及其独立档案
.\play.bat v0                     # 历史V0菜单
.\play.bat farm --farmtest         # V0种植/经济/存档逻辑回归
.\play.bat farm0 --farmtest        # 历史phase00自测
.\play.bat demo --selftest         # 历史地图demo自测
.\play.bat --shots=res://.shots/p8-current
```

`test.bat`运行资产QC、Python工具/配置测试、V0流程、完整V1模型/UI、完整V2模型/双45日/控件/源码冒烟，以及P8开发门禁，成功输出`FARMING TEST SUITE OK`。单独的phase00/demo历史测试按上述入口运行，玩家经营流程不加载这些场景。

## 当前验收与证据

| 范围 | 实际证据 |
|---|---|
| P8配数与模型 | 15项配数，A77/B98/C85/D190/E89/F92/G116/H60，共807项模型 |
| P8界面/手册 | 20项源码启动检查、73项真实控件事件、手册导出一致性；2560×1440/100%四章滚动截图；用户确认页面通过 |
| P8经营 | 两独立新档各120日、918项检查、27条新工艺每路线收取及全部产物后续消费，严格独立审计；冻结证据`.art-work/p8h-final2/` |
| V2 | P7模型331项、阶段正常回放、双45日、19项控件、14项源码冒烟 |
| V1/V0与历史 | 完整V1模型/UI/12项源码冒烟、V0 `FARMTEST OK`，历史phase00 `FARMTEST OK`及demo `SELFTEST OK` |
| 本地入口 | `play.bat --selftest`与项目默认主场景分别通过20项P8源码冒烟 |

2026-10-13最终日志在`.art-work/p8-close/`；完整套件和入口/历史日志已检查退出码、成功标记和原始错误输出。用户页面接受与代理实际执行证据分开，代理未执行完整原生桌面鼠标/窗口焦点流程；P8 Windows发行产物也未制作或验证，两者不作为本地阶段关闭条件。

经营重放按需执行`test-p8.bat -IncludePlaytest`，重新生成当前版本证据及审计；本轮说明/默认入口收尾没有重复120日回放，也不修改先前冻结manifest。Godot错误可能返回0，读取日志并核对标记同样必要。受限Windows环境可用`tools/farming/test_p8.ps1 -WorkspaceStores`：只替换测试槽到工作区，并仅豁免固定系统证书库诊断，不豁免脚本或其他引擎错误。

后续按实际变更选择检查，不无依据反复全套回放。测试使用隔离槽，历史场景与发行工具继续保留显式入口。

## 历史V0流程与专项入口（参考）

游戏流程覆盖土地开垦、播种扣种与占格、生长、凝露草一次采收、赤纹果有限再生/枯竭/清理、
库存与时间推进、存档恢复；Phase 4新增介质/B键、混合介质拒绝、多格树木/真菌隔离fixture与旧存档恢复检查。
Phase 4.b另有真实果树/月华菇操作、产物入库、存读档、锚点和耕地渲染回归；
截图新增四类并排、果树阶段和采后菌床，供结构验收。
Phase 5增加19项经济核心检查与11项真实闭环/存档迁移检查；含指定成功行为与每日扣饱食度、
五行匹配、交易失败零变更、生产材料消耗、面板无AP交易/喂养及旧schema2默认经济迁移。
原有40项基础检查保留，Phase4介质夹具补所需材料。
P6.a增加30项三槽/快照检查：槽位会话隔离、确认覆盖/删除、schema2/3导入、占地与作物一致性、
校验和、临时文件/目录/替换失败、备份恢复、损坏快照加载零变更及扩展状态保留。
只操作`user://farm_phase06_slot_tests_<唯一编号>`目录，结束后清理，不接触玩家存档。
独立检查使用`--headless --path . --script scripts/farming/tests/run_phase06_slots.gd`，输出`PHASE06 SLOT TEST OK`。
P6.b增加26项真实菜单/自动存档/退出检查，使用`user://farm_phase06_demo_tests_<编号>`测试槽。
覆盖最后1AP的播种/采收/开垦/介质/清理、保存失败不退出及重试不多过日、退出取消/放弃、
覆盖/删除/导入和F5/F9不触发玩家存读。独立入口为`run_phase06_demo.gd`，输出`PHASE06 DEMO TEST OK`。
P6.c增加25项经营记录检查，使用专用测试槽：成功播种/收获/买卖/喂养、多格树与再生、44/45/46天边界、最后1AP、冻结读档重看、放弃当天回退、保存退出与正常过日失败重试、旧档45天区间、损坏统计拒绝。
独立入口为`run_phase06_records.gd`；通过时输出`PHASE06 RECORDS TEST OK`。
不加载旧商场/野外演示或Phase 0验证场景。
逻辑测试使用headless和独立测试存档；截图是单独的视觉验证流程。
现有色板精确值越界告警保留，QC错误才阻断。

Phase 4正式图完成后，可单独运行GPU前后遮挡检查（需要渲染窗口，不能加`--headless`）：

```powershell
& $env:GODOT_EXE_CONSOLE --path . --script scripts/farming/tests/phase04_depth.gd
```

应输出`DEPTH CHECK behind=true front=true`；截图写入`.shots/farm-phase04c-final/`。
该检查使用真实CropRenderer和重叠标记，不加载历史场景，也不写玩家存档。

Phase 5界面预览（不写玩家存档，必须带`--fresh`）：

```powershell
& $env:GODOT_EXE_CONSOLE --path . --script scripts/farming/tests/phase05_preview.gd -- --fresh
```

截图输出`.shots/farm-phase05/market-hungry.png`与`market-fed.png`；游戏中M打开/关闭集市，Esc关闭。
界面优化后另有`inventory.png`、`market-trade.png`、`market-bulk.png`和`hud.png`。
预览验证弹窗暂停/恢复相机、逻辑视口边界、数量×5快捷键和工具按钮选择；成功输出`UI PREVIEW OK`。
仅跑经济核心可用`--headless --path . --script scripts/farming/tests/run_phase05.gd`。

兼容`play.bat farm --farmtest`、`play.bat farm --farm-shots=DIR`。
农场直接运行也接受`--selftest`和`--shots`别名；截图参数支持等号形式及shell拆分后的两项形式。
同时传测试与截图参数时只执行测试，避免两个流程竞态退出。
缺失正式资产时启动报错，不自动生成占位图覆盖正式资产。

Demo菜单预览：

```powershell
& $env:GODOT_EXE_CONSOLE --path . --script scripts/farming/tests/phase06_preview.gd
```

输出`DEMO PREVIEW OK`，截图位于`.shots/farm-phase06b/`。脚本只创建测试槽，结束后清理。
`play.bat farm --fresh`为无存档的开发预览，不能用于继续玩家进度。
当前玩家只通过每日结束自动存档与菜单选择继续；F5/F9和手动存读按钮均已移除。

## 历史内容按需运行

```powershell
.\play.bat demo                   # 旧商场演示
.\play.bat demo wilds             # 旧野外演示
.\play.bat demo --selftest         # 旧demo内核测试
.\play.bat farm0 --farmtest        # 历史Phase 0拼接测试
```

旧场景和测试保留为独立入口；只有修改旧内容或共享内核时才单独运行，
不再混入当前游戏流程验收。旧的`play.bat wilds/dusk`改为`play.bat demo wilds/dusk`。
历史执行记录里的旧测试命令仅说明当时结果；现行入口以本文为准。

## 首轮回顾截图验收

运行`--path . --script scripts/farming/tests/phase06_records_preview.gd`（GPU模式，不加headless）。
输出`RECORDS PREVIEW OK`，截图位于`.shots/farm-phase06c/`：进行中的经营记录、已冻结回顾和滚动明细。
三张界面均在640×360逻辑视口内，继续经营按钮始终可见；预览只写专用测试目录，结束后清理。

## 高级工具与范围操作验收

P6.d新增28项真实操作检查：购买与重复/余额校验、等级切换、三个栏位、中心范围和边缘、1/2/3/9次AP取整、普通单目标、高级不恢复耕地、双击第二事件、种子不足、AP不足不跨日续做、末AP完整自动档、混合介质、多格树播种/采收/清理去重、种子选择恢复与槽隔离。价格配置新增2项Python检查。
独立逻辑入口为`--headless --path . --script scripts/farming/tests/run_phase06_tools.gd`，输出`PHASE06 TOOLS TEST OK`。
GPU界面入口为`--path . --script scripts/farming/tests/phase06_tools_preview.gd`，输出`TOOLS PREVIEW OK`；五张截图位于`.shots/farm-phase06d/`。两个入口仅操作各自测试槽目录并清理，不能用来继续玩家存档。

## 教学与显示设置验收

P6.e新增28项真实流程检查：鼠标选择工具/选种、成功开地/播种、休息生长、采收、出售和饥饿喂养；失败不推进、重看不改资源、跳过隐藏提示、日存档恢复、放弃当天回退、槽间教学隔离、非法步骤拒绝；全局设置独立存储、重启读取、非法值/写入失败/损坏处理、菜单应用与FPS切换、输入恢复。
独立入口为`--headless --path . --script scripts/farming/tests/run_phase06_experience.gd`，输出`PHASE06 EXPERIENCE TEST OK`。
GPU入口为`--path . --script scripts/farming/tests/phase06_experience_preview.gd`，输出`EXPERIENCE PREVIEW OK`。八张截图位于`.shots/farm-phase06e/`，实测960/1280/1920窗口、全屏往返与帧率/FPS。该入口只改变测试进程自身显示，并创建/清理测试设置和槽目录，不操作玩家配置。

## 45天经营与独立发布验收

P6.f另有12项固定策略经营检查：正式初始资源、45个日存档与15/30天恢复、四类作物闭环、独立账本与六项回顾统计、期末余额、三工具投资和冻结报告持久化。入口为`--headless --path . --script scripts/farming/tests/phase06_playtest.gd`，成功输出`45 DAY PLAYTEST OK`；默认报告在`.art-work/phase06-playtest.json`。GPU截图不加headless并追加`--playtest-shots=res://.shots/farm-phase06f`。

`tools/farming/build_demo.ps1 -GodotExe <控制台引擎路径>`导出并等待实际release程序通过8项检查才打包，必须安装同版本Windows release模板。可单独运行导出程序的`-- --demo-smoke`，配`--headless --log-file <绝对日志路径>`；成功标记为`DEMO RELEASE SMOKE OK`，失败退出码为1。不要把GUI程序启动成功或PowerShell未等待的退出码当作检查结果。

发布检查覆盖旧场景/开发测试排除、JSON与60元石新槽、27张正式纹理解码、种植收获出售、钱包/工具自动存档及显示设置；使用唯一隔离目录并清理。GPU不加headless，追加`--smoke-shots=<绝对目录>`，审核真实发布程序的菜单、教学农场和设置。详细结果与限制见[45天试玩记录](phase06-playtest.md)。这是V0历史发行验收；较长试玩与导出按发布需要显式运行，当前日常测试组成见本文开头。


## Phase 6.5界面验收

新增`run_v1_phase65_ui.gd`的79项检查，原派工/报告界面调整后51项；两者使用临时槽与设置。覆盖数量交易、余额/库存不足、只读框选/建设预览、重复放置、清理/拆除/覆盖取消、确认期间阻断、模态/文本输入阻断、单个负责区域删除/定位、实时重排、4分辨率×3UI缩放、设置持久化/损坏及日存档失败原样重试。矢量QC由`test_ui_assets.py`检查ID覆盖、SVG尺寸/本地内容与10工具形状区分；发行冒烟解码所有58个符号并核对应用标识，源码12/独立包13项。

GPU截图入口：`--v1-shots=<目录> --shot-size=2560x1440 --ui-scale=100`（与引擎`--resolution 2560x1440`配合）。只操作独立预览槽，输出18页与`dimensions.json`；100/125/150%及2560/1920/1280/960四档结果保留`.art-work/phase65-*`。世界模型中的45天路线继续使用原`run_v1_journal.gd`，不把界面图例注入材料的截图夹具当经济验收。
