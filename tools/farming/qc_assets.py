#!/usr/bin/env python3
"""Read-only QC: --target crops|ground|transitions|all [--root DIR] [--report JSON]."""
import argparse
import json
import re
from pathlib import Path
from PIL import Image
from asset_common import ROOT, components, load_palette, palette_warning, seamless_errors, pixels
from gen_asset_manifest import build_manifest
import gen_phase00_textures as p0


def check_image(path, entry):
    errors, warnings = [], []
    kind = entry["type"]
    try:
        with Image.open(path) as source:
            source.load()
            if source.format != "PNG":
                errors.append("format must be PNG")
            image = source.copy()
    except (OSError, ValueError) as exc:
        return [f"cannot read image: {exc}"], warnings
    expected = "RGB" if kind == "ground" else "RGBA"
    if image.mode != expected:
        errors.append(f"mode {image.mode}, expected {expected}")
    if image.size != tuple(entry["size"]):
        errors.append(f"size {image.size}, expected {entry['size']}")
    if errors:
        return errors, warnings
    if kind == "ground":
        errors.extend(seamless_errors(image))
        colors = load_palette()["ground"].get(path.stem.removeprefix("ground_"), [])
    else:
        alpha = image.getchannel("A")
        if set(pixels(alpha)) - {0, 255}:
            errors.append("alpha must be binary 0/255")
        if kind == "crop_stage":
            width, height = image.size
            bbox = alpha.getbbox()
            if not bbox:
                errors.append("empty sprite")
            else:
                x0, y0, x1, y1 = bbox
                if min(x0, y0) < 2 or x1 > width-2 or y1 > height-2:
                    errors.append(f"2px safety border violated: {bbox}")
                if len(components(alpha)) != 1:
                    errors.append("disconnected foreground components")
                if abs((x0 + x1) / 2 - width/2) > 1 or y1 != height-2:
                    warnings.append(f"anchor: bbox center={(x0+x1)/2}, bottom={y1}; expected {width/2},{height-2}")
                if entry.get("stage") == "mature":
                    # Occupancy means bbox height / canvas, not opaque pixel area.
                    ratio = (y1 - y0) / height
                    if not 0.55 <= ratio <= 0.75:
                        warnings.append(f"mature height occupancy {ratio:.1%}, expected 55-75%")
            colors = [c for ramp in load_palette()["crops"].values() for c in ramp]
        elif kind == "atlas":
            if alpha.crop((960, 960, 1024, 1024)).getextrema() != (255, 255):
                errors.append("bm=255 must be fully opaque")
            colors = []
        else:
            colors = []
    if colors:
        warning = palette_warning(image, colors)
        if warning:
            warnings.append(warning)
    return errors, warnings


def inspect(root=ROOT, target="all"):
    entries = build_manifest()["assets"]
    kinds = {"crops": {"crop_stage"}, "ground": {"ground"}, "transitions": {"atlas", "atlas_meta"},
             "all": {"crop_stage", "ground", "atlas", "atlas_meta", "utility"}}[target]
    results = []
    expected_crops = {e["path"] for e in entries if e["type"] == "crop_stage"}
    for entry in entries:
        if entry["type"] not in kinds:
            continue
        path = Path(root) / entry["path"]
        errors, warnings = [], []
        if any(not re.fullmatch(r"[a-z0-9_]+", part) for part in Path(entry["path"]).with_suffix("").parts):
            errors.append("invalid snake_case path")
        if not path.is_file():
            errors.append("missing required asset")
        elif entry["type"] == "atlas_meta":
            try:
                meta = json.loads(path.read_text(encoding="utf-8"))
                if meta.get("bits") != p0.BITS or meta.get("tile") != 64 or meta.get("grid") != [16, 16]:
                    errors.append("atlas metadata bits/tile/grid mismatch")
                if meta.get("upper") != path.stem.removeprefix("trans_upper_"):
                    errors.append("atlas metadata upper mismatch")
            except (OSError, ValueError, AttributeError) as exc:
                errors.append(f"invalid metadata: {exc}")
        else:
            e, w = check_image(path, entry)
            errors.extend(e)
            warnings.extend(w)
        results.append({"path": entry["path"], "errors": errors, "warnings": warnings})
    if target in ("all", "crops"):
        for path in (Path(root) / "assets/farming/crops").glob("*/stage_*.png"):
            rel = path.relative_to(root).as_posix()
            if path.parent.name != "_placeholder" and rel not in expected_crops:
                results.append({"path": rel, "errors": ["unexpected crop stage"], "warnings": []})
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", choices=["all", "crops", "ground", "transitions"], default="all")
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    results = inspect(args.root.resolve(), args.target)
    for result in results:
        for level in ("errors", "warnings"):
            for message in result[level]:
                print(f"[{level}] {result['path']}: {message}")
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    failed = sum(bool(r["errors"]) for r in results)
    print(f"QC: {len(results)} checked, {failed} failed")
    return int(failed > 0)


if __name__ == "__main__":
    raise SystemExit(main())
