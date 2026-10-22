"""Build concise, standalone image-to-model briefs for actual placeholder facilities.

Reads current production/visual definitions and placeholder generator declarations.
Writes documentation only; does not generate art, models, or runtime replacements.
"""
import ast
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / 'docs/farming/art'
GENERATORS = ['gen_p103_facility_art.py', 'gen_p104_facility_art.py',
              'gen_p105_facility_art.py', 'gen_p106_facility_art.py']

# id, image structure, model focus; functional appearance, not new gameplay.
DESIGNS = [
    ('dispatch_station', '矮木柜连接一个简洁的立式调度板，板上有三块素色木牌，顶部一面短小灰绿旗。浅木和青灰石脚为主，一处玉青扣件；无文字、钟表阵列或复杂机械。',
     '保留矮柜、调度板和短旗三部分；木牌固定在板面，旗布有厚度，不做独立飘散布片。'),
    ('feed_trough', '一只横向长浅木食槽，四角短支脚，两格宽浅槽口，内壁暖米色，边缘一小段玉青包边。空槽，不画饲料或动物；轮廓宽矮。',
     '槽口真实内凹，保留槽壁和底板厚度；两格可辨，横向支脚与槽体连接。'),
    ('small_bed', '一张低矮浅木小动物床架，内部四个紧凑的暖米色软垫窝，按两行两列排列。窄边框、短脚、一处灰绿布边；无床幔、屋顶或枕头堆。',
     '四个软垫窝共享同一床框与底座，窝沿圆润、软垫概括，保持四槽结构和1×1总占地。'),
    ('medium_bed', '一张浅木中型动物床架，同一框内左右并排两个较宽的浅凹软垫窝。边框比小床更厚实，暖米垫配灰茶绿内沿；保持1×1总占地，两窝清楚，无床幔。',
     '保留同框两个卧位，左右并排，床框稳固，窝垫使用较大平滑形块；不做四窝，不扩大地图占地。'),
    ('large_bed', '一张宽厚的浅木大型动物卧床，只有一个完整的大椭圆暖米软垫窝，两条低护边与短脚。少量灰绿布边，重心低；仍为1×1设施，不画成四床或人用双人床。',
     '同一床框里只保留一个大卧位，软垫有适度厚度和凹面；不增加床组或把占地扩成2×2。'),
    ('care_table', '一张矮浅木照料台，台面一块暖米软垫，后缘固定一个短工具架，只挂一把宽齿刷和一个浅碗。青灰石脚、少量玉青夹件；无医疗仪器、动物或杂物。',
     '台面、软垫、短工具架明确分层，刷和碗与托架可靠连接；保留空操作区，不增加成排小工具。'),
    ('soothing_station', '一个矮浅木安抚音箱台，正面两个大而简洁的圆形共鸣口，顶部中央固定一枚矮玉青调音晶体。暖米包边、青灰石脚；无声波图案、悬浮晶体或舞台。',
     '保留双圆形共鸣口和一枚固定晶体；音箱口用浅凹结构，无密集网孔，晶体连接底座。'),
    ('toy_station', '一台仙侠木作风格的抓娃娃机：浅木直立柜框，前方一块淡青玻璃窗，顶部单个短机械爪，底部三个概括的藤球，前侧一个操作杆和一个按钮。整体圆润素净，无灯带、文字或雕花。',
     '保留柜框、可辨内腔、机械爪、三个藤球和简单控制面板；玻璃可独立调材质，爪与顶部支架相连，不生成满柜玩具或密集导轨。'),
    ('wool_station', '一张低矮浅木采毛台，后侧固定一排六枚宽厚弧形云梳齿，右侧一只短浅收纳槽，青灰石脚。云梳是唯一奇幻形状，少量玉青连接件；无细雕、羊或毛堆。',
     '保留云梳齿、台面、短槽三部分；梳齿有厚度并连接后梁，右槽不悬空，不增加刀片或繁密卷纹。'),
    ('silkworm_rack', '一座矮而通透的浅木蚕架，三层宽浅托盘、四根短立柱，每层有清楚间距。盘沿灰茶绿，顶部仅一个轻微叶形弧度；空架，无蚕、桑叶、蚕茧或细密编织纹。',
     '三层托盘与立柱连成稳固框架，托盘边缘有厚度，层间留空；不逐根生成筛网或编织纤维。'),
    ('spirit_liquid_collector', '一座青灰石脚的浅木集露台，顶部一片宽厚的玉青叶形导流盘，盘尖朝前，下方固定一个暖米陶罐。叶盘、短支架、陶罐三部分清楚；无液滴、细管网或发光。',
     '叶盘采用实心厚曲面，中央一条浅导槽；陶罐置于台面，盘尖与罐口关系明确，不增加真实流体。'),
    ('scale_station', '一张宽矮青灰石面养鳞台，浅木框脚，台面两块圆润的灰金矿质养护板，前缘一只浅收纳槽。板面各用一两条宽色带表达矿层；无蜥蜴、鳞片堆或密集宝石。',
     '保留石台、两块大养护板和浅槽；矿层用材质色面表达，避免大量独立鳞片和微小矿晶。'),
    ('rock_breaking_yard', '一个2×2低矮碎岩作业场，青灰石边界与浅木加固梁，中央一块宽厚承岩砧，两侧少量矮挡板。最多两块大岩料示意结构，入口朝前；无高棚、矿洞、动物或碎石堆。',
     '承岩砧和矮挡板落在2×2基础内，保留前方开口；岩料仅概括大体积，可分离，不建碎片粒子或锤击动画。'),
    ('ore_sorting_yard', '一个2×2低矮选矿作业场，浅木分选架配青灰石脚，一块略倾斜的宽筛盘和两个并排的接料槽。灰金只点在筛盘包边；筛面用粗疏分隔表现，无细网、传送带或矿石堆。',
     '宽筛盘、支架和双接料槽连成一个设施，筛盘可向前倾斜但底座保持轴对齐；筛孔用少量大分隔或贴图暗示。'),
    ('carbonization_nest', '一座2×2低圆拱炭化巢，暖灰石壳，正面单个宽矮巢口，下缘浅木托料槽，顶部一只短通气帽。巢口内侧暗暖褐，少量陶土色包边；无火焰、烟雾、炭腹虫或复杂炉管。',
     '拱壳、巢口、短通气帽有完整厚度，内部只补基本腔体；不建火焰和烟，也不增加烟囱阵列。'),
    ('compost_mouse_den', '一座2×2宽矮翻肥窝，浅木围框和青灰石角脚，中央一层概括的暖褐翻肥床，后缘一个圆拱小窝口。灰绿边条呼应叶形；无鼠、散土颗粒、杂草或满地工具。',
     '围框、低肥床、单个窝口构成稳定整体；肥床仅用几块圆润起伏表现，窝口有厚度，不建粒状土壤。'),
    ('shell_forming_station', '一座2×2岩壳成型台，厚青灰石台面、浅木下架，台上两只宽浅的螺旋壳形凹模并排固定，前缘小接料槽。淡玉青仅点在模沿；螺旋各一圈主形，无细纹或蜗牛。',
     '壳形凹模使用宽厚圆弧和浅凹，不做薄螺旋片；两模固定在石台，底架连通，保留2×2比例。'),
    ('carp_harvest_station', '一座1×1浅木水上捕鲤台，低方平台、短支架、横向宽口捞框和一个浅接鱼槽。捞框以粗框及少量交叉带示意，玉青包边；无鱼、细网丝、长码头或吊臂。',
     '保留低平台、短架、宽捞框和接鱼槽；捞框连接支架，网面用粗格或材质简化，不生成薄丝和背景水。'),
    ('oilfish_harvest_station', '一座1×1浅木水上取油台，青灰石工作面，一只小型圆腹陶质处理罐、短手柄和正前方接油碗，罐与碗间只有一个短嘴。暖米配少量柔金；无鱼、油流、管线阵列或现代工厂。',
     '处理罐、短嘴和接油碗是主要识别构件；罐放稳在台面，保留嘴部厚度，不建液体或复杂内部机构。'),
    ('pearl_station', '一座1×1水上采珠台，浅木方台、青灰石脚，台面一只宽浅贝壳形托座和一个小圆收纳碗。托座暖米白，少量淡藕紫边色；无蚌、珍珠堆、金饰或密集贝壳纹。',
     '贝壳形托座属于工具，不生成活体贝；托座用两三块大弧面概括，小碗独立固定，无珍珠颗粒。'),
    ('gel_station', '一座1×1水上采胶台，浅木低平台，固定一只宽浅青灰陶盆，盆上一个短弧架托住厚叶形导胶片，前缘小出口。淡藕紫局部点色；无水母、胶液拉丝、细管或透明气泡。',
     '盆、短架和厚导胶片三者连接清楚；盆有壁厚和内腔，不建液体、胶丝或透明薄膜。'),
    ('coral_station', '一座1×1水上采礁台，青灰石台面和浅木低架，后方一个两叉粗枝形工具座，前方一只宽浅接料盘。灰粉只点在工具座端部；无活珊瑚、礁石堆、锯齿密枝或锤击效果。',
     '两叉工具座以粗圆枝概括并固定在台面，浅盘保留厚度；不扩展成珊瑚丛或细密分枝。'),
    ('silt_processing_station', '一座1×1水上泥料处理台，青灰石脚的浅木台体，左右两个宽浅沉泥盆，中央一块短平隔板，前侧一只可见出料嘴。泥褐与玉青小面积点色；无泥鳅、泥浆、水流或管网。',
     '双盆、隔板、短出料嘴形成清楚路径，保持盆壁厚度；不建流体和真实细筛，结构收在单格内。'),
    ('aquatic_crop_station', '一座1×1水生种植台，低矮浅木方形浮台，一侧固定宽口投料盒，另一侧一把短柄叶形耙放在卡座上。暖米盒体配灰茶绿边沿；空载，无植物、水面切片、长栈桥或花盆阵列。',
     '浮台、投料盒、短耙共用紧凑底架，耙齿只做少量粗齿；不把设施做成整块种植田或水池。'),
    ('water_change_station', '一座放在岸上陆地的1×1换水站，青灰石底座，浅木短支架托住两只并排暖米陶罐，前侧一个简洁手摇轮和两个短接口。少量玉青环带；无长水管、水流、池塘或大型水车。',
     '双罐、支架和手摇轮连接稳固，短接口作为可接管端口；本体位于岸上，不生成固定朝向的长入水管或背景岸线。'),
]

