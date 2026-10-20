# 当前农场测试与历史入口

> **2026-10-20 P10.7本轮技术验收完成：** schema25，统一入口`test-p10-7.bat`；[总验收记录](phase107-validation.json)为true，保存全部必需分区的源码、依赖、引擎、日志及产物哈希。选定模型/知识回归合计3573项（含核心54、磁盘事务49、契约48、农业324、陆地558、服务261、物种482、水产285、参考夹具942、矿物364、生态57、百科44、手册105）；另有无图形界面UI20/GPU23、配置测试8、审计测试15。六短场景外部审计10279项，93日整合冒烟1616项、零死亡。范围与限制见[需求证据对照](phase107-completion-audit.md)，当前参数见[阶段页§11](phase-10.7-经济口径修正与生产路线再平衡.md#11-当前实现与验收记录2026-10-20)。这不是对所有历史测试入口的通过声明。

> **P10.7分层证据与补跑：** `stage-orders`、`stage-resources`、`research-access`、`barter`、`specialist-route`、`growth-budget`已各自生成≤30日独立快照、命令与收据，审计从外部库存/现金重建。无注入新档19日累计12次供货；声明起始条件的成长场景25日，实际两次扩建、首收周转后5轮完成目标包。[经济报告](phase107-economy.md)分列首轮/稳态/捕捞成本、现金与标准筛查、条件推算及实测；捕捞切换等待1日/分配1AP已计入，实际四单位鲤7日/油鱼9日逐项核对。配置以正有理数势函数检查纯兑换及买卖＋兑换组合，生产正AP/时间另行评价。长线只查策略无关稳定性与覆盖，不要求经营达阶段3、全研究或终态财富。旧P10.6证据不改，主观试玩不代签。

```powershell
.\test-p10-7.bat -Stage Plan
.\test-p10-7.bat -Stage Model -Models transactions
.\test-p10-7.bat -Stage Run -Cases barter
.\test-p10-7.bat -Stage Audit -Cases barter
.\test-p10-7.bat -Stage Probes
.\test-p10-7.bat -Stage Report
.\test-p10-7.bat -Stage UI
.\test-p10-7.bat -Stage Smoke
.\test-p10-7.bat -Stage Accept
```

默认全链复用未变且完整的分区；`-Fresh`只重跑本次所选工作，经营/冒烟重跑前归档旧证据。审计改动可只重审，源代码或产物变化使依赖证据失效；`-SkipGpu`仅作局部检查，不能代替完整Accept。日志要求退出码、成功标记及错误扫描均通过，仅豁免精确已知Windows根证书读取诊断。GPU临时关闭不可写着色器缓存，运行后清理临时配置；不豁免其他引擎错误。未运行整个历史`test.bat`；下方旧阶段数字保留其历史含义。

> **2026-10-20 P10.6已实施并技术验收：** `test-p10-6.bat`默认链：烘焙检查→`run_phase106.gd`模型285→`run_p103.gd`模型556→`run_fixture_lint.gd`参考夹具自检942→`run_p106_playtest.gd`八场景回放117（单条≤30日，证据`.art-work/p106-playtest/`）→`audit_p106_playtest.py`收据审计733→`test_p106_audit.py`十一类篡改探针；`-SkipPlaytest`仅秒级检查，`-AuditExisting`只重审已有证据。里程碑冒烟`run_p106_smoke.gd`一条90日跨模块整合1453项按②类口径通过（仅策略无关不变量＋覆盖清单），证据`.art-work/p106-smoke/`。schema24；回放期修复合并悬空房间/拆分占地规则/凭证截断进度三处引擎缺陷。`run_phase101`/`run_phase10`各六项失败经worktree复验为P10.6前已存在。下方公告按历史阅读。

> **2026-10-19 长线冒烟改造与120日常规门禁退役（用户确认，P10.6起生效）：** 依据P10.5收口实践——P8的120日回放五轮迭代仅1项真发现（P10.4玩具站结构漂移属跨模块集成回归），其余全是测试脚本自身的策略调度校准；而≤30日模块回放＋收据审计器抓住了本阶段全部规则问题且零误报。据此：①每阶段/收口的常规120日A/B门禁**正式退役**（v1.45已降级，此次为最终确认），历史证据保留不追溯；②里程碑级单条60~120日冒烟**保留但改造断言**——只断言策略无关的稳定性不变量：逐日干净收账、账本守恒（审计器）、无动物意外死亡（故意断粮场景除外）、疲劳/禁工有界、库存与现金非负、快照编解码往返一致、机制覆盖清单勾选；**禁止**研究全完成/五行供货/终态库存阈值等经济终点断言——经济可行性由标准成本表与专项成本对照负责，经济存在性证明用累计领取收据（宽松下限），不用终态库存；③新增秒级**参考夹具自检**（①层扩展）：各阶段标准模块布局存为静态清单，断言当前配置下所有分区结构合格、维持→获岗→恢复循环可数日跑通无罢工——玩具站类跨模块结构漂移3秒暴露，不再等20分钟长跑；落地为P10.6首个小任务。长跑仅保留两个不可替代职责：跨模块干扰、长周期雪球。

> **2026-10-19 并行执行约定（用户确认，P10.5起生效）：** 重型回放（≥10分钟的Godot套件）允许**跨套件并行**，规则如下——①并行单位是"套件"，不同套件必须写各自独立证据根（`.art-work/<suite>-playtest/`），同一套件的多个实例禁止并发；②套件内场景/路线保持串行（共享收据文件句柄）；③一切临时目录/槽名必须含`OS.get_process_id()`（P10.5已把`get_ticks_usec()`裸名全部改为`PID+ticks`：历史损坏的根因是两进程启动滴答相近导致证据目录同名互写，出现160KB截断与"无法替换正式存档"，非引擎不能并行）；④并行度取物理核数一半左右，Godot单套件单线程，Python审计器可随后并行；⑤模型/契约专项（秒级）不值得并行，照旧串行；⑥并行运行中禁止对同一证据根做归档/移动操作。快速入口：PowerShell `Start-Job`/`Start-Process` 分发各`test-p10-*.bat`，或参考`.art-work/closure_run*.py`的顺序版改造。旧"长套件必须严格串行"的口径作废，改为上述隔离规则。

> **2026-10-19 P10.5草案待实施：** [阶段页§14](phase-10.5-陆生物种扩充与精养生产.md)规划三用途互斥/钢绵羊迁移、四精养工艺、六新物种/群与容量、桑叶—蚕丝、灵液交易、役使/建材和系统保存七个短分区；精养进度/付料/领取去重、疲劳递推、禁止蚕繁殖须独立审计并做篡改探针。保持≤30日模块主体，只有里程碑一条60～120日整合；整合须外部逐日保存完整库存/现金账，不能以末15日尾账冒充全程。拟新增P10.5执行入口，目前没有脚本/通过证据，本次不跑玩法测试，代码仍schema22。下方为已交付历史记录。

> **显式边界前置（2026-10-18）：** `run_room_boundaries.gd`46项；`run_room_boundary_playtest.gd`固定夹具仅3日、18项；`python tools/farming/audit_room_boundaries.py .art-work/p104-boundary/scenario.json`收据及库存对账；`python -m unittest discover -s tools/farming -p test_room_boundaries_audit.py -v`诚实场景与四类篡改检查通过。证据`.art-work/p104-tests/boundary*.log`和`.art-work/p104-boundary/scenario.json`，设计见[明文规则](房间归属与连通设计.md)。当前开发schema22，后续P10.4整合只在里程碑安排一条长线冒烟，历史长回放不改。

> **2026-10-19 P10.4已实施并技术验收：** `test-p10-4.bat`默认Model，Plan/Run/Audit/Probes/UI/Smoke/Accept独立执行，可`-Cases toy -Rerun`归档并只重跑该分区。模型261、容量/小数342、农业317、畜牧555；八短场景900、Python4测试含八类审计篡改、实际GPU31、一条完成的60日整合780通过。服务全60日独立审计，库存独立审计为保存的末15日，更早逐日运行时/Codec已校验；没有全程外部库存账。当前schema22。见[补跑说明](p104-分层验收与补跑.md)与[当前证据](phase104-validation.json)，后续旧公告按历史阅读。

> **2026-10-18 分层测试约定（用户确认，P10.4起生效）：** 120日全量A/B回放降级，验收口径改为——①模型/契约专项（秒级，日常迭代门禁）；②模块级场景回放（每阶段必做，≤30日，固定夹具＋确定性断言＋收据级审计器，规则可行性在此证明）；③模块级A/B（需对比策略时才做，仅含本模块的小经济，对比信号比全量干净）；④长线冒烟（仅里程碑：schema跳版或跨模块整合时跑**一条**60~120日全量，天数按清单覆盖而非固定，只负责跨模块干扰与长周期雪球两类问题）；⑤审计器与天数无关，账本守恒/递推校验/篡改探针保留在每阶段。经济可行性改用专项成本对照（购入vs繁殖vs长期供给的静态＋短程账），不再隐含在长回放里。历史各阶段的120日A/B证据保留为历史交付，不按新口径追溯重跑。


> **2026-10-18 P10.3交付：** `test-p10-3.bat`默认链：烘焙检查→`run_phase103.gd`模型549→`run_p103_playtest.gd`九路线经营1047（短场景×5＋役使/圈养A/B各120日）→`audit_p103_playtest.py`收据级审计→`run_p103_probes.gd`六类Codec篡改探针；`-SkipPlaytest`仅快速检查。证据`.art-work/p103-playtest/`。UI自动化测试按用户指示豁免；P8双路线120日（944）与审计在收口串行重跑通过。

> **2026-10-18 P10.3.a冻结：** 参数与契约冻结见[阶段文档§14.1](phase-10.3-陆生动物分区与日程.md)。实施将新增`run_phase103.gd`模型专项与畜牧经营审计器；当前仍无P10.3测试脚本，游戏schema20。

> **2026-10-18 P10.3待实施：** [陆生动物分区与日程](phase-10.3-陆生动物分区与日程.md)§12列出短场景、分区经营、跨日维护/禁工、床位并发、劳动/疲劳、资源守恒及出生防重领的验收要求。当前没有P10.3测试脚本或通过证据；本次仅起草设计，游戏仍schema20。后续新审计器须覆盖动物单位账本，不能直接以旧农业审计器或旧120日结果替代。

> **2026-10-18 分区执行：** 已增加配置/策略八分区与独立Plan/Run/Assemble/Audit/Probes/Accept阶段。一条失败不会取消其他选中路线；只补跑指定分区，重跑前归档原文件。审计修正可以直接重审账本，源码清单变动仍使旧证据失效。新工具全套146项（含分区专项17项）、真实单条B的120日补跑及组装/审计/探针通过，A原文件与B归档均逐文件验证未变；原八条仅重审通过、没有重玩。使用命令与边界见[分区回放说明](p102-分区回放说明.md)。下方P10.2的129项与哈希记录为该阶段交付时的历史证据，保持原样。

> **2026-10-18 P10.2检查完成：** 当前schema20，不兼容早期P8档。`test-p10-2.bat`默认运行快速检查，再运行普通/育种/丰产/复合各独立A/B的120日经营门禁、完整产业与房间审计、16类篡改拒绝；`-SkipPlaytest`只做源/百科、Python、模型/UI、既有后勤/农业和知识检查；`-AuditExisting`只复核已有终态回放，不重跑游戏。默认证据目录`.art-work/p102-playtest/business-v5/`，可用`-EvidenceRoot`指定新目录。已有运行进程或中断账本会明确报错，须先检查，不覆盖原始证据。只豁免精确的Windows根证书读取环境警告，其他Godot错误均失败。模型209/UI30/GPU37、Python129、完整P8与历史V1/V2、八条120日经营、四组完整审计、16类篡改拒绝及`-AuditExisting`全部通过；见[P10.2§14](phase-10.2-地板与农业房间.md)、[成本回报](phase102-business.md)与[机器记录](phase102-validation.json)。下方旧schema及旧阶段经营脚本按历史记录阅读。

P10.2复核命令：

```powershell
.\test-p10-2.bat -SkipPlaytest
.\test-p8.bat -WorkspaceStores
powershell -NoProfile -ExecutionPolicy Bypass -File tools/farming/test_p102_historical.ps1
.\test-p10-2.bat -AuditExisting -EvidenceRoot .art-work/p102-playtest/business-v5
python tools/farming/report_p102_business.py .art-work/p102-playtest/business-v5
python tools/farming/record_p102_validation.py .art-work/p102-playtest/business-v5
```

历史回归执行原V1/V2断言，仅把测试存储路径替换到工作区；V1默认存档命名空间断言保持。新增测试夹具只用于旧视觉场景的成熟状态，不用于生长奖励或正常经营证明。快速Godot检查每项60秒；经营进程每条15分钟，默认4条并行（独立脚本可设`-Parallel 1…8`，本批使用8条），超时只终止本脚本登记的进程树。P10/P10.1旧长回放操作器用于原历史证据；当前农业区经营请使用P10.2入口。终态快照成本累计到clock120，续跑开日121单独留证；不把续日费用混进对照表。

> **2026-10-16 P10接入：** 默认入口继续沿用P8.7投影，新增后勤蛊玩法与schema18（兼容读取schema17）。`test-p10.bat`检查源契约、模型/界面、手册/百科及有/无蛊各双120日回放和严格审计；`-SkipPlaytest`可只跑快速专项。P10模型与界面检查已并入`test-p8.bat`及完整`test.bat`。当前执行证据见[Phase 10](phase-10-后勤蛊虫与生产协同.md#14-执行与验收记录)。下面的schema17/旧数量描述历史阶段证据。

> **P10最终结果：** 181项模型、21项界面（含真实Vulkan窗口）、99项Python工具、12章手册/196实体百科同源检查、完整`test.bat`通过。四条独立120日回放完成，两组`complete`严格审计通过，后勤12类/普通10类篡改拒绝通过；[机器可读记录](phase10-validation.json)保存源清单和证据SHA256。首轮外层退出码收集误报已修复并验证Godot退出0/1；最终以`-AuditExisting`重审未改动的原始回放。只豁免精确的Windows根证书读取环境警告。

> **2026-10-15 当前P8.7：** 默认`farm_p8.tscn`加载`p87_scene.gd`，保留schema17和原玩法。完整`test.bat`通过；最终89项投影、146项生产视觉、324项GUI信号交互专项通过，阴影补充后的60帧和独立包91/91/93项重新验证。运行`review_p87_trial.ps1 -ChecksOnly`复查专项，`review_p87_full.ps1`生成正式三窗口/缩放/侧栏矩阵，`qc_p87_visuals.py`检查资源及显式冻结的投影基准，`build_p87_demo.ps1`构建隔离包；[证据](art/p87-final-validation.json)。

> **P8.6历史基线：** 95项生产视觉及原48图/42帧证据保留；`qc_p86_visuals.py`、`review_p86_full.ps1`和固定原shell的`build_p86_demo.ps1`用于该历史批次。P8.5轮廓等价QC只适用于历史升分辨率批次，不用于有意修形或P8.7根点/投影调整。

> P8经营基线：本地测试阶段已完成；默认`play.bat`/F5为`farm_p8.tscn`。P8使用独立三槽`user://farm_demo_p8_slots`、schema17，V2/V1/V0及历史场景均显式进入。原应用标识保持，旧档不迁移到P8。用户确认经营页面验收通过；原先后置的Windows独立包已在P8.6完成，见[交付记录](art/p86-windows-delivery.md)。

## 日常流程

```powershell
.\play.bat                        # P8生态经营、新手手册、独立三槽
.\play.bat --selftest             # P8源码隔离冒烟（20项）
.\test-p8.bat                      # P8编译/配数/模型/手册/源码检查
.\test-p10.bat                     # P10专项与有/无蛊各双120日对照、严格审计
.\test-p10.bat -SkipPlaytest       # P10快速模型/界面/同源文档检查
.\test-p10.bat -AuditExisting     # 核验已有四路日志/源清单并重审原始账簿
.\test.bat                        # 资产、工具及V0/V1/V2/P8完整回归
.\play.bat v2                     # 历史V2及其独立档案
.\play.bat v1                     # 历史V1及其独立档案
.\play.bat v0                     # 历史V0菜单
.\play.bat farm --farmtest         # V0种植/经济/存档逻辑回归
.\play.bat farm0 --farmtest        # 历史phase00自测
.\play.bat demo --selftest         # 历史地图demo自测
.\play.bat --shots=res://.shots/p8-current
```

`test.bat`运行资产QC、Python工具/配置测试、V0流程、完整V1模型/UI、完整V2模型/双45日/控件/源码冒烟，以及P8开发门禁，成功输出`FARMING TEST SUITE OK`。单独的phase00/demo历史测试按上述入口运行，玩家经营流程不加载这些场景。

## 当前验收与证据

| 范围 | 实际证据 |
|---|---|
| P8配数与模型 | 15项配数，A77/B98/C85/D190/E89/F92/G116/H60，共807项模型 |
| P8界面/手册 | 20项源码启动检查、77项真实控件事件、手册导出一致性；2560×1440/100%四章滚动截图；用户确认页面通过 |
| P8扩地 | 69项专项、配置非法变体、11章导出；2560×1440和960×540购买及西侧水场截图 |
| P8经营 | 两独立新档各120日、924项扩地经营检查、27条新工艺每路线收取及全部产物后续消费，严格独立审计；当前证据`.art-work/p8-expansion/business2/`；schema16旧冻结证据`.art-work/p8h-final2/`保留 |
| V2 | P7模型331项、阶段正常回放、双45日、19项控件、14项源码冒烟 |
| V1/V0与历史 | 完整V1模型/UI/12项源码冒烟、V0 `FARMTEST OK`，历史phase00 `FARMTEST OK`及demo `SELFTEST OK` |
| 本地入口 | `play.bat --selftest`与项目默认主场景分别通过20项P8源码冒烟 |

2026-10-13最终日志在`.art-work/p8-close/`；完整套件和入口/历史日志已检查退出码、成功标记和原始错误输出。用户页面接受与代理实际执行证据分开，代理未执行完整原生桌面鼠标/窗口焦点流程；P8 Windows发行产物也未制作或验证，两者不作为本地阶段关闭条件。

经营重放按需执行`test-p8.bat -IncludePlaytest`，重新生成当前版本证据及审计；扩地收尾重新执行双120日，证据另存`.art-work/p8-expansion/business2/`，不修改先前冻结manifest。Godot错误可能返回0，读取日志并核对标记同样必要。受限Windows环境可用`tools/farming/test_p8.ps1 -WorkspaceStores`：只替换测试槽到工作区，并仅豁免固定系统证书库诊断，不豁免脚本或其他引擎错误。

后续按实际变更选择检查，不无依据反复全套回放。测试使用隔离槽，历史场景与发行工具继续保留显式入口。

## 历史V0流程与专项入口（参考）

游戏流程覆盖土地开垦、播种扣种与占格、生长、凝露草一次采收、赤纹果有限再生/枯竭/清理、
库存与时间推进、存档恢复；Phase 4新增介质/B键、混合介质拒绝、多格树木/真菌隔离fixture与旧存档恢复检查。
Phase 4.b另有真实果树/月华菇操作、产物入库、存读档、锚点和耕地渲染回归；
截图新增四类并排、果树阶段和采后菌床，供结构验收。
Phase 5增加19项经济核心检查与11项真实闭环/存档迁移检查；含指定成功行为与每日扣饱食度、
五行匹配、交易失败零变更、生产材料消耗、面板无AP交易/喂养及旧schema2默认经济迁移。
原有40项基础检查保留，Phase4介质夹具补所需材料。
P6.a增加30项三槽/快照检查：槽位会话隔离、确认覆盖/删除、schema2/3导入、占地与作物一致性、
校验和、临时文件/目录/替换失败、备份恢复、损坏快照加载零变更及扩展状态保留。
只操作`user://farm_phase06_slot_tests_<唯一编号>`目录，结束后清理，不接触玩家存档。
独立检查使用`--headless --path . --script scripts/farming/tests/run_phase06_slots.gd`，输出`PHASE06 SLOT TEST OK`。
P6.b增加26项真实菜单/自动存档/退出检查，使用`user://farm_phase06_demo_tests_<编号>`测试槽。
覆盖最后1AP的播种/采收/开垦/介质/清理、保存失败不退出及重试不多过日、退出取消/放弃、
覆盖/删除/导入和F5/F9不触发玩家存读。独立入口为`run_phase06_demo.gd`，输出`PHASE06 DEMO TEST OK`。
P6.c增加25项经营记录检查，使用专用测试槽：成功播种/收获/买卖/喂养、多格树与再生、44/45/46天边界、最后1AP、冻结读档重看、放弃当天回退、保存退出与正常过日失败重试、旧档45天区间、损坏统计拒绝。
独立入口为`run_phase06_records.gd`；通过时输出`PHASE06 RECORDS TEST OK`。
不加载旧商场/野外演示或Phase 0验证场景。
逻辑测试使用headless和独立测试存档；截图是单独的视觉验证流程。
现有色板精确值越界告警保留，QC错误才阻断。

Phase 4正式图完成后，可单独运行GPU前后遮挡检查（需要渲染窗口，不能加`--headless`）：

```powershell
& $env:GODOT_EXE_CONSOLE --path . --script scripts/farming/tests/phase04_depth.gd
```

应输出`DEPTH CHECK behind=true front=true`；截图写入`.shots/farm-phase04c-final/`。
该检查使用真实CropRenderer和重叠标记，不加载历史场景，也不写玩家存档。

Phase 5界面预览（不写玩家存档，必须带`--fresh`）：

```powershell
& $env:GODOT_EXE_CONSOLE --path . --script scripts/farming/tests/phase05_preview.gd -- --fresh
```

截图输出`.shots/farm-phase05/market-hungry.png`与`market-fed.png`；游戏中M打开/关闭集市，Esc关闭。
界面优化后另有`inventory.png`、`market-trade.png`、`market-bulk.png`和`hud.png`。
预览验证弹窗暂停/恢复相机、逻辑视口边界、数量×5快捷键和工具按钮选择；成功输出`UI PREVIEW OK`。
仅跑经济核心可用`--headless --path . --script scripts/farming/tests/run_phase05.gd`。

兼容`play.bat farm --farmtest`、`play.bat farm --farm-shots=DIR`。
农场直接运行也接受`--selftest`和`--shots`别名；截图参数支持等号形式及shell拆分后的两项形式。
同时传测试与截图参数时只执行测试，避免两个流程竞态退出。
缺失正式资产时启动报错，不自动生成占位图覆盖正式资产。

Demo菜单预览：

```powershell
& $env:GODOT_EXE_CONSOLE --path . --script scripts/farming/tests/phase06_preview.gd
```

输出`DEMO PREVIEW OK`，截图位于`.shots/farm-phase06b/`。脚本只创建测试槽，结束后清理。
`play.bat farm --fresh`为无存档的开发预览，不能用于继续玩家进度。
当前玩家只通过每日结束自动存档与菜单选择继续；F5/F9和手动存读按钮均已移除。

## 历史内容按需运行

```powershell
.\play.bat demo                   # 旧商场演示
.\play.bat demo wilds             # 旧野外演示
.\play.bat demo --selftest         # 旧demo内核测试
.\play.bat farm0 --farmtest        # 历史Phase 0拼接测试
```

旧场景和测试保留为独立入口；只有修改旧内容或共享内核时才单独运行，
不再混入当前游戏流程验收。旧的`play.bat wilds/dusk`改为`play.bat demo wilds/dusk`。
历史执行记录里的旧测试命令仅说明当时结果；现行入口以本文为准。

## 首轮回顾截图验收

运行`--path . --script scripts/farming/tests/phase06_records_preview.gd`（GPU模式，不加headless）。
输出`RECORDS PREVIEW OK`，截图位于`.shots/farm-phase06c/`：进行中的经营记录、已冻结回顾和滚动明细。
三张界面均在640×360逻辑视口内，继续经营按钮始终可见；预览只写专用测试目录，结束后清理。

## 高级工具与范围操作验收

P6.d新增28项真实操作检查：购买与重复/余额校验、等级切换、三个栏位、中心范围和边缘、1/2/3/9次AP取整、普通单目标、高级不恢复耕地、双击第二事件、种子不足、AP不足不跨日续做、末AP完整自动档、混合介质、多格树播种/采收/清理去重、种子选择恢复与槽隔离。价格配置新增2项Python检查。
独立逻辑入口为`--headless --path . --script scripts/farming/tests/run_phase06_tools.gd`，输出`PHASE06 TOOLS TEST OK`。
GPU界面入口为`--path . --script scripts/farming/tests/phase06_tools_preview.gd`，输出`TOOLS PREVIEW OK`；五张截图位于`.shots/farm-phase06d/`。两个入口仅操作各自测试槽目录并清理，不能用来继续玩家存档。

## 教学与显示设置验收

P6.e新增28项真实流程检查：鼠标选择工具/选种、成功开地/播种、休息生长、采收、出售和饥饿喂养；失败不推进、重看不改资源、跳过隐藏提示、日存档恢复、放弃当天回退、槽间教学隔离、非法步骤拒绝；全局设置独立存储、重启读取、非法值/写入失败/损坏处理、菜单应用与FPS切换、输入恢复。
独立入口为`--headless --path . --script scripts/farming/tests/run_phase06_experience.gd`，输出`PHASE06 EXPERIENCE TEST OK`。
GPU入口为`--path . --script scripts/farming/tests/phase06_experience_preview.gd`，输出`EXPERIENCE PREVIEW OK`。八张截图位于`.shots/farm-phase06e/`，实测960/1280/1920窗口、全屏往返与帧率/FPS。该入口只改变测试进程自身显示，并创建/清理测试设置和槽目录，不操作玩家配置。

## 45天经营与独立发布验收

P6.f另有12项固定策略经营检查：正式初始资源、45个日存档与15/30天恢复、四类作物闭环、独立账本与六项回顾统计、期末余额、三工具投资和冻结报告持久化。入口为`--headless --path . --script scripts/farming/tests/phase06_playtest.gd`，成功输出`45 DAY PLAYTEST OK`；默认报告在`.art-work/phase06-playtest.json`。GPU截图不加headless并追加`--playtest-shots=res://.shots/farm-phase06f`。

`tools/farming/build_demo.ps1 -GodotExe <控制台引擎路径>`导出并等待实际release程序通过8项检查才打包，必须安装同版本Windows release模板。可单独运行导出程序的`-- --demo-smoke`，配`--headless --log-file <绝对日志路径>`；成功标记为`DEMO RELEASE SMOKE OK`，失败退出码为1。不要把GUI程序启动成功或PowerShell未等待的退出码当作检查结果。

发布检查覆盖旧场景/开发测试排除、JSON与60元石新槽、27张正式纹理解码、种植收获出售、钱包/工具自动存档及显示设置；使用唯一隔离目录并清理。GPU不加headless，追加`--smoke-shots=<绝对目录>`，审核真实发布程序的菜单、教学农场和设置。详细结果与限制见[45天试玩记录](phase06-playtest.md)。这是V0历史发行验收；较长试玩与导出按发布需要显式运行，当前日常测试组成见本文开头。


## Phase 6.5界面验收

新增`run_v1_phase65_ui.gd`的79项检查，原派工/报告界面调整后51项；两者使用临时槽与设置。覆盖数量交易、余额/库存不足、只读框选/建设预览、重复放置、清理/拆除/覆盖取消、确认期间阻断、模态/文本输入阻断、单个负责区域删除/定位、实时重排、4分辨率×3UI缩放、设置持久化/损坏及日存档失败原样重试。矢量QC由`test_ui_assets.py`检查ID覆盖、SVG尺寸/本地内容与10工具形状区分；发行冒烟解码所有58个符号并核对应用标识，源码12/独立包13项。

GPU截图入口：`--v1-shots=<目录> --shot-size=2560x1440 --ui-scale=100`（与引擎`--resolution 2560x1440`配合）。只操作独立预览槽，输出18页与`dimensions.json`；100/125/150%及2560/1920/1280/960四档结果保留`.art-work/phase65-*`。世界模型中的45天路线继续使用原`run_v1_journal.gd`，不把界面图例注入材料的截图夹具当经济验收。

扩地最终补验：A/B第120日现金1382/1414、人工费1049/1102，每条正常购买六块660元石，新田4次麦收、西侧2个周期启动。严格审计及12类篡改拒绝通过；西侧收取另从真实存档续测至123日，未注入库存，保存重开无重复。详见[P8.h最终台账](phase-08h-90日经营验收与交付.md)。代码/数据`3cf704e`，测试/工具`57caf03`，文档独立提交。
