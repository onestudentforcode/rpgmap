"""Generate P8 placeholder UI icons in the Phase 6.5 vector style.

Soft fills with the shared dark stroke; shape archetypes by category, colour by
element. Deterministic output so reruns are byte-identical. Formal art arrives in
a later dedicated batch and replaces these files by the same names.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ICON_DIR = ROOT / 'assets/farming/ui'
MANIFEST = ICON_DIR / 'manifest.json'
STROKE = '#334238'
ELEMENT_FILL = {'wood': '#9ec27a', 'fire': '#e0985a', 'water': '#7bb0cf', 'earth': '#bfa283', 'gold': '#d9b95c'}
OPACITY = 0.42
STYLE = f'fill-opacity="{OPACITY}" stroke="{STROKE}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"'

# ident -> (shape, element); shapes: seed, drop, pile, badge, panel, plant, bench
SHAPES = {
    'research_bench': ('bench', 'earth'),
    'bee_hive': ('panel', 'wood'),
    'farm_processor': ('panel', 'earth'),
    'purifying_bed': ('panel', 'water'),
    'rock_workyard': ('panel', 'earth'),
    'dispatch_station': ('bench', 'earth'),
    'feed_trough': ('panel', 'wood'),
    'small_bed': ('panel', 'wood'),
    'medium_bed': ('panel', 'wood'),
    'large_bed': ('panel', 'wood'),
    'care_table': ('bench', 'earth'),
    'kitchen': ('panel', 'fire'),
    'field_service_station': ('panel', 'wood'),
    'growth_lamp': ('bench', 'gold'),
    'honeybell_seed': ('seed', 'wood'),
    'oilseed_flower_seed': ('seed', 'wood'),
    'purifying_mat_culture': ('pile', 'water'),
    'nectar': ('drop', 'water'),
    'pollen': ('pile', 'wood'),
    'honey': ('badge', 'wood'),
    'beeswax': ('badge', 'fire'),
    'oilseed': ('seed', 'wood'),
    'flower_petal': ('badge', 'wood'),
    'grain_meal': ('pile', 'wood'),
    'grass_meal': ('pile', 'wood'),
    'crude_oil': ('drop', 'fire'),
    'oil_cake': ('pile', 'wood'),
    'refined_oil': ('drop', 'fire'),
    'spent_filter': ('pile', 'earth'),
    'land_feed': ('pile', 'wood'),
    'water_feed': ('pile', 'wood'),
    'refined_wax': ('badge', 'fire'),
    'mineral_feed': ('pile', 'earth'),
    'filter_media': ('pile', 'earth'),
    'wastewater': ('drop', 'water'),
    'sludge': ('pile', 'earth'),
    'nutrient_liquid': ('drop', 'water'),
    'dense_algae': ('pile', 'wood'),
    'gravel': ('pile', 'earth'),
    'stone_powder': ('pile', 'earth'),
    'crushed_ore': ('pile', 'earth'),
    'ore_concentrate': ('badge', 'earth'),
    'tailings': ('pile', 'earth'),
    'slag': ('pile', 'earth'),
    'composite_stone_panel': ('panel', 'earth'),
    'reclaimed_fill': ('pile', 'earth'),
    'honey_cake': ('badge', 'wood'),
    'fish_spirit_meal': ('badge', 'wood'),
    'dew_soup': ('drop', 'water'),
    'fire_paste': ('badge', 'fire'),
    'earth_pill': ('badge', 'earth'),
    'gold_food': ('badge', 'gold'),
    'honeybell_bush': ('plant', 'wood'),
    'oilseed_flower': ('plant', 'wood'),
}

def body(shape, fill):
    if shape == 'seed':
        return f'<g fill="{fill}" {STYLE}><path d="M32 54V26"/><path d="M32 34C20 34 14 24 15 15C26 15 32 22 32 34Z"/><path d="M32 40C44 40 50 30 49 21C38 21 32 28 32 40Z"/></g>'
    if shape == 'drop':
        return f'<g fill="{fill}" {STYLE}><path d="M32 8C44 26 48 32 48 40a16 16 0 0 1-32 0C16 32 20 26 32 8Z"/><path d="M25 42a7 7 0 0 0 6 7" fill="none"/></g>'
    if shape == 'pile':
        return f'<g fill="{fill}" {STYLE}><path d="M14 50a9 9 0 0 1 7-15 12 12 0 0 1 22 0 9 9 0 0 1 7 15Z"/><circle cx="22" cy="28" r="4"/><circle cx="38" cy="22" r="4"/></g>'
    if shape == 'badge':
        return f'<g fill="{fill}" {STYLE}><path d="M32 8l6 13 14 2-10 10 3 14-13-7-13 7 3-14-10-10 14-2Z"/></g>'
    if shape == 'panel':
        return f'<g fill="{fill}" {STYLE}><rect x="14" y="22" width="36" height="28" rx="5"/><path d="M10 24 32 10l22 14" fill="none"/><path d="M24 50V36h16v14" fill="none"/></g>'
    if shape == 'plant':
        return f'<g fill="{fill}" {STYLE}><path d="M32 56V30"/><path d="M32 12c9 0 14 6 14 12-6 4-14 3-14-12Z"/><path d="M32 12c-9 0-14 6-14 12 6 4 14 3 14-12Z"/><circle cx="32" cy="24" r="4" fill="#f0e6c8"/></g>'
    return f'<g fill="{fill}" {STYLE}><path d="M12 44h40M18 44V24l6-8h16l6 8v20"/><path d="M26 32h12" fill="none"/><circle cx="32" cy="18" r="3"/></g>'

def svg(ident):
    shape, element = SHAPES[ident]
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">'
            + body(shape, ELEMENT_FILL[element]) + '</svg>\n')

def main():
    existing = {p.stem for p in ICON_DIR.glob('*.svg')}
    written = []
    for ident in sorted(SAPES := SHAPES):
        path = ICON_DIR / f'{ident}.svg'
        content = svg(ident)
        if not path.exists() or path.read_text(encoding='utf-8') != content:
            path.write_text(content, encoding='utf-8', newline='\n')
            written.append(ident)
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    icons = sorted(set(manifest['icons']) | set(SHAPES))
    if icons != manifest['icons']:
        manifest['icons'] = icons
        MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')
    # Determinism probe: rewrite with identical bytes.
    for ident in sorted(SHAPES):
        assert (ICON_DIR / f'{ident}.svg').read_text(encoding='utf-8') == svg(ident)
    print(f'P8 ICONS OK: {len(SHAPES)} placeholders ready ({len(written)} written), manifest lists {len(icons)}')

if __name__ == '__main__':
    main()