WATER_DESIGNS = {
    'feed_trough': ('保留同款两格食槽，改为低矮投饵盒和两侧短浮木承托；槽口仍向上，暖米槽壁配玉青边。无饵料、鱼或水面。',
                    '投饵盒与短浮木连成整体，保持两个宽浅槽口；不增加锚链、长支柱和池框。'),
    'small_bed': ('保留同款床框配色，改为低矮水生栖息浮台，内部两行两列四个小浅窝，窝面为灰绿平滑湿石垫。无枕被、鱼或水面；1×1总占地。',
                  '四个栖息窝共享一个短浮托底座，石垫平滑而有厚度；不建水池、床幔或海底地面。'),
    'medium_bed': ('保留同款较厚床框，改为水生栖息浮台，内部左右并排两个较宽浅窝，灰茶绿湿石垫配暖米边框。无织物床褥或水面；1×1总占地。',
                   '保留两个栖息窝、厚边框和紧凑浮托，左右并排，用宽浅凹面表达；不做四窝，不扩占地或增加池水。'),
    'care_table': ('保留同款短工具架、宽齿刷和浅碗，软垫改为暖米色浅托盘，底部改为短浮木支撑。玉青夹件不变；无动物、鱼、药瓶阵列或水面。',
                   '工具架连接浮台，浅托盘有完整内腔；不增加细网、水下长腿或流体。'),
    'soothing_station': ('保留同款双共鸣口和单枚矮玉青晶体，底部改为两条短浮木承托，箱体更低。晶体固定、配色一致；无水纹、声波或水面。',
                         '双共鸣口、固定晶体和短浮托连成一个模型；不生成声波环、悬浮碎片或池框。'),
}

