# P6.f — 45天经营试玩与发布验收

日期：2026-10-10。原始台账：[phase06-playtest.json](phase06-playtest.json)。本轮是自动执行真实操作的固定策略模拟，加人工查看截图；不是人工连续游玩45天，也不是所有经营策略的平衡结论。

## 经营方法与结果

使用正式初始60元石、既有种子和24AP；不注入资源、作物状态或时间。八处种植位置覆盖三株凝露草、两株赤纹果、一株2×2果树和两株菌菇。菌床材料实际购买。成熟即采收，留一份凝露叶，其余食材出售；缺种时购买，留25元石余量购高级工具，仅启用高级采收。第15/30天退出并继续，验证跨时节恢复。

| 植物 | 播种株数 | 收获次数 |
|---|---:|---:|
| 凝露草 | 36 | 33 |
| 赤纹果 | 12 | 32 |
| 青玉果树 | 3 | 7 |
| 月华菇 | 24 | 22 |
| 合计 | 75 | 94 |

出售收入2796，种子支出123，生产材料12，工具110，净收入2551，期末余额2611元石。成功喂养7次，消耗凝露叶7份。高级锄头第1天购入，高级采收器和播种器第5天购入；因此这套八处种植策略能够循环购买种子、准备菌床和投资工具，没有现金断流。

余额由独立交易前后差额计算；播种/采收从作物实例变化和库存差额计算，不复用记录系统的成功信号计数。45个日存档均可读取，六类统计与冻结回顾逐项一致，最终回顾持久化并保持首轮边界。12项检查全部通过。

当前价格、生长时间和营养公式保留。初始种子较充裕、工具第5天即可全购，符合本轮轻松经营方向；期末资金快速增加，尚不能据此证明长期经济平衡。纯菌菇、只种果树、少操作和大面积高级播种等策略未全面评估；个人自由试玩后再决定是否调价，不为压低余额额外加限制。

## 发布与显示

Windows x64 release使用匹配Godot 4.7.2模板，内嵌资源包。导出白名单只含当前农场场景、运行脚本、图片与烘焙JSON，旧商场/野外/Phase00和开发测试不进入包。开发测试改为按需加载；发布包的显式`--demo-smoke`只在独立目录执行，不接触玩家槽。

源码运行以PNG字节解码，保留正式图片同名替换立即生效的契约；发布包使用Godot导入的无损纹理，避免PNG源文件被导出器转换后无法直读。Nearest与现有尺寸、锚点保持。2D项目关闭Blender导入查询，不需额外安装Blender。

发布程序通过8项独立检查：默认菜单、旧场景/开发测试不在包、新槽60元石与JSON、27张地面/atlas/作物状态图解码、实际生长采收、出售、钱包及工具日存档恢复、独立设置写入。Headless及真实GPU运行均成功，无脚本/资源错误。

GPU截图人工核对：`.shots/farm-phase06f/`首轮回顾、次日四类作物；`.shots/farm-phase06f-release/`实际发布程序的菜单、农场教学和设置。Demo默认0.5倍视野，顶部及底部保留操作区的相机边界，种植/菌床推荐区与通道以现有界面文字标注，不赠送介质或限制土地用途。四类作物完整可见，按钮及回顾滚动区域可达，无新增美术和音乐。

完整基线：31项资产QC、25项Python工具、234项农场流程；另有12项45天验收与8项发布检查。原40项种植测试保留，历史测试保持独立入口。

## 复现

设置`$env:GODOT_EXE_CONSOLE`指向Godot控制台可执行文件，并安装同版本Windows release模板：

```powershell
.\test.bat
& $env:GODOT_EXE_CONSOLE --headless --path . --script scripts/farming/tests/phase06_playtest.gd -- --report=res://.art-work/phase06-playtest.json
.\tools\farming\build_demo.ps1
```

GPU试玩追加`--playtest-shots=res://.shots/farm-phase06f`且不加headless。独立发布检查：`LingTianDemo.exe --headless --log-file <绝对日志路径> -- --demo-smoke`；截图追加`--smoke-shots=<绝对目录>`且不加headless。GUI程序须等待进程退出并检查退出码与`DEMO RELEASE SMOKE OK`标记，不能仅凭启动成功判定。

交付路径：`dist/lingtian-demo/LingTianDemo.exe`、`README.md`与SHA256清单`manifest.json`；压缩包`dist/LingTianDemo-Windows-x64.zip`。构建脚本只有实际发布检查成功才打包，产物与日志不提交Git。玩家说明见[demo-操作说明.md](demo-操作说明.md)。

导出过滤配置与Blender开关依据Godot官方实现：[export_filter枚举](https://github.com/godotengine/godot/blob/master/editor/export/editor_export.cpp)、[Blender导入注册](https://github.com/godotengine/godot/blob/master/modules/gltf/register_types.cpp)。
