# -*- coding: utf-8 -*-
"""占位美术资产生成器（像素风，ComfyUI 正式图到位前的开发用占位）。

按主题生成（P2 换肤演练）：读取 content/themes/*.json 的 palette_overrides，
对基准色板做覆盖，输出 assets/themes/<id>/{tileset,objects,player}.png。
图集布局对所有主题一致（语义图块位置不变），主题间只有色板差异。

产出（全部 RGBA PNG，alpha 仅 0/255，最近邻）：
  assets/themes/<id>/tileset.png   224x32  7 枚 32x32 图块（单行，列号即图块序号）
  assets/themes/<id>/player.png    128x192 4 方向 x 4 帧 32x48 行走图（行序 下/左/右/上）
  assets/themes/<id>/objects.png   352x96  物件图集（柜台/货架/盆栽/告示牌/电梯/NPC x2/
                                           宝箱开闭/存档石/明雷标记/E 提示）

用法：python tools/gen_placeholder_assets.py
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "assets"
THEMES_DIR = ROOT / "content" / "themes"
TILE = 32

# 基准色板；主题 JSON 的 palette_overrides 对其按键覆盖
BASE_PAL = {
    # 地面
    "floor_a": "#d8cdb4", "floor_a_line": "#c2b598", "floor_a_hi": "#e2d8c2",
    "floor_a_dot": "#cfc3a8",
    "floor_b": "#d3c7ae", "floor_b_line": "#bdb093", "floor_b_dot": "#c7baa0",
    "carpet": "#8e3b3c", "carpet_dark": "#6f2c2e", "carpet_pat": "#a8524f",
    "corr": "#9aa392", "corr_line": "#7d8677", "corr_dot": "#8b9483",
    # 墙体
    "wall": "#2e4a4e", "wall_cap": "#22363a", "wall_line": "#274044",
    "wall_hi": "#4a6b70", "wall_ao": "#1c2e31",
    # 门 / 空
    "door_glow": "#e8d9a8", "door_glow2": "#c9b183", "door_thr": "#b8a06a",
    "void": "#101014", "void_dot": "#0c0c10",
    # 金属 / 木
    "brass": "#c49a4e", "brass_dark": "#96743a",
    "wood": "#7a5a3a", "wood_top": "#a8845a", "wood_panel": "#5d4430",
    "metal": "#8a9296", "metal_dark": "#6f777b",
    # 植物 / 纸
    "pot": "#8e5a3c", "leaf": "#3f6b46", "leaf_hi": "#57875a",
    "paper": "#e8dfc8", "ink": "#4a4038",
    # 角色
    "outline": "#1a1418", "skin": "#e8c8a8", "skin_sh": "#d4b090",
    "hair": "#3a2c28", "coat": "#2c3038", "coat_hi": "#3a3f4a",
    "pants": "#23262c", "shoe": "#14161a", "scarf": "#c8552e",
    # NPC（柜员）
    "npc_hair": "#2c2c30", "npc_shirt": "#cfc6b0", "npc_vest": "#4a3f30",
    "npc_pants": "#3a3428",
    # 电梯灯
    "lamp_red": "#b03a34",
    # P3 交互物件：存档石符文 / 明雷标记
    "rune": "#7fd0c8", "mark_bg": "#1f2a33", "mark_fg": "#e8963c",
    # 提示气泡
    "bubble_bg": "#2b2b30", "bubble_fg": "#f0ead8",
}

# 工作色板：生成时按主题覆盖（C() 只读它）
PAL = dict(BASE_PAL)


def load_theme_palettes() -> dict:
    """从 content/themes/*.json 读 {主题id: 色板覆盖}。"""
    themes = {}
    for p in sorted(THEMES_DIR.glob("*.json")):
        data = json.loads(p.read_text(encoding="utf-8"))
        themes[data["id"]] = data.get("palette_overrides", {})
    if not themes:
        raise SystemExit(f"未找到主题文件: {THEMES_DIR}")
    return themes


def C(name: str) -> tuple:
    h = PAL[name].lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def canvas(w: int, h: int) -> tuple:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def outline(img: Image.Image, color: tuple) -> Image.Image:
    """给所有不透明像素加 1px 深色描边（填充邻接透明位）。"""
    w, h = img.size
    src = img.copy()
    d = ImageDraw.Draw(img)
    opaque = src.getchannel("A").point(lambda a: a > 0)
    px = opaque.load()
    for y in range(h):
        for x in range(w):
            if px[x, y]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny]:
                    d.point((x, y), fill=color)
                    break
    return img


def dither(d: ImageDraw.ImageDraw, x0: int, y0: int, w: int, h: int,
           color: tuple, step: int = 5, seed: int = 0):
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            if (x * 7 + y * 13 + seed) % step == 0:
                d.point((x, y), fill=color)


# ---------------------------------------------------------------- 图块
def tile_floor_a() -> Image.Image:
    img, d = canvas(TILE, TILE)
    d.rectangle((0, 0, 31, 31), fill=C("floor_a"))
    d.rectangle((0, 0, 31, 0), fill=C("floor_a_hi"))
    d.rectangle((0, 0, 0, 31), fill=C("floor_a_hi"))
    d.rectangle((0, 31, 31, 31), fill=C("floor_a_line"))
    d.rectangle((31, 0, 31, 31), fill=C("floor_a_line"))
    dither(d, 2, 2, 28, 28, C("floor_a_dot"), step=11, seed=1)
    return img


def tile_floor_b() -> Image.Image:
    img, d = canvas(TILE, TILE)
    d.rectangle((0, 0, 31, 31), fill=C("floor_b"))
    d.rectangle((0, 31, 31, 31), fill=C("floor_b_line"))
    d.rectangle((31, 0, 31, 31), fill=C("floor_b_line"))
    dither(d, 2, 2, 28, 28, C("floor_b_dot"), step=7, seed=2)
    return img


def tile_carpet() -> Image.Image:
    img, d = canvas(TILE, TILE)
    d.rectangle((0, 0, 31, 31), fill=C("carpet"))
    d.rectangle((0, 0, 31, 31), outline=C("carpet_dark"))
    for cx, cy in ((8, 8), (24, 8), (16, 16), (8, 24), (24, 24)):
        d.rectangle((cx - 1, cy - 1, cx + 1, cy + 1), fill=C("carpet_pat"))
    dither(d, 2, 2, 28, 28, C("carpet_dark"), step=13, seed=3)
    return img


def tile_corridor() -> Image.Image:
    img, d = canvas(TILE, TILE)
    d.rectangle((0, 0, 31, 31), fill=C("corr"))
    d.rectangle((0, 31, 31, 31), fill=C("corr_line"))
    d.rectangle((31, 0, 31, 31), fill=C("corr_line"))
    dither(d, 2, 2, 28, 28, C("corr_dot"), step=9, seed=4)
    return img


def tile_wall() -> Image.Image:
    img, d = canvas(TILE, TILE)
    d.rectangle((0, 0, 31, 31), fill=C("wall"))
    d.rectangle((0, 0, 31, 5), fill=C("wall_cap"))
    d.rectangle((0, 6, 31, 6), fill=C("wall_hi"))
    for x in (10, 21):
        d.rectangle((x, 7, x, 31), fill=C("wall_line"))
    d.rectangle((0, 14, 31, 14), fill=C("brass"))
    d.rectangle((0, 29, 31, 31), fill=C("wall_ao"))
    return img


def tile_door() -> Image.Image:
    """东/西墙上的通道门洞（可行走，传送触发格）。"""
    img, d = canvas(TILE, TILE)
    d.rectangle((0, 0, 31, 31), fill=C("void"))
    d.rectangle((2, 4, 29, 31), fill=C("door_glow"))
    d.rectangle((2, 12, 29, 31), fill=C("door_glow2"))
    d.rectangle((0, 0, 31, 3), fill=C("brass"))
    d.rectangle((0, 0, 1, 31), fill=C("brass"))
    d.rectangle((30, 0, 31, 31), fill=C("brass"))
    d.rectangle((2, 29, 29, 31), fill=C("door_thr"))
    return img


def tile_void() -> Image.Image:
    img, d = canvas(TILE, TILE)
    d.rectangle((0, 0, 31, 31), fill=C("void"))
    dither(d, 0, 0, 32, 32, C("void_dot"), step=6, seed=5)
    return img


def gen_tileset() -> Image.Image:
    tiles = [tile_floor_a(), tile_floor_b(), tile_carpet(), tile_corridor(),
             tile_wall(), tile_door(), tile_void()]
    sheet = Image.new("RGBA", (TILE * len(tiles), TILE), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        sheet.paste(t, (i * TILE, 0))
    return sheet


# ---------------------------------------------------------------- 行走图
PW, PH = 32, 48


def _legs(d: ImageDraw.ImageDraw, ox: int, oy: int, stride: str):
    """stride: 'idle' | 'left' | 'right' | 'pass' —— 下/上视图的腿。"""
    lp = (ox + 12, oy + 34, ox + 15, oy + 43)
    rp = (ox + 16, oy + 34, ox + 19, oy + 43)
    if stride == "left":
        lp = (ox + 11, oy + 34, ox + 14, oy + 41)
        rp = (ox + 17, oy + 34, ox + 20, oy + 43)
    elif stride == "right":
        lp = (ox + 12, oy + 34, ox + 15, oy + 43)
        rp = (ox + 18, oy + 34, ox + 21, oy + 41)
    elif stride == "pass":
        lp = (ox + 12, oy + 34, ox + 15, oy + 42)
        rp = (ox + 16, oy + 34, ox + 19, oy + 42)
    d.rectangle(lp, fill=C("pants"))
    d.rectangle(rp, fill=C("pants"))
    d.rectangle((lp[0], lp[3] + 1, lp[2], lp[3] + 4), fill=C("shoe"))
    d.rectangle((rp[0], rp[3] + 1, rp[2], rp[3] + 4), fill=C("shoe"))


def _body_down(d: ImageDraw.ImageDraw, ox: int, oy: int, face: bool, stride: str):
    d.rectangle((ox + 10, oy + 4, ox + 21, oy + 9), fill=C("hair"))
    d.rectangle((ox + 10, oy + 5, ox + 11, oy + 12), fill=C("hair"))
    d.rectangle((ox + 20, oy + 5, ox + 21, oy + 12), fill=C("hair"))
    if face:
        d.rectangle((ox + 12, oy + 10, ox + 19, oy + 15), fill=C("skin"))
        d.rectangle((ox + 13, oy + 12, ox + 13, oy + 13), fill=C("outline"))
        d.rectangle((ox + 18, oy + 12, ox + 18, oy + 13), fill=C("outline"))
    else:
        d.rectangle((ox + 12, oy + 10, ox + 19, oy + 15), fill=C("hair"))
    # 躯干 + 围巾
    d.rectangle((ox + 9, oy + 16, ox + 22, oy + 33), fill=C("coat"))
    d.rectangle((ox + 9, oy + 16, ox + 22, oy + 18), fill=C("scarf"))
    d.rectangle((ox + 9, oy + 16, ox + 10, oy + 33), fill=C("coat_hi"))
    d.rectangle((ox + 14, oy + 21, ox + 17, oy + 26), fill=C("coat_hi"))
    # 手
    d.rectangle((ox + 9, oy + 30, ox + 10, oy + 32), fill=C("skin"))
    d.rectangle((ox + 21, oy + 30, ox + 22, oy + 32), fill=C("skin"))
    _legs(d, ox, oy, stride)


def _body_side(d: ImageDraw.ImageDraw, ox: int, oy: int, stride: str):
    d.rectangle((ox + 11, oy + 4, ox + 21, oy + 8), fill=C("hair"))
    d.rectangle((ox + 11, oy + 5, ox + 12, oy + 14), fill=C("hair"))
    d.rectangle((ox + 10, oy + 9, ox + 14, oy + 15), fill=C("skin"))
    d.rectangle((ox + 11, oy + 11, ox + 11, oy + 12), fill=C("outline"))
    d.rectangle((ox + 11, oy + 16, ox + 20, oy + 33), fill=C("coat"))
    d.rectangle((ox + 11, oy + 16, ox + 20, oy + 18), fill=C("scarf"))
    d.rectangle((ox + 14, oy + 20, ox + 16, oy + 31), fill=C("coat_hi"))
    d.rectangle((ox + 13, oy + 30, ox + 15, oy + 32), fill=C("skin"))
    if stride in ("left", "right"):
        d.rectangle((ox + 12, oy + 34, ox + 15, oy + 43), fill=C("pants"))
        d.rectangle((ox + 17, oy + 34, ox + 20, oy + 43), fill=C("pants"))
        d.rectangle((ox + 12, oy + 44, ox + 15, oy + 47), fill=C("shoe"))
        d.rectangle((ox + 17, oy + 44, ox + 20, oy + 47), fill=C("shoe"))
    else:
        d.rectangle((ox + 14, oy + 34, ox + 17, oy + 43), fill=C("pants"))
        d.rectangle((ox + 14, oy + 44, ox + 17, oy + 47), fill=C("shoe"))


def player_frame(direction: str, stride: str) -> Image.Image:
    img, d = canvas(PW, PH)
    bob = -1 if stride == "pass" else 0
    if direction == "down":
        _body_down(d, 0, bob, True, stride)
    elif direction == "up":
        _body_down(d, 0, bob, False, stride)
    elif direction == "left":
        _body_side(d, 0, bob, stride)
    return img


def gen_player_sheet() -> Image.Image:
    dirs = ["down", "left", "right", "up"]
    strides = ["idle", "left", "pass", "right"]
    sheet = Image.new("RGBA", (PW * 4, PH * 4), (0, 0, 0, 0))
    for r, dname in enumerate(dirs):
        for c, s in enumerate(strides):
            if dname == "right":
                # 右向 = 左向帧镜像（player_frame 无 right 分支，直接生成会是空画布）
                f = player_frame("left", s).transpose(Image.FLIP_LEFT_RIGHT)
            else:
                f = player_frame(dname, s)
            sheet.paste(f, (c * PW, r * PH))
    return outline(sheet, C("outline"))


# ---------------------------------------------------------------- 物件
def obj_counter() -> Image.Image:
    img, d = canvas(TILE, TILE)
    d.rectangle((0, 0, 31, 8), fill=C("wood_top"))
    d.rectangle((0, 0, 31, 0), fill=C("brass"))
    d.rectangle((0, 9, 31, 31), fill=C("wood_panel"))
    for y in (14, 20, 26):
        d.rectangle((2, y, 29, y), fill=C("wood"))
    d.rectangle((0, 8, 31, 9), fill=C("brass_dark"))
    return img


def obj_shelf() -> Image.Image:
    img, d = canvas(TILE, TILE)
    d.rectangle((0, 0, 31, 31), fill=C("wood_panel"))
    d.rectangle((1, 1, 30, 30), fill=C("wood"))
    goods = ["carpet", "leaf", "brass", "metal", "carpet_pat", "pot"]
    for row, y in ((0, 4), (1, 18)):
        d.rectangle((2, y + 10, 29, y + 11), fill=C("wood_top"))
        for i in range(4):
            d.rectangle((4 + i * 7, y, 9 + i * 7, y + 9),
                        fill=C(goods[(row * 4 + i) % len(goods)]))
    d.rectangle((0, 0, 31, 31), outline=C("wood_panel"))
    return img


def obj_plant() -> Image.Image:
    img, d = canvas(TILE, TILE)
    d.ellipse((8, 4, 24, 16), fill=C("leaf"))
    d.ellipse((4, 8, 16, 18), fill=C("leaf_hi"))
    d.ellipse((16, 8, 28, 18), fill=C("leaf"))
    d.ellipse((10, 2, 20, 10), fill=C("leaf_hi"))
    d.polygon([(8, 18), (24, 18), (21, 30), (11, 30)], fill=C("pot"))
    d.rectangle((7, 17, 24, 19), fill=C("brass_dark"))
    return img


def obj_sign() -> Image.Image:
    img, d = canvas(TILE, TILE)
    d.rectangle((14, 20, 17, 30), fill=C("wood_panel"))
    d.rectangle((4, 4, 27, 20), fill=C("paper"))
    d.rectangle((4, 4, 27, 20), outline=C("ink"))
    for i, y in enumerate((7, 11, 15)):
        w = 18 if i < 2 else 10
        d.rectangle((7, y, 7 + w, y + 1), fill=C("ink"))
    return img


def obj_elevator() -> Image.Image:
    img = Image.new("RGBA", (TILE, TILE * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, 31, 63), fill=C("metal_dark"))
    d.rectangle((2, 2, 29, 61), fill=C("metal"))
    d.rectangle((15, 2, 16, 61), fill=C("metal_dark"))
    d.rectangle((2, 2, 29, 4), fill=C("brass"))
    d.rectangle((2, 59, 29, 61), fill=C("brass_dark"))
    d.rectangle((2, 2, 3, 61), fill=C("brass"))
    d.rectangle((28, 2, 29, 61), fill=C("brass"))
    d.rectangle((12, 6, 19, 9), fill=C("bubble_bg"))
    d.rectangle((13, 7, 15, 8), fill=C("lamp_red"))
    return img


def obj_npc(frame: int) -> Image.Image:
    img, d = canvas(TILE, PH)
    oy = -1 if frame == 1 else 0
    d.rectangle((10, oy + 5, 21, oy + 10), fill=C("npc_hair"))
    d.rectangle((12, oy + 11, 19, oy + 15), fill=C("skin"))
    d.rectangle((13, oy + 12, 13, oy + 13), fill=C("outline"))
    d.rectangle((18, oy + 12, 18, oy + 13), fill=C("outline"))
    d.rectangle((9, oy + 16, 22, oy + 33), fill=C("npc_vest"))
    d.rectangle((13, oy + 16, 18, oy + 31), fill=C("npc_shirt"))
    d.rectangle((9, oy + 16, 22, oy + 18), fill=C("npc_vest"))
    d.rectangle((12, oy + 34, 15, oy + 43), fill=C("npc_pants"))
    d.rectangle((16, oy + 34, 19, oy + 43), fill=C("npc_pants"))
    d.rectangle((12, oy + 44, 15, oy + 47), fill=C("shoe"))
    d.rectangle((16, oy + 44, 19, oy + 47), fill=C("shoe"))
    return outline(img, C("outline"))


def obj_chest(closed: bool) -> Image.Image:
    img, d = canvas(TILE, TILE)
    d.rectangle((4, 14, 27, 27), fill=C("wood_panel"))
    for x in (8, 16, 24):
        d.rectangle((x, 18, x, 26), fill=C("wood"))
    d.rectangle((4, 26, 27, 27), fill=C("brass_dark"))
    if closed:
        d.rectangle((3, 8, 28, 14), fill=C("wood_top"))
        d.rectangle((3, 13, 28, 14), fill=C("brass_dark"))
        d.rectangle((14, 8, 17, 16), fill=C("brass"))
    else:
        d.rectangle((3, 3, 28, 9), fill=C("wood_top"))   # 上翻的盖
        d.rectangle((5, 14, 26, 19), fill=C("void"))     # 内腔
        d.rectangle((7, 16, 12, 18), fill=C("door_glow"))  # 内物微光
    return img


def obj_save_stone() -> Image.Image:
    img, d = canvas(TILE, TILE)
    d.polygon([(8, 28), (11, 6), (21, 6), (24, 28)], fill=C("metal_dark"))
    d.polygon([(10, 26), (12, 8), (20, 8), (22, 26)], fill=C("metal"))
    d.rectangle((14, 12, 17, 20), fill=C("rune"))
    d.rectangle((15, 14, 16, 18), fill=C("bubble_bg"))
    d.rectangle((6, 27, 25, 28), fill=C("corr_line"))
    return img


def obj_battle_mark() -> Image.Image:
    img, d = canvas(16, 16)
    d.polygon([(8, 1), (15, 8), (8, 15), (1, 8)], fill=C("mark_bg"))
    d.polygon([(8, 2), (14, 8), (8, 14), (2, 8)], outline=C("mark_fg"))
    d.rectangle((7, 4, 8, 9), fill=C("mark_fg"))
    d.rectangle((7, 11, 8, 12), fill=C("mark_fg"))
    return img


def obj_prompt() -> Image.Image:
    img, d = canvas(16, 16)
    d.rectangle((1, 1, 14, 14), fill=C("bubble_bg"))
    d.rectangle((1, 1, 14, 14), outline=C("bubble_fg"))
    # 像素 "E"
    d.rectangle((5, 4, 5, 11), fill=C("bubble_fg"))
    d.rectangle((5, 4, 10, 4), fill=C("bubble_fg"))
    d.rectangle((5, 7, 9, 7), fill=C("bubble_fg"))
    d.rectangle((5, 11, 10, 11), fill=C("bubble_fg"))
    return img


def gen_objects() -> Image.Image:
    sheet = Image.new("RGBA", (352, 96), (0, 0, 0, 0))
    sheet.paste(obj_counter().convert("RGBA"), (0, 0))
    sheet.paste(outline(obj_shelf(), C("outline")).convert("RGBA"), (32, 0))
    sheet.paste(outline(obj_plant(), C("outline")).convert("RGBA"), (64, 0))
    sheet.paste(outline(obj_sign(), C("outline")).convert("RGBA"), (96, 0))
    sheet.paste(obj_elevator(), (128, 0))
    sheet.paste(obj_prompt(), (160, 0))
    sheet.paste(obj_npc(0), (176, 0))
    sheet.paste(obj_npc(1), (208, 0))
    sheet.paste(outline(obj_chest(True), C("outline")).convert("RGBA"), (240, 0))
    sheet.paste(outline(obj_chest(False), C("outline")).convert("RGBA"), (272, 0))
    sheet.paste(outline(obj_save_stone(), C("outline")).convert("RGBA"), (304, 0))
    sheet.paste(obj_battle_mark(), (336, 0))
    return sheet


# ---------------------------------------------------------------- QC + 输出
def qc(name: str, img: Image.Image, expect: tuple) -> bool:
    problems = []
    if img.mode != "RGBA":
        problems.append(f"mode={img.mode}")
    if img.size != expect:
        problems.append(f"size={img.size} expect={expect}")
    alpha = img.getchannel("A")
    hist = alpha.histogram()
    semi = sum(hist[1:255])
    if semi:
        problems.append(f"{semi} 半透明像素（糊边）")
    # 行走图专项：四个方向行都必须有实质内容（防空帧漏检）
    if name == "player.png":
        for r, dname in enumerate(["down", "left", "right", "up"]):
            row = alpha.crop((0, r * PH, PW * 4, (r + 1) * PH))
            opaque = sum(1 for v in row.tobytes() if v == 255)
            if opaque < 500:
                problems.append(f"行 {dname} 仅 {opaque} 不透明像素（疑似空帧）")
    print(f"[{'OK ' if not problems else 'BAD'}] {name} {img.size} "
          + ("; ".join(problems) if problems else "alpha 二值 ✓"))
    return not problems


def main():
    themes = load_theme_palettes()
    ok = True
    for tid in sorted(themes):
        PAL.clear()
        PAL.update(BASE_PAL)
        PAL.update(themes[tid])
        out = ASSETS / "themes" / tid
        out.mkdir(parents=True, exist_ok=True)
        print(f"== 主题 {tid} ==")
        for name, img, expect in [
            ("tileset.png", gen_tileset(), (TILE * 7, TILE)),
            ("player.png", gen_player_sheet(), (PW * 4, PH * 4)),
            ("objects.png", gen_objects(), (352, 96)),
        ]:
            ok &= qc(name, img, expect)
            img.save(out / name)
        print(f"主题 {tid} → {out}")
    print("完成" if ok else "有 QC 问题，请检查")


if __name__ == "__main__":
    main()
