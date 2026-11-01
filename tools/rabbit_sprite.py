"""미노타우로스 그림으로 '만렙 토끼'(디아블로 카우 자리) 만들기
- 털을 토끼 털빛으로, 뿔을 지우고, 머리 자리에 진짜 토끼 머리(눈은 붉게)를 붙인다
  토끼 머리: OpenGameArt 'Rabbit' (Čestmír Dammer / Kelgar, CC0) 를 8방향으로 그려 둔 rabbit_head/y*.png
  (rabbit_head/render_head.gd 로 Godot 에서 다시 그릴 수 있음)
- rabbit.png / rabbit_king.png(금빛 털 + 왕관) + meta.json 에 항목 추가
python3 tools/rabbit_sprite.py
"""
import json, math, os, numpy as np, cv2
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
    rim = ndimage.binary_dilation(keep, iterations=3) & (lum < 130)      # 뿔 테두리의 어두운 선도 같이
    return keep | rim

def recolor(c, king):
    rgb = c[..., :3]; a = c[..., 3:4]
    lum = (.3 * rgb[..., 0] + .59 * rgb[..., 1] + .11 * rgb[..., 2])[..., None]
    l = 255 * (lum / 255) ** .8
    tint = np.array([1.12, .9, .58]) if king else np.array([1.13, .96, .84])   # 금빛 / 토끼 털빛(머리와 맞춤)
    out = l * tint * .92 + rgb * .1
    return np.concatenate([np.clip(out, 0, 255), a], -1)

HEAD_DIR = os.path.join(os.path.dirname(__file__), 'rabbit_head')
YAW = [90, 135, 180, 225, 270, 315, 0, 45]         # 그림 방향 0..7 → 토끼 머리를 그린 각도
HS = .64                                             # 머리 그림 크기(256px → 128px)
def head_imgs(king):
    out = []
    for yw in YAW:
        im = Image.open(os.path.join(HEAD_DIR, 'y%d.png' % yw)).convert('RGBA')
        a = np.array(im).astype(np.float32)
        if king: a[..., :3] = np.clip(a[..., :3] * np.array([1.12, .95, .62]) * 1.05, 0, 255)
        # 붉은 눈이 작아도 보이게 붉은 번짐
        red = (a[..., 0] > 150) & (a[..., 1] < 90) & (a[..., 3] > 100)
        if yw in (135, 180, 225):          # 뒷모습: 눈이 보이면 안 됨
            a[red, 0] = a[red, 1] = a[red, 2] = 90.0; red[:] = False
        if red.any():
            g = ndimage.gaussian_filter(red.astype(np.float32), 3.0); g = g / max(1e-6, g.max())
            a[..., 0] = np.clip(a[..., 0] + g * 160, 0, 255); a[..., 1] *= (1 - g * .6); a[..., 2] *= (1 - g * .6)
        im = Image.fromarray(a.astype(np.uint8), 'RGBA')
        im = im.resize((int(im.width * HS), int(im.height * HS)), Image.LANCZOS)
        al = np.array(im)[..., 3] > 150; low = al.copy(); low[:int(im.height * .55)] = False
        ys, xs = np.nonzero(low)
        anc = (xs.mean(), ys.mean()) if len(xs) else (im.width / 2, im.height * .7)
        ys2, xs2 = np.nonzero(al)
        out.append((im, anc, ys2.min() if len(ys2) else 0))
    return out

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

def head_of(c, H, prev=None):
    # 뿔 덩어리들 중 맨 위쪽 무리. 서 있는 자세의 머리 자리(prev)가 있으면 그 근처 무리를 고름(위로 든 도끼 자루 등은 버림)
    lab, n = ndimage.label(H)
    comps = []
    for i in range(1, n + 1):
        ys, xs = np.nonzero(lab == i)
        if len(xs) >= 6: comps.append((ys.mean(), xs.mean(), ys, xs))
    if not comps: return None
    sel = []
    if prev is not None:
        near = [cc for cc in comps if abs(cc[1] - prev[0]) < 60 and abs(cc[0] - prev[1]) < 60]
        if near:
            # 가장 큰 뿔 덩어리와 그 짝(가까운 것)
            big = max(near, key=lambda cc: len(cc[3]))
            sel = [cc for cc in near if abs(cc[1] - big[1]) < 45 and abs(cc[0] - big[0]) < 30]
    if not sel:
        top = min(cc[0] for cc in comps); sel = [cc for cc in comps if cc[0] < top + 40]
    ys = np.concatenate([cc[2] for cc in sel]); xs = np.concatenate([cc[3] for cc in sel])
    if len(xs) < 8: return None
    return float(xs.mean()), float(np.percentile(ys, 35)), float(xs.max() - xs.min())

TS = 30      # 본(머리) 반쪽 크기
def gray(c):
    g = (.3 * c[..., 0] + .59 * c[..., 1] + .11 * c[..., 2]) * (c[..., 3] / 255.0)
    return g.astype(np.float32)

def make_tmpl(c, inf, ox, oy):
    hx, hy, sp = inf; cx, cy = int(hx), int(hy + 10)
    g = gray(c); hgt, wid = g.shape
    x0, y0 = max(0, cx - TS), max(0, cy - TS); x1, y1 = min(wid, cx + TS), min(hgt, cy + TS)
    t = g[y0:y1, x0:x1].copy(); m = (c[y0:y1, x0:x1, 3] > 100).astype(np.uint8)
    return {"t": t, "m": m, "off": (cx - x0, cy - y0), "cell": (cx + ox, cy + oy), "sp": sp}

