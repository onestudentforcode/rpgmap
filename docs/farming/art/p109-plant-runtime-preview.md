# P10.9 植物运行试装

2026-10-22，按用户“先接入植物看看效果”实施。默认开发入口`play.bat`/F5使用P10.9植物，可打开**显示设置 → 植物美术预览**切换旧版；切换立即生效，仅本次运行有效，下次启动回到默认新版。命令行`-- --plants=legacy`可直接启动旧版，`-- --plants=p109`启动新版。

## 已接入范围

10种植物共41张：金穗麦、速生杉、脂树、木腐菌、青牧草、蜜铃灌木、油籽花、果桑、浮萍、芦苇各4阶段，油籽花另有flowering。成熟源图映射stage_3，沿用现有成长/花期/再生状态选择，不改占地、生产、AP或schema26。

- 原图保留在`assets/farming/p109/source/`，逐图核对源SHA256；未重新生图或重画内容。
- 运行图位于`assets/farming/p109/runtime/plants/<id>/<state>.png`，运行清单为同级`plant_manifest.json`。
- 每个物种统一画布、根点和显示尺寸，按阶段指定体量；不会把每张幼苗单独撑满画布。树木根冠与浮萍叶面分别标注，alpha边界只用于测量尺寸和留白。
- 导出记录保留源/输出哈希、源根点UV、裁剪范围、缩放/粘贴位置、根点量化误差。采用预乘alpha的Lanczos滤波，保留连续透明度；运行缓存生成mipmap，沿用Linear过滤。
- 投影只作用于地面坐标，主体不再沿Y压缩。当前试装并不等于源图已做精确35°相机校准。
- 新旧完整清单分别缓存，加载异常时保持当前配置；显示设置切换不写入存档。旧资源仍保留。
- 共享打包预处理`stage_p85_png_data.py`已添加新版41张PNG的`.bin`别名及`data_files`，避免PCK中只保留导入纹理而丢失原始PNG字节。

## 实际画面

本机证据位于`.art-work/p109/plant-preview/`，不随Git提交，可用下列脚本重建。`1440/`保存2560×1440版本；根目录为1920×1080版本。每种分辨率17帧，共34帧，`frames.json`记录实际尺寸与配置。

| 文件 | 内容 |
| --- | --- |
| `mixed-1.0-p109.png` / `mixed-1.0-legacy.png` | 同镜头混植，旧设施同屏 |
| `mixed-2.0-p109.png` / `mixed-2.0-legacy.png` | 近景细节与树冠前后遮挡 |
| `water-p109.png` / `water-legacy.png` | 真实鱼栅、水生种植区、种植站内的浮萍/芦苇 |
| `stages-1`至`stages-5`的两种配置PNG | 每页两种，横向stage_0至stage_3；油籽花末列额外flowering |
| `settings.png` | 实际新旧切换入口 |
| `runtime-contact-sheet.jpg` | 固定根点、同缩放的全部41张导出图总览 |

目录页属于合成阶段夹具；混植和水生种植使用真实种植/建设API，只把成长状态设置为便于对照的阶段。所有夹具使用工作区隔离存档，不操作玩家档。阶段目录中浮萍/芦苇先作轮廓对照，水面表现以`water`图为准。

已人工查看导出总览、阶段目录、混植近远景、水面和设置截图；未发现主体二次压缩或背景矩形污染。动物地图绘制、建筑替换均未实施。新旧建筑/植物的精度差异在混植图中仍可见，建筑继续后置。

## 验证与边界

- 植物专项274项通过：默认入口、41纹理、状态/花期边界、再生成熟体、投影根点、源/运行哈希、根点误差、新旧配置/环境配置独立及完整世界快照不变。
- 现有P8.7生产场景230项、投影98项通过。生产场景中的缺失纹理警告来自其主动故障注入。
- GPU夹具在1920×1080、2560×1440均退出0，各输出17帧。日志仍包含本机系统证书读取错误和OpenGL初始化缓存错误，随后成功识别RTX 4060并完成实际截图；不宣称零日志错误。
- 打包字节预处理125条通过，其中新增41个别名逐项与运行SHA256一致；本次没有制作或验证最终发行EXE/PCK。
- 纹理预算估算：新版完整RGBA8+mipmap约50.58MiB，旧版约47.00MiB；为即时对照同时缓存两套时合计约97.58MiB。这是纹理字节估算，不是进程峰值或实测帧率。
- 旧P8.7交互脚本323项中2项失败：GUI建造双格设施、拖选3×2；旧素材模式复现相同失败。其余321项包括坐标、缩放/平移、直接耕地/种植和保存读档通过。本次未把这两项旧交互夹具问题扩展为玩法修复，也不把此脚本记为全通过。

成熟原图已验收；其他阶段及当前同屏效果仍待用户视觉验收。`p109-replacement-inventory.json`的植物41条标记为运行试装，生物34条保持待接入；源归档清单保留其最初生产时的状态。

## 复现

在仓库根目录运行：

```powershell
python tools/farming/export_p109_plants.py
$plantGodot = 'C:/Users/88445/Desktop/code/daoyan/.tools/godot-4.7.2/engine/Godot_v4.7.2-stable_win64_console.exe'
& $plantGodot --path . --headless --script scripts/farming/tests/run_p109_plants.gd
& $plantGodot --path . --rendering-method gl_compatibility --script scripts/farming/validation/p109_plant_preview.gd -- --shot-size=1920x1080
& $plantGodot --path . --rendering-method gl_compatibility --script scripts/farming/validation/p109_plant_preview.gd -- --shot-size=2560x1440 --preview-dir=res://.art-work/p109/plant-preview/1440
```

本次可先直接运行游戏查看。后续按明确反馈调整具体尺寸/接地点，确认这批效果后再接动物；不自动追加候选或重做已选图。
