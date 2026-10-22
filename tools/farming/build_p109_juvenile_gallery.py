"""Build a local, static adult/juvenile comparison gallery from source records."""
from pathlib import Path
from html import escape
import json

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'assets/farming/p109/source'
NOTES = {
    'steel_sheep': '短角芽、大头短吻、较轻的身架；作为本轮幼体规格参考。',
    'rock_mole': '较圆的头与短吻、较小的矿石掘爪。',
    'rock_belly_beast': '较大的圆头与眼，胸腹岩片减少。',
    'mineral_scale_lizard': '大头大眼、短吻，成年背部大片鳞减少；头部鳞片仍偏密，需重点复核。',
    'compost_mouse': '较大头眼、细嫩小脚，背部叶形毛簇减少。',
    'dew_shell_snail': '短触角、较轻薄的壳，露珠减少；并排检查壳体成熟度。',
    'gravel_shell_snail': '大部分幼壳未矿化，仅保留少量砂砾。',
    'carbon_belly_bug': '采用C形分节幼虫轮廓，取消成虫完整鞘翅。',
    'leaf_silkworm': '单只幼蚕、减少叶状背饰；游戏成熟生产形态仍为蚕体。',
    'filter_algae_carp': '较大眼、纤细鱼苗体态、无成年长须，鳍尾缩短。',
    'oilfin_fish': '鱼苗体态与较短鳍，保留局部细金色油脂带。',
    'silt_loach': '较细的幼苗躯干与较大眼，须和鳍较短。',
    'pearl_mussel': '薄幼壳与稀疏生长纹，未出现成熟珍珠。',
    'gel_jellyfish': '浅碟状幼水母，伞体较薄，触腕较短。',
    'reef_coral': '初生骨芽群体，分枝数量和高度减少。',
    'bell_bee': '无翅、无成蜂长腿的蜂幼虫。',
    'purifying_mat': '薄而稀疏的菌丝斑块，留有透空间隙。',
}


def main():
    adults = json.loads((DEST/'manifest.json').read_text(encoding='utf-8'))['assets']
    states = json.loads((DEST/'states_manifest.json').read_text(encoding='utf-8'))['assets']
    by_id = {r['id']: r for r in adults}
    young = {r['id']: r for r in states if r['state'] == 'juvenile'}
    cards = []
    for ident in NOTES:
        adult, juvenile = by_id[ident], young[ident]
        name = adult.get('name', ident)
        pictures = []
        for title, row in [('成体', adult), ('幼体 · '+juvenile.get('version', 'v001'), juvenile)]:
            path = escape(row['file'], quote=True)
            pictures.append(f'<figure><figcaption>{title}</figcaption><a href="{path}" target="_blank"><img src="{path}" alt="{escape(name)} {title}" loading="lazy"></a></figure>')
        prompt = escape(juvenile['prompt'])
        cards.append(f'<article data-category="{adult["category"]}"><h2>{escape(name)} <small>{ident}</small></h2><div class="pair">'+''.join(pictures)+f'</div><p>{NOTES[ident]}</p><details><summary>查看实际幼体提示词</summary><pre>{prompt}</pre></details></article>')
    html = '''<!doctype html>
<html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>P10.9 成体与幼体对照</title>
<style>
:root{--canvas:#e7eee2;--ink:#34483a;--panel:#faf9f3}*{box-sizing:border-box}body{margin:0;background:#f2f3eb;color:var(--ink);font:16px/1.65 system-ui,"Microsoft YaHei",sans-serif}header,main{max-width:1440px;margin:auto;padding:24px}h1{margin:0;font-size:28px}header p{margin:8px 0}nav{display:flex;gap:8px;flex-wrap:wrap;align-items:center}button,a{color:inherit}button{border:1px solid #aab9a4;background:#fffdf6;border-radius:8px;padding:8px 13px;cursor:pointer}button:focus-visible,a:focus-visible{outline:3px solid #729b87;outline-offset:3px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,580px),1fr));gap:22px;padding-top:0}article{border:1px solid #d4decd;border-radius:14px;background:var(--panel);padding:18px;overflow:hidden}h2{margin:0 0 12px;font-size:20px}small{font-size:12px;color:#60755e;display:inline-block}figure{margin:0;min-width:0}figcaption{padding:5px 9px;font-size:13px;color:#52674d}.pair{display:grid;grid-template-columns:1fr 1fr;gap:8px}.pair a{display:block;height:270px;background:var(--canvas);border-radius:8px}.pair img{width:100%;height:100%;object-fit:contain}p{font-size:14px}details{border-top:1px solid #dde4d8;padding-top:10px;font-size:13px}summary{cursor:pointer}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:12px/1.8 system-ui;margin-bottom:0}.compact .pair a{height:140px}a{text-underline-offset:3px}[hidden]{display:none!important}@media(max-width:600px){header,main{padding:16px}.pair a{height:190px}h1{font-size:24px}}
</style>
<header><h1>P10.9 成体与幼体对照</h1><p>17种养殖生物。钢绵羊v002为后续制作规格参考，本轮新增16张；新图等待视觉验收。点击图片打开原始PNG。</p><p>两侧使用相同展示框，便于查看头身比例与器官发育差异；展示尺寸不代表游戏世界尺寸。钢绵羊成体为用户选中的RGB黑底原图。</p><nav><button data-bg="#e7eee2">浅草底</button><button data-bg="#343f46">深色底</button><button data-bg="#c6dedb">水色底</button><button id="size">切换小图</button><button data-filter="all">全部</button><button data-filter="animals">陆生</button><button data-filter="aquatic">水生</button><button data-filter="living">其他生活体</button><a href="index.html">成体总览</a><a href="juvenile_revision_requests.json">本轮实际提示词</a></nav></header><main>'''+''.join(cards)+'''</main><script>
document.querySelectorAll('[data-bg]').forEach(b=>b.onclick=()=>document.documentElement.style.setProperty('--canvas',b.dataset.bg));document.getElementById('size').onclick=()=>document.body.classList.toggle('compact');document.querySelectorAll('[data-filter]').forEach(b=>b.onclick=()=>document.querySelectorAll('article').forEach(c=>c.hidden=b.dataset.filter!=='all'&&c.dataset.category!==b.dataset.filter));
</script></html>'''
    (DEST/'juveniles.html').write_text(html+'\n', encoding='utf-8')
    print('Built juveniles.html:',len(cards),'pairs')


if __name__ == '__main__':
    main()