STYLE = ('为《灵田》制作一件独立设施设计图，用于后续图生3D。清淡雅致的仙侠生态游戏风，柔和三维体积、概括形块和少量手绘感，与已选植物画风统一。'
         '浅木、暖米、青灰石为主，只选一种低饱和点色。结构约3～5组，重复脚架可简化；花纹0～1处，材质不超过3类。'
         '不用写实微纹理、密集雕花符文、复杂齿轮管线或强发光。')
VIEW = ('正交相机沿设施正面中轴俯看35°，主体绕竖直轴偏转0°。矩形横边水平、纵深边和立柱竖直，附件同轴；只见顶面与正面，不露大侧面，不用等距菱形或透视展示角。'
        '圆口投影为长轴水平的椭圆；真实斜撑、筛盘倾角可保留。')
FINISH = ('左上柔光，完整单体，透明背景，四周留白。只画空载静态本体，不画文字、人物、动物、地面、水面、大投影、粒子或多视角拼图；不附加棚屋和庭院。')
MODEL = ('依据附上的已选设计图生成同一件完整静态3D设施。保留轮廓、比例与色块，合理补足背面，不另加装饰。'
         '用低至中等复杂度表达大形，薄件有厚度、构件连接可靠，纹理概括；不要求骨骼、动画或内部精密机构。'
         '木、石、陶、金属等按实际使用分区；不把受光高光和投影烘焙成固定黑白斑。')
