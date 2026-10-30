"""
작은 SDF 레이마칭 렌더러 (numpy).
캐릭터를 입체 도형(구·캡슐·타원체·둥근 상자·원뿔·고리)의 부드러운 합으로 만들고,
조명·그림자·앰비언트 오클루전·림라이트·노이즈 질감·발광을 계산해 투명 배경 PNG로 렌더링한다.
원작처럼 '3D로 만들어 미리 렌더링한 스프라이트'를 얻기 위한 도구.

좌표: x 오른쪽, y 위, z 카메라 쪽(화면 아래쪽). 바닥 y=0. 모델은 +z(화면 아래)를 바라보게 만든다.
"""
import numpy as np

# ---------------- 기본 도형 ----------------
def _len(v): return np.sqrt((v * v).sum(-1))

def d_sphere(p, c, r): return _len(p - c) - r

def d_capsule(p, a, b, r1, r2=None):
    if r2 is None: r2 = r1
    pa = p - a; ba = np.asarray(b) - a
    h = np.clip((pa @ ba) / (ba @ ba), 0, 1)
    return _len(pa - h[:, None] * ba) - (r1 + (r2 - r1) * h)

def d_ellipsoid(p, c, r):
    q = (p - c) / r
    k0 = _len(q); k1 = _len(q / r)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)

def d_rbox(p, c, half, rnd=0.0, rot=None):
    q = p - c
    if rot is not None: q = q @ rot
    q = np.abs(q) - (np.asarray(half) - rnd)
    return _len(np.maximum(q, 0)) + np.minimum(q.max(-1), 0) - rnd

def d_torus(p, c, R, r, rot=None):
    q = p - c
    if rot is not None: q = q @ rot
    xz = np.sqrt(q[:, 0] ** 2 + q[:, 2] ** 2) - R
    return np.sqrt(xz ** 2 + q[:, 1] ** 2) - r

def rot_x(a):
    c, s = np.cos(a), np.sin(a); return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
def rot_y(a):
    c, s = np.cos(a), np.sin(a); return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
def rot_z(a):
    c, s = np.cos(a), np.sin(a); return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])

def smin(a, b, k):
    if k <= 0: return np.minimum(a, b), (b < a)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    d = b * (1 - h) + a * h - k * h * (1 - h)
    return d, (h < 0.5)

# ---------------- 노이즈 ----------------
def _hash(i):
    return np.modf(np.sin(i @ np.array([127.1, 311.7, 74.7])) * 43758.5453)[0] % 1.0

def vnoise(p):
    i = np.floor(p); f = p - i; u = f * f * (3 - 2 * f)
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (u[:, 0] if dx else 1 - u[:, 0]) * (u[:, 1] if dy else 1 - u[:, 1]) * (u[:, 2] if dz else 1 - u[:, 2])
                out = out + w * _hash(i + np.array([dx, dy, dz]))
    return out

def fbm(p, oct=3):
    a, s, t = 0.5, 1.0, 0
    for _ in range(oct):
        t = t + a * vnoise(p * s); s *= 2.03; a *= 0.5
    return t

# ---------------- 장면 ----------------
class Mat:
    def __init__(self, col, noise=0.0, nscale=8.0, spec=0.25, shin=24, emit=None, emit_noise=0.0, rim=1.0, col2=None):
        self.col = np.array(col, float) / 255.0
        self.col2 = None if col2 is None else np.array(col2, float) / 255.0
        self.noise = noise; self.nscale = nscale; self.spec = spec; self.shin = shin
        self.emit = None if emit is None else np.array(emit, float) / 255.0
        self.emit_noise = emit_noise; self.rim = rim

class Scene:
    """prim 목록: (거리함수, 재질번호, 부드럽게 합칠 정도 k, 빼기 여부)"""
    def __init__(self):
        self.prims = []; self.mats = []
    def mat(self, m):
        self.mats.append(m); return len(self.mats) - 1
    def add(self, fn, mat, k=0.0, sub=False):
        self.prims.append((fn, mat, k, sub))
    def sdf(self, p, want_mat=False):
        d = np.full(len(p), 1e3); m = np.zeros(len(p), int)
        for fn, mi, k, sub in self.prims:
            di = fn(p)
            if sub:
                # 부드러운 빼기
                if k > 0:
                    h = np.clip(0.5 - 0.5 * (d + di) / k, 0, 1)
                    d = d * (1 - h) + (-di) * h + k * h * (1 - h)
                else:
                    d = np.maximum(d, -di)
                continue
            d, take = smin(d, di, k)
            if want_mat: m = np.where(take, mi, m)
        return (d, m) if want_mat else d

