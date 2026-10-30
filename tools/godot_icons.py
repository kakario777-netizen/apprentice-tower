"""고도판 UI 아이콘 미리 그리기 — 웹 iconCanvas/glyph/drawItem/gearCanvas 와 같은 모양.
사용: python3 tools/godot_icons.py   → godot/ui/*.png
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

ROOT = os.path.join(os.path.dirname(__file__), '..')
GLY = Image.open(os.path.join(ROOT, 'www/assets/ui/glyphs4.png')).convert('RGBA')
ICO = Image.open(os.path.join(ROOT, 'www/assets/ui/icons.png')).convert('RGBA')
OUT = os.path.join(ROOT, 'godot/ui')
os.makedirs(OUT, exist_ok=True)
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

PRIM = {'arcane': '#c39bff', 'fire': '#ff7b34', 'storm': '#86e3ff', 'frost': '#cdf2ff'}
GL = {'el': {'arcane': 20, 'fire': 37, 'storm': 7, 'frost': 24},
      'sec': {'blink': 19, 'ward': 4, 'stasis': 26, 'freeze': 14, 'nova': 15, 'acid': 38, 'purge': 45},
      'pass': {'vigor': 11, 'well': 42, 'calm': 29, 'quick': 23, 'thrift': 43, 'focus': 6, 'might': 31, 'swift': 9}}
SUBG = {'multi': '+1', 'seek': '↻', 'siphon': '◆', 'blast': '✸', 'embers': '∴', 'burn': '≋', 'chain': '⇢', 'shock': '≈', 'reach': '↔', 'widen': '◁', 'gust': '≫', 'harden': '■'}
SUBOF = {'multi': 'arcane', 'seek': 'arcane', 'siphon': 'arcane', 'blast': 'fire', 'embers': 'fire', 'burn': 'fire', 'chain': 'storm', 'shock': 'storm', 'reach': 'storm', 'widen': 'frost', 'gust': 'frost', 'harden': 'frost'}
FUS = ['arcane+fire', 'fire+storm', 'fire+frost', 'arcane+storm', 'arcane+frost', 'frost+storm']
FUSC = {'arcane+fire': '#ffa24a', 'fire+storm': '#ffc35a', 'fire+frost': '#f4f1ea', 'arcane+storm': '#9fe8ff', 'arcane+frost': '#bfe9ff', 'frost+storm': '#d9f6ff'}
DIFF = {'easy': ('#7fb2ff', 1), 'norm': ('#e3b04b', 2), 'hard': ('#ff6a5a', 3)}
ITEMI = {'pothp': 64, 'potmp': 65, 'scroll': 72}
GEARI = {'staff': [104, 106, 105], 'wand': [107, 107, 107], 'ring': [198, 204, 207], 'cloak': [136, 184, 192], 'amulet': [214, 212, 213], 'belt': [208, 208, 208], 'boots': [132, 148, 176]}
RARC = {'magic': '#6f9cff', 'rare': '#ffd76a', 'epic': '#ff9a3a'}

def rgb(h): h = h.lstrip('#'); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

def glyph_img(n, col):
    g = GLY.crop(((n % 8) * 256, (n >> 3) * 256, (n % 8) * 256 + 256, (n >> 3) * 256 + 256))
    if col:
        c = rgb(col); grad = Image.new('RGBA', (256, 256))
        px = grad.load()
        for y in range(256):
            t = 0 if y < 24 + .45 * 208 else min(1, (y - (24 + .45 * 208)) / (208 * .55))
            v = tuple(int(255 + (c[i] - 255) * t) for i in range(3))
            for x in range(256): px[x, y] = v + (255,)
        a = g.split()[3]; grad.putalpha(a); g = grad
    return g

def place(canvas, img, cx, cy, sz, glow=None, shadow=True):
    S = canvas.size[0]
    im = img.resize((int(sz), int(sz)), Image.LANCZOS)
    x, y = int(cx - sz / 2), int(cy - sz / 2)
    a = im.split()[3]
    if glow:
        gl = Image.new('RGBA', im.size, rgb(glow) + (0,)); gl.putalpha(a.point(lambda v: int(v * .85)))
        pad = int(sz * .4); big = Image.new('RGBA', (im.size[0] + pad * 2, im.size[1] + pad * 2), (0, 0, 0, 0)); big.paste(gl, (pad, pad), gl)
        big = big.filter(ImageFilter.GaussianBlur(sz * .14)); canvas.alpha_composite(big, (x - pad, y - pad))
    if shadow:
        sh = Image.new('RGBA', im.size, (0, 0, 0, 0)); sh.putalpha(a.point(lambda v: int(v * .85)))
        pad = int(sz * .2); big = Image.new('RGBA', (im.size[0] + pad * 2, im.size[1] + pad * 2), (0, 0, 0, 0)); big.paste(sh, (pad, pad), sh)
        big = big.filter(ImageFilter.GaussianBlur(sz * .04)); canvas.alpha_composite(big, (x - pad, y - pad + int(sz * .04)))
    canvas.alpha_composite(im, (x, y))

def base(color, plain, S=162):
    k = S / 54
    c = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    # 뒤쪽 은은한 빛
    g = Image.new('RGBA', (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(g)
    col = rgb(color)
    for r in range(int(27 * k), 0, -1):
        t = r / (27 * k); a = (.22 if plain else .38) * (1 - t) if t > 3 / 27 else (.22 if plain else .38)
        d.ellipse((S / 2 - r, S / 2 - r, S / 2 + r, S / 2 + r), fill=col + (int(255 * a),))
    c.alpha_composite(g)
    if not plain:
        d = ImageDraw.Draw(c)
        R = 23 * k
        d.ellipse((S / 2 - R, S / 2 - R, S / 2 + R, S / 2 + R), fill=(9, 7, 14, 166))
        d.ellipse((S / 2 - R, S / 2 - R, S / 2 + R, S / 2 + R), outline=col + (217,), width=int(1.5 * k))
    return c, k

def save(img, name): img.save(os.path.join(OUT, name + '.png'))

def card_variants(name, color, draw):
    for plain in (False, True):
        c, k = base(color, plain)
        draw(c, k, 44 if plain else 36, plain)
        save(c, name + ('_p' if plain else ''))

for el, col in PRIM.items():
    card_variants('el_' + el, col, lambda c, k, gs, p, el=el, col=col: place(c, glyph_img(GL['el'][el], col), 81, 81, gs * k, col))
for key in FUS:
    a, b = key.split('+')
    def dr(c, k, gs, p, a=a, b=b):
        place(c, glyph_img(GL['el'][a], PRIM[a]), 81 - 7 * k, 81 + 2 * k, gs * .72 * k, PRIM[a])
        place(c, glyph_img(GL['el'][b], PRIM[b]), 81 + 7 * k, 81 - 3 * k, gs * .72 * k, PRIM[b])
    card_variants('fus_' + key.replace('+', '_'), FUSC[key], dr)
for sid, el in SUBOF.items():
    col = PRIM[el]
    def dr(c, k, gs, p, el=el, col=col, sid=sid):
        place(c, glyph_img(GL['el'][el], col), 81 - k, 81 + k, gs * .85 * k, col)
        d = ImageDraw.Draw(c); bx, by, r = 81 + 13 * k, 81 + 13 * k, 8 * k
        d.ellipse((bx - r, by - r, bx + r, by + r), fill=rgb('#e3b04b') + (255,))
        f = ImageFont.truetype(FONT, int(10 * k)); t = SUBG[sid]
        w = d.textlength(t, font=f); d.text((bx - w / 2, by - 6.2 * k), t, font=f, fill=(27, 18, 6, 255))
    card_variants('sub_' + sid, col, dr)
for sid, n in GL['sec'].items():
    card_variants('sec_' + sid, '#e3b04b', lambda c, k, gs, p, n=n: place(c, glyph_img(n, '#ffe0a0' if p else '#e3b04b'), 81, 81, gs * k, '#ffe0a0' if p else '#e3b04b'))
for sid, n in GL['pass'].items():
    card_variants('pass_' + sid, '#a395b3', lambda c, k, gs, p, n=n: place(c, glyph_img(n, '#a395b3'), 81, 81, gs * k, '#a395b3'))
for did, (col, nn) in DIFF.items():
    def dr(c, k, gs, p, col=col, nn=nn):
        import math
        d = ImageDraw.Draw(c)
        for i in range(3):
            cx = 81 + (i - 1) * 11 * k; pts = []
            for j in range(10):
                a = j / 10 * math.tau - math.pi / 2; rr = (2.6 if j % 2 else 6.5) * k
                pts.append((cx + math.cos(a) * rr, 81 + math.sin(a) * rr))
            d.polygon(pts, fill=(rgb(col) + (255,)) if i < nn else (255, 255, 255, 38))
    card_variants('diff_' + did, col, dr)

def icon64(n): return ICO.crop(((n % 8) * 64, (n >> 3) * 64, (n % 8) * 64 + 64, (n >> 3) * 64 + 64))
for iid, n in ITEMI.items():
    c = Image.new('RGBA', (128, 128), (0, 0, 0, 0)); place(c, icon64(n), 64, 64, 112, '#ffd696'); save(c, 'item_' + iid)
for gid, ns in GEARI.items():
    for ri, rar in enumerate(['magic', 'rare', 'epic']):
        c, k = base(RARC[rar], True, 128)
        place(c, icon64(ns[ri]), 64, 64, 100, None); save(c, 'gear_%s_%s' % (gid, rar))
# 빈 칸 표시(흐린 윤곽)
for slot, n in {'amulet': 214, 'weapon': 104, 'cloak': 136, 'ring': 198, 'belt': 208, 'boots': 148}.items():
    ic = icon64(n); a = ic.split()[3].point(lambda v: int(v * .22)); g = Image.new('RGBA', ic.size, (220, 210, 240, 0)); g.putalpha(a)
    c = Image.new('RGBA', (128, 128), (0, 0, 0, 0)); c.alpha_composite(g.resize((100, 100), Image.LANCZOS), (14, 14)); save(c, 'slot_' + slot)
c = Image.new('RGBA', (128, 128), (0, 0, 0, 0)); place(c, glyph_img(30, '#f0e0c0'), 64, 64, 118, '#ffdca0'); save(c, 'bag')
print('icons', len(os.listdir(OUT)))
