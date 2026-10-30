"""
바닥·벽·마을 타일 텍스처 생성 (타일당 128px).
높이맵 → 법선 → 빛(왼쪽 위) + 틈새 그늘(AO) + 정반사로 입체감을 굽는다.
출력: www/assets/tiles/*.png (가로로 이어 붙인 아틀라스)
"""
import os, numpy as np
from PIL import Image, ImageDraw, ImageFilter

TS = 128
OUT = os.path.join(os.path.dirname(__file__), '..', 'www', 'assets', 'tiles')
rng = np.random.default_rng(7)

# ---------- 이어지는 노이즈 ----------
def pnoise(n, size=TS, seed=0):
    g = np.random.default_rng(seed).random((n, n))
    x = np.arange(size) / size * n
    i = np.floor(x).astype(int); f = x - i; f = f * f * (3 - 2 * f)
    i0 = i % n; i1 = (i + 1) % n
    a = g[np.ix_(i0, i0)]; b = g[np.ix_(i0, i1)]; c = g[np.ix_(i1, i0)]; d = g[np.ix_(i1, i1)]
    fy = f[:, None]; fx = f[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy

def fbm(base=4, oct=5, seed=0, size=TS):
    t = 0; a = 0.5; s = 0
    for k in range(oct):
        t = t + a * pnoise(base * 2 ** k, size, seed + k * 101); s += a; a *= 0.5
    return t / s

def blur(h, r):
    im = Image.fromarray((np.clip(h, 0, 1) * 65535).astype(np.uint16).astype(np.int32), 'I')
    # PIL 블러는 8비트 위주라 numpy로 상자 블러 반복
    out = h.copy()
    for _ in range(3):
        out = (np.roll(out, r, 0) + np.roll(out, -r, 0) + out) / 3
        out = (np.roll(out, r, 1) + np.roll(out, -r, 1) + out) / 3
    return out

def shade(albedo, h, strength=6.0, spec=0.15, ao_amt=1.4, light=(-0.55, -0.62, 0.56), amb=0.42):
    gy, gx = np.gradient(h)
    n = np.dstack([-gx * strength * TS / 32, -gy * strength * TS / 32, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    L = np.array(light); L /= np.linalg.norm(L)
    diff = np.clip((n * L).sum(2), 0, 1)
    ao = np.clip(1 - ao_amt * np.clip(blur(h, 3) - h, 0, None) * 6, 0.25, 1)
    Hh = L + np.array([0, 0, 1.0]); Hh /= np.linalg.norm(Hh)
    sp = np.clip((n * Hh).sum(2), 0, 1) ** 28 * spec
    col = albedo * (amb * ao + 0.85 * diff * (0.55 + 0.45 * ao))[..., None] + sp[..., None]
    return np.clip(col, 0, 1)

def save(name, tiles):
    os.makedirs(OUT, exist_ok=True)
    strip = np.concatenate(tiles, 1)
    Image.fromarray((strip * 255).astype(np.uint8), 'RGB' if strip.shape[2] == 3 else 'RGBA').save(os.path.join(OUT, name + '.png'), optimize=True)

yy, xx = np.mgrid[0:TS, 0:TS]

def slab_height(rects, bevel=7, seed=0):
    h = np.full((TS, TS), 0.0); idmap = np.full((TS, TS), -1)
    for k, (x, y, w, hh) in enumerate(rects):
        x, y, w, hh = [v * 2 for v in (x, y, w, hh)]
        inside = (xx >= x) & (xx < x + w) & (yy >= y) & (yy < y + hh)
        d = np.minimum(np.minimum(xx - x, x + w - 1 - xx), np.minimum(yy - y, y + hh - 1 - yy)).astype(float)
        prof = np.clip(d / bevel, 0, 1); prof = prof * prof * (3 - 2 * prof)
        top = 0.55 + 0.12 * np.random.default_rng(seed + k).random()
        h = np.where(inside, np.maximum(h, prof * top), h); idmap = np.where(inside, k, idmap)
    return h, idmap

def cracks(h, seed, n=2, depth=0.25):
    r = np.random.default_rng(seed)
    im = Image.new('L', (TS, TS), 0); dr = ImageDraw.Draw(im)
    for _ in range(n):
        x, y = r.random() * TS, r.random() * TS; pts = [(x, y)]
        for _ in range(6):
            x += (r.random() - 0.5) * 30; y += (r.random() - 0.3) * 22; pts.append((x, y))
        dr.line(pts, fill=255, width=2)
        if r.random() < 0.6:
            bx, by = pts[3]; dr.line([(bx, by), (bx + (r.random() - 0.5) * 30, by + r.random() * 20)], fill=200, width=1)
    c = np.asarray(im.filter(ImageFilter.GaussianBlur(0.6)), float) / 255
    return h - c * depth

PATS = [
    [[1, 1, 30, 30], [33, 1, 30, 30], [1, 33, 30, 30], [33, 33, 30, 30]],
    [[1, 1, 62, 62]],
    [[1, 1, 40, 19], [43, 1, 20, 19], [1, 22, 20, 20], [23, 22, 40, 20], [1, 44, 29, 19], [32, 44, 31, 19]],
    [[1, 1, 30, 62], [33, 1, 30, 30], [33, 33, 30, 30]],
    [[1, 1, 62, 30], [1, 33, 30, 30], [33, 33, 30, 30]],
    [[1, 1, 20, 30], [23, 1, 40, 30], [1, 33, 40, 30], [43, 33, 20, 30]],
]

def floor_tiles():
    tiles = []
    for v in range(14):
        h, ids = slab_height(PATS[v % len(PATS)], seed=v * 13)
        det = fbm(6, 5, seed=v * 7)
        h = h + (det - 0.5) * 0.16 * (ids >= 0) + (fbm(16, 3, seed=v * 5 + 3) - 0.5) * 0.05
        pits = fbm(24, 2, seed=v * 3 + 1); h -= np.clip(pits - 0.72, 0, 1) * 0.6 * (ids >= 0)
        if v % 3 != 1: h = cracks(h, v * 31, n=1 + v % 2)
        base = np.array([0.30, 0.26, 0.25])
        tint = np.zeros((TS, TS, 3))
        for k in range(ids.max() + 1):
            t = np.random.default_rng(v * 100 + k).normal(0, 0.008, 3) + np.random.default_rng(v * 100 + k + 50).normal(0, 0.035)
            tint[ids == k] = t
        cn = fbm(5, 4, seed=v * 11 + 9)
        alb = base + tint + (cn[..., None] - 0.5) * 0.12
        mortar = ids < 0
        alb[mortar] = np.array([0.09, 0.075, 0.08]) + (cn[mortar][:, None] - 0.5) * 0.04
        moss = (fbm(5, 4, seed=v * 17) > 0.6) & (h < 0.35)
        if v % 4 == 0:
            alb[moss] = alb[moss] * 0.5 + np.array([0.12, 0.2, 0.09]) * 0.5
        dirt = fbm(3, 3, seed=v * 19) ; alb *= (0.85 + 0.25 * dirt)[..., None]
        tiles.append(shade(alb, h, strength=4.2, spec=0.12))
    save('floor', tiles)

def face_tiles():
    tiles = []
    for v in range(6):
        r = np.random.default_rng(500 + v)
        h = np.zeros((TS, TS)); ids = np.full((TS, TS), -1); k = 0
        # 위쪽 마감석
        cap = (yy < 22); h = np.where(cap, 0.75 - np.clip((yy - 16) / 6, 0, 1) * 0.3, h); ids = np.where(cap, 999, ids)
        y = 26; row = 0
        while y < TS:
            bh = min(34, TS - y); x = -36 if row % 2 else 0
            while x < TS:
                bw = 62 + int(r.random() * 28)
                inside = (xx >= x + 2) & (xx < x + bw - 2) & (yy >= y + 2) & (yy < y + bh - 1)
                d = np.minimum(np.minimum(xx - x - 2, x + bw - 3 - xx), np.minimum(yy - y - 2, y + bh - 2 - yy)).astype(float)
                prof = np.clip(d / 7, 0, 1); prof = prof * prof * (3 - 2 * prof)
                top = 0.5 + 0.15 * r.random()
                h = np.where(inside, prof * top, h); ids = np.where(inside, k, ids); k += 1
                x += bw
            y += bh; row += 1
        det = fbm(6, 5, seed=600 + v)
        h = h + (det - 0.5) * 0.18 * (ids >= 0)
        h = cracks(h, 700 + v, n=1, depth=0.2)
        alb = np.zeros((TS, TS, 3)) + np.array([0.31, 0.27, 0.27])
        for kk in range(k):
            alb[ids == kk] += r.normal(0, 0.008, 3) + r.normal(0, 0.04)
        alb[ids == 999] = np.array([0.30, 0.27, 0.27])
        alb[ids < 0] = np.array([0.07, 0.06, 0.065])
        cn = fbm(4, 4, seed=650 + v); alb *= (0.8 + 0.35 * cn)[..., None]
        if v % 2 == 0:  # 이끼 흘러내림
            mx = r.integers(10, 110); drip = (np.abs(xx - mx - 6 * np.sin(yy / 9)) < 4 + 3 * fbm(8, 2, seed=v)) & (yy < 30 + r.integers(20, 70))
            alb[drip] = alb[drip] * 0.4 + np.array([0.12, 0.2, 0.08]) * 0.6
        col = shade(alb, h, strength=6, spec=0.1, light=(-0.45, -0.25, 0.85))
        # 아래쪽 그늘, 마감석 아래 그림자
        g = np.clip((yy - 96) / 32, 0, 1) ** 1.5 * 0.65
        col *= (1 - g)[..., None]
        s = np.clip(1 - (yy - 22) / 14, 0, 1) * (yy >= 22) * 0.5
        col *= (1 - s)[..., None]
        tiles.append(col)
    save('face', tiles)

def top_tiles():
    tiles = []
    base = fbm(5, 5, seed=900)
    for m in range(16):
        h = base * 0.3
        alb = np.zeros((TS, TS, 3)) + np.array([0.11, 0.09, 0.095]) * (0.8 + 0.4 * base)[..., None]
        edge = np.zeros((TS, TS))
        if m & 1: edge = np.maximum(edge, np.clip(1 - yy / 10, 0, 1))
        if m & 2: edge = np.maximum(edge, np.clip(1 - (TS - 1 - xx) / 10, 0, 1))
        if m & 8: edge = np.maximum(edge, np.clip(1 - xx / 10, 0, 1))
        h = h + edge * 0.5
        alb = alb * (1 - edge[..., None]) + np.array([0.36, 0.31, 0.31])[None, None] * edge[..., None]
        tiles.append(shade(alb, h, strength=4, spec=0.05))
    save('top', tiles)

def grass_tiles():
    tiles = []
    for v in range(10):
        n1 = fbm(4, 5, seed=1000 + v); n2 = fbm(12, 3, seed=1100 + v)
        h = n1 * 0.4 + n2 * 0.2
        alb = np.dstack([0.13 + 0.06 * n1, 0.24 + 0.1 * n1 + 0.05 * n2, 0.12 + 0.04 * n2])
        col = shade(alb, h, strength=3, spec=0.02)
        im = Image.fromarray((col * 255).astype(np.uint8)).resize((TS * 2, TS * 2), Image.BICUBIC)
        dr = ImageDraw.Draw(im); r = np.random.default_rng(1200 + v)
        for _ in range(900):
            x, y = r.random() * TS * 2, r.random() * TS * 2; l = 5 + r.random() * 9; lean = (r.random() - 0.5) * 6
            c = r.random()
            col_b = (int(60 + 50 * c), int(105 + 70 * c), int(45 + 30 * c)) if r.random() < 0.7 else (18, 40, 22)
            for ox in (0, TS * 2, -TS * 2):
                for oy in (0, TS * 2, -TS * 2):
                    dr.line([(x + ox, y + oy), (x + ox + lean, y + oy - l)], fill=col_b, width=2)
        im = im.resize((TS, TS), Image.LANCZOS)
        tiles.append(np.asarray(im, float) / 255)
    save('grass', tiles)

def voronoi(npts, seed):
    r = np.random.default_rng(seed); pts = r.random((npts, 2)) * TS
    allp = np.concatenate([pts + [dx * TS, dy * TS] for dx in (-1, 0, 1) for dy in (-1, 0, 1)])
    d = np.sqrt((xx[..., None] - allp[:, 0]) ** 2 + (yy[..., None] - allp[:, 1]) ** 2)
    s = np.sort(d, axis=2)
    return s[..., 0], s[..., 1], np.argmin(d, axis=2) % npts

def cobble_tiles():
    tiles = []
    for v in range(8):
        d1, d2, idx = voronoi(18, 1300 + v)
        edge = d2 - d1
        h = np.clip(edge / 9, 0, 1) ** 0.6 * 0.7 + (fbm(10, 3, seed=1400 + v) - 0.5) * 0.12
        r = np.random.default_rng(1500 + v); tint = r.normal(0, 0.012, (18, 3)) + r.normal(0, 0.05, (18, 1))
        alb = np.array([0.34, 0.33, 0.33]) + tint[idx]
        alb[edge < 2.2] = np.array([0.1, 0.1, 0.09])
        alb *= (0.85 + 0.25 * fbm(4, 3, seed=1600 + v))[..., None]
        tiles.append(shade(alb, h, strength=6, spec=0.2))
    save('cobble', tiles)

def hedge_tiles():
    out = []
    for face in (True, False):
        d1, d2, idx = voronoi(40, 1700 + face)
        h = np.clip(1 - d1 / 14, 0, 1) ** 0.7 * 0.6 + fbm(16, 3, seed=1800) * 0.25
        alb = np.dstack([0.10 + 0.06 * h, 0.22 + 0.16 * h, 0.10 + 0.05 * h])
        col = shade(alb, h, strength=5, spec=0.1)
        if face: col *= (1 - np.clip((yy - 90) / 38, 0, 1) * 0.6)[..., None]
        else: col *= 0.75
        out.append(col)
    save('hedge', out)

if __name__ == '__main__':
    for f in (floor_tiles, face_tiles, top_tiles, grass_tiles, cobble_tiles, hedge_tiles):
        f(); print(f.__name__, 'ok', flush=True)

# ================= 2.5D 버전 (원작처럼 매끈한 판석 + 높은 벽) =================
def floor_smooth():
    tiles = []
    for v in range(16):
        dark = v >= 8
        r = np.random.default_rng(3000 + v)
        n1 = fbm(3, 5, seed=3100 + v); n2 = fbm(10, 3, seed=3200 + v)
        base = np.array([0.20, 0.19, 0.215]) * (0.86 if dark else 1.0) * (1 + r.normal(0, 0.03))
        alb = base * (0.9 + 0.2 * n1)[..., None] + (n2[..., None] - 0.5) * 0.025
        # 아주 얕은 모서리와 가는 이음매
        e = np.minimum(np.minimum(xx, TS - 1 - xx), np.minimum(yy, TS - 1 - yy)).astype(float)
        h = np.clip(e / 4, 0, 1) * 0.35 + n1 * 0.05
        seam = e < 1.2
        alb[seam] = alb[seam] * 0.45
        # 긁힘·얼룩
        im = Image.new('L', (TS, TS), 0); dr = ImageDraw.Draw(im)
        for _ in range(r.integers(1, 4)):
            x, y = r.random() * TS, r.random() * TS; a = r.random() * np.pi
            dr.line([(x, y), (x + np.cos(a) * r.integers(10, 40), y + np.sin(a) * r.integers(10, 40))], fill=int(60 + r.random() * 60), width=1)
        sc = np.asarray(im, float) / 255; alb = alb * (1 - sc[..., None] * 0.25)
        stain = fbm(4, 3, seed=3300 + v); alb *= (0.92 + 0.12 * stain)[..., None]
        col = shade(alb, h, strength=1.6, spec=0.06, ao_amt=0.6, amb=0.55)
        tiles.append(col)
    save('floor2', tiles)

WH = 160  # 벽 앞면 텍스처 높이 (타일 128 대비 1.25배: 월드 32px 타일에 40px 높이)
def wall_face_tall():
    tiles = []
    gy, gx = np.mgrid[0:WH, 0:TS]
    for v in range(6):
        r = np.random.default_rng(4000 + v)
        h = np.zeros((WH, TS)); ids = np.full((WH, TS), -1); k = 0
        y = 6; row = 0
        while y < WH - 4:
            bh = min(int(46 + r.integers(-6, 6)), WH - 4 - y); x = -int(r.integers(20, 50)) if row % 2 else 0
            while x < TS:
                bw = int(56 + r.integers(0, 40))
                inside = (gx >= x + 2) & (gx < x + bw - 2) & (gy >= y + 2) & (gy < y + bh - 2)
                d = np.minimum(np.minimum(gx - x - 2, x + bw - 3 - gx), np.minimum(gy - y - 2, y + bh - 3 - gy)).astype(float)
                prof = np.clip(d / 6, 0, 1); prof = prof * prof * (3 - 2 * prof)
                h = np.where(inside, prof * (0.55 + 0.12 * r.random()), h); ids = np.where(inside, k, ids); k += 1
                x += bw
            y += bh; row += 1
        det = np.asarray(Image.fromarray((fbm(6, 5, seed=4100 + v) * 255).astype(np.uint8)).resize((TS, WH)), float) / 255
        h = h + (det - 0.5) * 0.14 * (ids >= 0)
        alb = np.zeros((WH, TS, 3)) + np.array([0.25, 0.235, 0.255])
        for kk in range(k): alb[ids == kk] *= (1 + r.normal(0, 0.07))
        alb[ids < 0] = np.array([0.05, 0.045, 0.055])
        alb *= (0.85 + 0.3 * det)[..., None]
        gyy, gxx = np.gradient(h)
        nrm = np.dstack([-gxx * 5, -gyy * 5, np.ones_like(h)]); nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
        L = np.array([-0.4, -0.35, 0.85]); L /= np.linalg.norm(L)
        diff = np.clip((nrm * L).sum(2), 0, 1)
        col = alb * (0.45 + 0.75 * diff)[..., None]
        # 위는 밝고 아래(바닥 쪽)는 어둡게 — 높이감
        g = (0.55 + 0.6 * (1 - gy / WH)) ** 1.2
        col *= g[..., None]
        col[:4] = col[:4] * 0.4 + np.array([0.42, 0.4, 0.44]) * 0.6   # 윗면과 만나는 모서리 빛
        col[-10:] *= np.linspace(1, 0.35, 10)[:, None, None]
        tiles.append(np.clip(col, 0, 1))
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray((np.concatenate(tiles, 1) * 255).astype(np.uint8)).save(os.path.join(OUT, 'wall2.png'), optimize=True)

def wall_top2():
    tiles = []
    base = fbm(5, 5, seed=4500)
    for m in range(16):
        alb = np.zeros((TS, TS, 3)) + np.array([0.15, 0.14, 0.165]) * (0.8 + 0.4 * base)[..., None]
        edge = np.zeros((TS, TS))
        if m & 1: edge = np.maximum(edge, np.clip(1 - yy / 10, 0, 1))
        if m & 2: edge = np.maximum(edge, np.clip(1 - (TS - 1 - xx) / 10, 0, 1))
        if m & 4: edge = np.maximum(edge, np.clip(1 - (TS - 1 - yy) / 12, 0, 1))
        if m & 8: edge = np.maximum(edge, np.clip(1 - xx / 10, 0, 1))
        alb = alb * (1 - edge[..., None]) + np.array([0.52, 0.49, 0.55]) * edge[..., None]
        tiles.append(shade(alb, base * 0.2 + edge * 0.4, strength=3, spec=0.05))
    save('top2', tiles)

if __name__ == '__main__' and os.environ.get('V2'):
    floor_smooth(); wall_face_tall(); wall_top2(); print('v2 ok')
