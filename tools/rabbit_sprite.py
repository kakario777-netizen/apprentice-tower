"""미노타우로스 그림으로 '만렙 토끼'(디아블로 카우 자리) 만들기
- 털을 하얗게(살짝 회색), 뿔을 지우고, 머리 위에 긴 토끼 귀를 그린다
- rabbit.png / rabbit_king.png(금빛 털 + 왕관) + meta.json 에 항목 추가
python3 tools/rabbit_sprite.py
"""
import json, math, os, numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

D = os.path.join(os.path.dirname(__file__), '..', 'godot', 'assets', 'sprites')
META = json.load(open(os.path.join(D, 'meta.json')))
SRC = META['minotaur']
SHEET = np.array(Image.open(os.path.join(D, 'minotaur.png')).convert('RGBA')).astype(np.float32)
PAD = 70          # 귀 들어갈 자리(위쪽)
SC = .8           # 4096 안에 들어가게 줄임(게임에선 hgt 기준이라 크기 같음)
SS = 4            # 귀 그릴 때 확대(매끈하게)

def horn_mask(c):
    r, g, b, a = c[..., 0], c[..., 1], c[..., 2], c[..., 3]
    lum = .3 * r + .59 * g + .11 * b
    mx = np.maximum(np.maximum(r, g), b); mn = np.minimum(np.minimum(r, g), b)
    sat = (mx - mn) / (mx + 1e-6)
    # 상아색 뿔: 밝고, 노르스름하지만 피부보다 덜 붉다(도끼날은 회색이라 빠짐)
    m = (a > 120) & (lum > 150) & (r - b > 30) & (r - b < 78) & (sat < .34) & (sat > .14) & (g > b + 15)
    m = ndimage.binary_opening(m, iterations=1)
    lab, n = ndimage.label(m)
    keep = np.zeros_like(m)
    for i in range(1, n + 1):
        if (lab == i).sum() >= 8: keep |= lab == i
    rim = ndimage.binary_dilation(keep, iterations=2) & (lum < 115)      # 뿔 테두리의 어두운 선도 같이
    return keep | rim

def recolor(c, king):
    rgb = c[..., :3]; a = c[..., 3:4]
    lum = (.3 * rgb[..., 0] + .59 * rgb[..., 1] + .11 * rgb[..., 2])[..., None]
    l = 255 * (lum / 255) ** .72                       # 밝게
    if king:
        tint = np.array([1.08, .9, .6])               # 금빛 털
        out = l * tint * .95 + rgb * .12
    else:
        tint = np.array([1.0, .98, .97])              # 하얀 털(살짝 따뜻하게)
        out = l * tint * .9 + rgb * .1
    return np.concatenate([np.clip(out, 0, 255), a], -1)

def ear_img(L, W, king):
    """세로로 선 귀 하나(밑동이 아래 가운데)"""
    w, h = int(W * SS * 1.6), int(L * SS * 1.15)
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    cx = w / 2
    outer = (242, 236, 228) if not king else (238, 200, 120)
    edge = (150, 142, 135) if not king else (150, 110, 50)
    d.ellipse([cx - W * SS / 2 - SS, h - L * SS - SS, cx + W * SS / 2 + SS, h + SS], fill=edge + (255,))
    d.ellipse([cx - W * SS / 2, h - L * SS, cx + W * SS / 2, h], fill=outer + (255,))
    d.ellipse([cx - W * SS * .26, h - L * SS * .9, cx + W * SS * .26, h - L * SS * .08], fill=(222, 140, 150, 255))
    d.ellipse([cx - W * SS * .12, h - L * SS * .82, cx + W * SS * .12, h - L * SS * .2], fill=(240, 175, 182, 255))
    # 한쪽 그늘
    sh = Image.new('L', (w, h), 0); ImageDraw.Draw(sh).ellipse([cx, h - L * SS, cx + W * SS / 2 + SS, h], fill=70)
    dark = Image.new('RGBA', (w, h), (40, 30, 30, 0)); dark.putalpha(sh)
    im = Image.alpha_composite(im, Image.composite(dark, Image.new('RGBA', (w, h)), im.split()[3]))
    return im

def crown_img(S):
    w, h = int(S * SS * 1.3), int(S * SS * .9)
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    x0, x1, yb, yt = w * .1, w * .9, h * .95, h * .1
    pts = [(x0, yb), (x0, h * .45), (w * .25, yt + h * .2), (w * .37, h * .45), (w * .5, yt), (w * .63, h * .45), (w * .75, yt + h * .2), (x1, h * .45), (x1, yb)]
    d.polygon(pts, fill=(140, 95, 20, 255)); d.polygon([(p[0], p[1] + SS * .8) for p in pts[1:-1]] + [(x1 - SS, yb - SS), (x0 + SS, yb - SS)], fill=(250, 200, 70, 255))
    d.rectangle([x0, h * .7, x1, yb], fill=(220, 160, 40, 255))
    for gx, col in [(w * .3, (220, 40, 60)), (w * .5, (60, 140, 255)), (w * .7, (220, 40, 60))]:
        d.ellipse([gx - SS * 2, h * .74, gx + SS * 2, h * .74 + SS * 4], fill=col + (255,))
    return im

