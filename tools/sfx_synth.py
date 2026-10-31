"""효과음 직접 만들기(합성) + CC0 원본 가공 → godot/sound/sfx/*.ogg
python3 tools/sfx_synth.py ASSET_SRC_DIR
  arcane : 비전탄 — 짧고 둥근 '보잉' (마법 반짝임 약간)
  fire   : 화염구 발사 — 낮게 깔리는 묵직한 '후웅' (rubberduck spell_fire_06 섞음)
  boom   : 화염구 폭발 — 저음 '쿵' + 터지는 소리 + 불티 (rubberduck explosion 섞음)
  frost  : 냉기 숨결(누르는 동안 반복) — '싸아아' 이음매 없는 반복
  creak  : 상자 여는 소리 — 가벼운 나무 '끼익'
"""
import os, sys, subprocess, numpy as np
SR = 44100
SRC = sys.argv[1] if len(sys.argv) > 1 else ''
OUT = os.path.join(os.path.dirname(__file__), '..', 'godot', 'sound', 'sfx')
rng = np.random.default_rng(7)

def load(p, rate=1.0):
    r = subprocess.run(['ffmpeg', '-v', 'quiet', '-i', p, '-ac', '1', '-ar', str(int(SR / rate)), '-f', 'f32le', '-'], capture_output=True)
    return np.frombuffer(r.stdout, dtype=np.float32).astype(np.float64)   # 낮은 율로 읽어 SR 로 쓰면 = 음 낮추기

def save(name, x, peak=.85):
    x = x / max(1e-9, np.abs(x).max()) * peak
    raw = os.path.join('/tmp', name + '.f32'); x.astype(np.float32).tofile(raw)
    subprocess.run(['ffmpeg', '-v', 'quiet', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', '1', '-i', raw, '-c:a', 'libvorbis', '-q:a', '5',
                    os.path.join(OUT, name + '.ogg')], check=True)
    os.remove(raw); print('saved', name, round(len(x) / SR, 2), 's')

def T(d): return np.arange(int(d * SR)) / SR

def onepole(x, fc):
    """시간에 따라 바뀌는 저역 통과(fc 는 배열 또는 수)"""
    fc = np.broadcast_to(np.asarray(fc, dtype=float), x.shape)
    a = 1 - np.exp(-2 * np.pi * fc / SR); y = np.empty_like(x); s = 0.0
    for i in range(len(x)):
        s += a[i] * (x[i] - s); y[i] = s
    return y

def band(x, lo, hi):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    X[(f < lo) | (f > hi)] = 0
    return np.fft.irfft(X, len(x))

def fit(a, n):
    out = np.zeros(n); out[:min(n, len(a))] = a[:n]; return out

# ---------- 비전탄: 보잉 ----------
def arcane():
    t = T(.34)
    f = 330 + 420 * np.exp(-t / .05)                       # 높은 데서 툭 떨어지는 음
    f = f * (1 + .07 * np.sin(2 * np.pi * 21 * t) * np.exp(-t / .16))   # 용수철처럼 떨림
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) + .32 * np.sin(2 * ph) + .1 * np.sin(3 * ph)
    env = (1 - np.exp(-t / .004)) * np.exp(-t / .1)
    sp = np.sin(2 * np.pi * np.cumsum(2600 - 1400 * t / .34) / SR) * np.exp(-t / .03) * .18   # 마법 반짝임
    x = body * env + sp
    return onepole(x, 5000)

# ---------- 화염구 발사: 묵직한 후웅 ----------
def fire_cast():
    d = .62; t = T(d); n = len(t)
    noise = rng.standard_normal(n)
    fc = 250 + 1700 * np.exp(-((t - .1) / .09) ** 2) + 400 * np.exp(-t / .3)   # 확 부풀었다 가라앉는 바람
    whoosh = onepole(onepole(noise, fc), fc)
    env = np.clip(t / .035, 0, 1) * np.exp(-np.maximum(t - .08, 0) / .2)
    rumble = np.sin(2 * np.pi * np.cumsum(85 - 30 * t / d) / SR) * np.exp(-t / .22) * np.clip(t / .02, 0, 1)
    crack = np.zeros(n)
    for i in rng.integers(int(.03 * SR), int(.45 * SR), 26):
        L = int(rng.integers(40, 160)); crack[i:i + L] += rng.standard_normal(L) * np.exp(-np.arange(L) / 25) * rng.uniform(.2, .6)
    crack = band(crack, 1500, 7000) * np.exp(-t / .25)
    x = whoosh / np.abs(whoosh).max() * env * 1.0 + rumble * .55 + crack * .5
    p = os.path.join(SRC, 'sfx/80-cc0-rpg-sfx/spell_fire_06.ogg')
    if os.path.exists(p):
        s = fit(load(p, .78), n); s = onepole(s, 3500); x += s / max(1e-9, np.abs(s).max()) * .5 * np.exp(-t / .3)
    return x * np.minimum(1, (d - t) / .08)

