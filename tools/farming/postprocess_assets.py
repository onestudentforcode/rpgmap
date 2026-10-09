#!/usr/bin/env python3
"""Process a batch manifest from raw/ to processed/ without touching assets/.

Input layout mirrors manifest paths, e.g. raw/assets/farming/ground/ground_grass.png.
Use --background '#ff00ff' for crop images generated on a solid key background.
"""
import argparse
import json
from pathlib import Path
from PIL import Image
from asset_common import ROOT, components, rgb, pixels
from qc_assets import check_image


def process(image, kind, threshold=128, background=None):
    w, h = image.size
    if w != h or w < 64 or w % 64:
        raise ValueError("source must be square, >=64, and an integer multiple of 64")
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
    if background is not None:
        key = rgb(background)
        image.putdata([(*p[:3], 0 if p[:3] == key else p[3]) for p in pixels(image)])
    elif image.getchannel("A").getextrema() == (255, 255):
        raise ValueError("opaque crop source: supply exact --background key or transparent PNG")
    image = image.resize((64, 64), Image.Resampling.NEAREST)
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
    if x1-x0 > 60 or y1-y0 > 60:
        raise ValueError("subject exceeds 60px safety area; regenerate with more padding")
    subject = image.crop(bbox)
    output = Image.new("RGBA", (64, 64))
    output.paste(subject, ((64-subject.width)//2, 62-subject.height))
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
    args = parser.parse_args()
    raw, out = args.input.resolve(), args.output.resolve()
    assets = (ROOT / "assets").resolve()
    if raw == out or raw in out.parents or out in raw.parents or out == assets or assets in out.parents:
        parser.error("raw/output must be separate, non-nested directories; output cannot be assets/")
    if not 1 <= args.alpha_threshold <= 255:
        parser.error("alpha threshold must be 1..255")
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
                output = process(image, entry["type"], args.alpha_threshold, args.background)
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
