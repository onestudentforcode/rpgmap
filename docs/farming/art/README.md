# P8.5 资产接入资料

日期：2026-10-14。当前完成植物离线导入底座，游戏显示待P8.5.b/c实施。

- [源植物交接归档](plant-assets-handoff.md)：来自美术工作区，文件链接按来源工作区解析，不能当作游戏资源路径。
- [植物导入报告](plant-import-report.json)：29图逐文件源路径、SHA256、画布与alpha检查；对应游戏侧 `assets/farming/crops/plant_manifest.json`。
- [设施盘点](facility-inventory.json)：覆盖当前15个游戏设施ID，记录已有图片尺寸、alpha与哈希。状态为盘点，未审批接入。

## 导入与核查

```powershell
python tools/farming/import_p8_plants.py --source C:/Users/88445/Desktop/blender_assest --check
python tools/farming/test_p8_plant_import.py --source C:/Users/88445/Desktop/blender_assest
python tools/farming/import_p8_plants.py --source C:/Users/88445/Desktop/blender_assest
python tools/farming/inventory_p8_facilities.py --source C:/Users/88445/Desktop/blender_assest
```

导入器先验证完整源批次再写入，写入异常回滚本次文件变化；相同输入重复导入不改文件。保持原RGBA与连续alpha，不裁边、不量化、不删分离器官。目标尺寸采用交接小图版本，实际画面需要更高清资源时另批整族派生并更新来源校验。工具只在开发时使用，运行时没有上述绝对路径依赖。

## 设施接入缺口

美术工作区已有 `body`、`found`、`fx` 三层图片与构建脚本。共用套件提供35°主体相机与90°底座相机：2格主体横宽6.4/瞄准高度1.1，1格主体横宽3.4/瞄准高度0.9。这些是脚本线索，不能直接声明每份已保存工程和图片均按该参数交付。

P8.5.d开始前需核对每层实际相机、渲染画布、投影根点、尺度、朝向、源版本及状态用途。底座独立作为地面层，不与主体共用排序；特效按同图根点对齐且不改变生产状态。根目录水井、矿场、伐木场及整图拼装需另核对真实资源点/设施ID，不能按名字自动接入。

当前没有设施被标为“规格齐全可直接接入”。后续应从现有匹配目录中选样，补齐元数据后进行场景验证；无匹配目录项保留占位并单列后续制作需求。
