"""
모든 캐릭터·몬스터·소품 스프라이트 시트를 렌더링한다.
출력: www/assets/sprites/<이름>.png (행=방향, 열=프레임) + www/assets/sprites/meta.json
방향 5개: 아래, 오른쪽아래, 오른쪽, 오른쪽위, 위 (왼쪽 방향은 게임에서 좌우 반전)
"""
import sys, os, json, time
import numpy as np
from multiprocessing import Pool
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import models as M
from sdf import render, project

OUT = os.path.join(os.path.dirname(__file__), '..', 'www', 'assets', 'sprites')
YAWS = [0, np.pi / 4, np.pi / 2, 3 * np.pi / 4, np.pi]

def W(**kw): return lambda ph: M.wizard(ph, **kw)
SPECS = {
    # 이름: (모델, 픽셀, 화면폭(모델단위), 중심높이, 방향수, 프레임수)
    'player':  (W(), 160, 1.6, 0.62, 5, 6),
    'guide':   (W(robe=(60, 90, 158), hat=(42, 63, 115), beard=(217, 211, 199), staff_orb=(255, 220, 140)), 160, 1.6, 0.62, 5, 1),
    'shop':    (W(robe=(138, 58, 90), hat=(94, 36, 64), trim=(255, 210, 122), staff_orb=(255, 150, 200)), 160, 1.6, 0.62, 5, 1),
    'skel':    (lambda ph: M.skeleton(ph, 'sword'), 128, 1.5, 0.55, 5, 6),
    'archer':  (lambda ph: M.skeleton(ph, 'bow'), 128, 1.5, 0.55, 5, 6),
    'mage_ice':    (lambda ph: M.skelmage(ph, 'ice'), 144, 1.7, 0.6, 5, 6),
    'mage_poison': (lambda ph: M.skelmage(ph, 'poison'), 144, 1.7, 0.6, 5, 6),
    'zombie':  (M.zombie, 128, 1.5, 0.5, 5, 6),
    'shade':   (M.shade, 128, 1.4, 0.45, 5, 6),
    'demon':   (M.demon, 192, 2.5, 0.75, 5, 6),
    'imp':     (M.imp, 112, 1.2, 0.36, 1, 6),
    'bat':     (M.bat, 128, 1.4, 0.48, 1, 6),
    'golem':   (M.golem, 224, 2.2, 0.75, 5, 6),
    'flesh':   (M.flesh, 192, 1.5, 0.36, 5, 6),
    'warlock': (M.warlock, 192, 2.3, 0.8, 5, 6),
    'chest':   (lambda ph: M.chest(False), 112, 1.0, 0.22, 1, 1),
    'chest_open': (lambda ph: M.chest(True), 112, 1.0, 0.25, 1, 1),
}

def job(args):
    name, d = args
    fn, px, view, ty, nd, nf = SPECS[name]
    yaw = YAWS[d] if nd > 1 else 0.0
    frames = []; tips = []
    for f in range(nf):
        ph = 2 * np.pi * f / nf
        S = fn(ph)
        img = render(S, px, view, target=(0, ty, 0), yaw=yaw, ss=2)
        frames.append(img)
        if hasattr(S, 'staff_tip'):
            tips.append([round(v, 1) for v in project(S.staff_tip, px, view, target=(0, ty, 0), yaw=yaw)])
    row = np.concatenate(frames, 1)
    Image.fromarray((np.clip(row, 0, 1) * 255).astype(np.uint8), 'RGBA').save(os.path.join(OUT, f'_{name}_{d}.png'))
    return name, d, tips

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[1:] or list(SPECS)
    jobs = [(n, d) for n in only for d in range(SPECS[n][4])]
    t0 = time.time(); tips = {}
    with Pool(2) as pool:
        for name, d, tp in pool.imap_unordered(job, jobs):
            tips.setdefault(name, {})[d] = tp
            print(f'{name} 방향{d} 완료 ({time.time() - t0:.0f}s)', flush=True)
    metaf = os.path.join(OUT, 'meta.json')
    meta = json.load(open(metaf)) if os.path.exists(metaf) else {}
    for name in only:
        fn, px, view, ty, nd, nf = SPECS[name]
        rows = [Image.open(os.path.join(OUT, f'_{name}_{d}.png')) for d in range(nd)]
        sheet = Image.new('RGBA', (px * nf, px * nd))
        for d, r in enumerate(rows): sheet.paste(r, (0, d * px))
        sheet.save(os.path.join(OUT, f'{name}.png'), optimize=True)
        for d in range(nd): os.remove(os.path.join(OUT, f'_{name}_{d}.png'))
        ax, ay = project((0, 0, 0), px, view, target=(0, ty, 0))
        meta[name] = {'px': px, 'view': view, 'dirs': nd, 'frames': nf, 'anchor': [round(ax, 1), round(ay, 1)]}
        if tips.get(name) and any(tips[name].values()):
            meta[name]['tips'] = [tips[name][d] for d in range(nd)]
    json.dump(meta, open(metaf, 'w'), ensure_ascii=False, indent=1)
    print('끝', f'{time.time() - t0:.0f}s')
