#!/usr/bin/env python3
"""Process a batch manifest from raw/ to processed/ without touching assets/.

Input layout mirrors manifest paths, e.g. raw/assets/farming/ground/ground_grass.png.
Use --background '#ff00ff' for crop images generated on a solid key background.
"""
import argparse
import json
from collections import deque
from pathlib import Path
from PIL import Image
from asset_common import ROOT, components, rgb, pixels
from qc_assets import check_image


def process(image, kind, threshold=128, background=None, background_tolerance=0, pad_to_multiple=False,
            target_size=(64, 64)):
    w, h = image.size
    tw, th = target_size
    if any(not isinstance(v, int) or v < 64 or v % 64 for v in (tw, th)):
        raise ValueError("target canvas must use positive multiples of 64")
    if kind == "ground" and (tw, th) != (64, 64):
        raise ValueError("ground target must remain 64x64")
    if pad_to_multiple and (tw, th) != (64, 64):
        raise ValueError("padding is supported only for the 64x64 crop contract")
    if pad_to_multiple and kind == "crop_stage" and w == h and w >= 64 and w % 64:
        if background is None:
            raise ValueError("padding opaque source requires an explicit background key")
        size = ((w + 63) // 64) * 64
        padded = Image.new("RGBA", (size, size), (*rgb(background), 255))
        padded.paste(image.convert("RGBA"), ((size-w)//2, (size-h)//2))
        image, w, h = padded, size, size
    if w < tw or h < th or w % tw or h % th or w // tw != h // th:
        raise ValueError("source must match target aspect and be an integer multiple of target canvas")
    if kind == "ground":
        if "transparency" in image.info or ("A" in image.getbands() and image.getchannel("A").getextrema() != (255, 255)):
            raise ValueError("ground source must be fully opaque")
        image = image.convert("RGB").resize((64, 64), Image.Resampling.NEAREST)
        # Symmetric edge blending keeps corners consistent; interior stays unchanged.
        px = image.load()
        for offset in range(4):
            weight = (4 - offset) / 4
            for y in range(64):
                a, b = px[offset, y], px[63 - offset, y]
                mean = tuple(round((a[c] + b[c]) / 2) for c in range(3))
                px[offset, y] = tuple(round(a[c] * (1-weight) + mean[c] * weight) for c in range(3))
                px[63-offset, y] = tuple(round(b[c] * (1-weight) + mean[c] * weight) for c in range(3))
        for offset in range(4):
            weight = (4 - offset) / 4
            for x in range(64):
                a, b = px[x, offset], px[x, 63-offset]
                mean = tuple(round((a[c] + b[c]) / 2) for c in range(3))
                px[x, offset] = tuple(round(a[c] * (1-weight) + mean[c] * weight) for c in range(3))
                px[x, 63-offset] = tuple(round(b[c] * (1-weight) + mean[c] * weight) for c in range(3))
        return image
    image = image.convert("RGBA")
    image = image.resize((tw, th), Image.Resampling.NEAREST)
    if background is not None:
        key = rgb(background)
        px = image.load()
        # Flood only border-connected key pixels, preserving enclosed leaf/dew highlights.
        candidates = {(x, y) for y in range(th) for x in range(tw)
                      if max(abs(px[x,y][c]-key[c]) for c in range(3)) <= background_tolerance}
        queue = deque(p for p in candidates if p[0] in (0,tw-1) or p[1] in (0,th-1))
        visited = set(queue)
        while queue:
            x, y = queue.popleft()
            px[x,y] = (0,0,0,0)
            for point in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if point in candidates and point not in visited:
                    visited.add(point)
                    queue.append(point)
    elif image.getchannel("A").getextrema() == (255, 255):
        raise ValueError("opaque crop source: supply exact --background key or transparent PNG")
    image.putalpha(image.getchannel("A").point(lambda a: 255 if a >= threshold else 0))
    groups = components(image.getchannel("A"))
    if not groups:
        raise ValueError("empty sprite after alpha threshold")
    px = image.load()
    for group in groups[1:]:
        for x, y in group:
            px[x, y] = (0, 0, 0, 0)
    bbox = image.getchannel("A").getbbox()
    x0, y0, x1, y1 = bbox
    if x1-x0 > tw-4 or y1-y0 > th-4:
        raise ValueError("subject exceeds canvas safety area; regenerate with more padding")
    subject = image.crop(bbox)
    output = Image.new("RGBA", (tw, th))
    output.paste(subject, ((tw-subject.width)//2, th-2-subject.height))
    # Clear invisible RGB so white matte pixels cannot survive in transparent space.
    output.putdata([p if p[3] else (0, 0, 0, 0) for p in pixels(output)])
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--alpha-threshold", type=int, default=128)
    parser.add_argument("--background")
    parser.add_argument("--background-tolerance", type=int, default=0, help="RGB key tolerance, only border-connected pixels")
    parser.add_argument("--pad-to-multiple", action="store_true", help="pad crop canvas to next multiple of 64 before integer NEAREST reduction")
    args = parser.parse_args()
    raw, out = args.input.resolve(), args.output.resolve()
    assets = (ROOT / "assets").resolve()
    if raw == out or raw in out.parents or out in raw.parents or out == assets or assets in out.parents:
        parser.error("raw/output must be separate, non-nested directories; output cannot be assets/")
    if not 1 <= args.alpha_threshold <= 255:
        parser.error("alpha threshold must be 1..255")
    if not 0 <= args.background_tolerance <= 255:
        parser.error("background tolerance must be 0..255")
    if out.exists() and any(out.iterdir()):
        parser.error("output must be empty; use a new run directory")
    entries = json.loads(args.manifest.read_text(encoding="utf-8"))["assets"]
    reports = []
    for entry in entries:
        if entry["type"] not in ("ground", "crop_stage"):
            continue
        rel = Path(entry["path"])
        if rel.is_absolute() or ".." in rel.parts or not rel.as_posix().startswith("assets/farming/"):
            parser.error(f"unsafe manifest path: {rel}")
        source, destination = raw / rel, out / rel
        result = {"path": rel.as_posix(), "errors": [], "warnings": []}
        try:
            with Image.open(source) as image:
                output = process(image, entry["type"], args.alpha_threshold, args.background,
                                 args.background_tolerance, args.pad_to_multiple, tuple(entry["size"]))
            destination.parent.mkdir(parents=True, exist_ok=True)
            output.save(destination)
            result["errors"], result["warnings"] = check_image(destination, entry)
            if entry["type"] == "ground":
                preview = Image.new("RGB", (192, 192))
                for y in range(3):
                    for x in range(3):
                        preview.paste(output, (x*64, y*64))
                preview_path = out / "previews" / (rel.stem + "_3x3.png")
                preview_path.parent.mkdir(parents=True, exist_ok=True)
                preview.save(preview_path)
        except (OSError, ValueError, KeyError) as exc:
            result["errors"].append(str(exc))
        reports.append(result)
        print(f"[{'FAIL' if result['errors'] else 'OK'}] {rel}: {result['errors']} {result['warnings']}")
    out.mkdir(parents=True, exist_ok=True)
    (out / "qc_report.json").write_text(json.dumps(reports, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    if not reports:
        parser.error("manifest has no AI assets")
    return int(any(r["errors"] for r in reports))


if __name__ == "__main__":
    raise SystemExit(main())