# ---------------- 렌더 ----------------
def render(scene, size, view, target=(0, 0.55, 0), elev_deg=48, yaw=0.0, ss=2, key=(-0.55, 0.85, 0.45), steps=96):
    """size: 출력 픽셀, view: 화면에 담을 세계 폭, yaw: 모델 회전(라디안). RGBA float 배열 반환."""
    N = size * ss
    e = np.radians(elev_deg)
    fwd = -np.array([0, np.sin(e), np.cos(e)])
    right = np.array([1.0, 0, 0]); up = np.cross(right, fwd) * -1
    up = np.array([0, np.cos(e), -np.sin(e)])
    tgt = np.array(target, float)
    ps = view / N
    ii, jj = np.meshgrid(np.arange(N), np.arange(N))
    u = (ii.ravel() + 0.5 - N / 2) * ps; v = (N / 2 - (jj.ravel() + 0.5)) * ps
    ro = tgt + u[:, None] * right + v[:, None] * up - fwd * 3.0
    rd = np.broadcast_to(fwd, ro.shape).copy()
    R = rot_y(-yaw)
    def S(p, want=False): return scene.sdf(p @ R.T, want)
    t = np.zeros(len(ro)); hit = np.zeros(len(ro), bool); alive = np.ones(len(ro), bool)
    for _ in range(steps):
        idx = np.nonzero(alive)[0]
        if len(idx) == 0: break
        p = ro[idx] + rd[idx] * t[idx, None]
        d = S(p)
        h = d < 0.0015
        hit[idx[h]] = True; alive[idx[h]] = False
        t[idx] += np.maximum(d * 0.9, 0.0008)
        far = t[idx] > 6.0
        alive[idx[far]] = False
    img = np.zeros((len(ro), 4))
    hi = np.nonzero(hit)[0]
    if len(hi):
        p = ro[hi] + rd[hi] * t[hi, None]
        d, mid = S(p, True)
        eps = 0.0015
        k1 = np.array([1, -1, -1]); k2 = np.array([-1, -1, 1]); k3 = np.array([-1, 1, -1]); k4 = np.array([1, 1, 1])
        n = (k1 * S(p + k1 * eps)[:, None] + k2 * S(p + k2 * eps)[:, None] + k3 * S(p + k3 * eps)[:, None] + k4 * S(p + k4 * eps)[:, None])
        n /= np.maximum(_len(n)[:, None], 1e-6)
        # AO
        ao = np.zeros(len(p))
        for i, hh in enumerate([0.015, 0.035, 0.06, 0.09, 0.13]):
            ao += (hh - S(p + n * hh)) * (0.75 ** i)
        ao = np.clip(1 - 3.2 * ao, 0.15, 1)
        # 그림자
        L = np.array(key, float); L /= np.linalg.norm(L)
        sh = np.ones(len(p)); ts = np.full(len(p), 0.02)
        for _ in range(22):
            dd = S(p + n * 0.004 + L * ts[:, None])
            sh = np.minimum(sh, 10 * dd / ts); ts += np.clip(dd, 0.01, 0.12)
        sh = np.clip(sh, 0.12, 1)
        # 재질
        pm = p @ R.T
        alb = np.zeros((len(p), 3)); spec = np.zeros(len(p)); shin = np.zeros(len(p)); emit = np.zeros((len(p), 3)); rimk = np.zeros(len(p))
        for mi, m in enumerate(scene.mats):
            sel = mid == mi
            if not sel.any(): continue
            c = np.broadcast_to(m.col, (sel.sum(), 3)).copy()
            if m.noise > 0:
                nz = fbm(pm[sel] * m.nscale, 3)
                if m.col2 is not None: c = c * (1 - nz[:, None]) + m.col2 * nz[:, None]
                else: c = c * (1 + (nz[:, None] - 0.5) * 2 * m.noise)
            alb[sel] = c; spec[sel] = m.spec; shin[sel] = m.shin; rimk[sel] = m.rim
            if m.emit is not None:
                en = 1.0
                if m.emit_noise > 0: en = 1 - m.emit_noise + m.emit_noise * 2 * fbm(pm[sel] * 6 + 3.1, 2)[:, None]
                emit[sel] = m.emit * en
        V = -rd[hi]
        diff = np.clip(n @ L, 0, 1)
        Fl = np.array([0.7, 0.3, 0.6]); Fl /= np.linalg.norm(Fl)
        fill = np.clip(n @ Fl, 0, 1)
        Hh = L + V; Hh /= _len(Hh)[:, None]
        sp = spec * np.clip((n * Hh).sum(-1), 0, 1) ** np.maximum(shin, 1) * sh
        rim = (1 - np.clip((n * V).sum(-1), 0, 1)) ** 3 * np.clip(n[:, 1] * 0.5 + 0.6, 0, 1) * rimk
        sky = 0.5 + 0.5 * n[:, 1]
        light = (0.30 * sky * ao)[:, None] * np.array([0.85, 0.85, 1.05]) \
              + (1.05 * diff * sh)[:, None] * np.array([1.0, 0.94, 0.85]) \
              + (0.22 * fill * ao)[:, None] * np.array([0.6, 0.65, 1.0])
        col = alb * light + sp[:, None] * np.array([1, 0.97, 0.9]) + (rim * 0.45)[:, None] * np.array([0.75, 0.8, 1.0]) * ao[:, None] + emit
        col = col / (1 + 0.25 * col)
        img[hi, :3] = np.clip(col, 0, 1) ** (1 / 1.12)
        img[hi, 3] = 1
    img = img.reshape(N, N, 4)
    if ss > 1:
        img = img.reshape(size, ss, size, ss, 4)
        a = img[..., 3:4]
        rgb = (img[..., :3] * a).sum((1, 3)); aa = a.sum((1, 3))
        img = np.concatenate([rgb / np.maximum(aa, 1e-6), aa / (ss * ss)], -1)
    return img

def project(pt, size, view, target=(0, 0.55, 0), elev_deg=48, yaw=0.0):
    """세계 좌표 점이 스프라이트의 어느 픽셀에 오는지 (기준점·지팡이 끝 위치용)"""
    e = np.radians(elev_deg)
    up = np.array([0, np.cos(e), -np.sin(e)]); right = np.array([1.0, 0, 0])
    p = rot_y(yaw) @ np.asarray(pt, float) - np.asarray(target, float)
    ps = view / size
    return (size / 2 + (p @ right) / ps, size / 2 - (p @ up) / ps)
