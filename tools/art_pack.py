# GPT 그림 묶음 → godot/art (월드 그림은 절반 크기) + art.json(칸·발 위치)
import sys, os, glob, json
from PIL import Image
import numpy as np
src, dst = sys.argv[1], sys.argv[2]
fix = sys.argv[3] if len(sys.argv) > 3 else None
os.makedirs(dst, exist_ok=True)
files = {os.path.splitext(os.path.basename(p))[0]: p for p in glob.glob(src + '/**/*.png', recursive=True)}
if fix:
    for p in glob.glob(fix + '/*.png'): files[os.path.splitext(os.path.basename(p))[0]] = p
WORLD = ('player', 'npc_', 'mon_', 'boss_', 'tile_', 'prop_', 'bld_', 'nat_', 'spare_mon', 'spare_boss', 'spare_prop')
meta = {}
for k, p in sorted(files.items()):
    if not k.startswith(WORLD): continue
    im = Image.open(p).convert('RGBA')
    a = np.array(im)
    if k == 'prop_lab_table': a[a[:, :, 3] < 100, 3] = 0          # 남은 반투명 배경 지우기
    if k == 'bld_tower_gate': a = np.concatenate([a[52:], np.zeros((52,) + a.shape[1:], a.dtype)])   # 발 위치 64px로
    im = Image.fromarray(a)
    w, h = im.size
    im = im.resize((w // 2, h // 2), Image.LANCZOS)
    w, h = im.size
    im.save(os.path.join(dst, k + '.png'), optimize=True)
    if k.startswith('tile_'): continue
    al = np.array(im)[:, :, 3]
    n = 4 if (w == 4 * h and h >= 256) else 1
    cw = w // n
    boxes = []
    for c in range(n):
        ys, xs = np.where(al[:, c * cw:(c + 1) * cw] > 110)
        boxes.append([int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())] if len(xs) else [0, 0, cw, h])
    meta[k] = {'w': w, 'h': h, 'n': n, 'b': boxes}
json.dump(meta, open(os.path.join(dst, 'art.json'), 'w'), separators=(',', ':'))
print(len(meta), 'meta')
