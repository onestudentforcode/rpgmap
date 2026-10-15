# P8.7 Windows交付

2026-10-15。默认P8已切换35°统一投影；逻辑64单位地格、经营配数与schema17三槽保持。运行包无需Godot、Blender、Python或外部素材工作区。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/farming/build_p87_demo.ps1
```

产物为`dist/lingtian-p87-demo/LingTianDemoP87.exe`及`dist/LingTianDemoP87-Windows-x64.zip`，ZIP含程序、中英文操作说明和manifest。开发试样的标尺、F7/F8和隔离存档入口不进入正式操作流程。

构建使用隔离项目和独立export preset，以`farm_p87.tscn`作为`farm_p8.tscn`入口别名，manifest如实记录该映射。原PNG按清单枚举，目前48份；新增投影/柔影配置和shader一起打包，阴影纹理在运行时缓存生成。P8.6历史构建脚本固定回原P8.6 shell，原包保留。

最终验证：独立目录91项、解压目录91项、解压GPU93项。覆盖全部原PNG哈希、投影配置、柔影/水场处理、真实生命周期与存读档、缺图恢复，以及实际1920×1080导出GPU画面。ZIP解压后逐项核对程序及说明哈希；源脚本、shader、关键配置及入口共70份与当前工作区一致。

ZIP为42,740,486字节，SHA256为`1af1f566c3b2c7ef281a697d9d4bac68fdf4f5e5492fc9c6cc0411c00aeb167a`。构建来源为`1eef1d9`之后的D阶段工作区快照，`source_dirty=true`如实保留；不将最终提交号追写到已生成的包。

Windows独占归档和延迟改变窗口尺寸的问题已在本轮工具中处理：ZIP使用共享读取的框架接口，GPU探针校验实际PNG尺寸，不能只凭“保存成功”判通过。最终证据见[p87-final-validation.json](p87-final-validation.json)，运行日志和原图在`.art-work/p87-release-logs/`。
