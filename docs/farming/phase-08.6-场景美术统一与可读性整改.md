# Phase 8.6 — 场景美术统一与可读性整改

日期：2026-10-15。状态：**用户已验收A样板并授权完成；B～E实现、全场本地复核、完整回归及Windows独立包交付完成，默认P8为P8.6。**

## 1. 已确认方向与基线

保留35°正交物件机位、矩形地格及64单位逻辑格；延续明亮柔和、灰茶绿/暖土/谷金方向，增强主体与背景层次。采用现有Blender离线PNG、连续alpha、透明边修正和mipmap管线。

P8.5最终技术基线以`art/p85-final-validation.json`为准：整套回归通过，29植物图与15设施主体已验证，Windows包通过独立/解压启动检查。历史阶段页中的进行中描述不代表该最终记录失败；本轮视觉整改另立P8.6，不改写历史验收证据。

本轮处理接地感、幼苗剪影、环境过渡/水岸、资源点造型及轻量UI协调。半透明覆盖率不能直接证明材质透明；设施found层是实体灰色地板，继续暂缓整批接入。全屏色彩丰富度与边缘/核心亮度差用于诊断，不作为普适审美硬阈值。经营空地、水库与未购地保留用途。

## 2. 实施顺序与闸口

| 阶段 | 工作 | 进入下一阶段的条件 |
|---|---|---|
| A 代表场景 | 金穗麦、青牧草、松脂树四阶段，木工台、水场、石料点与岸线；同镜头原版/仅接地/整体整改对照 | 本地检查通过，用户确认具体样板画面 |
| B 实体整改 | 7植物/15设施接地；stage_0/1模型修形；按问题重渲染 | 全量根点、成长、边缘、遮挡和预览验证 |
| C 环境统一 | 四类陆地及平滑过渡、水面与岸线、石堆/矿石露头/泉眼 | 地形内外角、边界和资源点混排检查 |
| D UI协调 | P8卡片层次与设施缩略图，保留布局和导航图标 | 三窗口可读性及V1/V2隔离检查 |
| E 回归交付 | 专项、完整回归、Windows包和解压启动、最终证据 | 技术与用户画面接受分别登记 |

A确认是本计划中的产品验收闸口，不得用代理自评替代。A期间只在显式试样中启用候选图与材质；批量资源导入和默认视觉切换留在确认之后。独立工具与测试底座可先完成。

## 3. 接口和兼容约定

- `configure_visual_trial(profile, runtime_dir)`仅为开发试样接口。`baseline`恢复原图/材质，`grounding`仅接地，`integrated`接地并加载候选幼苗与环境；错误配置应返回诊断，避免写经营状态。
- 沿用`visual()`的texture/rect/root/key，追加可选阴影描述。所有接地先绘制，再按既有根点排序主体，最后绘制选择/生产/派工标记。陆地软阴影与水域接触表现分别配置；不把统一灰地板烘焙进主体。
- 幼苗调整器官几何，保持画布、相机和根点；候选渲染存入`.art-work/p86-runtime`，A不覆盖运行PNG和原始美术工程。整阶段画布映射一致，不逐图裁边塞满地格。
- 资源点绘制抽为默认保持原行为的覆盖入口，P8候选景物参与统一排序；保留单格点击、原派工标记、详情剩余额度和采集规则。
- 环境试样只修改场景实例材料与纹理；全量阶段生产P8独立过渡/岸线资源，不覆盖V1/V2 atlas，不改变地权或水格可建设范围。
- 渲染支持资产/阶段子集、输出目录和recipe签名；续渲需验证源工程、渲染脚本/参数、相机、采样、色彩管理、尺寸与输出校验值。修形获审后建立新QC基准，保留旧报告。
- 最终打包从清单枚举资源，覆盖新增资源点与接地资源，去除固定44图假设；schema17与经营配数保持。

## 4. 可重复样板与验证

入口：`scripts/farming/validation/p86_visual_preview.gd`；GPU矩阵：`tools/farming/review_p86_trial.ps1`。截图与隔离测试档保存在`.art-work/p86-trial/<分辨率>/`。玩家存档不参与试样。

样板使用生产P8 Shell，开垦、播种、建设调用实际模型；材料、研究、资金与目标成长进度是显式夹具，不能当作自然经营成果。三个视觉profile共享同一经营快照、镜头和窗口，视觉切换后快照必须一致。