def paste_rot(base, part, cx, by, ang, scale=1.0):
    """part 의 밑동 가운데를 (cx, by)에 두고 ang(도) 기울여 붙임"""
    p = part.rotate(ang, resample=Image.BICUBIC, expand=True, center=(part.width / 2, part.height))
    # 회전 후 밑동 위치 계산
    r = math.radians(-ang); w0, h0 = part.width, part.height
    bx, byy = 0, h0 / 2                                   # 중심 기준 밑동
    rx = bx * math.cos(r) - byy * math.sin(r); ry = bx * math.sin(r) + byy * math.cos(r)
    p = p.resize((max(1, int(p.width / SS * scale)), max(1, int(p.height / SS * scale))), Image.LANCZOS)
    px = cx - p.width / 2 - rx / SS * scale; py = by - p.height / 2 - ry / SS * scale
    base.alpha_composite(p, (int(round(px)), int(round(py))))

def head_of(c, H):
    ys, xs = np.nonzero(H)
    if len(xs) < 8: return None
    return float(xs.mean()), float(np.percentile(ys, 35)), float(xs.max() - xs.min())

def build(king):
    fr = SRC['fr']; out_frames = []; last = {}
    ear = ear_img(64, 17, king); crown = crown_img(30)
    for idx, f in enumerate(fr):
        if f is None:
            out_frames.append(None); continue
        pg, x, y, w, h, ox, oy = f
        c = SHEET[y:y + h, x:x + w].copy()
        H = horn_mask(c)
        info = head_of(c, H)
        anim_dir = idx // 8
        if info is None: info = last.get(anim_dir % 8)
        else: last[anim_dir % 8] = info
        # 뿔 지우기 + 구멍 메우기
        body = (c[..., 3] > 30) & ~H
        holes = ndimage.binary_fill_holes(body) & ~body
        c[H, 3] = 0
        if holes.any():
            blur = np.stack([ndimage.uniform_filter(c[..., k] * (c[..., 3] > 30), 5) for k in range(3)], -1)
            wgt = ndimage.uniform_filter((c[..., 3] > 30).astype(np.float32), 5)[..., None] + 1e-6
            c[holes, :3] = (blur / wgt)[holes]; c[holes, 3] = 255
        c = recolor(c, king)
        im = Image.new('RGBA', (w, h + PAD), (0, 0, 0, 0))
        im.paste(Image.fromarray(c.astype(np.uint8), 'RGBA'), (0, PAD))
        if info is not None:
            hx, hy, spread = info; hy += PAD
            side = spread < 26                     # 옆모습: 귀가 겹쳐 보임
            gap = 5 if side else min(13, spread * .22)
            s = 1.0
            for k, sgn in enumerate([-1, 1]):
                a = sgn * (6 if side else 14) + (8 if side else 0)
                paste_rot(im, ear, hx + sgn * gap, hy + 4, -a, s * (.92 if (side and k == 0) else 1.0))
            if king:
                paste_rot(im, crown, hx, hy + 10, 0, 1.0)
        im = im.resize((max(1, round(im.width * SC)), max(1, round(im.height * SC))), Image.LANCZOS)
        out_frames.append((im, ox * SC, (oy - PAD) * SC))
    # 선반식으로 다시 담기
    W = 4096; xs = ys = 0; rowh = 0; places = []
    for it in out_frames:
        if it is None:
            places.append(None); continue
        im = it[0]
        if xs + im.width > W:
            xs = 0; ys += rowh + 1; rowh = 0
        places.append((xs, ys)); xs += im.width + 1; rowh = max(rowh, im.height)
    H_ = ys + rowh + 1
    sheet = Image.new('RGBA', (W, H_), (0, 0, 0, 0)); newfr = []
    for it, pl in zip(out_frames, places):
        if it is None:
            newfr.append(None); continue
        im, ox, oy = it; sheet.paste(im, pl)
        newfr.append([0, pl[0], pl[1], im.width, im.height, ox, oy])
    name = 'rabbit_king' if king else 'rabbit'
    sheet.save(os.path.join(D, name + '.png'))
    m = dict(SRC); m['fr'] = newfr; m['pages'] = 1
    m['cw'] = SRC['cw'] * SC; m['ch'] = SRC['ch'] * SC; m['anchor'] = [SRC['anchor'][0] * SC, SRC['anchor'][1] * SC]; m['hgt'] = SRC['hgt'] * SC
    META[name] = m
    print(name, sheet.size)

build(False); build(True)
json.dump(META, open(os.path.join(D, 'meta.json'), 'w'), ensure_ascii=False, separators=(',', ':'))
