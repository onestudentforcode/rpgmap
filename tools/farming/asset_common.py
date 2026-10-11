"""Shared non-mutating asset inspection and palette utilities."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load_palette():
    return json.loads((ROOT / "tools/farming/palette.json").read_text(encoding="utf-8"))


def rgb(value):
    return tuple(int(value.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))


def pixels(image):
    # Pillow 14 removes getdata; older supported Pillow versions lack the replacement.
    return image.get_flattened_data() if hasattr(image, "get_flattened_data") else image.getdata()


def protect_delivered(paths):
    status_path = ROOT / "content/farming/art_status.json"
    statuses = json.loads(status_path.read_text(encoding="utf-8")) if status_path.exists() else {}
    blocked = [p for p in paths if statuses.get(p, {}).get("status") == "delivered"]
    if blocked:
        raise ValueError("refusing placeholder overwrite of delivered assets: " + ", ".join(blocked))


def components(alpha):
    """8-connected foreground; diagonal pixel-art connections are valid."""
    w, h = alpha.size
    px = alpha.load()
    unseen = {(x, y) for y in range(h) for x in range(w) if px[x, y]}
    groups = []
    while unseen:
        start = min(unseen, key=lambda p: (p[1], p[0]))
        unseen.remove(start)
        stack, group = [start], [start]
        while stack:
            x, y = stack.pop()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    p = (x + dx, y + dy)
                    if p in unseen:
                        unseen.remove(p)
                        stack.append(p)
                        group.append(p)
        groups.append(group)
    return sorted(groups, key=len, reverse=True)


def seamless_errors(img):
    w, h = img.size
    px = img.load()
    def col(a, b):
        return sum(abs(px[a, y][c] - px[b, y][c]) for y in range(h) for c in range(3)) / (h * 3)
    def row(a, b):
        return sum(abs(px[x, a][c] - px[x, b][c]) for x in range(w) for c in range(3)) / (w * 3)
    errors = []
    for label, boundary, interior in (
        ("X", col(w - 1, 0), max(col(x, x + 1) for x in range(w - 1))),
        ("Y", row(h - 1, 0), max(row(y, y + 1) for y in range(h - 1))),
    ):
        if boundary > interior * 1.3 + 1e-9:
            errors.append(f"seam {label}: boundary {boundary:.3f} > inner {interior:.3f} * 1.3")
    return errors


def palette_warning(img, colors):
    allowed = {rgb(c) for c in colors}
    visible = [p[:3] for p in pixels(img.convert("RGBA")) if p[3]]
    ratio = sum(p not in allowed for p in visible) / max(1, len(visible))
    return f"palette outside anchors: {ratio:.1%}" if ratio > 0.02 else None
