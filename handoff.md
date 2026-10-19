# handoff — 跨机器开发交接

> **测试口径更新（2026-10-19，用户确认）：** 常规120日门禁退役；里程碑长线冒烟只断言策略无关稳定性不变量（收账/守恒/无意外死亡/疲劳有界/非负/快照往返＋覆盖清单），禁止经济终点断言，经济可行性由标准成本表负责；新增秒级参考夹具自检承接跨模块结构漂移（P10.6首个小任务）。见[测试说明](docs/farming/testing.md)顶部与总计划v1.50。

> **P10.5本轮技术验收完成（2026-10-19）：** 冻结`12274c7`、核心`ea0ac92`、UI/知识/占位图`5881ef0`及收口提交。schema23接入九种陆生名册（六新：炭腹虫/叶丝蚕/露壳蜗牛/矿鳞蜥/堆肥鼠/砾甲蜗牛）、成体三用途互斥（繁殖/精养/役使）、精养区＋四专属台（每照料单位4空间、开日效率100/75/50/0、进度归动物）、钢绵羊产毛迁出圈养、岩兽工作场拆碎岩场/选矿场、五役使工艺、果桑限采6轮、8新材料/4木工配方与解锁接线；`p103`配置v2承载全部注册表。模型473＋回归（P103 556/P104 261/08a 95/08f 358/08h 57）、P103/P104全量回放与审计、模块回放557与收据审计、百科/手册/资产/Python基础全绿；P8 120日回放发现并修复三处P10.4/10.5结构漂移后按用户指示豁免最终复跑（A线已确认恢复，B线留待里程碑冒烟自然复验），详见[阶段页§14.5豁免记录](docs/farming/phase-10.5-陆生物种扩充与精养生产.md)。`test-p10-5.bat`为入口（`-SkipPlaytest`快速）。主观试玩、正式美术、里程碑长线冒烟另排；下方公告按历史阅读。

> **P10.5草案已起草（2026-10-19）：** 下一实施入口[陆生物种扩充与精养生产](docs/farming/phase-10.5-陆生物种扩充与精养生产.md)P10.5.a。六种旧池陆生候选全部加入；成体繁殖/精养/役使互斥，新增精养区并将钢绵羊产毛迁入，精养进度归动物、沿用2维持＋6照料和开日疲劳100/75/50/停产。叶丝蚕/炭腹虫按群，蚕不繁殖；专属生产设施、公共圈舍/床/食槽，灵液主产物只售/水行供货，水产配方后置。草案补齐桑叶、工艺/下游、注册表/保存/分层验收，数值及旧岩兽工作场拆分为待冻结建议；本次只改文档，P10.4/schema22、运行内容、历史验收JSON和美术不动，未运行P10.5测试。下方公告按历史阅读。

> **P10.4本轮技术验收完成（2026-10-19）：** 核心`881dbd4`、UI/知识/占位图`74cbe08`；显式田块边界前置`9f2ec9c`。schema22接入一级门槛、安抚/奴道150%、耐用藤球、实际服务容量、繁育贡献/初始成长、岗位余量与明确系统关联。模型261、容量专项342、农业317、畜牧555；八短场景900、GPU31、一条完成的60日整合780与服务全程审计通过，库存独立审计仅末15日，之前由逐日运行时/Codec核对。`test-p10-4.bat`默认模型，可单独补跑/审计分区，见[分层入口](docs/farming/p104-分层验收与补跑.md)、[操作说明](docs/farming/demo-p104-操作说明.md)、[最终证据](docs/farming/phase104-validation.json)。旧证据不改；新建筑仍占位美术，主观试玩待玩家，幼体市场限购/繁殖经济平衡、历史压缩与精细照料另排。下方公告保留为历史。

> **P10.4.a冻结完成（2026-10-18）：** [阶段页§16.2](docs/farming/phase-10.4-畜牧蛊虫与三级生产系统.md)已核对并冻结首轮设施/蛊/藤球、150%与维护/容量、Q100进度、三级贡献/余量、`p104_services.gd`及`world.services`、schema22与副本预览。边界前置已提交`9f2ec9c`；下一步b接入内容和一级门槛，继续按`fad3a0c`分层验证，不将冻结文档当作新能力已经实现。

> **P10.4前置：显式房间边界已落地（2026-10-18）：** 农业改为玩家登记田块ID/地格列表，紧贴和外部桥接均不合并，新耕地不自动加入；多格作物不得跨界。UI可创建/编辑/解除，保存校验覆盖归属、连通、重叠，畜牧沿用原显式区域。当前开发schema22、旧17～21保留文件并拒绝；明文设计见[房间归属与连通](docs/farming/房间归属与连通设计.md)。边界专项46、三日模块场景18、六条生长/一次领取库存审计与四类篡改拒绝通过；不跑全量120日。下一步P10.4.a冻结后推进实施。

> **P10.4草案已起草（2026-10-18）：** 下一入口为[畜牧蛊虫与三级生产系统](docs/farming/phase-10.4-畜牧蛊虫与三级生产系统.md)P10.4.a。统一三级定义，安抚繁殖、奴道工作、抓娃娃机玩具站/木工台免解锁耐用藤球；首轮拟定150%两蛊、单位玩具判定、繁育初始成长/役使余量与综合配置。确认规则和建议数值已分列，a阶段冻结；本次仅文档，未实现上述功能或跳schema，现行仍21。验收遵守分层约定，模型＋≤30日模块场景/收据审计为主体，里程碑仅一条长线冒烟；下方讨论条目及旧公告作为历史记录。

