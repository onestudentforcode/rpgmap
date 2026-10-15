"""Generate an opt-in, smooth-alpha P8 trial atlas. Never changes shared assets."""
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, __version__ as pillow_version

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / '.art-work/p86-assets'


def smoothstep(lo, hi, value):
    t = max(0.0, min(1.0, (value-lo)/(hi-lo)))
    return t*t*(3-2*t)


def coverage(bm, x, y):
    # Cardinal neighbors connect at full opacity; missing diagonals form a soft
    # inner notch. No checkerboard dithering or binary-alpha quantization.
    a = 1.0
    for bit, distance in ((1, y), (2, 64-x), (4, 64-y), (8, x)):
        if not bm & bit:
            a = min(a, smoothstep(-0.5, 1.25, distance))
    corners = ((x, y, 1, 8, 128), (64-x, y, 1, 2, 16),
               (64-x, 64-y, 4, 2, 32), (x, 64-y, 4, 8, 64))
    for cx, cy, side_a, side_b, diagonal in corners:
        if not bm & side_a and not bm & side_b and cx < 10 and cy < 10:
            d = math.hypot(cx-10, cy-10)
            a = min(a, 1-smoothstep(9.4, 10.6, d))
        elif bm & side_a and bm & side_b and not bm & diagonal:
            a = min(a, smoothstep(5.4, 6.6, math.hypot(cx, cy)))
    return round(a*255)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    atlas = Image.new('RGBA', (1024, 1024), (255, 255, 255, 0))
    pixels = atlas.load()
    for bm in range(256):
        ox, oy = (bm & 15)*64, (bm >> 4)*64
        for y in range(64):
            for x in range(64):
                pixels[ox+x, oy+y] = (255, 255, 255, coverage(bm, x+.5, y+.5))
    path = OUT / 'transition_soft.png'
    atlas.save(path)
    report = {'schema_version': 1, 'purpose': 'P8.6 opt-in representative scene only',
              'generator': Path(__file__).relative_to(ROOT).as_posix(),
              'generator_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              'pillow_version': pillow_version,
              'canvas_px': [1024, 1024], 'tile_px': 64, 'variants': 256,
              'atlas_of': 'col=bitmask&15,row=bitmask>>4',
              'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
              'continuous_alpha': True, 'dither': False}
    (OUT/'transition-report.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
    print('P86 TRANSITION TRIAL OK', path)


if __name__ == '__main__':
    main()