MODEL_FINISH = ('只生成设施本体，不带背景、地面、水体或大影子。保留可检查的材质和贴图，使用服务实际支持的模型格式。'
                '后续在Blender用正面中轴35°正交相机渲染，主体偏转0°，矩形横边水平、纵深边竖直。'
                '占地中心为放置原点，地面或水面接触高度明确，不随透明边框居中。')


def read(relative):
    return json.loads((ROOT/relative).read_text(encoding='utf-8'))


def main():
    production = read('content/farming/p8/production.json')
    definitions = {row['id']: row for row in production['facilities']}
    visuals = read('assets/farming/facilities/facility_manifest.json')['facilities']
    provenance = {}
    for filename in GENERATORS:
        for node in ast.parse((ROOT/'tools/farming'/filename).read_text(encoding='utf-8')).body:
            if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id in ['SPECS','STATIONS','YARDS'] for t in node.targets):
                for ident in ast.literal_eval(node.value): provenance[ident] = 'tools/farming/'+filename
    active = set(provenance) & set(visuals) & set(definitions)
    assert active == {row[0] for row in DESIGNS} and len(active) == 25
    assert len(visuals) == 39
    entries = []
    for ident, subject, model_focus in DESIGNS:
        definition = definitions[ident]
        variants = [('land' if definition['terrain'] == 'land' else 'water', subject, model_focus)]
        dual = definition.get('terrains', []) == ['land','water']
        if dual:
            water_subject, water_focus = WATER_DESIGNS[ident]
            variants.append(('water', water_subject, water_focus))
        assert definition['footprint'] == visuals[ident]['footprint']
        for variant, subject, focus in variants:
            shape = definition['footprint']
            medium = '岸上陆地' if ident == 'water_change_station' else ('陆地' if variant == 'land' else '水上')
            identity = f"对象：{definition['name']}（{ident}），{medium}{shape[0]}×{shape[1]}占地。"
            image_prompt = '\n\n'.join([STYLE, identity+subject, VIEW, FINISH])
            model_prompt = '\n\n'.join([identity+MODEL, focus, MODEL_FINISH])
            base = f"{ident}_{variant}"
            entries.append({'id':ident, 'name':definition['name'], 'variant':variant, 'footprint':shape,
                'medium':medium, 'status':'prompts_ready_not_generated',
                'scope_evidence':provenance[ident], 'legacy_runtime_file':visuals[ident]['path'],
                'legacy_runtime_sha256':visuals[ident]['sha256'],
                'planned_paths':{
                    'design':f'assets/farming/p109/source/facilities/{ident}/{base}_design_view35_v001.png',
                    'model':f'facilities/p109/{ident}/{variant}/{base}_v001.glb',
                    'blend':f'facilities/p109/{ident}/{variant}/{base}_v001.blend',
                    'render':f'assets/farming/p109/runtime/facilities/{ident}/{variant}/body.png'},
                'image_prompt':image_prompt, 'image_to_model_prompt':model_prompt})
            if ident in production['p103']['bed_facilities']:
                slots = production['p103']['bed_facilities'][ident]['slots']
                entries[-1]['runtime_bed_slots'] = slots
                entries[-1]['design_bed_slots'] = 2 if ident == 'medium_bed' else slots
                entries[-1]['capacity_alignment'] = 'runtime_revision_pending' if slots != entries[-1]['design_bed_slots'] else 'aligned'
    assert len(entries) == 30
    data = {'schema':1,'date':'2026-10-22','scope':'25 active placeholder facilities, 30 land/water briefs',
            'production_file':'content/farming/p8/production.json',
            'production_sha256':hashlib.sha256((ROOT/'content/farming/p8/production.json').read_bytes()).hexdigest(),
            'status':'prompts_only_no_images_models_or_runtime_changes',
            'counts':{'active_facilities':39,'existing_model_entries':14,'placeholder_facilities':25,'dual_medium_facilities':5,'prompt_pairs':30},
            'excluded_existing_model_ids':[k for k in visuals if k not in active],
            'assets':entries}
    (DOCS/'p109-facility-prompts.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    heading = '''# P10.9 占位设施：生图与图生建模提示词

2026-10-22。按用户最新路线：**提示词 → 设计图 → 依据选中图建模 → Blender统一渲染 → 导入游戏**。本次只完成提示词，不生成图片或模型，不替换运行素材。动物视野与地格交互仍属于P10.10。

> **中床口径修订：** 用户本次确认中床应为2槽，陆地/水上设计均改为同框两个卧位。核查发现原P10.3设计、当前源配置和baked运行配置仍为4槽，分配与预约按配置逐槽执行；“中型占2空间”不代表床组只有2槽。本次更正美术提示词，未改玩法容量，配套JSON分别记录design_bed_slots=2、runtime_bed_slots=4及待同步状态。

## 范围与使用

对照当前production设施定义、运行manifest以及P10.3～P10.6占位生成器，确定25项仍为程序占位；供食槽、小床、中床、照料台、安抚台各有陆地/水上两版，共30组。每项下方两段均可独立复制；生图时可以附一张已通过的植物/设施图作为画风参考，建模时必须附该项实际选中的设计图。占位PNG只证明当前缺口，不作为造型或斜角机位母版。

控制标准：主要结构约3～5组、材质不超过3类、花纹0～1处；以轮廓、功能结构和一处克制的奇幻形状区别设施。木纹/石纹只保留宽色带。沿用浅木、暖米、青灰与少量玉青/灰绿/柔金/淡藕紫，不重新建立高饱和风格。旧版精细采毛台示意只取云梳、托槽与材质关系，简化雕花和齿形层次。

清单中的14项已有旧版模型，本轮不混入占位任务：木工台、炭窑炉、堆肥箱、熔炼炉、圈舍、旧鱼塘、藻池、研究台、蜂箱、农事加工台、净化床、厨房、田间维护站、生长灯。已有模型不等于最终美术通过。fish_pond已退役，rock_workyard已由碎岩场/选矿场替代，不新增旧设施任务。当前没有另一批独立房屋建筑定义可补。鱼栅是模块边界绘制，不属于这25项设施本体；如后续制作鱼栅模块，另建直段/接角提示词，仍继承统一机位。

## 交付与渲染约定

- 先出每项一个空载静态设计图，不附动物、成堆产物或工作特效，不自动扩成多候选或多状态。
- 建模走依据选中图的图生3D路线；服务若不支持文字，用建模段作检查清单。Blender用于导入整理、统一材质/尺度和渲染，不恢复脚本从零重建路线。
- 模型按X为宽、Y为深、Z为高整理，正面定义为-Y；放置原点在占地中心、接触高度Z=0。可采用一格1单位，1×1底部支撑留在1×1内，2×2留在2×2内。床组均为1×1；美术采用小床四槽、中床两槽、大床一槽。中床当前运行配置仍为四槽，见上方修订说明。
- 正交相机从正面-Y向原点俯看35°，无绕Z斜转和横滚；矩形横边水平、纵深边竖直。横纵方向与附件统一，生成图的角度描述不等于最终相机已校准。
- 共用水上版独立留档，不把陆地软床直接放进水里。水上物件以水面接触高度定位，换水站为岸上设施；水、岸线、倒影和水下色调在场景处理，不烘焙成背景切片。
- 接触影/投影与主体分开，暂不制作火焰、烟、液流和粒子。最终只把统一渲染结果接入运行清单；保留旧占位资源供回退。
- 路径详见配套JSON的planned_paths：设计PNG、原始带材质模型、整理后blend、运行body.png分开。glb仅为服务支持时的建议文件名，实际使用其他格式须按真实格式记录；这些路径目前均为计划，文件尚未生产。
- 建议设计图用1024级方形画布，主体完整留白；运行图按最终显示尺寸另行导出，沿用非像素Linear+mipmap，记录画布、放置原点和显示尺寸，不把设计图直接覆盖旧body.png。

## 对象索引

| 项目 | ID | 占地 | 本轮版本 |
| --- | --- | --- | --- |
'''
    lines = [heading.rstrip()]
    for ident,_,_ in DESIGNS:
        d=definitions[ident]
        variants='陆地＋水上' if ident in WATER_DESIGNS else ('岸上' if ident=='water_change_station' else ('陆地' if d['terrain']=='land' else '水上'))
        lines.append(f"| {d['name']} | `{ident}` | {d['footprint'][0]}×{d['footprint'][1]} | {variants} |")
    for number,entry in enumerate(entries,1):
        lines += ['',f"## {number:02d} {entry['name']} · {entry['medium']}（{entry['id']} / {entry['variant']}）",'',
                  '生图：','', '```text',entry['image_prompt'],'```','',
                  '依据选中图建模：','', '```text',entry['image_to_model_prompt'],'```']
    lines += ['', '## 清单复核', '',
              '配套结构化请求：[p109-facility-prompts.json](p109-facility-prompts.json)。复现：`python tools/farming/build_p109_facility_prompts.py`。工具只写本页和配套JSON；它核对25项占位生成器覆盖、当前名称/占地、五项双介质和30组请求，不触碰源图、运行清单或玩法。',
              '', '后续验收重点是轴对齐、缩小后的功能识别、陆水接触高度和模型结构完整；不以雕花密度衡量完成度。']
    (DOCS/'p109-facility-prompts.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print('P109 FACILITY PROMPTS OK: 25 placeholder facilities, 30 standalone image/model prompt pairs; no art generated.')


if __name__ == '__main__':
    main()
