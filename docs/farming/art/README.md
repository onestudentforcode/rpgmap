# P8.5 资产接入资料

日期：2026-10-14。七植物与15设施主体已接入；e阶段高清图、地形背景与三窗口技术验收已完成，用户画面接受待确认。

- [源植物交接归档](plant-assets-handoff.md)：来自美术工作区，文件链接按来源工作区解析，不能当作游戏资源路径。
- [植物导入报告](plant-import-report.json)：29图逐文件源路径、SHA256、画布与alpha检查；对应游戏侧 `assets/farming/crops/plant_manifest.json`。
- [设施盘点](facility-inventory.json)：覆盖当前15个游戏设施ID，记录已有图片尺寸、alpha与哈希。状态为盘点，未审批接入。
- [设施实际渲染元数据](facility-render-metadata.json)：后台Blender只读打开15份源工程，记录各层相机矩阵、世界原点投影、正交宽度与工程哈希。
- [运行图对比](runtime-render-comparison.json)与[窗口矩阵](visual-matrix.json)：44图轮廓对比与30截图尺寸记录。
- [同屏美术指导](p85-visual-direction.md)：地面中间调、细节层级和透明/过滤取舍。

## 导入与核查

```powershell
python tools/farming/import_p8_plants.py --source C:/Users/88445/Desktop/blender_assest --check
python tools/farming/test_p8_plant_import.py --source C:/Users/88445/Desktop/blender_assest
python tools/farming/import_p8_plants.py --source C:/Users/88445/Desktop/blender_assest
python tools/farming/inventory_p8_facilities.py --source C:/Users/88445/Desktop/blender_assest
python tools/farming/import_p8_facilities.py --source C:/Users/88445/Desktop/blender_assest --check
python tools/farming/import_p8_facilities.py --source C:/Users/88445/Desktop/blender_assest
```

上述不带 `--runtime-renders` 的命令重装原交接小图。当前定版运行图须先用后台Blender执行 `render_p85_runtime.py -- --source <美术工作区> --resume`，输出到 `.art-work/p85-runtime`，再给两种导入器添加 `--runtime-renders .art-work/p85-runtime`。工具先验证完整对应批次，再事务写入；相同图源和参数重复执行不会降采样或继续乘四放大。

运行图为小植物256²、树512×768、单格设施256²、双格设施512²；来源工程/场景/采样数/PNG哈希逐图记录在运行清单的 `runtime_variant`。原始交接报告仍用于追溯小图，不代表当前游戏图片的哈希。当前44图RGBA解码约29.3MiB，加mipmap约39MiB（不含引擎/驱动开销）；PNG合计约3.9MB。

读取PNG后在内存修正透明边RGB并生成mipmap，只改变采样，不改文件alpha、画布或根点。植物/设施共用的P8 Overlay使用Linear+mipmap，旧地形过滤和V1/V2保持原样。P8地形独立材质降低高频纹理对比，水库与UI不调色。

导入器先验证完整源批次再写入，写入异常回滚本次文件变化；相同输入重复导入不改文件。保持原RGBA与连续alpha，不裁边、不量化、不删分离器官。目标尺寸采用交接小图版本，实际画面需要更高清资源时另批整族派生并更新来源校验。工具只在开发时使用，运行时没有上述绝对路径依赖。

## 设施接入缺口

美术工作区已有 `body`、`found`、`fx` 三层图片与构建脚本。共用套件提供35°主体相机与90°底座相机：2格主体横宽6.4/瞄准高度1.1，1格主体横宽3.4/瞄准高度0.9。这些是脚本线索，不能直接声明每份已保存工程和图片均按该参数交付。

P8.5.d开始前需核对每层实际相机、渲染画布、投影根点、尺度、朝向、源版本及状态用途。底座独立作为地面层，不与主体共用排序；特效按同图根点对齐且不改变生产状态。根目录水井、矿场、伐木场及整图拼装需另核对真实资源点/设施ID，不能按名字自动接入。

上文盘点描述a阶段的初始缺口。d阶段已通过后台Blender补齐15个设施的实际相机/根点元数据，确认清单为全部15个游戏设施的 `body` 层。游戏侧采用 `assets/farming/facilities/facility_manifest.json`，导入器验证工程与图片仍符合已检查哈希。

主体以玩法占地中心作为地板世界原点，植物仍以占地底边中心作为根点；两者均按各自真实地面原点排序。主体完整画布初值为1格108.8²、2格204.8²，保持等比；实际主体只占画布的一部分，不按bbox填满地格。建造预览与已放置主体共用同一份几何映射。

15份正俯视 `found` 层本批全部暂缓，避免在现有地形上铺满统一灰色地板；`fx` 层本批全部暂缓，待定义工作/待收/停机的视觉语义后另接。源工程与图片保留，不合成进主体，不伪造未交付的生产状态帧。根目录水井/矿场/伐木场继续暂缓，其玩法身份是资源点还是设施须另核对；当前资源点继续用既有图标。
