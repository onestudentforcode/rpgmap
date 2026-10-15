"""Validate actual review frames, then assemble labelled comparison evidence.

Metrics describe fixed world regions and composited sprites. They are diagnostic,
not universal aesthetic pass/fail thresholds. Does not alter runtime artwork.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageStat

ROOT = Path(__file__).resolve().parents[2]
PROFILES = ('baseline', 'grounding', 'integrated')
LABELS = ('原版 P8.5', '仅增加接地', '整体整改样板')


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8'))


def font(size):
    candidate = Path('C:/Windows/Fonts/msyh.ttc')
    return ImageFont.truetype(str(candidate), size) if candidate.exists() else ImageFont.load_default()


def label_grid(rows, destination, cell=(780, 400), labels=LABELS):
    title_height, gap = 56, 12
    canvas = Image.new('RGB', (cell[0] * 3 + gap * 4,
                               (cell[1] + title_height) * len(rows) + gap * (len(rows) + 1)), '#f6f4ed')
    draw = ImageDraw.Draw(canvas)
    for row_index, (name, pictures) in enumerate(rows):
        for column, (label, picture) in enumerate(zip(labels, pictures)):
            x = gap + column * (cell[0] + gap)
            y = gap + row_index * (cell[1] + title_height + gap)
            draw.text((x + 12, y + 10), f'{label} · {name}', font=font(24), fill='#334238')
            picture = picture.convert('RGB')
            picture.thumbnail(cell, Image.Resampling.LANCZOS)
            canvas.paste(picture, (x + (cell[0] - picture.width) // 2, y + title_height))
    canvas.save(destination)


def crop_bounds(frame, identities, stages, padding=35):
    rectangles = [crop['rect'] for crop in frame['crops']
                  if crop['id'] in identities and crop['stage'] in stages]
    left = min(rect[0] for rect in rectangles) - padding
    top = min(rect[1] for rect in rectangles) - padding
    right = max(rect[0] + rect[2] for rect in rectangles) + padding
    bottom = max(rect[1] + rect[3] for rect in rectangles) + padding
    return tuple(round(value) for value in (left, top, right, bottom))


def main(folder):
    matrix = []
    for size in ('2560x1440', '1920x1080', '960x540'):
        directory = folder / size
        report = read_json(directory / 'trial.json')
        expected = tuple(map(int, size.split('x')))
        if report['failures'] or len(report['frames']) != 24:
            raise ValueError(f'{size}: trial is incomplete or failed')
        names = set()
        for frame in report['frames']:
            path = directory / frame['file']
            with Image.open(path) as picture:
                if picture.size != expected or tuple(frame['size']) != expected:
                    raise ValueError(f'{path}: viewport differs')
            if frame['file'] in names:
                raise ValueError(f'{path}: duplicate frame')
            names.add(frame['file'])
        matrix.append({'viewport': list(expected), 'frames': 24, 'failures': []})
    directory = folder / '2560x1440'
    report = read_json(directory / 'trial.json')
    indexed = {(frame['profile'], frame['case']): frame for frame in report['frames']}
    rows = []
    for case, title in (('scene-1.0', '固定场景 · 1.0缩放'),
                        ('waterfront-3.0', '水岸与设施 · 3.0缩放')):
        pictures = [Image.open(directory / indexed[profile, case]['file']).copy() for profile in PROFILES]
        rows.append((title, pictures))
    label_grid(rows, folder / 'scene-comparison.png', (780, 440))
    gray_pictures = [Image.open(directory / indexed[profile, 'scene-1.0']['file']).convert('L').convert('RGB')
                     for profile in PROFILES]
    label_grid([('灰度层次 · 同镜头', gray_pictures)], folder / 'grayscale-comparison.png', (780, 440))
    detail_rows = []
    case = 'seedlings-3.0'
    bounds = crop_bounds(indexed['baseline', case], {'golden_wheat', 'pasture_grass'}, {'stage_0', 'stage_1'})
    pictures = [Image.open(directory / indexed[profile, case]['file']).crop(bounds) for profile in PROFILES]
    detail_rows.append(('幼苗 · 固定世界区域', pictures))
    case = 'resources-3.0'
    # Center of the resource row; the image is the same crop for all profiles.
    bounds = (800, 400, 1740, 900)
    pictures = [Image.open(directory / indexed[profile, case]['file']).crop(bounds) for profile in PROFILES]
    detail_rows.append(('石料点 · 固定画面区域', pictures))
    label_grid(detail_rows, folder / 'detail-comparison.png', (780, 420))
    plants = read_json(ROOT / 'assets/farming/crops/plant_manifest.json')['plants']
    plant_names = {'golden_wheat':'金穗麦', 'pasture_grass':'青牧草', 'resin_tree':'松脂树'}
    composite_rows = []
    for ident in ('golden_wheat', 'pasture_grass', 'resin_tree'):
        for stage in ('stage_0', 'stage_1'):
            data = plants[ident]
            size = tuple(round(value * data['scale_multiplier']) for value in data['draw_size'])
            relative = Path(data['stages'][stage].removeprefix('res://'))
            before = Image.open(ROOT / relative).convert('RGBA').resize(size, Image.Resampling.LANCZOS)
            after = Image.open(ROOT / '.art-work/p86-runtime' / relative).convert('RGBA').resize(size, Image.Resampling.LANCZOS)
            bounds = [before.getbbox(), after.getbbox()]
            common = (max(0, min(box[0] for box in bounds)-4), max(0, min(box[1] for box in bounds)-4),
                      min(size[0], max(box[2] for box in bounds)+4), min(size[1], max(box[3] for box in bounds)+4))
            pictures = []
            for tone in ('#eff0e6', '#9aa98c', '#424d40'):
                panel = Image.new('RGB', (700, 250), tone)
                painter = ImageDraw.Draw(panel)
                painter.text((20, 8), '原图', font=font(22), fill='#202b23' if tone != '#424d40' else '#ffffff')
                painter.text((370, 8), '候选', font=font(22), fill='#202b23' if tone != '#424d40' else '#ffffff')
                for index, sprite in enumerate((before, after)):
                    background = Image.new('RGBA', size, tone)
                    background.alpha_composite(sprite)
                    sample = background.crop(common)
                    sample = sample.resize((sample.width*4, sample.height*4), Image.Resampling.NEAREST)
                    panel.paste(sample.convert('RGB'), (60+350*index, 42))
                pictures.append(panel)
            composite_rows.append((f'{plant_names[ident]} {stage[-1]} · 默认尺度×4', pictures))
    label_grid(composite_rows, folder / 'alpha-backgrounds.png', (700, 250), ('浅背景', '中背景', '深背景'))
    metrics = []
    for profile in PROFILES:
        frame = indexed[profile, 'seedlings-3.0']
        image = Image.open(directory / frame['file']).convert('RGB')
        for crop in frame['crops']:
            if crop['id'] not in {'golden_wheat', 'pasture_grass'} or crop['stage'] != 'stage_0':
                continue
            x, y, width, height = crop['rect']
            region = image.crop((round(x), round(y), round(x+width), round(y+height))).convert('L')
            stats = ImageStat.Stat(region)
            metrics.append({'profile': profile, 'id': crop['id'], 'stage': crop['stage'],
                            'roi_luma_mean_0_255': stats.mean[0], 'roi_luma_stddev': stats.stddev[0]})
    manifest = {'matrix': matrix, 'total_frames': 72, 'metrics_are_diagnostic': True,
                'roi_metrics': metrics, 'awaiting_user_visual_acceptance': True,
                'artifacts': {name: hashlib.sha256((folder/name).read_bytes()).hexdigest()
                              for name in ('scene-comparison.png', 'detail-comparison.png', 'grayscale-comparison.png', 'alpha-backgrounds.png')}}
    (folder / 'review-summary.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    print('P86 REVIEW EVIDENCE OK: 72 frames, 4 comparisons')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--folder', type=Path, default=ROOT / '.art-work/p86-trial')
    main(parser.parse_args().folder)