# ---------- 화염구 폭발: 쿵 + 펑 + 불티 ----------
def fire_boom():
    d = 1.15; t = T(d); n = len(t)
    sub = np.sin(2 * np.pi * np.cumsum(62 * np.exp(-t / .5) + 30) / SR) * np.exp(-t / .2) * np.clip(t / .004, 0, 1)
    nb = rng.standard_normal(n)
    blast = onepole(nb, 300 + 2600 * np.exp(-t / .07)) * np.exp(-t / .22)
    blast = blast / np.abs(blast).max()
    roar = onepole(rng.standard_normal(n), 600) * np.exp(-t / .45); roar /= np.abs(roar).max()
    crack = np.zeros(n)
    for i in rng.integers(int(.02 * SR), int(.9 * SR), 60):
        L = int(rng.integers(30, 120)); crack[i:i + L] += rng.standard_normal(L) * np.exp(-np.arange(L) / 18) * rng.uniform(.1, .5)
    crack = band(crack, 1800, 8000) * np.exp(-t / .35)
    x = sub * 1.0 + blast * .8 + roar * .35 + crack * .45
    p = os.path.join(SRC, 'sfx/100-cc0-sfx/explosion.ogg')
    if os.path.exists(p):
        s = fit(load(p, .85), n); x += s / max(1e-9, np.abs(s).max()) * .55
    x = np.tanh(x * 1.3)
    return x * np.minimum(1, (d - t) / .1)

# ---------- 냉기 숨결: 싸아아 (이음매 없이 반복) ----------
def frost_loop():
    d = 2.0; n = int(d * SR); f = np.fft.rfftfreq(n, 1 / SR)
    mag = np.exp(-((np.log(f + 1) - np.log(5200)) / .55) ** 2) + .35 * np.exp(-((np.log(f + 1) - np.log(9500)) / .35) ** 2)
    mag += .12 * np.exp(-((np.log(f + 1) - np.log(1400)) / .5) ** 2)       # 숨결 아랫부분
    X = mag * np.exp(1j * rng.uniform(0, 2 * np.pi, len(f)))
    hiss = np.fft.irfft(X, n); hiss /= np.abs(hiss).max()                   # 주파수 영역에서 만들어 저절로 이어짐
    t = np.arange(n) / SR
    mod = 1 + .18 * np.sin(2 * np.pi * 2 * t / d) + .1 * np.sin(2 * np.pi * 5 * t / d + 1)   # 정수 번 흔들려 끝과 처음이 맞음
    x = hiss * mod
    for k, a in [(2600, .05), (3900, .035), (5200, .025)]:                  # 얼음 울림(희미하게)
        fk = round(k * d) / d
        x += a * np.sin(2 * np.pi * fk * t) * (1 + np.sin(2 * np.pi * 3 * t / d + k)) / 2
    for i in rng.integers(0, n, 40):                                        # 얼음 알갱이 '틱'
        L = int(.02 * SR); fr = rng.uniform(5000, 9000); tt = np.arange(L) / SR
        ping = np.sin(2 * np.pi * fr * tt) * np.exp(-tt / .004) * rng.uniform(.05, .15)
        idx = (i + np.arange(L)) % n; x[idx] += ping
    return x

# ---------- 상자: 가벼운 나무 끼익 ----------
def creak():
    d = .5; t = T(d); n = len(t)
    rate = 70 + 70 * np.sin(np.pi * np.clip(t / .42, 0, 1)) ** 1.5 + 8 * rng.standard_normal(n).cumsum() / np.sqrt(n)
    ph = np.cumsum(rate / SR); idx = np.nonzero(np.diff(np.floor(ph)) > 0)[0]
    imp = np.zeros(n); imp[idx] = rng.uniform(.6, 1, len(idx))
    L = int(.03 * SR); tt = np.arange(L) / SR
    ir = sum(a * np.sin(2 * np.pi * fr * tt) * np.exp(-tt / dc) for fr, a, dc in [(520, 1, .009), (1150, .7, .006), (2300, .35, .004), (3400, .15, .003)])
    x = np.convolve(imp, ir)[:n]
    env = np.clip(t / .05, 0, 1) * np.clip((.46 - t) / .08, 0, 1)
    return onepole(x * env, 4500)

if __name__ == '__main__':
    save('arcane', arcane(), .7)
    save('fire', fire_cast(), .85)
    save('boom', fire_boom(), .9)
    save('frost', frost_loop(), .6)
    save('creak', creak(), .6)
