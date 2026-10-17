# P8.6 Windows交付

2026-10-15。默认入口为P8.6，保留schema17三槽与既有P8玩法。用户已接受A样板并授权完成全量推广；全场本地检查和用户样板接受分别记录。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/farming/build_p86_demo.ps1
```

产物：`dist/lingtian-p86-demo/LingTianDemoP86.exe`、`dist/LingTianDemoP86-Windows-x64.zip`与`.sha256`。ZIP含程序、中英文说明及manifest；无需Godot/Blender/Python或素材目录。

发布过程在`.art-work/p86-release-<GUID>`隔离复制P8及共享运行依赖，以独立`export_p86.cfg`导出嵌入PCK。清单枚举29植物图、15设施主体、3资源点和1过渡atlas，共48份原PNG字节；阴影在运行时缓存生成，设施缩略图复用主体。源码manifest不增加发布别名，只有隔离项目添加`.png.bin`映射。

验证完成：输出目录headless86项、解压目录headless86项、解压GPU87项。包含全部PNG哈希、生产环境/缩略图、新档/自然成熟/保存/读取/收获/重种和缺图恢复。证据`.art-work/p86-release-logs/`，GPU画面`packaged-render.png`。ZIP已解压并对程序/说明哈希重新核对。

包来源为本次实现工作区，`source_dirty=true`如实记录；manifest列出隔离项目源文件和交付文件哈希，可核对实际构建内容。完整回归证据与最终ZIP哈希见`p86-final-validation.json`。
