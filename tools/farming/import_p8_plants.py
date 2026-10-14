"""Validate a complete Blender handoff before installing any P8 plant files.

Usage: python tools/farming/import_p8_plants.py --source PATH [--check]
The source workspace is never modified. No pixel-art postprocessing is applied.
"""
import argparse
import hashlib
import io
import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def safe_path(root, relative):
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f"path escapes root: {relative}")
    return path


def image_check(data, expected, label):
    with Image.open(io.BytesIO(data)) as image:
        image.load()
        if image.format != "PNG" or image.mode != "RGBA" or image.size != tuple(expected):
            raise ValueError(f"{label}: expected RGBA PNG {expected}, got {image.format}/{image.mode}/{image.size}")
        alpha = image.getchannel("A")
        bbox = alpha.getbbox()
        if not bbox:
            raise ValueError(f"{label}: empty alpha")
        w, h = image.size
        if bbox[0] <= 0 or bbox[1] <= 0 or bbox[2] >= w or bbox[3] >= h:
            raise ValueError(f"{label}: foreground touches canvas edge: {bbox}")
        # Continuous alpha and disconnected leaves/needles are valid here.
        return {"size": list(image.size), "alpha_bbox": list(bbox),
                "continuous_alpha": any(count and 0 < index < 255
                                        for index, count in enumerate(alpha.histogram()))}


def prepare(source, root=ROOT):
    handoff = json.loads((source / "UPSTREAM_PLANT_ASSETS.json").read_text(encoding="utf-8"))
    production = json.loads((root / "content/farming/p8/production.json").read_text(encoding="utf-8"))
    definitions = {c["id"]: c for c in production["crops"]}
    assets = handoff["assets"]
    ids = [a["id"] for a in assets]
    if len(ids) != len(set(ids)) or set(ids) != set(definitions):
        raise ValueError("handoff must contain exactly the current P8 crop IDs")
    pending, checks, visuals = {}, [], {}
    for asset in assets:
        ident = asset["id"]
        if asset["footprint"] != definitions[ident]["footprint"]:
            raise ValueError(f"{ident}: footprint mismatch")
        uv = asset["anchor_uv"]
        size = asset["canvas_small_px"]
        draw_size = asset["suggested_world_calibrated_canvas_godot"]
        if len(uv) != 2 or any(not math.isfinite(v) or not 0 <= v <= 1 for v in uv):
            raise ValueError(f"{ident}: invalid anchor UV")
        if len(draw_size) != 2 or any(not math.isfinite(v) or v <= 0 for v in draw_size):
            raise ValueError(f"{ident}: invalid draw size")
        if not math.isclose(draw_size[1] / draw_size[0], size[1] / size[0], rel_tol=1e-6):
            raise ValueError(f"{ident}: draw aspect ratio mismatch")
        if len(asset["stages"]) != 4 or sorted(s["index"] for s in asset["stages"]) != list(range(4)):
            raise ValueError(f"{ident}: four unique stages required")
        visual = {"footprint": asset["footprint"], "canvas_px": size,
                  "anchor_uv": uv, "draw_size": draw_size, "scale_multiplier": 1.0,
                  "stages": {}, "sha256": {}}
        entries = [(f"stage_{s['index']}", s) for s in asset["stages"]]
        if "flowering" in asset:
            if ident != "oilseed_flower":
                raise ValueError("unexpected flowering crop")
            entries.append(("flowering", asset["flowering"]))
        elif ident == "oilseed_flower":
            raise ValueError("oilseed flowering image required")
        for key, entry in entries:
            relative = f"assets/farming/crops/{ident}/{key}.png"
            if entry["suggested_upstream_file"] != "res://" + relative:
                raise ValueError(f"{ident}/{key}: destination mismatch")
            data = safe_path(source, entry["source_runtime_png"]).read_bytes()
            digest = hashlib.sha256(data).hexdigest()
            if digest != entry["runtime_sha256"]:
                raise ValueError(f"{ident}/{key}: SHA256 mismatch")
            check = image_check(data, size, f"{ident}/{key}")
            checks.append({"id": ident, "state": key, "source": entry["source_runtime_png"],
                           "path": relative, "sha256": digest, **check})
            pending[relative] = data
            visual["stages"][key] = "res://" + relative
            visual["sha256"][key] = digest
        visuals[ident] = visual
    runtime = {"schema_version": 1, "logical_cell_size": 64, "texture_filter": "linear",
               "source_commit": handoff["source_commit"], "plants": visuals}
    pending["assets/farming/crops/plant_manifest.json"] = encoded(runtime)
    pending["docs/farming/art/plant-import-report.json"] = encoded({
        "source_repository": handoff["source_repository"], "source_commit": handoff["source_commit"],
        "files_checked": len(checks), "checks": checks})
    return pending


def install(pending, root=ROOT):
    # All source data is validated and buffered before the first write.
    # Roll back this batch if a destination cannot be written.
    paths = {key: safe_path(root, key) for key in pending}
    previous = {key: p.read_bytes() if p.exists() else None for key, p in paths.items()}
    written = []
    try:
        for key, data in pending.items():
            path = paths[key]
            if previous[key] == data:
                continue
            path.parent.mkdir(parents=True, exist_ok=True)
            written.append(key)
            path.write_bytes(data)
    except Exception:
        for key in reversed(written):
            if previous[key] is None:
                paths[key].unlink(missing_ok=True)
            else:
                paths[key].write_bytes(previous[key])
        raise
    return len(written)


def inspect_installed(root=ROOT):
    """QC installed resources without the art workspace; return per-file results."""
    manifest_path = root / 'assets/farming/crops/plant_manifest.json'
    if not manifest_path.exists():
        return []
    results = []
    try:
        manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
        definitions = json.loads((root / 'content/farming/p8/production.json').read_text(encoding='utf-8'))['crops']
        plants = manifest['plants']
        if set(plants) != {c['id'] for c in definitions}:
            raise ValueError('installed plant IDs differ from P8 definitions')
        for definition in definitions:
            ident = definition['id']
            visual = plants[ident]
            if visual['footprint'] != definition['footprint']:
                raise ValueError(f'{ident}: installed footprint mismatch')
            keys = {f'stage_{i}' for i in range(4)}
            if ident == 'oilseed_flower':
                keys.add('flowering')
            if set(visual['stages']) != keys:
                raise ValueError(f'{ident}: installed states mismatch')
            for key, resource in visual['stages'].items():
                relative = f'assets/farming/crops/{ident}/{key}.png'
                errors = []
                try:
                    if resource != 'res://' + relative:
                        raise ValueError('installed resource path mismatch')
                    data = safe_path(root, relative).read_bytes()
                    if hashlib.sha256(data).hexdigest() != visual['sha256'][key]:
                        raise ValueError('installed SHA256 mismatch')
                    image_check(data, visual['canvas_px'], relative)
                except (OSError, ValueError, KeyError) as exc:
                    errors.append(str(exc))
                results.append({'path': relative, 'errors': errors, 'warnings': []})
    except (OSError, ValueError, KeyError) as exc:
        results.append({'path': 'assets/farming/crops/plant_manifest.json',
                        'errors': [str(exc)], 'warnings': []})
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--check", action="store_true", help="validate without writing")
    args = parser.parse_args()
    try:
        pending = prepare(args.source.resolve())
        changed = 0 if args.check else install(pending)
        print(f"P8 PLANT HANDOFF OK: 29 PNGs validated; {changed} files written")
    except (OSError, ValueError, KeyError) as exc:
        parser.exit(1, f"P8 PLANT HANDOFF ERROR: {exc}\n")


if __name__ == "__main__":
    main()