每profile输出全景、默认/最大幼苗、默认/最大水岸、资源近景、0.1概览和侧栏开启，共8帧；三个profile×三窗口为72帧。默认1.0要求可区分空格、幼苗与成熟；3.0检查边缘/接缝；0.1只检查概览。覆盖2560×1440、1920×1080、960×540。

图像规格检查保留连续alpha，不套旧像素资产的二值alpha/NEAREST限制。记录世界局部ROI明度/轮廓变化，并检查彩色、灰度及浅中深背景合成；技术检查包括根点、固定画布、状态映射、缺图回退、恢复基线和经营快照不变性。

## 5. 执行记录

### 2026-10-15 — A实施启动

已建立阶段范围、试样闸口与隔离预览入口。接地接口、环境试样、幼苗器官修形和渲染工具并行实施中。测试结果、截图和用户接受将在实际完成后追加；目前不宣布A或P8.6通过。

后续范围：动物新模型、设施工作特效、采后新形态、等距/实时3D、繁殖寿命和玩法扩展不纳入本轮。

### 2026-10-15 — A本地实现与验证完成

已完成三档可恢复试样、按阶段配置的陆地软接触阴影/水场接触环、候选纹理原子预检与替换、资源点绘制hook、场景实例材质/平滑过渡/北岸线，以及35°透明石堆。原始模型、正式植物PNG与运行清单未覆盖；默认游戏仍为baseline。

第一版六张幼苗在GPU同屏后，麦/草stage_0仍偏细；第二版增加叶扇中心线展开并提高高度。最终金穗麦stage_0默认逻辑剪影为6.76×12.92像素，青牧草7.09×11.29像素；stage_1分别为11.75×15.27和12.86×15.49像素。相机、画布和根点误差为0，其他四张候选沿用首版。尺寸与面积只是诊断，用户尚未确认画面。

| 验证 | 实际结果 | 证据 |
|---|---|---|
| 渲染工具 | 5项单测通过；A2两图重渲后再次resume为0重渲 | `.art-work/p86-runtime/seedling-qc.json`、render-report.json |
| 接地/候选原子性 | 25项通过；坏图、空候选目录、环境缺图、非法profile均保留旧画面 | `.art-work/p86-grounding-check.log` |
| 环境生命周期 | 40项通过；prepare/apply/restore、metadata/PNG校验、快照不变 | `.art-work/p86-environment-check.log` |
| P8.5视觉生命周期 | 原209项通过 | `.art-work/p86-p85-visual-regression.log` |
| V1/V2兼容 | V1界面79项、V2资源hook16项通过，进程退出码均0 | `.art-work/p86-legacy-stores/compatibility-report.json` |
| 配数与正式图片 | `bake_p8.py --check`通过；作物/设施QC 64项、0失败 | 检查输出；旧V0色板警告保留 |
| 最终GPU矩阵 | 三窗口各24帧，72帧尺寸/命名/失败记录检查通过 | `.art-work/p86-trial/<分辨率>/trial.json`与日志 |

证书store受限诊断按既有精确规则单独审计，未豁免脚本或Shader错误。首轮GPU因引擎本地着色器缓存权限错误被runner判失败；允许该测试写入引擎缓存后重跑，最终三窗口矩阵通过。测试存档和截图均在工作区。

审阅图：`.art-work/p86-trial/scene-comparison.png`、`detail-comparison.png`、`grayscale-comparison.png`、`alpha-backgrounds.png`。左至右为原版、仅接地、整体整改；灰度和浅/中/深背景合成用于边缘检查，实际可读性以GPU截图为准。汇总见`art/p86-trial-validation.json`。

已知边界：岸线样板仅覆盖实际草地与水库之间的北岸；其余岸线方向/凹凸角、矿石/泉眼景物、全量幼苗、UI协调、最终整套`test.bat`及新Windows包属于后续B～E。本阶段不声称P8.6整体交付完成。