def locate(c, H, ox, oy, T):
    if T is None: return head_of(c, H)
    g = gray(c); hgt, wid = g.shape; th, tw = T["t"].shape
    ex, ey = T["cell"][0] - ox, T["cell"][1] - oy          # 서 있을 때 머리 자리(이 장 좌표)
    R = 85
    sx0 = int(max(0, ex - R - T["off"][0])); sy0 = int(max(0, ey - R - T["off"][1]))
    sx1 = int(min(wid, ex + R + (tw - T["off"][0]))); sy1 = int(min(hgt, ey + R + (th - T["off"][1])))
    win = g[sy0:sy1, sx0:sx1]
    if win.shape[0] < th or win.shape[1] < tw: return head_of(c, H)
    res = cv2.matchTemplate(win, T["t"], cv2.TM_CCORR_NORMED, mask=T["m"])
    res = np.nan_to_num(res, nan=0.0, posinf=0.0, neginf=0.0)
    _, score, _, loc = cv2.minMaxLoc(res)
    cx = sx0 + loc[0] + T["off"][0]; cy = sy0 + loc[1] + T["off"][1]
    if score < .82: return head_of(c, H, (ex, ey - 10))
    return float(cx), float(cy - 10), T["sp"]

def build(king):
    fr = SRC['fr']; out_frames = []; last = {}
    tmpls = {}
    for d8 in range(8):
        f0 = fr[d8 * 8]
        if f0 is None: continue
        c0 = SHEET[f0[2]:f0[2] + f0[4], f0[1]:f0[1] + f0[3]].copy()
        inf = head_of(c0, horn_mask(c0))
        if inf is None: continue
        tmpls[d8] = make_tmpl(c0, inf, f0[5], f0[6])
    heads = head_imgs(king); crown = crown_img(30)
    for idx, f in enumerate(fr):
        if f is None:
            out_frames.append(None); continue
        pg, x, y, w, h, ox, oy = f
        c = SHEET[y:y + h, x:x + w].copy()
        H = horn_mask(c)
        # 머리 위치: 서 있는 자세(방향마다 첫 장)에서 뿔로 찾은 소 머리를 본으로, 모든 장에서 그 머리 모양을 찾아냄(템플릿 매칭)
        row = idx // 8; d8 = row % 8
        info = locate(c, H, ox, oy, tmpls.get(d8))
        if info is None: info = last.get(row)
        last[row] = info
        # 소 머리를 뿔째 통째로 지우기(어차피 토끼 머리로 덮음): 머리 둘레 네모(뿔 끝까지), 도끼날(회색 쇠)은 남김
        if info is not None:
            hx0, hy0, sp0 = info
            half = min(40, max(24, sp0 / 2 + 6))
            yy, xx = np.mgrid[0:h, 0:w]
            R = ((xx - hx0) / half) ** 2 + ((yy - (hy0 + 2)) / 24.0) ** 2 < 1.0        # 머리 둘레 타원(어깨는 안 깎이게)
            near = (xx - hx0) ** 2 + (yy - hy0) ** 2 < 75 ** 2
            H = H & near                                                          # 뿔 끝은 색으로(타원 밖이어도)
            rr, gg, bb = c[..., 0], c[..., 1], c[..., 2]
            mx_ = np.maximum(np.maximum(rr, gg), bb); mn_ = np.minimum(np.minimum(rr, gg), bb)
            metal = ((mx_ - mn_) / (mx_ + 1e-6) < .1) & (mx_ > 110)
            H = H | ndimage.binary_dilation(H, iterations=3) & (c[..., 3] > 0) | (R & ~metal)
        # 뿔 지우기 + 구멍 메우기
        body = (c[..., 3] > 30) & ~H
        holes = ndimage.binary_fill_holes(body) & ~body
        c[H, 3] = 0
        if holes.any():
            # 구멍은 가장 가까운 살갗 색으로 채움
            _, (iy, ix) = ndimage.distance_transform_edt(~((c[..., 3] > 30) & ~H), return_indices=True)
            c[holes, :3] = c[iy[holes], ix[holes], :3]; c[holes, 3] = 255
        # 떨어져 나간 작은 조각(뿔 끝 등)은 지움
        lab2, n2 = ndimage.label(c[..., 3] > 30)
        if n2 > 1:
            sz = ndimage.sum(np.ones_like(lab2), lab2, range(1, n2 + 1)); big = np.argmax(sz) + 1
            for i in range(1, n2 + 1):
                if i != big and sz[i - 1] < 220: c[lab2 == i, 3] = 0
        c = recolor(c, king)
        im = Image.new('RGBA', (w, h + PAD), (0, 0, 0, 0))
        im.paste(Image.fromarray(c.astype(np.uint8), 'RGBA'), (0, PAD))
        if info is not None:
            hx, hy, spread = info; hy += PAD
            hi, anc, top = heads[(idx // 8) % 8]
            fx, fy = hx, hy + 22                       # 소 머리 얼굴 가운데쯤
            px = int(round(fx - anc[0])); py = int(round(fy - anc[1]))
            im.alpha_composite(hi, (max(0, px), max(0, py)))
            if king:
                paste_rot(im, crown, fx, fy - 20, 0, 1.0)
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