> **藤球设计补充（2026-10-18，耐用性已确认）：** 首种玩具为藤球，现有木工台制作、配方无需解锁，效果为10%概率额外恢复1点疲劳，装入玩具站后长期使用，不按次消耗，见[讨论记录](docs/farming/畜牧蛊虫与房间加成-讨论记录.md)。每有效额外放牧单位判定一次为待确认建议；配方材料/工时、玩具站服务容量尚未确定。仅记录设计，未改内容或代码。

> **畜牧下一阶段讨论（2026-10-18，最新补充）：** 已记录[三级房间与畜牧宿主方向](docs/farming/畜牧蛊虫与房间加成-讨论记录.md)。一级允许基础设施运行，二级通过适配蛊虫或特殊道具开放强化，三级为多个房间的协同系统；育种/丰产/复合农业区均归三级。本轮二级方向为安抚台繁殖加速、奴道调度增加工作进度、玩具站装入特殊道具玩具；玩具站外观确定为抓娃娃机，玩具具备独立配方/工业路线方向，不再使用休憩亭。育幼暂不做二级，食道节粮/梦道恢复仅预留。照料台保留一级配套；剪毛、清洗等精细照料后续由独立设施承载，本轮不做。宿主统一匹配资格，避免按房间重复设入驻白名单。本次仅讨论记录，schema21与既有代码/证据不变。

> **P10.3开发完成并关闭（2026-10-18）：** a～f全链交付：schema21、名册/五类分区/床组（4张1格）、八单位日程（标准/晚班，入组选班、变更受空档规则约束）、整段维持与固定禁工、日界疲劳与濒危死亡、四岗位批次轮班、成长/圈养/无性繁殖、管理面板与预警、百科手册、占位美术。验收：模型549、九路线经营回放1047、审计器收据级校验、六类Codec篡改探针、P8双路线120日944与审计、旧套件改写后全绿；UI自动化与主观试玩按用户指示豁免/未代签。入口`test-p10-3.bat`（`-SkipPlaytest`快速）。证据`.art-work/p103-playtest/`。下一阶段：畜牧蛊、入驻宿主与房间回报。

> **P10.3.e完成（2026-10-18）：** 管理面板`p103_ui.gd`（顶栏“畜牧分区”入口）、百科rule:animal-zones（18规则207实体）、手册第15章、六设施占位美术+图标（QC 81/0）。UI自动化测试按用户指示豁免；快速套件全绿（P103模型549、P102模型214、08a/f、百科44、手册93、Python契约）。下一入口P10.3.f：畜牧分区经营回放+审计+文档收口，全量回归仅此一步串行执行。

> **P10.3.b/c/d模型完成（2026-10-18）：** 核心模块`p103_ranch.gd`交付（名册/五类分区/床组预约/八单位时钟/整段维持/固定禁工/日界疲劳/岗位批次/成长/圈养/无性繁殖），schema21拒绝17～20，六种新设施入内容（床组4张1格、大床1张满格），`pen`/`rock_workyard`旧路径关闭。P103模型549项、P102模型214项、08a/f/h_living、扩地、百科/手册、Python契约全绿；P8双路线120日经营完整通过一次（944项）且审计器已适配畜牧收据。快速验证入口`test-p10-3.bat`。下一实施入口P10.3.e（管理UI、预警、百科畜牧条目、设施美术）。待办：e/f阶段；全量回归只在f收口串行执行。

> **P10.3.a冻结完成（2026-10-18）：** 现状核对与参数冻结见[陆生动物分区与日程](docs/farming/phase-10.3-陆生动物分区与日程.md)§14.1：新增`p103_ranch.gd`单模块、schema21拒绝17～20、`pen`/`rock_workyard`关闭旧habitat路径（受影响旧回归测试随f改写）、五种新设施（调度站/供食槽/小床/中床/照料台）、容量算法与两预设日程、疲劳/禁工/岗位/繁殖参数、操作费均已冻结。下一实施入口P10.3.b（名册、五类分区、混养、床位及空间预约）。当前仍P10.2/schema20，下方交付证据保持历史状态。

> **P10.3草案已起草（2026-10-18）：** 下一实施入口为[陆生动物分区与日程](docs/farming/phase-10.3-陆生动物分区与日程.md)P10.3.a。用户确认仅三种陆生动物，钢绵羊2空间、啮岩鼹/岩腹兽各1且可混养；五类露天功能区、八单位日程、连续两单位维持、失败窗口结束后禁工八单位、错时床位、实际劳动疲劳、设施持有工作进度和圈养无性繁殖。草案已拟定疲劳/繁殖/设施等首轮参数；实施时冻结并验证。先做分区与基础规则，新蛊虫和房间加成另排。本次只改文档，没有实现或验证P10.3玩法；当前仍P10.2/schema20，下方交付证据保持历史状态。

> **经营检查可分区补跑（2026-10-18）：** `test-p10-2.bat -Stage Plan`查看状态；`-Stage Run -Cases compound/B -Rerun`只重玩复合B并归档原B，其他路线保留；`-Stage Audit -Cases compound/B`只重审复合A/B，`-Stage Probes -Cases compound/B`只跑篡改检查。显式分区命令跳过快速模型/UI；需要时单独`-SkipPlaytest`。共享源码变动仍使引用它的旧回放失效，局部通过不算全量验收。工具146项与真实单条补跑已验证，见[说明及证据](docs/farming/p102-分区回放说明.md)。本次只改调度、测试和文档，P10.2原验收JSON保持历史版本。

