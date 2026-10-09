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

`test.bat`依次运行21项资产QC、16项资产/配置工具测试、农场游戏流程测试；
任一步失败立即返回非零退出码，成功输出`FARMING TEST SUITE OK`。
游戏流程覆盖土地开垦、播种扣种与占格、生长、凝露草一次采收、赤纹果有限再生/枯竭/清理、
库存与时间推进、存档恢复；Phase 4新增介质/B键、混合介质拒绝、多格树木/真菌隔离fixture与旧存档恢复检查。
不加载旧商场/野外演示或Phase 0验证场景。
逻辑测试使用headless和独立测试存档；截图是单独的视觉验证流程。
现有色板精确值越界告警保留，QC错误才阻断。

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
