# P8.5 Windows 发布管线

日期：2026-10-14。入口：`tools/farming/build_p85_demo.ps1`。根目录`export_presets.cfg`仍是历史发布配置；P8.5使用独立`tools/farming/export_p8.cfg`，不依赖历史显式资源清单。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/farming/build_p85_demo.ps1
# 可用 -GodotExe 指定 Godot Windows console 引擎，或设置 GODOT_EXE_CONSOLE。
```

构建机需要Python、Godot及匹配的Windows导出模板；玩家运行不需要Blender、Python、美术工作区或源码。

## 输出与资源

- `dist/lingtian-p85-demo/LingTianDemoP85.exe`：Windows x64，嵌入PCK，主入口为现行`farm_p8.tscn`。
- `dist/LingTianDemoP85-Windows-x64.zip`及`.sha256`：程序、中英文操作说明、`manifest.json`。
- `.art-work/p85-release-logs/`：导入、导出、独立启动、解压启动、GPU启动日志及实际包截图。

工具先在`.art-work/p85-release-<GUID>`创建隔离导出项目，仅复制P8及共享运行依赖。不复制`.blend`、美术主图、开发截图或源工作区；源项目的manifest不改写。

29植物图及15设施主体以原PNG字节复制为`.png.bin`，只在隔离项目manifest增加`data_files`/`data_file`。Godot包内按原字节解码，缓存仍以规范PNG路径索引；这是为避免导入后的纹理资源替代原PNG字节。发布检查对44份包内数据逐一核对运行manifest中的SHA256。地形走Godot导入纹理，共享地形渲染器只增加P8发布feature分支。

## 实际包验证

构建工具分别从输出目录和新解压目录运行程序，不带源码`--path`。`--p85-smoke`使用进程独立测试档案，不打开玩家卷册。

检查包括：实际P8发布feature、29+15纹理缓存、44份原PNG哈希、P8目录与地面Shader、真实开垦/播种/四日日结自动保存/成熟/读档/收获/重种，以及人为缺图诊断和恢复加载。headless为65项；解压包GPU检查另保存七植物成熟行截图，为66项。成熟行是合成视觉夹具，前面的经营步骤调用实际生产代码。

每次构建检查退出码、错误日志及完成标记；ZIP解压后重新核对程序/说明文件哈希。manifest记录源码提交、是否有未提交改动、隔离运行文件和交付文件的哈希。最终交付应从已提交运行版本构建，`source_dirty=false`。

发布链路此前已通过65/65/66项检查；地面B定版后仍须重新构建并检查最终产物，旧试验包不能作为最终交付。P8.5关闭证据以阶段文档中的最终记录为准。
