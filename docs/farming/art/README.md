# P8资产接入与美术验收资料

> **P8.7计划与试样：** [P8.7相机机位与地面投影统一](../phase-08.7-相机机位与地面投影统一.md)，区分地面投影与PNG主体投影，先验证35°匹配试样；A样板已获用户接受，继续B～D；当前资源及默认入口暂保持P8.6。

> **当前P8.6（2026-10-15）：** 用户已验收A样板；全量植物/设施接地、幼苗、三资源点、全方向水岸及轻量UI已进入默认P8。见[阶段记录](../phase-08.6-场景美术统一与可读性整改.md)、[48图/42截图检查](p86-asset-qc.json)与[Windows交付](p86-windows-delivery.md)。下文为P8.5历史管线，P8.6改用`qc_p86_visuals.py`及新视觉基准；不再以“轮廓必须等于原小图”检查有意修形。

## 当前P8.6

当前运行资源均随仓库提交，运行和发布无需外部美术工作区。安装与重建步骤见[阶段文档](../phase-08.6-场景美术统一与可读性整改.md)，资源/根点基准见[p86-visual-baseline.json](p86-visual-baseline.json)，完整回归和包哈希见[最终证据](p86-final-validation.json)。本机已有GPU截图证据时可重新核查：

```powershell
python tools/farming/bake_p8.py --check
python tools/farming/qc_p86_visuals.py
```

QC默认读取`.art-work/p86-final-visual`；新机器先运行`tools/farming/review_p86_full.ps1`生成证据。普通检查不会改写视觉基准。

## P8.5历史资料

日期：2026-10-14。七植物与15设施主体已接入；用户选择B地面，正式三窗口矩阵已通过。Windows独立包已重建并验证，最终完整回归与关闭记录见阶段文档。以下命令用于追溯P8.5，重新导入该批次会替换P8.6幼苗，当前批次应使用P8.6阶段文档中的渲染配方与安装工具。

- [源植物交接归档](plant-assets-handoff.md)：来自美术工作区，文件链接按来源工作区解析，不能当作游戏资源路径。
- [植物导入报告](plant-import-report.json)：29图逐文件源路径、SHA256、画布与alpha检查；对应游戏侧 `assets/farming/crops/plant_manifest.json`。
- [设施盘点](facility-inventory.json)：a阶段原始盘点，覆盖15个游戏设施ID；d阶段已确认接入全部15主体，底座/特效仍暂缓。
- [设施实际渲染元数据](facility-render-metadata.json)：后台Blender只读打开15份源工程，记录各层相机矩阵、世界原点投影、正交宽度与工程哈希。
- [运行图对比](runtime-render-comparison.json)与[窗口矩阵](visual-matrix.json)：44图轮廓对比与30截图尺寸记录。
- [同屏美术指导](p85-visual-direction.md)：地面中间调、细节层级和透明/过滤取舍。
- [地面材质计划](p85-ground-material-plan.md)：用户反馈、A/B试样及B定版记录。
- [Windows发布管线](p85-windows-delivery.md)：隔离导出、44原PNG字节、独立/解压启动检查。

## 导入与核查

```powershell
python tools/farming/import_p8_plants.py --source C:/Users/88445/Desktop/blender_assest --check
python tools/farming/test_p8_plant_import.py --source C:/Users/88445/Desktop/blender_assest
python tools/farming/inventory_p8_facilities.py --source C:/Users/88445/Desktop/blender_assest
python tools/farming/import_p8_facilities.py --source C:/Users/88445/Desktop/blender_assest --check
python tools/farming/qc_assets.py --target crops
```

上面的`--check`只验证原交接批次，不写入游戏资源。当前定版图片已提交，新机器直接运行/发布无需重渲染。需要重建运行图时，先用后台Blender执行下列命令，再显式导入完整高清批次；不带`--runtime-renders`的写入命令会恢复原交接小图。

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --disable-autoexec --python tools/farming/render_p85_runtime.py -- --source C:/Users/88445/Desktop/blender_assest --resume
python tools/farming/import_p8_plants.py --source C:/Users/88445/Desktop/blender_assest --runtime-renders .art-work/p85-runtime
python tools/farming/import_p8_facilities.py --source C:/Users/88445/Desktop/blender_assest --runtime-renders .art-work/p85-runtime
python tools/farming/qc_p85_visuals.py --source C:/Users/88445/Desktop/blender_assest
```

Blender路径可按构建机修改。工具先验证完整对应批次，再事务写入；相同图源和参数重复执行不会降采样或继续乘四放大。

运行图为小植物256²、树512×768、单格设施256²、双格设施512²；来源工程/场景/采样数/PNG哈希逐图记录在运行清单的 `runtime_variant`。原始交接报告仍用于追溯小图，不代表当前游戏图片的哈希。当前44图RGBA解码约29.3MiB，加mipmap约39MiB（不含引擎/驱动开销）；PNG合计约3.8MB。

读取PNG后在内存修正透明边RGB并生成mipmap，只改变采样，不改文件alpha、画布或根点。植物/设施共用的P8 Overlay使用Linear+mipmap，旧地形过滤和V1/V2保持原样。P8地形独立材质降低高频纹理对比，水库与UI不调色。

导入器先验证完整源批次再写入，写入异常回滚本次文件变化；相同输入重复导入不改文件。保持原RGBA与连续alpha，不裁边、不量化、不删分离器官。当前整族4倍运行图保持原逻辑尺度和归一根点，清单包含更新后的来源校验。工具只在开发时使用，运行时没有上述绝对路径依赖。

## 设施接入缺口

美术工作区已有 `body`、`found`、`fx` 三层图片与构建脚本。共用套件提供35°主体相机与90°底座相机：2格主体横宽6.4/瞄准高度1.1，1格主体横宽3.4/瞄准高度0.9。这些是脚本线索，不能直接声明每份已保存工程和图片均按该参数交付。

P8.5.d开始前需核对每层实际相机、渲染画布、投影根点、尺度、朝向、源版本及状态用途。底座独立作为地面层，不与主体共用排序；特效按同图根点对齐且不改变生产状态。根目录水井、矿场、伐木场及整图拼装需另核对真实资源点/设施ID，不能按名字自动接入。

上文盘点描述a阶段的初始缺口。d阶段已通过后台Blender补齐15个设施的实际相机/根点元数据，确认清单为全部15个游戏设施的 `body` 层。游戏侧采用 `assets/farming/facilities/facility_manifest.json`，导入器验证工程与图片仍符合已检查哈希。

主体以玩法占地中心作为地板世界原点，植物仍以占地底边中心作为根点；两者均按各自真实地面原点排序。主体完整画布初值为1格108.8²、2格204.8²，保持等比；实际主体只占画布的一部分，不按bbox填满地格。建造预览与已放置主体共用同一份几何映射。

15份正俯视 `found` 层在P8.5全部暂缓，避免在现有地形上铺满统一灰色地板；`fx` 层待定义工作/待收/停机的视觉语义后另接。源工程与图片保留，不合成进主体，不伪造未交付的生产状态帧。P8.6采用独立接触阴影，并已为三资源点接入石堆、矿石露头和泉眼造型，保留原交互行为。