> **P10.2开发完成（2026-10-18）：** 当前schema20，地板、1×1站双范围、连通农业区、实际贡献与成熟奖励、保存/UI/知识全部交付；旧17/18/19明确拒绝且保留原文件。模型209/UI30/GPU37、Python129、完整P8及隔离存储历史V1/V2、八条120日经营、四组完整审计、16类篡改拒绝全部通过。证据目录`.art-work/p102-playtest/business-v5/`，原失败/中断批次保留；跨机器需一并复制工作区证据，详见[阶段页§14](docs/farming/phase-10.2-地板与农业房间.md)。`test-p10-2.bat`默认包含经营门禁，`-SkipPlaytest`仅快速检查，`-AuditExisting`只重审终态证据，已验证通过。[操作说明](docs/farming/demo-p102-操作说明.md)、[成本回报](docs/farming/phase102-business.md)、[最终哈希记录](docs/farming/phase102-validation.json)。主观试玩未代签，不制作开发发行包；下方版本描述按历史阅读，不改旧证据哈希。

> **P10.2草案（2026-10-17）：** 下一实施入口为[地板与农业房间](docs/farming/phase-10.2-地板与农业房间.md)：露天耕地四邻接；一级育种＝催生＋锁水，一级丰产＝催生＋节肥，三种齐全为二级；按合格生长贡献计算首次成熟25%单次种子和每轮主产物25%随机舍入。**田间维护站替换为1×1，功能不变，普通范围按新占地外扩2格重算5×5、蛊四向3×3，贴图/根点/阴影/拾取同步适配；旧档无需兼容，不做迁移、不删旧文件。** 硬质地板输送/管线/传动后置。本次只起草文档，现行仍P10.1/schema19；下方2×2与17/18升级为历史阶段规则，不作为P10.2要求。

> **P10.1全部完成并留证（2026-10-17）：** a冻结→b覆盖决议/schema19→c/d生产与保存验收→e界面知识→f经营交付。终态：模型168项＋UI 28项＋对照81项＋契约5项＋Python契约14项；农业A/B各120日468项、装配936项、严格审计（余量守恒A 2633/B 2664点、维护A 544/B 545、稻米A 248/B 256）与8类篡改探针全绿；五场景对照实测见[阶段文档§12.2](docs/farming/phase-10.1-农业区与辅助蛊.md)。专用入口`test-p10-1.bat`（`-SkipPlaytest`跳过120日回放）。当前游戏schema19（17/18无损升级）；用户主观试玩未代签、Windows包按约定不制作。原始证据在`.art-work/p101-playtest/`与`.art-work/p101-tests/`。方法教训（静态契约+快速链，避免全量重跑迭代）记录于阶段文档§12.3。

> **P10.1.b/c/d已实现并专项通过（2026-10-17）：** 覆盖与效果决议（冻结四向3×3、完整占地`resolve()`、tag分组最高转、余量消耗、1AP朝向）、生产消耗验收（连续服务口径2/3/4/4/6日成熟、留株再生、油籽花窗口仍两日可采、零耗肥、多格累计）与保存验收（11只配给、17→18→19严格升级、legacy当日120%旧口径、重种不洗余量、最后1AP回滚）全部落地；`run_phase101.gd` 168项、P10模型/UI 181+21项、Python 103项、P8全套、V0/V1/V2回归绿。**当前游戏schema19；下一入口P10.1.e界面与知识（四向预览、部分覆盖解释、宿主面板朝向）。**

> **P10.1.a配数冻结（2026-10-17）：** [农业区与辅助蛊](docs/farming/phase-10.1-农业区与辅助蛊.md)§12.1已冻结：复用田间维护站（槽名`agriculture_assist`）、四向3×3九格、默认东向+转向1AP次日生效、催生150%（`growth_gu` id/费率不变）、新`water_gu`/`fert_gu`保留50%、三蛊维护1元石/日无食料、`plant_grow`资格8ID、11只配给（前六只与P10一致）与旧档补发五只（`agri_supplement`）、schema19（`facings`/`remainders`/`legacy_until`，旧档当日旧口径保留）。

> **P10.1设计草案（2026-10-17）：** 下一实施入口为[农业区与辅助蛊](docs/farming/phase-10.1-农业区与辅助蛊.md)。用户确认普通农业、三蛊共用单槽宿主、定向光环与完整占地、面积承载、异类组合/同tag最高转优先、固定可重复模块；催生采用生长点倍率，以150%为配数起点。房间满配收益、饥饿死亡、升转与其他产业后置。P10旧证据不可改哈希冒充新版本。

