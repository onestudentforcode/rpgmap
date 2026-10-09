# 当前农场测试与历史入口

2026-10-09起默认启动与测试仅面向当前种植模块。Godot主场景为`farm_main.tscn`；
保留原应用标识与存档目录，已有农场存档不迁移。

## 日常流程

```powershell
.\play.bat                        # 当前农场游戏
.\test.bat                        # 当前模块完整测试
.\play.bat --selftest             # 当前农场逻辑测试
.\play.bat --shots=res://.shots/farm-current
```

`test.bat`依次运行31项资产QC、23项资产/配置工具测试、97项农场游戏流程检查；
任一步失败立即返回非零退出码，成功输出`FARMING TEST SUITE OK`。
游戏流程覆盖土地开垦、播种扣种与占格、生长、凝露草一次采收、赤纹果有限再生/枯竭/清理、
库存与时间推进、存档恢复；Phase 4新增介质/B键、混合介质拒绝、多格树木/真菌隔离fixture与旧存档恢复检查。
Phase 4.b另有真实果树/月华菇操作、产物入库、存读档、锚点和耕地渲染回归；
截图新增四类并排、果树阶段和采后菌床，供结构验收。
Phase 5增加19项经济核心检查与11项真实闭环/存档迁移检查；含指定成功行为与每日扣饱食度、
五行匹配、交易失败零变更、生产材料消耗、面板无AP交易/喂养及旧schema2默认经济迁移。
原有40项基础检查保留，Phase4介质夹具补所需材料。
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
仅跑经济核心可用`--headless --path . --script scripts/farming/tests/run_phase05.gd`。

兼容`play.bat farm --farmtest`、`play.bat farm --farm-shots=DIR`。
农场直接运行也接受`--selftest`和`--shots`别名；截图参数支持等号形式及shell拆分后的两项形式。
同时传测试与截图参数时只执行测试，避免两个流程竞态退出。
缺失正式资产时启动报错，不自动生成占位图覆盖正式资产。

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
