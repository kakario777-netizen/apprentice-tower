"""
Flare(https://github.com/flareteam/flare-game, CC-BY-SA 3.0) 의 3D 렌더 스프라이트를
우리 게임 형식으로 다시 묶는다.

출력 시트: 행 = 동작 순서 × 8방향, 열 = 프레임. 모든 칸 크기가 같고 발 기준점이 같은 자리에 온다.
meta.json 항목: {cw, ch, anchor, dirs:8, anims:{이름:{row, frames, dur, type}}, src:'flare'}

Flare 방향 번호(0~7): SW, W, NW, N, NE, E, SE, S  (화면 기준 각도는 DIRANG 참고)
"""
import os, re, json, sys
from PIL import Image

FLARE = sys.argv[1] if len(sys.argv) > 1 else os.environ.get('FLARE', 'flare')
CORE = os.path.join(FLARE, 'mods', 'fantasycore')
OUT = os.path.join(os.path.dirname(__file__), '..', 'www', 'assets', 'sprites')

def parse_anim(path):
    anims = {}; cur = None; image = None; imgs = {}
    for line in open(path, encoding='utf-8'):
        line = line.strip()
        if line.startswith('image='):
            v = line[6:]
            if ',' in v: pth, an = v.split(',', 1); imgs[an.strip()] = pth
            else: image = v
        m = re.match(r'\[(\w+)\]', line)
        if m: cur = m.group(1); anims[cur] = {'frames': 1, 'dur': 500, 'type': 'looped', 'f': {}}; continue
        if cur is None or '=' not in line: continue
        k, v = line.split('=', 1)
        if k == 'frames': anims[cur]['frames'] = int(v)
        elif k == 'duration': anims[cur]['dur'] = int(re.sub(r'\D', '', v) or 0) * (1000 if v.endswith('s') and not v.endswith('ms') else 1)
        elif k == 'type': anims[cur]['type'] = v
        elif k == 'frame':
            parts = v.split(',')
            i, d, x, y, w, h, ox, oy = map(int, parts[:8])
            anims[cur]['f'][(i, d)] = (x, y, w, h, ox, oy)
            if len(parts) > 8: anims[cur].setdefault('fimg', {})[(i, d)] = parts[8].strip()
    for an, pth in imgs.items():
        if an in anims: anims[an]['img'] = pth
    return image or (list(imgs.values())[0] if imgs else None), anims