> **P10开发交付完成（2026-10-16）：** 五类后勤蛊、六只一次性试用实例、部署/维护/稻米生产、明光/催生、研究辅助、管理页、百科及12章手册已接入。默认P8入口/P8.7投影，schema18兼容读取schema17。最终181项模型、21项界面及GPU检查、99项Python工具、完整`test.bat`、有/无蛊各双120日严格审计及12＋10类篡改拒绝通过；见[Phase 10](docs/farming/phase-10-后勤蛊虫与生产协同.md#14-执行与验收记录)与[验收证据](docs/farming/phase10-validation.json)。运行`play.bat`后打开“后勤蛊”，见[操作说明](docs/farming/demo-p10-操作说明.md)。`test-p10.bat`重跑专项和经营；`-SkipPlaytest`快速检查，`-AuditExisting`重审原始证据。真实上游、凝露P1、正式美术与新Windows包后置，未代签用户主观试玩。下面P9/P8.7数量、schema17及“下一步方向”属于历史记录。

> **P9已完成（2026-10-16）：** [游戏内百科全书](docs/farming/phase-09-游戏内百科全书.md)全部交付：P9.a调查（[audit交付](docs/farming/encyclopedia/audit/report.md)五件套，复核50项0问题）；P9.b内容层（curated源`content/farming/encyclopedia/encyclopedia.json`＋编译器`tools/farming/bake_encyclopedia.py`→`content/farming/baked/encyclopedia/encyclopedia.json`，格式版本1；187实体/242过程/14规则；`--check`过期检查接入test-p8）；P9.c游戏内阅读（`scripts/farming/p8/p8_encyclopedia.gd`缺氧风格双栏阅读器，接入统一手册双页签与各面板查询按钮）；P9.d同源导出[百科全书](docs/farming/demo-p8-百科全书.md)＋8项核验单测（工具单测共89项）；试玩反馈修复（长文AUTOWRAP_ARBITRARY换行约30字/行、隐藏"实现依据"refs，专项44项）；P9.e用户验收通过，**Windows打包按用户要求豁免（开发阶段不打包；正式打包时需在打包配置中显式包含`content/farming/baked/encyclopedia/`数据）**，分辨率抽查与完整`test.bat`全绿。默认P8.7/schema17保持，未改任何玩法数值。下一步方向待用户确定。

> **上一阶段P8.6基线：** [场景美术统一与可读性整改](docs/farming/phase-08.6-场景美术统一与可读性整改.md)已在用户样板接受后完成B～E。当时默认P8启用全量接地、7植物幼苗整改、3资源点、平滑地形/全方向水岸和设施缩略图；保留35°/矩形地格、schema17及经营规则。`test.bat`、42张正式GPU截图、独立包86/86/87项检查通过；[最终证据](docs/farming/art/p86-final-validation.json)，产物`dist/LingTianDemoP86-Windows-x64.zip`。用户样板接受与代理全场复核分别记录。

> **P8.7已完成并设为默认：** [相机机位与地面投影统一](docs/farming/phase-08.7-相机机位与地面投影统一.md)A～D完成。地面约64×36.71，主体保持原比例；根点、柔影、操作逆变换、定位和相机统一，逻辑网格/schema17不变。用户接受35°样板，对最终画面基本接受并要求补影，补影已完成并由代理复核。89/146/324项专项、正式60帧、完整`test.bat`和Windows91/91/93项通过；[最终证据](docs/farming/art/p87-final-validation.json)，包为`dist/LingTianDemoP87-Windows-x64.zip`。

> 最后更新：2026-10-16（Phase 9游戏内百科全书全部完成并关闭：调查/内容层/游戏内阅读/手册导出/试玩反馈修复/验收交付，Windows包按用户要求豁免，详见阶段页执行记录；P8.7交付及旧证据保持）。
> **现行本地基线：** [P8生态产业网络与工艺研究](docs/farming/phase-08-生态产业网络与工艺研究.md)。默认`play.bat`/F5进入P8，`play.bat p8`等价；三槽`user://farm_demo_p8_slots`、schema17、独立设置、初始90元石/每天24AP、初始20×22地图及下方20×8水库，外接32×22连续地图；新增陆地112格/380元石、水面96格/280元石。63资源、7植物、15设施、40配方、12研究已运行；一人多设施、默认关闭的显式兼任共享个人12次工作/预算，普通及活体自动生产按目标/在制/保留量执行。玩家阅读[P8新手手册](docs/farming/demo-p8-新手手册.md)，也可从游戏顶栏“手册”进入。
> **验收与后续：** 双120日各27/27工艺收取及全部产物后续消费、装置/兼任经营和严格审计通过，当前扩地双120日924项、12类篡改拒绝，证据`.art-work/p8-expansion/business2/`；旧冻结经营证据留`.art-work/p8h-final2/`。用户确认经营页面验收通过，经营阶段关闭范围见[P8.h记录](docs/farming/phase-08h-90日经营验收与交付.md)。场景美术与Windows独立包已在P8.6交付；动物新模型、设施工作特效、采后形态、音乐、繁殖寿命及上游接线另排。参考[资源/工艺表](docs/farming/phase-08-资源与工艺表.md)、[研究关系](docs/farming/phase-08-研究与生产关系.md)和[阶段索引](docs/farming/phase-08-分阶段实施计划.md#独立开发文档索引)。旧版通过`v2`/`v1`/`v0`显式进入，各自档案隔离；V2仍采用P7一人一设施规则。
> **扩地收尾：** 地权与schema17实装，69项专项通过；旧schema16 P8档需重新开档，不删除或迁移原文件。购地入口、价格与事务见[扩地方案](docs/farming/phase-08h-扩地与经营余量方案.md)，最终证据见P8.h末尾记录。
> **现场记录：** P8页面接受来自本次用户确认；代理已执行的GUI事件/截图与未执行的完整原生鼠标/窗口焦点流程分别留档，不将用户接受改写为代理执行记录。P7历史原生桌面补验同样不追加为P8前置。
> 交接对象：新机器上的开发者或 AI 会话。
> **开工前必读：§2 新机器清单 → §6 命令自检；现行主线是种植模块，先读 [docs/farming/master-plan.md](docs/farming/master-plan.md)；改 demo 地图前必读 [docs/map-schema.md](docs/map-schema.md)。**

## 1. 项目定位（三句话）

1. **rpgmap 是实验沙盒**：验证「tile 网格内核 + 确定性地图工作流」能否支撑两类复用场景——
   星露谷式多城镇（单镇多张功能地图 + 特殊交互点）和野外战斗触发图（地图只抛事件不承载战斗）。
2. **daoyan 接入不是现阶段任务**：`docs/daoyan-reuse-plan.md` + `-answers.md` 是背景资料
   （将来移植的目标形态与接口摸底），实验期间**只读不改** daoyan 仓库。
3. **P8.7世界素材采用Blender建模并离线渲染2D PNG**：美术工作区为`C:/Users/88445/Desktop/blender_assest`；
   七植物、15设施及3资源点已接入，源工程只读，正式运行不依赖美术工作区。当前交付见[Phase 8.6](docs/farming/phase-08.6-场景美术统一与可读性整改.md)。历史image_gen/ComfyUI资料保留；新非像素素材使用对应QC，不套旧二值alpha和量化规则。

## 2. 新机器快速上手（checklist）

1. `git clone https://github.com/onestudentforcode/rpgmap.git`（Windows 环境；脚本为 .bat）
2. 安装 **Godot 4.7.2 stable**（标准版即可；另有 `_console.exe` 后缀版用于看输出，可选）
3. 安装 **Python 3 + Pillow**（仅 `tools/` 脚本需要；无 Pillow 时除资产生成外均可正常开发）
4. 告诉启动脚本引擎路径（二选一）：
   - 设环境变量 `GODOT_EXE` / `GODOT_EXE_CONSOLE` 指向 Godot 可执行文件（推荐）
   - 或直接改 `play.bat` 顶部的默认路径
5. 首次运行 `test.bat`：执行资产QC、工具测试及V0/V1/V2/P8完整回归；`test-v1.bat`、`test-v2.bat`、`test-p8.bat`可分开运行对应版本检查。
   **预期输出 FARMING TEST SUITE OK**；`play.bat --selftest`单跑P8源码隔离冒烟，V0逻辑用`play.bat farm --farmtest`，历史phase00/demo自测见`docs/farming/testing.md`。
6. 运行`play.bat`或Godot F5进入P8.7；`play.bat p8`等价，`test-p8.bat`验证配数/模型/手册/源码冒烟及投影/交互。P8.7独立包已交付，构建入口为`tools/farming/build_p87_demo.ps1`。历史V2用`play.bat v2`，其原包和`tools/farming/build_v2_demo.ps1`保留；V1/V0用`v1`/`v0`，旧演示`demo`，phase00 `farm0`。

## 3. 当前状态

- **P0–P4 全部完成**（阶段详情与验收记录见 [docs/demo-phases.md](docs/demo-phases.md) §3）：
  - P0 内核 MVP（网格地图/行走精灵/对话/双图切换）
  - P1 数据外置 + 烘焙管线（JSON 源数据 → bake 校验/规范化/manifest → 运行时只读）
  - P2 主题包换肤（palette_overrides + per-tile 绘制风格；同布局多主题已验证）
  - P3 类型化交互点（dialogue/menu/chest/battle/save；接缝信号 menu_command、battle_requested）
  - P4 野外场景（wilds 主题 + 40×30 滚动图 + 明雷遭遇 + 跨主题门户/换装）
- 内核需求 **R1–R9 全部验证**（demo-phases.md §2 的表格）
- 内容规模：3 主题 × 5 地图（大厅/后廊/储物间/坊市/荒地）、14 门户
- **2026-10-08 立项转向：灵植经营模块（种植系统）从零重构**，总规划见
  [docs/farming/master-plan.md](docs/farming/master-plan.md)（唯一权威）：
  - 完全放弃旧经营地基（最近一次提交的 Blender 管线实验）——**已于 2026-10-08 归档至
    `archive/old-farming/`**（Phase 0 任务 0.1 完成：引用复核零依赖、selftest 复核通过），
    **禁止作为新模块依赖**；新模块规范见 phase-00 §4
  - 保留复用：bake 纪律、自测/截图基建、QC 铁律、地图内核（作为「游戏侧」对接面）
  - **Phase 0 已完成（2026-10-08 关闭）**：D1=tile 64×64 冻结、美术规范冻结
    （phase-00 §4）、拼接验证场景落地；详情与已知坑见
    [phase-00](docs/farming/phase-00-技术基线与重构准备.md) §7/§8
  - **Phase 1 已完成（2026-10-08 关闭）**：地形分层栈（草/泥/石板 + 动态耕地）+
    LandGrid 状态/原子占用模型 + 增量渲染 + 纯逻辑存档；过渡边缘观感问题挂起
    （P1-C，待 AI 素材替换时统一处理）
  - **Phase 2 已完成（2026-10-08 关闭）**：时间体系（24 时节×15 天×24 行动点，
    AP 归零自动次日）+ 作物生命周期（GROWING/MATURE/REGROWING/EXHAUSTED，
    有限次再生+枯竭清理）+ 多素材产出（确定性掷量）+ 库存 + 存档 v2；
    farmtest 40 项全过（详见 [phase-02](docs/farming/phase-02-核心种植系统.md)）
  - **Phase 3 已关闭**：四类地面与现有两种植物正式图片已接入，资产管线与过渡验收完成；
    详见 [phase-03](docs/farming/phase-03-AI作物资产管线.md)。
  - **Phase 4 已关闭**：四类作物运行、介质/多格/存档和正式图齐备；用户审核果树B＋菌菇A后完成衍生。
    清单31项均交付或程序生成，31项QC/20项工具/67项流程及前后遮挡像素验证通过；
    详见[phase-04](docs/farming/phase-04-四类作物扩展.md)。
  - **Phase 5已关闭（本仓库闭环）**：60元石、木属性食材、饱食度6（每日/指定成功行为各减1）、
    集市/喂养面板、介质材料消耗、schema3兼容存档；31项QC/23项工具/97项流程检查通过。
    详见[phase-05](docs/farming/phase-05-喂养与经济闭环.md)；上游实际接线尚未实施。
- demo 实验的 P5/P6 **暂缓**（P5 跨机器出图协作模式由种植模块 Phase 3 继承）
- 开放问题（命名/持久化深度/战斗桩深度）见 demo-phases.md §6，均给了默认值，不阻塞

## 4. 文档地图

| 文档 | 内容 | 何时读 |
|------|------|--------|
| [docs/farming/master-plan.md](docs/farming/master-plan.md) | **灵植经营模块总 Phase 规划（现行主线）** | **开工先读** |
| [docs/farming/phase-08.7-相机机位与地面投影统一.md](docs/farming/phase-08.7-相机机位与地面投影统一.md) | **P8.7已完成：35°投影、阴影、交互/相机及Windows交付** | 当前画面与交付先读 |
| [docs/farming/phase-08.6-场景美术统一与可读性整改.md](docs/farming/phase-08.6-场景美术统一与可读性整改.md) | **P8.6已完成：场景统一、全场检查及Windows独立包交付** | 当前美术与交付先读 |
| [docs/farming/phase-08.5-建模素材接入与场景美术.md](docs/farming/phase-08.5-建模素材接入与场景美术.md) | **P8.5已完成：Blender渲染2D、植物/设施接入与发布管线** | 追溯素材管线时 |
| [docs/farming/phase-08-生态产业网络与工艺研究.md](docs/farming/phase-08-生态产业网络与工艺研究.md) | **P8已关闭的生态/研究/人力经营基线** | **经营主线先读** |
| [docs/farming/phase-08-资源与工艺表.md](docs/farming/phase-08-资源与工艺表.md) | 6物种/8设施/24工艺，资源ID/价格/守恒/成本初值 | 配数与配置落地前 |
| [docs/farming/phase-08-研究与生产关系.md](docs/farming/phase-08-研究与生产关系.md) | 三层12研究DAG、样本来源与三组生产网 | 实施解锁与路线前 |
| [docs/farming/phase-08-分阶段实施计划.md](docs/farming/phase-08-分阶段实施计划.md) | P8.a～h实际记录、e/f联验、双120日与本地关闭 | 查阅验收与改动边界 |
| [docs/farming/phase-08a-数据配数与事务底座.md](docs/farming/phase-08a-数据配数与事务底座.md) | 已完成的独立档案、成本编译/分摊、日界候选及基础换水 | 调整底座前 |
| [docs/farming/phase-07-V2养殖与资源循环.md](docs/farming/phase-07-V2养殖与资源循环.md) | 已关闭P7 / V2范围、实现与验收 | 核对历史养殖基线时 |
| [docs/farming/phase-07a-验收记录.md](docs/farming/phase-07a-验收记录.md) | 已完成底座、实际10日台账与尚未验收养殖边界 | 核对当前运行事实 |
| [docs/farming/phase-07b-养殖基础与成长.md](docs/farming/phase-07b-养殖基础与成长.md) | 已完成幼体/成长/基础维护、水体与资源一览的设计依据 | 调整既有养殖时 |
| [docs/farming/phase-07c-特殊生产与养殖回流.md](docs/farming/phase-07c-特殊生产与养殖回流.md) | 暂不生产、特殊周期/唯一收取、粪肥回流与供货 | 实施P7.c前 |
| [docs/farming/phase-07d-设施负责人.md](docs/farming/phase-07d-设施负责人.md) | 一人一设施不兼职、开放人数、巡栏/计件费与现金风险 | 实施P7.d前 |
| [docs/farming/phase-07e-经营总览与资源关注.md](docs/farming/phase-07e-经营总览与资源关注.md) | 总览定位、初始空关注提示/按槽保存、条目与45天累计 | 实施P7.e前 |
| [docs/farming/phase-07f-试玩验收与V2交付.md](docs/farming/phase-07f-试玩验收与V2交付.md) | 双路线45日、回归/UI/Windows包及验收后默认切V2 | 实施P7.f前 |
| [docs/farming/phase-06.5-UI美化与交互完善.md](docs/farming/phase-06.5-UI美化与交互完善.md) | 已验收UI基线、三个批次与验收规则 | 调整界面时 |
| [docs/farming/ui-design/phase65-interface.md](docs/farming/ui-design/phase65-interface.md) | 用户决定、布局/尺寸、图标与四条高频流程；含交互草图入口 | 实施Phase 6.5时 |
| [docs/farming/demo-v1-plan.md](docs/farming/demo-v1-plan.md) | 已关闭V1的玩法基线、实施与验收记录 | 查阅现行玩法时 |
| [docs/farming/demo-v1-employment.md](docs/farming/demo-v1-employment.md) | 普通雇工、任务标记、调度与存档规则 | 调整派工时 |
| [docs/farming/phase-04-四类作物扩展.md](docs/farming/phase-04-四类作物扩展.md) | V0介质与大画布契约、执行记录 | 查阅既有作物/资产时 |
| [docs/demo-phases.md](docs/demo-phases.md) | demo 实验阶段规划与验收记录（P0–P4） | 内核/工作流背景 |
| [docs/map-schema.md](docs/map-schema.md) | 地图/主题数据格式 + bake 流程 | **改 demo 地图/改主题前** |
| [docs/assets-spec.md](docs/assets-spec.md) | 美术资产规格（ComfyUI 对接） | demo 美术回填时；种植模块美术规范以 Phase 0/3 新产出为准 |
| docs/daoyan-reuse-plan(-answers).md | daoyan 背景与接口摸底 | 仅背景，勿据此实施 |
| [todo.md](todo.md) | P0 历史清单（已全部完成） | 考古 |

## 5. 架构速览

```
content/maps/*.json + content/themes/*.json     ← 唯一事实源（手工维护，进 git）
        │  python tools/bake_maps.py（校验 + 规范化 + manifest）
        ▼
content/baked/<theme>/…                          ← 烘焙产物（生成物，进 git，运行时唯一读取物）
        │  scripts/map_host.gd（加载/构建 TileMapLayer/物件/交互区）
        ▼
scripts/main.gd（状态机：移动/对话/菜单/战斗桩/切图）
```

- `scripts/`：`main.gd` 主控与状态机 + 两条接缝信号（`menu_command`/`battle_requested`，
  正式实现时分别桥接宿主命令分发与战斗入口）；`map_host.gd` 烘焙加载器；
  `player.gd`（含主题换装 retheme）；`dialogue_ui.gd`；`menu_panel.gd`；
  `interactable.gd`（靠近交互区）；`game_state.gd`（消费型状态，进程内，
  **移植时替换为引擎快照字段**）
- `tools/`：`bake_maps.py`（烘焙）；`gen_placeholder_assets.py`（按主题生成占位美术，含 QC）
- `assets/themes/<id>/`：各主题贴图（图集布局全主题一致，只有色板/风格差异）

## 6. 常用命令

```
play.bat                        # P8本地生态经营、三槽、研究与新手手册
play.bat p8                     # 与默认入口等价
play.bat v2                     # 历史V2养殖基线及独立存档
play.bat v1                     # 历史V1农务与加工基线
play.bat v0                     # V0独立开始页与旧存档
test-v1.bat                     # V1模型、界面、经营记录与隔离冒烟
test.bat                        # 资产QC + 工具测试 + V0/V1/V2/P8完整回归
play.bat --selftest             # P8源码隔离冒烟（headless）
play.bat --shots=DIR            # P8隔离预览截图
play.bat demo wilds             # 旧商场/野外演示，显式入口
play.bat demo --selftest         # 旧演示测试，按需单独运行
test-p8.bat                      # P8配数/模型/手册一致性/源码冒烟

python tools/bake_maps.py               # 烘焙（改 content/ 后必跑；校验失败即退出）
python tools/gen_placeholder_assets.py  # 重新生成占位美术（读 themes/*.json 色板）

# —— 种植模块（farming）——
python tools/farming/bake_farm.py          # 种植数据烘焙（改 content/farming/ 后必跑）
python tools/farming/gen_farm_terrains.py  # 重生成地形占位纹理（--verify 只校验）
python tools/farming/gen_farm_crops.py     # 重生成作物占位阶段图（--verify 只校验）
python tools/farming/gen_asset_manifest.py # 资产采购单（改数据/交付资产后重跑；--missing 查缺）
python tools/farming/gen_farm_terrains.py --transitions-only # 正式地面回传后仅重建 atlas（不覆盖 ground）
python tools/farming/qc_assets.py --target all # 正式资产统一检查（占位差异见 art-pipeline.md）
python tools/farming/build_art_handoff.py --batch ground --output .art-work/handoff/ground # 空输出目录
play.bat farm                              # 主农场场景（开垦/种植/采收/存档）
play.bat farm --farmtest                   # 种植/经济/Demo存档流程自测（当前 234 项）
play.bat farm --fresh                      # V0无存档开发预览；V1新游戏从默认开始页选槽
play.bat farm0                             # Phase 0 拼接验证场景（历史回归）
```

**纪律：改 `content/` 源数据后先 bake 再跑自测/游戏**（自测读的是烘焙产物）。
改 `assets/` 贴图后，编辑器打开会自动重导入；纯命令行场景跑一次
`godot --headless --path . --import`。

## 7. 当前闭环与后续阶段

**Demo V1已关闭，Phase 6.5也已实施并验收。** 当时默认为V1；当前默认`play.bat`/F5已切P8，V1由`play.bat v1`进入，V0通过`play.bat v0`保留；历史应用标识不变。2560×1440主规格及三种兼容窗口、100/125/150% UI缩放通过，58个SVG与独立设置接入，79项新增UI检查、原有回归及13项发行版冒烟通过。具体见[Phase 6.5关闭记录](docs/farming/phase-06.5-UI美化与交互完善.md)。完整世界场景美术仍需另批，后续世界图片继续核对拼接、机位及光照。

**Phase7/V2已完成并经用户确认关闭，原生桌面试玩移交后续补验。** 两条独立新档各45日无注入、满容量持续供料、五行供货、两种粪肥实际回流、收入再投资及46日冻结均通过。331项P7边界、19项GUI事件、12组/96张截图、V1/V0/历史回归、导出/解压各15项完整冒烟已执行。包含内嵌PCK的exe、README及逐文件manifest/SHA256；原始90日台账、哈希与命令详见[验收记录](docs/farming/phase07-v2-playtest.md)。P7关闭时schema11、默认V2、无旧档迁移、人数不限；现在由`play.bat v2`显式进入。原生Computer Use不可用，原生桌面全流程不得记为已通过；该补验不阻塞阶段关闭。

**P8经营基线与P8.7投影交付已完成。** 数据/成本/候选日结底座、研究、三组生态、多设施负责人/兼任、普通及活体生产策略、田间装置与五行灵食均已运行。当前schema17，新档90元石；扩地双120日924项检查及严格台账审核、每路线27条新工艺正常收取及全部产物后续消费通过。用户确认经营页面验收通过，11章新手手册与独立文档同源。`play.bat`/F5默认P8；扩地、P8.7场景投影及Windows独立包均已交付。经营关闭证据见[P8.h](docs/farming/phase-08h-90日经营验收与交付.md)，当前投影、阴影、回归与包证据见[P8.7](docs/farming/phase-08.7-相机机位与地面投影统一.md)。

历史V1基线：逐条摘要/时节小结、首次45天总计与三个时节小计已接入；无注入经营路线初始60→298，121项记录、51项原界面及79项Phase 6.5界面检查通过。独立包`dist/LingTianDemoV1-Windows-x64.zip`包含明亮矢量UI与占位世界美术，解压运行`LingTianDemoV1.exe`，说明见[demo-v1-操作说明](docs/farming/demo-v1-操作说明.md)。重建使用`tools/farming/build_v1_demo.ps1 -GodotExe <控制台路径>`，需匹配的Windows release模板；13项打包后冒烟通过。旧V1从升级当天开始记录，已过45天的旧档无法补造首次回顾。下述Phase记录为V0基线。

Phase 0–5已关闭；Phase5以本仓库种植经济闭环为完成条件，对上游保留适配接口。
Phase6范围已由用户确认，草案见[phase-06](docs/farming/phase-06-Demo体验与三槽存档.md)：
开始菜单/引导、三槽每日自动存档（撤除玩家手动存读）、首个45天经营回顾、购买高级3×3工具（成功AP总成本折半向上取整）与设置。
P6.a/P6.b已完成：默认进入Demo开始菜单、三槽选择/删除/覆盖/导入、每日自动保存及统一退出流程。F5/F9和手动存读按钮撤除。
P6.c已完成：成功行为统计、首次45天冻结回顾与菜单重看，随所属槽保存。P6.d已完成：M工具页购买高级锄头/播种器/采收器，工具栏普/高切换、中心3×3范围、整批成功AP折半取整及工具槽隔离。P6.e已完成：七步成功操作教学、跳过/重看/日存档恢复，主菜单与游戏菜单显示设置开放。P6.f完成45天自动经营/截图审核与Windows独立包；31项QC、25项工具、234项流程，另12项试玩与8项发布检查通过。Phase6关闭，价格保留试玩初值，个人体验反馈另行调整。

Windows试玩包：`dist/LingTianDemo-Windows-x64.zip`，解压运行`LingTianDemo.exe`；操作说明见`docs/farming/demo-操作说明.md`。重新构建：配置`GODOT_EXE_CONSOLE`与同版本Windows release模板，执行`tools/farming/build_demo.ps1`。发布包只含当前农场，旧demo/Phase00和开发测试不随包交付；历史工作区入口仍保留。构建产物、隔离验收日志与截图不提交Git，原始45天台账及评估位于`docs/farming/phase06-playtest.*`。
全局显示设置单独保存于user://farm_demo_settings.cfg：全屏/窗口分辨率、垂直同步或帧率上限与FPS显示；教学状态随游戏槽保存。
不新增作物/人物/美术/音乐，不实现蛊虫主动能力或实际上游接线。
游戏中M打开库存/集市/喂养，R进入次日；指定行为调用`record_gu_use(behavior, succeeded)`，默认允许battle。
现有四类作物正式图全部保留，后续美术继续适量加入东方玄幻意象；母版先人工审核后衍生。
完整生成记录见docs/farming/art-generation-phase04.json，原图/候选/失败报告保留在.art-work/。

已冻结基线（后续阶段直接遵守）：

- tile **64×64**；分层地形栈 + 自研 bitmask 过渡（`trans_upper_*`）；美术规范
  phase-00 §4 + 素材替换契约 phase-01 §2.6（现有两种植物已使用正式图；
  逻辑零像素依赖；替换后必跑 QC → farmtest → 截图核对）
- `LandGrid`（WILD/TILLED/PLANTED/OCCUPIED-prev/UNAVAILABLE + 原子多格占用 +
  增量信号）与 `CropManager`（GROWING/MATURE/REGROWING/EXHAUSTED、
  harvest_items 多产出、max_harvests 有限采收、(uid,count) 确定性掷量）+
  `FarmClock`（24 时节×15 天×24AP，day_changed 离散推进）
- 数据纪律：`content/farming/` 源 JSON → `bake_farm.py` → `baked/`（运行时唯一读取）

现有正式图片不得被占位生成覆盖。使用 B 在空耕地轮换介质，每次消耗 1AP；准备菌床/朽木另扣对应商品1份；
当前介质外观为临时色块。大画布按 sprite_size 登记，逻辑占地仍由 footprint 决定。
默认测试仅覆盖当前种植模块，旧 demo 与 farm0 保留显式独立入口。

## 8. 机器相关差异与已知坑

- **引擎路径**：本仓库历史路径（daoyan/.tools/...）只属于旧机器——新机器务必配置 §2.4
- **gitignore 的三类文件**：`*.import`（首次运行自动重建）、`.godot/`（引擎缓存）、
  `.shots/`（截图产物）——clone 后缺失都是正常的
- **占位美术 QC 铁律**（历史上右向行走整行空帧导致"角色凭空消失"的事故，
  见 demo-phases.md P1 修复记录）：alpha 二值、NEAREST、逐行不透明度检查已内置在
  生成器 QC 里；回填正式图时 QC 工具必须同等强度
- **双主题布局一致性自检**（selftest 内）：同一布局被多个主题共享时，改布局会影响
  所有引用主题——这是设计使然，自检失败通常意味着烘焙未重跑
- 对话防误触冷却 60ms、切图门户冷却 400ms：调手感时别把防回弹机制调没（出生格
  必须不压触发格，bake 有校验）

## 9. 新 AI 会话交接边界

1. 先读本文档 + docs/farming/master-plan.md（现行主线），然后跑 `test.bat` 确认种植模块基线；详见`docs/farming/testing.md`
2. 一切地图/主题修改走「源 JSON → bake → 验证」流程，禁止手改 `content/baked/`
3. 不改daoyan；Phase5本仓库闭环已完成，上游实际接线另行授权。出图以image_gen及统一后处理/QC为准
4. 提交纪律：**每个小阶段（任务级）完成即 git 提交**，不等整个 Phase 收尾；
   Phase 级收尾另加：自测全过 + 截图人工核对 + 验收记录勾选
5. 种植模块一切以 master-plan.md 为准：一次只展开当前 Phase；旧经营地基
   （Blender 管线实验文件，见 master-plan 附录 A.3）仅作参考，禁止作为新模块依赖

### P7.f技术交付命令

```powershell
.\test-v2.bat
.\play.bat v2 --selftest
powershell -NoProfile -ExecutionPolicy Bypass -File tools/farming/review_v2_ui.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/farming/build_v2_demo.ps1
```

界面矩阵依赖双45日回放生成的实际快照，先执行`test-v2.bat`。测试隔离槽自动清理，不使用玩家目录。构建产物/中间日志/截图分别留`dist/`、`.art-work/`、`.shots/`；完整台账与说明已提交。原生桌面鼠标完整试玩待补，具体环境错误和补验路线见P7.f记录。