## 6. 重现A样板

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --disable-autoexec --python tools/farming/render_p85_runtime.py -- --source C:/Users/88445/Desktop/blender_assest --ids golden_wheat pasture_grass resin_tree --states stage_0 stage_1 --out .art-work/p86-runtime --recipe content/farming/p8/seedling_recipe.json --resume
python tools/farming/gen_p86_transition_trial.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --disable-autoexec --python tools/farming/render_p86_stone_trial.py
python tools/farming/check_p86_environment_assets.py
powershell -NoProfile -ExecutionPolicy Bypass -File tools/farming/review_p86_trial.ps1
python tools/farming/summarize_p86_trial.py
```

工具支持显式Blender来源与Godot路径；原始美术工程只读打开，候选输出留在`.art-work`。命令只构建开发试样，不导入正式资源、不创建新发布包。

## 7. 用户样板接受与全量推广（2026-10-15）

用户明确回复「效果验收通过，继续完成」，A验收闸口解除。历史A记录和截图保留；下面记录后续实际实现，不把代理全场检查写成用户第二次逐图接受。

### B 实体整改完成

已将获审的六图与另外四物种八张幼苗导入，7植物stage_0/1共14图；固定35°、完整画布、逻辑尺度及投影根点。麦/草/松脂保留A图；速生杉加宽针叶及树干、油籽花/蜜铃补强幼叶与茎、木腐菇补强菌丝菌核和原基。stage_2/3及独立花期图保留原图。每张运行图哈希与渲染recipe进清单，导入失败事务回滚。

7植物各阶段与15设施已有统一接地配置；鱼塘为水色接触环，其他物件为柔边暖色阴影。图层沿用接地→根点排序主体→状态标记。原found灰底与工作特效仍暂缓。正式配置为`content/farming/p8/grounding.json`，资源清单同步包含可选shadow描述。

### C 环境与资源点完成

默认P8使用独立平滑过渡atlas与连续世界材质，V1/V2共享资产不覆盖。全方向岸线用真实网格水陆/可购状态生成mask，Shader计算相邻异类格矩形的带符号距离；支持北/南/东/西岸、凹凸角、孤立水格和岛屿，购买负坐标水域后刷新。岸线覆盖不改变水格或建设资格。

石堆、矿石露头、泉眼均为35°正交Blender透明PNG，独立资源清单管理；与植物/设施共同排序，原单格点击、派工标记、采集额度和资源详情保持。生产模块`p8_environment_visuals.gd`只读取项目/PCK资源，不依赖`.art-work`或外部美术源。

### D UI协调完成

通过V1默认保持行为的主题工厂，在P8使用暖纸/浅茶卡片层次；正文与辅助文字沿用已验收颜色。15设施从同一主体PNG的alpha包围盒派生留白缩略图，缓存后用于营建与所有设施详情。世界图仍保留原完整画布；导航和工具SVG、面板布局未重做。

### E 已执行的验收与交付

- `run_p86_production.gd`95项通过：默认启用、7×4成长阴影、15设施接地/缩略图、3资源根点、负坐标真实购地后的岸线mask、反复切档和schema17快照恢复。
- `qc_p86_visuals.py`核对48份PNG字节、固定根点/画布及新版视觉基准；未来检查不自动更新基准。
- 正式2560×1440、1920×1080、960×540各14帧，共42张GPU截图通过尺寸和日志检查，并已亲看密植、三资源点、全植物/设施、岸线拓扑及小窗口营建界面。岸线拓扑是明确标注的测试地形，不冒充正常地图或经营进度。
- Windows包已完成独立目录86项、解压目录86项、解压GPU87项验证；48份包内原PNG哈希、新档、自然成熟、保存/读取、收获/重种、缺图诊断和恢复均通过。包无需Blender、Python或美术源目录。
- 完整`test.bat`退出码0，最终标记`FARMING TEST SUITE OK`；75项资源QC无失败、81项Python工具测试通过，V0/V1/V2/P8全套通过，其中P8.g116项、P8.h活体60项、P8源码冒烟20项、手册77项/11章、扩地69项完成。证据`.art-work/p86-full-regression.log`。

交付入口：`tools/farming/build_p86_demo.ps1`；产物`dist/LingTianDemoP86-Windows-x64.zip`。本次包如实记录`source_dirty=true`的实现工作区快照，并记录全部隔离运行文件哈希，不伪称已提交源码版本。

全量资源重建：使用`seedling_release_recipe.json`渲染七植物stage_0/1到单一`.art-work`目录，再通过`install_p86_visuals.py --renders <目录>`事务接入；生成脚本不保存上游原工程。正式游戏和玩家包不需要重建。

最终汇总：[p86-final-validation.json](art/p86-final-validation.json)。ZIP为42,715,343字节，SHA256 `ef832db1a428f3ff153031b840991cb816450a8e9a72791d24d9eb96c6bfd0b1`；60份包内运行脚本/Shader与当前工作区哈希一致。导入器重复执行0文件写入，视觉基准48项、正式三窗口42帧全部通过。