def build(name, layers, want, scale, layer_order=None):
    """layers: [(애니 파일, 레이어 종류)], want: [(우리 동작 이름, flare 동작 이름 후보들)]"""
    parsed = []
    for apath, kind in layers:
        img, anims = parse_anim(apath)
        IMGS = {}
        for line in open(apath, encoding='utf-8'):
            if line.startswith('image=') and ',' in line: pth, an = line.strip()[6:].split(',', 1); IMGS[an.strip()] = pth
        cache = {}
        def getim(pth):
            if pth not in cache: cache[pth] = Image.open(os.path.join(CORE, pth)).convert('RGBA')
            return cache[pth]
        for an in anims:
            anims[an]['im'] = getim(anims[an].get('img', img))
            anims[an]['fim'] = {k: getim(IMGS[key]) for k, key in anims[an].get('fimg', {}).items() if key in IMGS}
        parsed.append((None, anims, kind))
    base = parsed[0][1]
    chosen = []
    for our, cands in want:
        for c in cands:
            if c in base: chosen.append((our, c)); break
    # 칸 크기·기준점
    minx = miny = 1e9; maxx = maxy = -1e9
    for im, anims, kind in parsed:
        for our, c in chosen:
            if c not in anims: continue
            for (i, d), (x, y, w, h, ox, oy) in anims[c]['f'].items():
                if w <= 1: continue
                minx = min(minx, -ox); miny = min(miny, -oy); maxx = max(maxx, w - ox); maxy = max(maxy, h - oy)
    cw = int((maxx - minx) * scale) + 2; ch = int((maxy - miny) * scale) + 2
    nf = max(base[c]['frames'] for _, c in chosen)
    cells = {}
    st = base[chosen[0][1]]['f'].values()
    hgt = sorted(oy for (x, y, w, h, ox, oy) in st if w > 1)
    meta = {'cw': cw, 'ch': ch, 'anchor': [round(-minx * scale + 1, 1), round(-miny * scale + 1, 1)], 'dirs': 8, 'anims': {}, 'src': 'flare',
            'hgt': round(hgt[len(hgt) // 2] * scale, 1) if hgt else ch}
    for ai, (our, c) in enumerate(chosen):
        A = base[c]
        meta['anims'][our] = {'row': ai * 8, 'frames': A['frames'], 'dur': A['dur'], 'type': A['type']}
        for d in range(8):
            order = parsed
            if layer_order:
                ordk = layer_order[d]
                order = sorted(parsed, key=lambda t: ordk.index(t[2]) if t[2] in ordk else 99)
            for i in range(A['frames']):
                big = Image.new('RGBA', (int(maxx - minx) + 2, int(maxy - miny) + 2))
                for im, anims, kind in order:
                    fr = anims.get(c, {}).get('f', {}).get((i, d))
                    if not fr: continue
                    x, y, w, h, ox, oy = fr
                    if w <= 1: continue
                    src = anims[c]['fim'].get((i, d), anims[c]['im'])
                    big.alpha_composite(src.crop((x, y, x + w, y + h)), (int(-ox - minx) + 1, int(-oy - miny) + 1))
                cells[(ai * 8 + d, i)] = big.resize((cw, ch), Image.LANCZOS)
    meta['nf'] = nf
    meta.update(pack(name, cells, nf, 8 * len(chosen)))
    print(name, meta['pages'], 'pages', list(meta['anims']), flush=True)
    return meta

def pack(name, cells, nf, nrows, PW=4096, PH=8192):
    """빈 공간을 잘라낸 프레임들을 한 장(넘치면 여러 장)에 촘촘히 묶는다.
    fr[row*nf+col] = [쪽, x, y, w, h, 칸 안 x, 칸 안 y] (빈 프레임은 None)"""
    fr = [None] * (nf * nrows); items = []
    for (r, c), im in cells.items():
        bb = im.getbbox()
        if not bb: continue
        items.append((r * nf + c, im.crop(bb), bb[0], bb[1]))
    items.sort(key=lambda t: -t[1].height)
    pages = []; cur = None; x = y = sh = 0
    def newpage():
        nonlocal cur, x, y, sh
        cur = []; pages.append(cur); x = y = sh = 0
    newpage()
    for idx, im, ox, oy in items:
        w, h = im.size
        if x + w > PW: x = 0; y += sh + 1; sh = 0
        if y + h > PH: newpage()
        cur.append((x, y, im)); fr[idx] = [len(pages) - 1, x, y, w, h, ox, oy]
        x += w + 1; sh = max(sh, h)
    for pi, pg in enumerate(pages):
        W = max(x0 + im.width for x0, y0, im in pg); H = max(y0 + im.height for x0, y0, im in pg)
        sheet = Image.new('RGBA', (W, H))
        for x0, y0, im in pg: sheet.alpha_composite(im, (x0, y0))
        sheet.save(os.path.join(OUT, name + ('' if pi == 0 else '_%d' % pi) + '.png'), optimize=True)
    return {'fr': fr, 'pages': len(pages)}

def loot(name, anim_rel, scale):
    img, anims = parse_anim(os.path.join(CORE, 'animations', anim_rel))
    im = Image.open(os.path.join(CORE, img)).convert('RGBA')
    A = list(anims.values())[0]
    fr = [A['f'][k] for k in sorted(A['f']) if A['f'][k][2] > 1]
    x, y, w, h, ox, oy = fr[-1]
    c = im.crop((x, y, x + w, y + h)); bb = c.getbbox(); c = c.crop(bb)
    c = c.resize((max(1, int(c.width * scale)), max(1, int(c.height * scale))), Image.LANCZOS)
    c.save(os.path.join(OUT, name + '.png'), optimize=True)
    print(name, c.size, flush=True)
    return {'cw': c.width, 'ch': c.height, 'anchor': [c.width / 2, c.height * 0.8], 'dirs': 1, 'anims': {'idle': {'row': 0, 'frames': 1, 'dur': 1000, 'type': 'looped'}}, 'src': 'flare'}

def hue_copy(src, dst, deg, sat=1.0, scale=1.0, pages=1):
    for pi in range(pages):
        sfx = '' if pi == 0 else '_%d' % pi
        hue_one(src + sfx, dst + sfx, deg, sat)

def hue_one(src, dst, deg, sat):
    import numpy as np
    im = Image.open(os.path.join(OUT, src + '.png')).convert('RGBA')
    a = np.asarray(im).astype(float) / 255
    rgb = a[..., :3]; al = a[..., 3:]
    hsv = np.asarray(Image.fromarray((rgb * 255).astype('uint8')).convert('HSV')).astype(float)
    hsv[..., 0] = (hsv[..., 0] + deg / 360 * 255) % 255; hsv[..., 1] = np.clip(hsv[..., 1] * sat + 25, 0, 255)
    out = np.asarray(Image.fromarray(hsv.astype('uint8'), 'HSV').convert('RGB')).astype(float) / 255
    Image.fromarray((np.concatenate([out, al], -1) * 255).astype('uint8'), 'RGBA').save(os.path.join(OUT, dst + '.png'), optimize=True)

def single(name, anim_rel, scale, want=(('idle', ('power', 'stance')),)):
    img, anims = parse_anim(os.path.join(CORE, 'animations', anim_rel))
    im = Image.open(os.path.join(CORE, img)).convert('RGBA')
    # 방향 하나짜리(아이템·이펙트): 첫 동작만, 모든 프레임
    for our, cands in want:
        for c in cands:
            if c in anims: A = anims[c]; break
    frames = [A['f'][k] for k in sorted(A['f']) if A['f'][k][2] > 1 and k[1] == 0]
    if not frames: frames = [v for v in A['f'].values() if v[2] > 1][:A['frames']]
    minx = min(-f[4] for f in frames); miny = min(-f[5] for f in frames)
    maxx = max(f[2] - f[4] for f in frames); maxy = max(f[3] - f[5] for f in frames)
    cw = int((maxx - minx) * scale) + 2; ch = int((maxy - miny) * scale) + 2
    sheet = Image.new('RGBA', (cw * len(frames), ch))
    for i, (x, y, w, h, ox, oy) in enumerate(frames):
        big = Image.new('RGBA', (int(maxx - minx) + 2, int(maxy - miny) + 2))
        big.alpha_composite(im.crop((x, y, x + w, y + h)), (int(-ox - minx) + 1, int(-oy - miny) + 1))
        sheet.alpha_composite(big.resize((cw, ch), Image.LANCZOS), (i * cw, 0))
    sheet.save(os.path.join(OUT, name + '.png'), optimize=True)
    print(name, sheet.size, len(frames), flush=True)
    return {'cw': cw, 'ch': ch, 'anchor': [round(-minx * scale + 1, 1), round(-miny * scale + 1, 1)], 'dirs': 1, 'anims': {'idle': {'row': 0, 'frames': len(frames), 'dur': A['dur'], 'type': A['type']}}, 'src': 'flare'}

ENEMY_ANIMS = [('stance', ('stance',)), ('run', ('run',)), ('attack', ('swing', 'shoot', 'cast')), ('hit', ('hit',)), ('die', ('die', 'critdie'))]
CAST_ANIMS = [('stance', ('stance',)), ('run', ('run',)), ('attack', ('cast', 'shoot', 'swing')), ('hit', ('hit',)), ('die', ('die', 'critdie'))]

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    mf = os.path.join(OUT, 'meta.json'); meta = json.load(open(mf)) if os.path.exists(mf) else {}
    E = lambda n: os.path.join(CORE, 'animations', 'enemies', n + '.txt')
    jobs = sys.argv[2:]
    def want(k): return not jobs or k in jobs
    # ---- 몬스터 ----
    for ours, fl, sc, anims in [('skel', 'skeleton', 1.0, ENEMY_ANIMS), ('archer', 'skeleton_archer', 1.0, ENEMY_ANIMS),
                                ('mage', 'skeleton_mage', 1.0, CAST_ANIMS), ('zombie', 'zombie', 1.0, ENEMY_ANIMS),
                                ('goblin', 'goblin', 1.0, ENEMY_ANIMS), ('antlion', 'antlion', 1.0, ENEMY_ANIMS),
                                ('antlion_small', 'antlion_small', 1.0, ENEMY_ANIMS), ('fire_ant', 'fire_ant', 1.0, ENEMY_ANIMS)]:
        if want(ours): meta[ours] = build(ours, [(E(fl), 'main')], anims, sc)
    for ours, fl, sc in [('minotaur', 'minotaur', 1.0), ('wyvern_fire', 'wyvern_fire', 1.0)]:
        if not want(ours): continue
        d = os.path.join(CORE, 'animations', 'enemies')
        # 여러 장으로 나뉜 몬스터: 같은 이름으로 시작하는 애니 파일 중 본체
        meta[ours] = build(ours, [(os.path.join(d, fl + '.txt'), 'main')], ENEMY_ANIMS, sc)
    # ---- 주인공 (마법사 옷 레이어 합성) ----
    if want('player'):
        lo = {}
        for line in open(os.path.join(CORE, 'engine', 'hero_layers.txt')):
            if line.startswith('layer='):
                parts = line.strip()[6:].split(','); lo[parts[0]] = parts[1:]
        order = [lo[k] for k in ['SW', 'W', 'NW', 'N', 'NE', 'E', 'SE', 'S']]
        A = lambda n: os.path.join(CORE, 'animations', 'avatar', 'male', n + '.txt')
        layers = [(A('head_short'), 'head'), (A('mage_hood'), 'head'), (A('mage_vest'), 'chest'), (A('mage_sleeves'), 'hands'),
                  (A('mage_skirt'), 'legs'), (A('mage_boots'), 'feet'), (A('greatstaff'), 'main')]
        meta['player'] = build('player', layers, CAST_ANIMS, 1.0, order)
    # ---- 마을 사람 ----
    for ours, fl in [('guide', 'guild_man'), ('shop', 'wandering_trader')]:
        if want(ours): meta[ours] = build(ours, [(os.path.join(CORE, 'animations', 'npcs', fl + '.txt'), 'main')], [('stance', ('stance',))], 1.0)
    # ---- 바닥에 떨어진 물건 ----
    for ours, fl in [('loot_coins', 'coins25'), ('loot_hp', 'hp_potion'), ('loot_mp', 'mp_potion'), ('loot_scroll', 'scroll'), ('loot_ring', 'ring'),
                     ('loot_staff', 'greatstaff'), ('loot_wand', 'wand'), ('loot_cloak', 'clothes'), ('loot_gem', 'gem')]:
        if want(ours): meta[ours] = loot(ours, os.path.join('loot', fl + '.txt'), 1.0)
    # ---- 마법 이펙트 ----
    for ours, fl in [('fx_fireball', 'fireball'), ('fx_icicle', 'icicle'), ('fx_lightning', 'lightning'), ('fx_plasma', 'plasmaball'),
                     ('fx_blast', 'blast'), ('fx_freeze', 'freeze'), ('fx_runes', 'runes'), ('fx_heal', 'heal'), ('fx_shield', 'shield'),
                     ('fx_spark_red', 'spark_red'), ('fx_spark_blue', 'spark_blue'), ('fx_spark_green', 'spark_green'), ('fx_spark_orange', 'spark_orange'),
                     ('fx_quake', 'quake'), ('fx_ember', 'ember'), ('fx_mist', 'dark_mist')]:
        if want(ours):
            try: meta[ours] = single(ours, os.path.join('powers', fl + '.txt'), .5, (('idle', ('power', 'stance', 'travel')),))
            except Exception as ex: print('건너뜀', ours, ex)
    if want('lich') and 'mage' in meta:
        hue_copy('mage', 'lich', 200, 1.6, pages=meta['mage'].get('pages', 1)); meta['lich'] = dict(meta['mage'])
    json.dump(meta, open(mf, 'w'), ensure_ascii=False, indent=1)
    print('meta 저장')
