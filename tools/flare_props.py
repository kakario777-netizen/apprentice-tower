"""Flare(CC-BY-SA 3.0) 타일셋에서 소품 그림과 바닥 질감을 뽑아낸다.
사용: python3 tools/flare_props.py <flare 저장소 경로>
- 소품: www/assets/props/<이름>.png + props.json(앵커 = 땅에 닿는 점)
- 바닥: 아이소메트릭 마름모 타일을 정사각형으로 펼쳐 www/assets/tiles/grass3.png, path3.png
"""
import os, re, sys, json
import numpy as np
from PIL import Image

FLARE = sys.argv[1] if len(sys.argv) > 1 else 'flare'
CORE = os.path.join(FLARE, 'mods', 'fantasycore')
OUT = os.path.join(os.path.dirname(__file__), '..', 'www', 'assets')

def tiles(name):
    im = Image.open(os.path.join(CORE, 'images', 'tilesets', name + '.png')).convert('RGBA'); out = {}
    for l in open(os.path.join(CORE, 'tilesetdefs', name + '.txt')):
        m = re.match(r'tile=(\d+),(\d+),(\d+),(\d+),(\d+),(-?\d+),(-?\d+)', l.strip())
        if m:
            i, x, y, w, h, ox, oy = map(int, m.groups())
            out[i] = (im.crop((x, y, x + w, y + h)), ox, oy)
    return out

PROPS = {
    'tileset_grassland': {
        'oak1': 252, 'oak2': 253, 'oak3': 254, 'oak4': 255, 'pine1': 248, 'pine2': 249, 'pine3': 250, 'pine4': 251,
        'birch1': 240, 'birch2': 241, 'birch3': 242, 'birch4': 243, 'deadtree1': 244, 'deadtree2': 245,
        'fern1': 112, 'fern2': 113, 'leaf1': 116, 'leaf2': 117, 'flower1': 118, 'flower2': 119,
        'shrub1': 120, 'shrub2': 121, 'shrub3': 122, 'shrub4': 123, 'grass1': 124, 'grass2': 125, 'grass3': 126, 'grass4': 127,
        'rock1': 128, 'rock2': 129, 'rock3': 130, 'rock4': 131, 'stump1': 136, 'stump2': 137, 'sign1': 138, 'sign2': 139,
        'grave1': 140, 'grave2': 141, 'cross1': 142, 'cross2': 143, 'crate1': 96, 'crate2': 97, 'crate3': 98, 'crate4': 99,
        'wood1': 100, 'wood2': 101, 'campfire': 102, 'anvil': 103, 'fence1': 104, 'fence2': 107, 'waystone': 264, 'waystone_on': 265,
    },
    'tileset_dungeon': {
        'bones1': 176, 'bones2': 177, 'skulls': 178, 'bones3': 179, 'bones4': 180, 'bones5': 181, 'skeleton1': 182, 'skeleton2': 183,
        'barrel1': 146, 'barrel2': 162, 'dcrate1': 147, 'dcrate2': 163, 'chest_c': 144, 'chest_c2': 145, 'chest_o': 160, 'chest_o2': 161,
        'lectern1': 148, 'lectern2': 164, 'statue1': 128, 'statue2': 130, 'brazier': 151, 'chain1': 192, 'chain2': 193,
        'stairs_down': 286, 'stairs_down2': 287, 'rune1': 17, 'rune2': 18, 'table1': 122, 'throne': 132,
    },
}

def props():
    os.makedirs(os.path.join(OUT, 'props'), exist_ok=True); meta = {}
    for ts, names in PROPS.items():
        T = tiles(ts)
        for nm, idx in names.items():
            im, ox, oy = T[idx]
            bb = im.getbbox()
            if not bb: continue
            c = im.crop(bb); ax, ay = ox - bb[0], oy - bb[1]
            c.save(os.path.join(OUT, 'props', nm + '.png'), optimize=True)
            meta[nm] = {'w': c.width, 'h': c.height, 'ax': ax, 'ay': ay}
    json.dump(meta, open(os.path.join(OUT, 'props', 'props.json'), 'w'))
    print('props', len(meta))

def iso2sq(im, n=128):
    a = np.asarray(im).astype(float); h, w = a.shape[:2]
    u, v = np.meshgrid((np.arange(n) + .5) / n, (np.arange(n) + .5) / n)
    x = w / 2 + (u - v) * (w / 2) - .5; y = (u + v) * (h / 2) - .5
    x = np.clip(x, 0, w - 1.001); y = np.clip(y, 0, h - 1.001)
    x0 = x.astype(int); y0 = y.astype(int); fx = (x - x0)[..., None]; fy = (y - y0)[..., None]
    p = a[y0, x0] * (1 - fx) * (1 - fy) + a[y0, x0 + 1] * fx * (1 - fy) + a[y0 + 1, x0] * (1 - fx) * fy + a[y0 + 1, x0 + 1] * fx * fy
    p[..., 3] = 255
    return Image.fromarray(p.clip(0, 255).astype('uint8'))

def floors():
    T = tiles('tileset_grassland')
    for out, ids in [('grass3', range(16, 32)), ('path3', range(32, 48))]:
        sheet = Image.new('RGBA', (128 * len(ids), 128))
        for k, i in enumerate(ids): sheet.paste(iso2sq(T[i][0]), (k * 128, 0))
        sheet.save(os.path.join(OUT, 'tiles', out + '.png'), optimize=True)
    D = tiles('tileset_dungeon')
    sheet = Image.new('RGBA', (128 * 10, 128))
    for k, i in enumerate(range(36, 46)): sheet.paste(iso2sq(D[i][0]), (k * 128, 0))
    sheet.save(os.path.join(OUT, 'tiles', 'plaza3.png'), optimize=True)
    print('floors ok')

if __name__ == '__main__':
    props(); floors()
