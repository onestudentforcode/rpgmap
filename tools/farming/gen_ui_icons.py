"""Deterministic, code-native SVG symbols for Phase 6.5. No scene art implied."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/farming/ui"
STROKE = '#334238'
GREEN = '#9bb493'
BLUE = '#96bbc6'
CLAY = '#cba884'
GOLD = '#d4bb73'

def path(d):
    return f'<path d="{d}"/>'

SYMBOLS = {
 'inspect': '<circle cx="27" cy="27" r="15"/>'+path('M38 38L53 53'),
 'till': path('M15 48L43 15M30 12L52 31M13 50L27 53'),
 'plant': path('M32 54V27M32 35C9 35 12 14 13 14C30 13 32 27 32 35M32 29C53 29 53 10 52 10C34 10 32 22 32 29'),
 'harvest': path('M17 51L40 14M40 14C63 26 45 53 22 43M19 49L27 54'),
 'irrigate': path('M12 29H37V50H12ZM37 33L53 22L58 27L38 44M16 28V18H31V28M49 40L49 48M56 38L56 46'),
 'fertilize': path('M18 16H46L50 52H14ZM23 15L20 9H44L41 15M25 34H39M32 27V41'),
 'fell': path('M16 55L40 12M37 15L53 18L47 35L29 31'),
 'clear': path('M14 51L43 14M39 10L52 23M12 41L23 51L10 55L6 50M39 40L53 54M53 40L39 54'),
 'cancel': path('M16 16L48 48M48 16L16 48'),
 'area': path('M10 25V10H25M39 10H54V25M54 39V54H39M25 54H10V39M25 32H39M32 25V39'),
 'workers': '<circle cx="23" cy="20" r="9"/><circle cx="45" cy="23" r="7"/>'+path('M7 52V44C7 29 39 29 39 44V52M39 36C54 33 58 40 58 51'),
 'market': path('M10 23H54L49 53H15ZM22 23C22 4 42 4 42 23'),
 'orders': path('M15 8H49V56H15ZM24 21H40M24 31H40M24 42L29 47L41 37'),
 'history': path('M12 12H29L32 16L35 12H52V52H35L32 56L29 52H12ZM32 16V56M18 24H26M38 24H46M18 34H26M38 34H46'),
 'help': '<circle cx="32" cy="32" r="23"/>'+path('M24 24C24 12 44 15 41 26C40 32 32 32 32 39M32 47H32.1'),
 'menu': path('M14 18H50M14 32H50M14 46H50'),
 'settings': '<circle cx="32" cy="32" r="9"/>'+path('M25 8H39L41 17L50 20L57 31L51 37L49 47L38 55L30 51L20 53L10 43L13 34L8 24L18 14L25 15Z'),
 'day': '<circle cx="32" cy="32" r="14"/>'+path('M32 4V11M32 53V60M4 32H11M53 32H60M12 12L17 17M47 47L52 52M12 52L17 47M47 17L52 12'),
 'build': path('M8 27L32 8L56 27M15 23V55H49V23M26 55V37H38V55'),
 'fit': path('M9 24V9H24M40 9H55V24M55 40V55H40M24 55H9V40'),
 'close': path('M18 18L46 46M46 18L18 46'),
 'locate': '<circle cx="32" cy="32" r="18"/><circle cx="32" cy="32" r="5"/>'+path('M32 4V17M32 47V60M4 32H17M47 32H60'),
 'buy': path('M12 44H52V54H12M32 9V40M20 28L32 40L44 28'),
 'sell': path('M12 44H52V54H12M32 40V9M20 21L32 9L44 21'),
 'claim': path('M9 22L32 10L55 22V49L32 58L9 49ZM9 22L32 33L55 22M32 33V58M22 41L29 48L43 34'),
 'play': path('M23 13L51 32L23 51Z'),
 'back': path('M33 15L16 32L33 49M17 32H53'),
 'grain': path('M32 55V12M32 22C16 21 15 9 16 8C31 8 32 16 32 22M32 33C48 32 49 20 48 19C33 19 32 27 32 33M32 44C16 43 15 31 16 30C31 30 32 38 32 44'),
 'tree': path('M32 5L48 28H41L54 44H37V57H27V44H10L23 28H16Z'),
 'resin_tree': path('M32 7L51 32H43L55 46H37V57H27V46H10L23 32H14ZM45 40C42 45 39 50 45 52C51 50 48 45 45 40'),
 'mushroom': path('M8 34C8 2 56 2 56 34ZM26 34L22 54H42L38 34M18 23H18.1M32 17H32.1M44 25H44.1'),
 'raw_wood': path('M16 15L52 25V49L16 39Z')+'<ellipse cx="16" cy="27" rx="9" ry="12"/>'+path('M25 19L48 27M25 35L48 43'),
 'twig': path('M17 56L39 7M27 34L13 18M34 19L52 16M24 40L46 34'),
 'straw': path('M15 52L29 9M26 55L39 12M38 54L49 15M13 39L44 48M17 30L48 39'),
 'wood_chips': path('M10 34L24 26L29 36L15 44ZM32 14L47 8L52 19L39 26ZM34 41L49 32L57 45L42 55Z'),
 'plank': path('M9 19L44 8L55 43L20 56ZM16 30L49 19M20 44L53 33'),
 'charcoal': path('M10 43L18 23L40 15L54 31L48 53L27 57ZM18 23L33 32L40 15M33 32L27 57M33 32L54 31'),
 'humus': path('M7 50L18 37L30 41L43 30L57 50ZM23 31V16M23 22C10 22 12 10 12 10C23 9 23 16 23 22M23 21C35 21 35 8 35 8C24 8 23 15 23 21'),
 'clean_water': path('M32 5C23 19 12 32 12 42C12 64 52 64 52 42C52 32 41 19 32 5M22 39C19 46 24 51 30 51'),
 'stone': path('M8 40L19 19L38 11L53 27L57 48L36 55L14 52ZM19 19L34 34L53 27M34 34L36 55M34 34L8 40'),
 'ore': path('M8 41L18 22L39 14L55 36L47 53L21 56ZM18 22L32 38L39 14M32 38L47 53M32 38L8 41M39 24L46 34L40 42L34 33Z'),
 'metal': path('M13 31L22 17H44L54 31L49 48H18ZM13 31H54M22 17L26 31M44 17L40 31'),
 'resin': path('M32 7C22 23 14 33 14 44C14 60 50 60 50 44C50 33 42 23 32 7M26 39L35 28L41 42L31 49Z'),
 'earth': path('M7 50L19 32L30 40L44 20L57 50ZM24 50V42M39 50V40M47 50V34'),
 'fire': path('M29 6C44 19 35 26 46 20C62 45 50 58 32 58C12 58 4 38 23 25C18 34 31 37 29 6M30 39C20 53 40 57 40 48C40 44 36 40 35 34'),
 'wood': path('M32 54V16M32 38C7 38 10 13 10 13C31 12 32 26 32 38M32 29C55 29 54 7 54 7C33 6 32 19 32 29'),
 'water': path('M32 6C24 18 12 32 12 42C12 63 52 63 52 42C52 32 40 18 32 6'),
 'gold': path('M32 7L54 24L46 51H18L10 24ZM10 24H54M32 7L23 24L32 51L41 24Z'),
 'sawmill': path('M10 54V33L26 22V33L41 22V54ZM41 54V9H51V54M17 44H22M31 44H35')+'<circle cx="46" cy="19" r="4"/>',
 'charcoal_kiln': path('M10 54V29C10 3 54 3 54 29V54ZM24 54V36C24 23 40 23 40 36V54M18 17H46'),
 'composter': path('M12 20H52L47 56H17ZM8 20H56M18 32H46M20 44H44M32 20V7M32 13L22 7M32 13L42 7'),
 'smelter': path('M13 55V27L22 18H42L51 27V55ZM24 55V37H40V55M25 18V8H39V18M29 46L34 36L37 47'),
}

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    data = json.loads((ROOT/'content/farming/v1/production.json').read_text(encoding='utf-8'))
    # Semantic aliases retain each configured ID; all item routes have a distinct symbol.
    aliases = {'golden_wheat_seed':'plant','fast_fir_seed':'tree','resin_tree_seed':'resin_tree',
               'wood_decay_spawn':'mushroom','golden_wheat':'grain','fast_fir':'tree',
               'wood_decay_mushroom':'mushroom','wooden_plank':'plank','wood_plank':'plank',
               'iron_ore':'ore','iron_ingot':'metal','iron':'metal','stone_block':'stone',
               'fertile_humus':'humus','mushroom_flesh':'mushroom','wood_mushroom':'mushroom',
               'raw_stone':'stone','wood_chip':'wood_chips','woodshop':'sawmill',
               'char_kiln':'charcoal_kiln','compost_bin':'composter'}
    ids = {x['id'] for section in ('resources','crops','facilities') for x in data[section]}
    ids.update(('inspect','till','plant','harvest','irrigate','fertilize','fell','clear','cancel','area'))
    ids.update(('wood','fire','earth','water','gold'))
    ids.update(('workers','market','orders','history','help','menu','settings','day','build','fit','close','locate','buy','sell','claim','play','back'))
    previous = json.loads((OUT/'manifest.json').read_text(encoding='utf-8')) if (OUT/'manifest.json').exists() else {'icons':[]}
    for obsolete in set(previous['icons']) - ids:
        file = OUT / f'{obsolete}.svg'
        assert file.resolve().parent == OUT.resolve()
        file.unlink(missing_ok=True)
    # Fail rather than silently ship unrelated placeholder symbols.
    for ident in sorted(ids):
        key = aliases.get(ident, ident)
        assert key in SYMBOLS, f'No semantic symbol for {ident}'
        fill = BLUE if key in ('clean_water','water','irrigate') else GOLD if key in ('grain','resin','gold','metal') else CLAY if key in ('earth','humus','ore','stone','charcoal') else GREEN
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64"><g fill="{fill}" fill-opacity="0.42" stroke="{STROKE}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">{SYMBOLS[key]}</g></svg>\n'
        (OUT/f'{ident}.svg').write_text(svg, encoding='utf-8')
    manifest = {'phase':'6.5','type':'native-vector','size':[64,64],'filter':'linear','icons':sorted(ids),
                'tools':10,'resources':len(data['resources']),'plants':4,'facilities':4,'elements':5}
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'UI ICONS OK: {len(ids)} SVG symbols')

if __name__ == '__main__': main()
