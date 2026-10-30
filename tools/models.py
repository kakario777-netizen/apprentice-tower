"""
캐릭터·몬스터·소품 3D 모델 (SDF 도형 조합). 모두 +z(화면 아래)를 바라보고, 발이 y=0에 닿게 만든다.
ph: 걷기·날갯짓 위상(0~2π)
"""
import numpy as np
from sdf import *

A = np.array
def P(*v): return A(v, float)

# ---------- 공용 부품 ----------
def limb(S, a, b, r1, r2, mat, k=0.01):
    a = P(*a); b = P(*b); S.add(lambda p, a=a, b=b: d_capsule(p, a, b, r1, r2), mat, k)

def ball(S, c, r, mat, k=0.0, sub=False):
    c = P(*c); S.add(lambda p, c=c: d_sphere(p, c, r), mat, k, sub)

def ell(S, c, r, mat, k=0.0):
    c = P(*c); r = P(*r); S.add(lambda p, c=c, r=r: d_ellipsoid(p, c, r), mat, k)

def box(S, c, h, mat, rnd=0.01, k=0.0, rot=None, sub=False):
    c = P(*c); h = P(*h); S.add(lambda p, c=c, h=h: d_rbox(p, c, h, rnd, rot), mat, k, sub)

def tor(S, c, R, r, mat, k=0.0, rot=None):
    c = P(*c); S.add(lambda p, c=c: d_torus(p, c, R, r, rot), mat, k)

def arm_pts(sh, ang_fwd, ang_out, l1, l2, bend=0.6):
    """어깨 위치에서 팔 관절 계산: ang_fwd 앞뒤 흔들기, ang_out 옆으로 벌리기"""
    sh = P(*sh)
    d1 = P(np.sin(ang_out) * np.sign(sh[0] if sh[0] != 0 else 1), -np.cos(ang_fwd) * np.cos(ang_out), np.sin(ang_fwd) * np.cos(ang_out))
    el = sh + d1 * l1
    a2 = ang_fwd + bend
    d2 = P(d1[0] * 0.6, -np.cos(a2), np.sin(a2))
    d2 /= np.linalg.norm(d2)
    return sh, el, el + d2 * l2

# ================= 해골 =================
def skeleton(ph=0.0, kind='sword'):
    S = Scene()
    bone = S.mat(Mat((228, 218, 196), noise=0.18, nscale=14, spec=0.35, shin=30, col2=(200, 186, 160)))
    dark = S.mat(Mat((24, 16, 22), spec=0.0, rim=0.2))
    eye = S.mat(Mat((40, 10, 10), emit=(255, 70, 50), rim=0))
    metal = S.mat(Mat((160, 168, 182), noise=0.1, nscale=20, spec=0.9, shin=60))
    wood = S.mat(Mat((110, 72, 40), noise=0.35, nscale=18, spec=0.1))
    sw = np.sin(ph); bob = abs(np.cos(ph)) * 0.025
    hip = 0.42 + bob
    # 다리
    for side in (-1, 1):
        a = ph if side > 0 else ph + np.pi
        knee = P(side * 0.07, hip - 0.2, np.sin(a) * 0.09 + 0.02)
        foot = P(side * 0.08, 0.03 + max(0, np.sin(a)) * 0.05, np.sin(a) * 0.14)
        limb(S, (side * 0.07, hip, 0), knee, 0.028, 0.024, bone, 0.01)
        limb(S, knee, foot, 0.024, 0.02, bone, 0.01)
        ball(S, knee, 0.033, bone, 0.01)
        S.add(lambda p, f=foot: d_rbox(p, f + P(0, -0.01, 0.03), (0.035, 0.018, 0.06), 0.012), bone, 0.01)
    # 골반·척추·갈비뼈
    box(S, (0, hip, 0), (0.1, 0.035, 0.05), bone, 0.025, 0.02)
    for i in range(5):
        ball(S, (0, hip + 0.05 + i * 0.045, -0.02 - 0.01 * np.sin(i)), 0.026, bone, 0.015)
    cy = hip + 0.2
    S.add(lambda p: d_ellipsoid(p, P(0, cy, 0.0), P(0.13, 0.12, 0.09)), bone, 0.02)
    S.add(lambda p: d_ellipsoid(p, P(0, cy, 0.01), P(0.11, 0.105, 0.075)), bone, 0.0, True)
    for i in range(4):
        y = cy - 0.08 + i * 0.05
        S.add(lambda p, y=y: d_rbox(p, P(0, y, 0.08), (0.12, 0.012, 0.02), 0.01), dark, 0.0, True)
    ball(S, (0, cy + 0.02, 0.0), 0.02, bone, 0.02)
    # 팔
    shy = cy + 0.1
    for side in (-1, 1):
        a = ph + np.pi if side > 0 else ph
        swing = np.sin(a) * 0.5
        if kind == 'sword' and side > 0: swing = 0.9 + np.sin(ph) * 0.15
        if kind == 'bow': swing = 1.35 if side < 0 else 1.1
        sh, el, ha = arm_pts((side * 0.15, shy, 0), swing, 0.18, 0.17, 0.16, 0.5 if kind != 'bow' else 0.1)
        limb(S, sh, el, 0.024, 0.02, bone, 0.01); limb(S, el, ha, 0.02, 0.017, bone, 0.01)
        ball(S, sh, 0.035, bone, 0.015); ball(S, el, 0.026, bone, 0.01); ball(S, ha, 0.03, bone, 0.01)
        if kind == 'sword' and side > 0:
            tip = ha + P(0.02, 0.32, 0.12)
            S.add(lambda p, a=ha + P(0, 0.04, 0.015), b=tip: d_capsule(p, a, b, 0.022, 0.006), metal, 0.0)
            S.add(lambda p, c=ha + P(0, 0.035, 0.012): d_rbox(p, c, (0.07, 0.012, 0.02), 0.006), metal, 0.0)
            S.add(lambda p, a=ha + P(0, -0.04, -0.01), b=ha + P(0, 0.03, 0.01): d_capsule(p, a, b, 0.014), wood, 0.0)
        if kind == 'bow' and side < 0:
            bc = ha + P(0, 0.0, 0.03)
            S.add(lambda p, c=bc: np.maximum(d_torus(p, c, 0.2, 0.014, rot_z(np.pi / 2)), -(p[:, 2] - c[2]) ), wood, 0.0)
            S.add(lambda p, a=bc + P(0, 0.2, 0), b=bc + P(0, -0.2, 0): d_capsule(p, a, b, 0.004), dark, 0.0)
    # 해골 머리
    hy = shy + 0.16
    S.add(lambda p: d_ellipsoid(p, P(0, hy, 0), P(0.1, 0.105, 0.11)), bone, 0.03)
    S.add(lambda p: d_rbox(p, P(0, hy - 0.08, 0.03), (0.06, 0.035, 0.06), 0.02), bone, 0.03)
    for side in (-1, 1):
        S.add(lambda p, s=side: d_sphere(p, P(s * 0.042, hy + 0.005, 0.09), 0.034), dark, 0.01, True)
        S.add(lambda p, s=side: d_sphere(p, P(s * 0.042, hy + 0.005, 0.075), 0.013), eye, 0.0)
    S.add(lambda p: d_rbox(p, P(0, hy - 0.04, 0.105), (0.01, 0.018, 0.02), 0.005), dark, 0.0, True)
    for i in range(4):
        S.add(lambda p, i=i: d_rbox(p, P(-0.033 + i * 0.022, hy - 0.085, 0.09), (0.006, 0.015, 0.02), 0.002), dark, 0.0, True)
    return S

# ================= 마법사 (주인공·교수) =================
def wizard(ph=0.0, robe=(47, 111, 134), hat=(31, 77, 94), trim=(227, 176, 75), beard=None, staff_orb=(195, 155, 255), cast=False, old=False):
    S = Scene()
    m_robe = S.mat(Mat(robe, noise=0.25, nscale=10, spec=0.08, shin=8, col2=tuple(int(c * 0.72) for c in robe)))
    m_hat = S.mat(Mat(hat, noise=0.2, nscale=9, spec=0.08, col2=tuple(int(c * 0.7) for c in hat)))
    m_trim = S.mat(Mat(trim, spec=0.8, shin=50))
    m_skin = S.mat(Mat((240, 205, 170), noise=0.05, spec=0.15, shin=12))
    m_dark = S.mat(Mat((30, 20, 25), spec=0.1))
    m_boot = S.mat(Mat((60, 40, 30), noise=0.2, spec=0.3))
    m_wood = S.mat(Mat((120, 80, 45), noise=0.4, nscale=22, spec=0.15))
    m_orb = S.mat(Mat(staff_orb, emit=tuple(min(255, int(c * 1.0)) for c in staff_orb), spec=1.0, shin=80))
    m_beard = S.mat(Mat(beard or (220, 215, 205), noise=0.3, nscale=30, spec=0.05)) if beard else None
    bob = abs(np.cos(ph)) * 0.02; sw = np.sin(ph)
    # 발
    for side in (-1, 1):
        a = ph if side > 0 else ph + np.pi
        f = P(side * 0.07, 0.025 + max(0, np.sin(a)) * 0.04, np.sin(a) * 0.1 + 0.03)
        S.add(lambda p, f=f: d_ellipsoid(p, f, P(0.045, 0.03, 0.07)), m_boot, 0.0)
    # 로브 (아래가 넓은 원뿔 + 치맛자락 흔들림)
    base = 0.05
    S.add(lambda p: d_capsule(p, P(0, base + 0.05, sw * 0.012), P(0, 0.34 + bob, 0), 0.18, 0.125), m_robe, 0.0)
    S.add(lambda p: d_capsule(p, P(0, 0.34 + bob, 0), P(0, 0.56 + bob, -0.005), 0.125, 0.135), m_robe, 0.05)
    S.add(lambda p: d_ellipsoid(p, P(sw * 0.01, base + 0.05, sw * 0.02), P(0.2, 0.05, 0.19)), m_robe, 0.05)
    m_cape = S.mat(Mat(tuple(int(c * 0.55) for c in robe), noise=0.3, nscale=9, spec=0.05))
    S.add(lambda p: d_rbox(p, P(sw * 0.02, 0.33 + bob, -0.12), (0.15, 0.26, 0.02), 0.02, rot_x(-0.12)), m_cape, 0.02)
    S.add(lambda p: d_torus(p, P(0, 0.58 + bob, 0.0), 0.11, 0.03), m_cape, 0.02)
    S.add(lambda p: d_torus(p, P(0, 0.42 + bob, 0), 0.155, 0.018), m_trim, 0.0)
    S.add(lambda p: d_rbox(p, P(0, 0.42 + bob, 0.155), (0.025, 0.025, 0.012), 0.006), m_trim, 0.0)
    S.add(lambda p: d_rbox(p, P(0, 0.33 + bob, 0.15), (0.012, 0.25, 0.03), 0.01), m_trim, 0.0)
    # 어깨·소매·손
    shy = 0.6 + bob
    for side in (-1, 1):
        a = ph + np.pi if side > 0 else ph
        swing = np.sin(a) * 0.35
        if side > 0: swing = 0.75 + (0.35 if cast else 0) + np.sin(ph) * 0.08
        sh, el, ha = arm_pts((side * 0.14, shy, 0), swing, 0.22, 0.15, 0.14, 0.35)
        limb(S, sh, el, 0.055, 0.06, m_robe, 0.03)
        limb(S, el, ha + (ha - el) * -0.15, 0.06, 0.075, m_robe, 0.01)
        ball(S, ha, 0.035, m_skin, 0.0)
        if side > 0:
            top = ha + P(0.03, 0.48, 0.06); bot = ha + P(-0.01, -0.36, -0.02)
            S.add(lambda p, a=bot, b=top: d_capsule(p, a, b, 0.016, 0.02), m_wood, 0.0)
            S.add(lambda p, c=top + P(0, 0.04, 0): d_torus(p, c, 0.04, 0.012), m_wood, 0.0)
            S.add(lambda p, c=top + P(0, 0.055, 0): d_sphere(p, c, 0.05), m_orb, 0.0)
            S.staff_tip = top + P(0, 0.05, 0)
    # 머리
    hy = 0.72 + bob
    ball(S, (0, hy, 0.015), 0.12, m_skin, 0.02)
    m_hair = S.mat(Mat((90, 60, 40) if not beard else (210, 205, 198), noise=0.3, nscale=30, spec=0.15))
    S.add(lambda p: d_ellipsoid(p, P(0, hy + 0.035, -0.02), P(0.125, 0.09, 0.115)), m_hair, 0.02)
    for side in (-1, 1):
        S.add(lambda p, s=side: d_ellipsoid(p, P(s * 0.045, hy - 0.005, 0.118), P(0.018, 0.024, 0.012)), m_dark, 0.0)
        S.add(lambda p, s=side: d_sphere(p, P(s * 0.04, hy + 0.003, 0.127), 0.006), m_orb, 0.0)
        S.add(lambda p, s=side: d_sphere(p, P(s * 0.075, hy - 0.04, 0.1), 0.02), S.mat(Mat((250, 160, 150), spec=0.1)), 0.02)
    S.add(lambda p: d_sphere(p, P(0, hy - 0.025, 0.13), 0.018), m_skin, 0.01)
    if beard:
        S.add(lambda p: d_capsule(p, P(0, hy - 0.04, 0.06), P(0, hy - 0.2, 0.09), 0.07, 0.025), m_beard, 0.03)
        S.add(lambda p: d_ellipsoid(p, P(0, hy - 0.03, 0.09), P(0.06, 0.02, 0.03)), m_beard, 0.02)
    # 모자: 챙 + 휘어진 고깔
    hb = hy + 0.11; hz = -0.035
    S.add(lambda p: d_ellipsoid(p, P(0, hb, hz), P(0.19, 0.022, 0.18)), m_hat, 0.0)
    S.add(lambda p: d_torus(p, P(0, hb + 0.03, hz), 0.105, 0.02), m_trim, 0.0)
    tipx = -0.06 + sw * 0.015
    S.add(lambda p: d_capsule(p, P(0, hb + 0.01, hz), P(0.0, hb + 0.2, hz - 0.03), 0.11, 0.065), m_hat, 0.02)
    S.add(lambda p: d_capsule(p, P(0.0, hb + 0.2, hz - 0.03), P(tipx, hb + 0.33, hz - 0.09), 0.065, 0.028), m_hat, 0.03)
    S.add(lambda p: d_capsule(p, P(tipx, hb + 0.33, hz - 0.09), P(tipx * 2.2, hb + 0.36, hz - 0.17), 0.028, 0.008), m_hat, 0.02)
    return S

# ================= 좀비 =================
def zombie(ph=0.0):
    S = Scene()
    skin = S.mat(Mat((122, 150, 96), noise=0.35, nscale=12, spec=0.25, shin=14, col2=(88, 110, 66)))
    cloth = S.mat(Mat((96, 72, 56), noise=0.5, nscale=14, spec=0.05, col2=(60, 44, 34)))
    dark = S.mat(Mat((30, 22, 18)))
    eye = S.mat(Mat((60, 60, 10), emit=(240, 230, 90)))
    bob = abs(np.cos(ph)) * 0.02
    hip = 0.36 + bob
    for side in (-1, 1):
        a = ph if side > 0 else ph + np.pi
        knee = P(side * 0.09, hip - 0.18, np.sin(a) * 0.07 + 0.03)
        foot = P(side * 0.1, 0.035 + max(0, np.sin(a)) * 0.04, np.sin(a) * 0.12)
        limb(S, (side * 0.08, hip, 0), knee, 0.06, 0.05, cloth, 0.02)
        limb(S, knee, foot, 0.05, 0.042, skin, 0.02)
        S.add(lambda p, f=foot: d_ellipsoid(p, f + P(0, 0, 0.03), P(0.05, 0.03, 0.08)), skin, 0.02)
    # 구부정한 몸통
    S.add(lambda p: d_capsule(p, P(0, hip, 0), P(0, hip + 0.28, 0.08), 0.15, 0.17), cloth, 0.03)
    S.add(lambda p: d_ellipsoid(p, P(0, hip + 0.32, 0.06), P(0.19, 0.11, 0.14)), skin, 0.05)
    for i in range(3):
        S.add(lambda p, i=i: d_sphere(p, P(-0.08 + i * 0.09, hip + 0.06 + i * 0.05, 0.16), 0.035), dark, 0.02, True)
    shy = hip + 0.34
    for side in (-1, 1):
        a = ph + (0 if side > 0 else np.pi)
        sh = P(side * 0.18, shy, 0.06)
        el = sh + P(side * 0.03, -0.04 + np.sin(a) * 0.02, 0.2)
        ha = el + P(0, -0.02 + np.sin(a) * 0.03, 0.19)
        limb(S, sh, el, 0.055, 0.045, skin, 0.03); limb(S, el, ha, 0.045, 0.04, skin, 0.02)
        for f in range(3):
            limb(S, ha, ha + P(side * 0.02 * (f - 1), -0.03, 0.06), 0.013, 0.01, skin, 0.01)
    hy = shy + 0.1
    S.add(lambda p: d_ellipsoid(p, P(0.02, hy, 0.13), P(0.1, 0.11, 0.1)), skin, 0.04)
    S.add(lambda p: d_rbox(p, P(0.02, hy - 0.06, 0.2), (0.05, 0.015, 0.02), 0.01), dark, 0.0, True)
    for side in (-1, 1):
        S.add(lambda p, s=side: d_sphere(p, P(0.02 + s * 0.04, hy + 0.02, 0.21), 0.025), dark, 0.0, True)
        S.add(lambda p, s=side: d_sphere(p, P(0.02 + s * 0.04, hy + 0.02, 0.205), 0.012 if s > 0 else 0.009), eye, 0.0)
    return S

# ================= 박쥐 =================
def bat(ph=0.0):
    S = Scene()
    fur = S.mat(Mat((70, 52, 88), noise=0.4, nscale=26, spec=0.1, col2=(44, 32, 58)))
    wing = S.mat(Mat((96, 62, 104), noise=0.25, nscale=8, spec=0.2, col2=(64, 40, 70), rim=1.4))
    bone = S.mat(Mat((40, 28, 48)))
    eye = S.mat(Mat((80, 0, 0), emit=(255, 60, 60)))
    fang = S.mat(Mat((240, 236, 225), spec=0.6))
    y0 = 0.45 + np.sin(ph) * 0.03
    flap = np.sin(ph) * 0.9
    S.add(lambda p: d_ellipsoid(p, P(0, y0, 0), P(0.1, 0.11, 0.09)), fur, 0.0)
    S.add(lambda p: d_sphere(p, P(0, y0 + 0.11, 0.03), 0.075), fur, 0.04)
    for side in (-1, 1):
        S.add(lambda p, s=side: d_capsule(p, P(s * 0.04, y0 + 0.15, 0.02), P(s * 0.08, y0 + 0.26, 0.0), 0.03, 0.006), fur, 0.02)
        S.add(lambda p, s=side: d_sphere(p, P(s * 0.03, y0 + 0.12, 0.095), 0.016), eye, 0.0)
        S.add(lambda p, s=side: d_capsule(p, P(s * 0.015, y0 + 0.07, 0.09), P(s * 0.015, y0 + 0.04, 0.095), 0.008, 0.002), fang, 0.0)
        R = rot_z(-s * flap if False else 0)
        ang = side * (0.25 + flap)
        def wpt(x, y, s=side, ang=ang):
            v = P(s * x, y, 0)
            c, sn = np.cos(ang), np.sin(ang)
            v = P(v[0] * c - v[1] * sn * s * 0 + 0, v[0] * sn * s + v[1], v[2]) if False else v
            # 몸 옆 축을 기준으로 위아래로 펄럭
            r = rot_z(ang * 0.8)
            return P(0, y0 + 0.02, 0) + r @ v
        root = wpt(0.06, 0.0)
        tips = [wpt(0.42, 0.12), wpt(0.38, -0.04), wpt(0.26, -0.12)]
        elbow = wpt(0.22, 0.1)
        limb(S, root, elbow, 0.02, 0.012, bone, 0.01)
        for t in tips: limb(S, elbow, t, 0.01, 0.004, bone, 0.0)
        # 날개막: 얇은 납작 타원체 몇 개
        for (a, b) in [(root, tips[0]), (elbow, tips[1]), (root, tips[2]), (elbow, tips[2])]:
            mid = (a + b) / 2; L = np.linalg.norm(b - a)
            S.add(lambda p, a=a, b=b: d_capsule(p, a, b, 0.006) - 0.0, wing, 0.0)
        S.add(lambda p, pts=(root, elbow, tips[0], tips[1], tips[2]): _membrane(p, pts), wing, 0.01)
    return S

def _membrane(p, pts):
    root, elbow, t0, t1, t2 = pts
    best = np.full(len(p), 1e3)
    for (a, b, c) in [(root, elbow, t0), (root, t0, t1), (root, t1, t2)]:
        best = np.minimum(best, _tri(p, a, b, c) - 0.008)
    return best

def _tri(p, a, b, c):
    ba = b - a; pa = p - a; cb = c - b; pb = p - b; ac = a - c; pc = p - c
    nor = np.cross(ba, ac)
    s = (np.sign((np.cross(ba, nor) * pa).sum(-1)) + np.sign((np.cross(cb, nor) * pb).sum(-1)) + np.sign((np.cross(ac, nor) * pc).sum(-1)))
    def seg(pv, e):
        h = np.clip((pv @ e) / (e @ e), 0, 1); return ((pv - h[:, None] * e) ** 2).sum(-1)
    d1 = np.minimum(np.minimum(seg(pa, ba), seg(pb, cb)), seg(pc, ac))
    d2 = (pa @ nor) ** 2 / (nor @ nor)
    return np.sqrt(np.where(s < 2, d1, d2))

# ================= 꼬마 불꽃 =================
def imp(ph=0.0):
    S = Scene()
    fire = S.mat(Mat((255, 120, 40), emit=(255, 110, 30), emit_noise=0.6, spec=0.0, rim=0.6))
    core = S.mat(Mat((255, 230, 150), emit=(255, 225, 140)))
    horn = S.mat(Mat((60, 20, 10), spec=0.4))
    eye = S.mat(Mat((255, 255, 200), emit=(255, 255, 210)))
    y0 = 0.32 + np.sin(ph) * 0.03
    S.add(lambda p: d_ellipsoid(p, P(0, y0, 0), P(0.13, 0.15, 0.12)), fire, 0.0)
    for i in range(3):
        a = ph + i * 2.1
        S.add(lambda p, a=a, i=i: d_capsule(p, P((i - 1) * 0.05, y0 + 0.08, 0), P((i - 1) * 0.07 + np.sin(a) * 0.03, y0 + 0.26 + 0.04 * np.cos(a), -0.03), 0.06, 0.006), fire, 0.05)
    S.add(lambda p: d_ellipsoid(p, P(0, y0 - 0.01, 0.06), P(0.07, 0.08, 0.05)), core, 0.03)
    for side in (-1, 1):
        S.add(lambda p, s=side: d_capsule(p, P(s * 0.08, y0 + 0.1, 0.0), P(s * 0.15, y0 + 0.2, -0.02), 0.02, 0.004), horn, 0.0)
        S.add(lambda p, s=side: d_sphere(p, P(s * 0.045, y0 + 0.03, 0.115), 0.022), eye, 0.0)
        S.add(lambda p, s=side: d_capsule(p, P(s * 0.11, y0 - 0.02, 0.02), P(s * 0.17, y0 - 0.06 + np.sin(ph + s) * 0.03, 0.06), 0.025, 0.015), fire, 0.03)
    return S

# ================= 해골 술사 =================
def skelmage(ph=0.0, variant='ice'):
    S = Scene()
    col = (47, 95, 158) if variant == 'ice' else (63, 106, 36)
    glow = (150, 210, 255) if variant == 'ice' else (170, 240, 90)
    robe = S.mat(Mat(col, noise=0.3, nscale=9, spec=0.06, col2=tuple(int(c * 0.6) for c in col)))
    inner = S.mat(Mat((12, 8, 14), spec=0.0, rim=0.1))
    bone = S.mat(Mat((228, 218, 196), noise=0.15, nscale=14, spec=0.35))
    eye = S.mat(Mat((30, 30, 40), emit=glow))
    wood = S.mat(Mat((90, 62, 40), noise=0.4, nscale=20, spec=0.1))
    orb = S.mat(Mat(glow, emit=glow, spec=1.0))
    gold = S.mat(Mat((200, 160, 70), spec=0.8, shin=40))
    sw = np.sin(ph) * 0.015
    S.add(lambda p: d_capsule(p, P(sw, 0.07, 0), P(0, 0.62, 0), 0.21, 0.12), robe, 0.0)
    S.add(lambda p: d_ellipsoid(p, P(sw, 0.06, 0.0), P(0.23, 0.06, 0.21)), robe, 0.05)
    S.add(lambda p: d_torus(p, P(0, 0.4, 0), 0.155, 0.014), gold, 0.0)
    # 두건
    S.add(lambda p: d_capsule(p, P(0, 0.66, -0.01), P(0, 0.86, -0.05), 0.15, 0.06), robe, 0.04)
    S.add(lambda p: d_ellipsoid(p, P(0, 0.71, 0.09), P(0.1, 0.11, 0.09)), inner, 0.0, True)
    S.add(lambda p: d_ellipsoid(p, P(0, 0.7, 0.05), P(0.075, 0.085, 0.08)), bone, 0.0)
    for side in (-1, 1):
        S.add(lambda p, s=side: d_sphere(p, P(s * 0.03, 0.715, 0.12), 0.022), inner, 0.0, True)
        S.add(lambda p, s=side: d_sphere(p, P(s * 0.03, 0.715, 0.11), 0.012), eye, 0.0)
    for side in (-1, 1):
        sh = P(side * 0.14, 0.58, 0)
        el = sh + P(side * 0.06, -0.12, 0.08); ha = el + P(side * 0.0, -0.02 if side < 0 else 0.06, 0.12)
        limb(S, sh, el, 0.05, 0.055, robe, 0.03); limb(S, el, ha, 0.055, 0.065, robe, 0.01)
        ball(S, ha + P(0, 0, 0.03), 0.025, bone, 0.0)
        if side > 0:
            top = ha + P(0.02, 0.4, 0.04); bot = ha + P(0, -0.42, 0)
            S.add(lambda p, a=bot, b=top: d_capsule(p, a, b, 0.016), wood, 0.0)
            S.add(lambda p, c=top: d_torus(p, c + P(0, 0.05, 0), 0.05, 0.01, rot_x(np.pi / 2)), wood, 0.0)
            S.add(lambda p, c=top + P(0, 0.05, 0): d_sphere(p, c, 0.035 + 0.004 * np.sin(ph * 2)), orb, 0.0)
    return S

# ================= 그림자 =================
def shade(ph=0.0):
    S = Scene()
    body = S.mat(Mat((62, 44, 92), noise=0.45, nscale=7, spec=0.1, col2=(30, 20, 48), emit=(20, 8, 36), emit_noise=0.5, rim=1.8))
    eye = S.mat(Mat((80, 0, 20), emit=(255, 60, 100)))
    y0 = 0.42 + np.sin(ph) * 0.03
    S.add(lambda p: d_capsule(p, P(0, y0 - 0.05, 0), P(0, y0 + 0.2, 0), 0.17, 0.13), body, 0.0)
    for i in range(4):
        a = ph * 1.3 + i * 1.6; x = (i - 1.5) * 0.08
        S.add(lambda p, a=a, x=x: d_capsule(p, P(x, y0 - 0.05, 0), P(x * 1.3 + np.sin(a) * 0.05, 0.05 + 0.03 * np.cos(a), np.cos(a) * 0.04), 0.07, 0.008), body, 0.06)
    for side in (-1, 1):
        S.add(lambda p, s=side: d_capsule(p, P(s * 0.15, y0 + 0.12, 0.02), P(s * 0.26, y0 - 0.02 + np.sin(ph + s) * 0.04, 0.12), 0.045, 0.012), body, 0.05)
        S.add(lambda p, s=side: d_ellipsoid(p, P(s * 0.05, y0 + 0.2, 0.12), P(0.022, 0.034, 0.02)), eye, 0.0)
    return S

# ================= 화염 마귀 =================
def demon(ph=0.0):
    S = Scene()
    rock = S.mat(Mat((70, 30, 24), noise=0.5, nscale=10, spec=0.3, shin=20, col2=(36, 14, 12), emit=(120, 30, 0), emit_noise=0.9))
    lava = S.mat(Mat((255, 140, 40), emit=(255, 120, 30), emit_noise=0.4))
    horn = S.mat(Mat((40, 30, 28), noise=0.3, nscale=20, spec=0.5))
    wingm = S.mat(Mat((110, 30, 22), noise=0.3, nscale=6, spec=0.15, col2=(70, 16, 12), rim=1.5))
    eye = S.mat(Mat((255, 230, 120), emit=(255, 230, 120)))
    bob = abs(np.cos(ph)) * 0.02; hip = 0.42 + bob
    for side in (-1, 1):
        a = ph if side > 0 else ph + np.pi
        knee = P(side * 0.13, hip - 0.18, np.sin(a) * 0.07 + 0.08)
        foot = P(side * 0.14, 0.04 + max(0, np.sin(a)) * 0.04, np.sin(a) * 0.1)
        limb(S, (side * 0.12, hip, 0), knee, 0.09, 0.07, rock, 0.03); limb(S, knee, foot, 0.07, 0.05, rock, 0.03)
        S.add(lambda p, f=foot: d_ellipsoid(p, f + P(0, 0, 0.04), P(0.07, 0.04, 0.1)), rock, 0.03)
    S.add(lambda p: d_capsule(p, P(0, hip, 0), P(0, hip + 0.3, 0.02), 0.2, 0.26), rock, 0.06)
    S.add(lambda p: d_ellipsoid(p, P(0, hip + 0.18, 0.17), P(0.12, 0.14, 0.06)), lava, 0.04)
    shy = hip + 0.34
    for side in (-1, 1):
        a = ph + (np.pi if side > 0 else 0)
        sh, el, ha = arm_pts((side * 0.27, shy, 0.02), 0.5 + np.sin(a) * 0.3, 0.35, 0.2, 0.2, 0.7)
        limb(S, sh, el, 0.09, 0.075, rock, 0.04); limb(S, el, ha, 0.075, 0.06, rock, 0.03)
        S.add(lambda p, c=ha: d_sphere(p, c, 0.075), rock, 0.03)
        S.add(lambda p, c=ha + P(0, 0.07, 0.03): d_sphere(p, c, 0.05 + 0.006 * np.sin(ph * 3)), lava, 0.0)
        # 날개
        fl = 0.2 + np.sin(ph * 0.5) * 0.15
        root = P(side * 0.12, shy - 0.02, -0.15)
        tip = root + P(side * 0.55, 0.35 + fl * 0.3, -0.2)
        mid = root + P(side * 0.35, 0.05, -0.15)
        limb(S, root, tip, 0.03, 0.01, horn, 0.02)
        S.add(lambda p, a=root, b=tip, c=mid: _tri(p, a, b, c) - 0.01, wingm, 0.01)
        S.add(lambda p, a=root, b=mid, c=root + P(side * 0.2, -0.25, -0.1): _tri(p, a, b, c) - 0.01, wingm, 0.01)
    hy = shy + 0.14
    S.add(lambda p: d_ellipsoid(p, P(0, hy, 0.07), P(0.13, 0.13, 0.12)), rock, 0.05)
    S.add(lambda p: d_rbox(p, P(0, hy - 0.07, 0.17), (0.07, 0.02, 0.03), 0.01), lava, 0.0)
    for side in (-1, 1):
        S.add(lambda p, s=side: d_capsule(p, P(s * 0.08, hy + 0.08, 0.04), P(s * 0.2, hy + 0.2, -0.04), 0.04, 0.025), horn, 0.02)
        S.add(lambda p, s=side: d_capsule(p, P(s * 0.2, hy + 0.2, -0.04), P(s * 0.18, hy + 0.33, -0.1), 0.025, 0.004), horn, 0.0)
        S.add(lambda p, s=side: d_ellipsoid(p, P(s * 0.05, hy + 0.02, 0.18), P(0.03, 0.016, 0.02)), eye, 0.0)
    return S

# ================= 보스 =================
def golem(ph=0.0):
    S = Scene()
    stone = S.mat(Mat((150, 142, 128), noise=0.45, nscale=7, spec=0.15, col2=(96, 90, 80)))
    moss = S.mat(Mat((70, 100, 60), noise=0.5, nscale=16, spec=0.05))
    core = S.mat(Mat((120, 230, 255), emit=(120, 230, 255)))
    bob = abs(np.cos(ph)) * 0.02; hip = 0.36 + bob
    for side in (-1, 1):
        a = ph if side > 0 else ph + np.pi
        S.add(lambda p, s=side, a=a: d_rbox(p, P(s * 0.17, hip * 0.5 + max(0, np.sin(a)) * 0.03, np.sin(a) * 0.06), (0.1, hip * 0.5, 0.11), 0.04), stone, 0.02)
    S.add(lambda p: d_rbox(p, P(0, hip + 0.25, 0), (0.3, 0.24, 0.2), 0.08, rot_x(0.08)), stone, 0.04)
    S.add(lambda p: d_rbox(p, P(0.1, hip + 0.45, -0.05), (0.15, 0.06, 0.12), 0.04), moss, 0.03)
    S.add(lambda p: d_sphere(p, P(0, hip + 0.25, 0.2), 0.07), core, 0.0)
    S.add(lambda p: d_rbox(p, P(0, hip + 0.25, 0.2), (0.12, 0.12, 0.05), 0.02), stone, 0.0, True)
    S.add(lambda p: d_sphere(p, P(0, hip + 0.25, 0.17), 0.065), core, 0.0)
    for side in (-1, 1):
        a = ph + (np.pi if side > 0 else 0)
        sh = P(side * 0.36, hip + 0.38, 0)
        ha = sh + P(side * 0.06, -0.4, 0.1 + np.sin(a) * 0.08)
        S.add(lambda p, a=sh, b=ha: d_capsule(p, a, b, 0.11, 0.09), stone, 0.04)
        S.add(lambda p, c=ha + P(0, -0.04, 0.02): d_rbox(p, c, (0.11, 0.1, 0.12), 0.05), stone, 0.03)
        S.add(lambda p, c=sh + P(0, 0.06, 0): d_rbox(p, c, (0.14, 0.09, 0.14), 0.05), stone, 0.03)
    hy = hip + 0.6
    S.add(lambda p: d_rbox(p, P(0, hy, 0.05), (0.12, 0.1, 0.11), 0.04), stone, 0.03)
    for side in (-1, 1):
        S.add(lambda p, s=side: d_rbox(p, P(s * 0.05, hy + 0.01, 0.16), (0.025, 0.012, 0.01), 0.004), core, 0.0)
    return S

def flesh(ph=0.0, small=False):
    S = Scene()
    meat = S.mat(Mat((196, 111, 128), noise=0.5, nscale=6, spec=0.5, shin=30, col2=(150, 60, 80), rim=1.2))
    vein = S.mat(Mat((120, 40, 60), spec=0.3))
    white = S.mat(Mat((245, 240, 235), spec=0.9, shin=60))
    iris = S.mat(Mat((184, 16, 44), spec=0.8, emit=(60, 0, 10)))
    pupil = S.mat(Mat((5, 0, 0), spec=1.0))
    stitch = S.mat(Mat((60, 30, 30)))
    pulse = 1 + 0.03 * np.sin(ph * 2)
    y0 = 0.32
    S.add(lambda p: d_ellipsoid(p, P(0, y0, 0), P(0.3, 0.3, 0.27) * pulse), meat, 0.0)
    for i in range(7):
        a = i * 0.9 + 0.3; b = i * 1.7
        c = P(np.cos(a) * 0.22, y0 + np.sin(b) * 0.16, np.sin(a) * 0.18)
        S.add(lambda p, c=c, i=i: d_sphere(p, c, 0.1 + 0.03 * np.sin(ph * 2 + i)), meat, 0.08)
    for i in range(4):
        a = i * 1.5
        S.add(lambda p, a=a: d_torus(p, P(np.cos(a) * 0.15, y0 + 0.1, np.sin(a) * 0.1 + 0.15), 0.07, 0.008, rot_x(0.9)), stitch, 0.0)
    S.add(lambda p: d_sphere(p, P(0, y0 + 0.08, 0.2), 0.13), white, 0.02)
    S.add(lambda p: d_sphere(p, P(0, y0 + 0.08, 0.27), 0.075), iris, 0.0)
    S.add(lambda p: d_sphere(p, P(0, y0 + 0.08, 0.32), 0.035), pupil, 0.0)
    S.add(lambda p: d_torus(p, P(0, y0 + 0.08, 0.22), 0.13, 0.025, rot_x(np.pi / 2)), meat, 0.02)
    return S

def warlock(ph=0.0):
    S = Scene()
    robe = S.mat(Mat((50, 26, 90), noise=0.35, nscale=8, spec=0.1, col2=(26, 12, 50)))
    trim = S.mat(Mat((150, 90, 230), spec=0.6, emit=(40, 10, 70)))
    inner = S.mat(Mat((8, 4, 12)))
    eye = S.mat(Mat((255, 80, 210), emit=(255, 80, 210)))
    wood = S.mat(Mat((60, 40, 30), noise=0.4, nscale=20, spec=0.2))
    orb = S.mat(Mat((230, 210, 255), emit=(220, 190, 255), spec=1.0))
    bone = S.mat(Mat((220, 210, 190), spec=0.4))
    sw = np.sin(ph) * 0.02
    S.add(lambda p: d_capsule(p, P(sw, 0.08, 0), P(0, 0.75, 0), 0.26, 0.13), robe, 0.0)
    S.add(lambda p: d_ellipsoid(p, P(sw, 0.06, 0), P(0.3, 0.07, 0.27)), robe, 0.06)
    S.add(lambda p: d_torus(p, P(0, 0.08, 0), 0.28, 0.02), trim, 0.03)
    S.add(lambda p: d_rbox(p, P(0, 0.4, 0.2), (0.03, 0.33, 0.03), 0.01, rot_x(0.35)), trim, 0.0)
    # 어깨 장식
    for side in (-1, 1):
        S.add(lambda p, s=side: d_ellipsoid(p, P(s * 0.18, 0.72, 0), P(0.12, 0.07, 0.12)), robe, 0.03)
        for k in range(3):
            S.add(lambda p, s=side, k=k: d_capsule(p, P(s * (0.15 + k * 0.05), 0.76, -0.02 + k * 0.02), P(s * (0.2 + k * 0.07), 0.88, -0.06), 0.02, 0.004), bone, 0.0)
    # 두건
    S.add(lambda p: d_capsule(p, P(0, 0.8, -0.02), P(0, 1.06, -0.1), 0.17, 0.04), robe, 0.05)
    S.add(lambda p: d_ellipsoid(p, P(0, 0.86, 0.1), P(0.11, 0.12, 0.1)), inner, 0.0, True)
    for side in (-1, 1):
        S.add(lambda p, s=side: d_ellipsoid(p, P(s * 0.035, 0.87, 0.1), P(0.02, 0.012, 0.01)), eye, 0.0)
    for side in (-1, 1):
        sh = P(side * 0.18, 0.7, 0)
        el = sh + P(side * 0.08, -0.15, 0.1); ha = el + P(0, 0.05 if side > 0 else -0.05, 0.14)
        limb(S, sh, el, 0.065, 0.075, robe, 0.03); limb(S, el, ha, 0.075, 0.09, robe, 0.01)
        S.add(lambda p, c=ha + P(0, 0, 0.04): d_sphere(p, c, 0.03), bone, 0.0)
        if side > 0:
            top = ha + P(0.03, 0.55, 0.04); bot = ha + P(0, -0.55, 0)
            S.add(lambda p, a=bot, b=top: d_capsule(p, a, b, 0.02), wood, 0.0)
            for k in range(3):
                S.add(lambda p, k=k, c=top: d_capsule(p, c, c + P(np.cos(k * 2.1) * 0.08, 0.1, np.sin(k * 2.1) * 0.08), 0.012, 0.004), wood, 0.0)
            S.add(lambda p, c=top + P(0, 0.09, 0): d_sphere(p, c, 0.05 + 0.006 * np.sin(ph * 2)), orb, 0.0)
    return S

# ================= 보물상자 =================
def chest(open_=False):
    S = Scene()
    wood = S.mat(Mat((130, 82, 44), noise=0.5, nscale=16, spec=0.15, col2=(90, 54, 28)))
    gold = S.mat(Mat((222, 178, 84), noise=0.1, nscale=30, spec=0.9, shin=50))
    dark = S.mat(Mat((24, 14, 8)))
    coin = S.mat(Mat((255, 214, 100), spec=1.0, shin=60, emit=(80, 50, 0)))
    S.add(lambda p: d_rbox(p, P(0, 0.12, 0), (0.24, 0.12, 0.16), 0.02), wood, 0.0)
    if open_ is True:
        S.add(lambda p: d_rbox(p, P(0, 0.22, 0), (0.21, 0.08, 0.13), 0.01), dark, 0.0, True)
        S.add(lambda p: d_ellipsoid(p, P(0, 0.18, 0), P(0.2, 0.05, 0.12)), coin, 0.0)
        lid = lambda p: d_rbox(p, P(0, 0.33, -0.2), (0.24, 0.11, 0.035), 0.02, rot_x(-0.25))
        S.add(lid, wood, 0.0)
    else:
        S.add(lambda p: d_rbox(p, P(0, 0.28, 0), (0.245, 0.05, 0.165), 0.03), wood, 0.0)
        S.add(lambda p: np.maximum(d_ellipsoid(p, P(0, 0.31, 0), P(0.245, 0.06, 0.165)), -(p[:, 1] - 0.31)), wood, 0.02)
    for x in (-0.17, 0.17):
        S.add(lambda p, x=x: d_rbox(p, P(x, 0.13, 0), (0.025, 0.13, 0.165), 0.006), gold, 0.0)
        if not open_: S.add(lambda p, x=x: d_rbox(p, P(x, 0.29, 0), (0.025, 0.075, 0.17), 0.008), gold, 0.0)
    S.add(lambda p: d_rbox(p, P(0, 0.23, 0.165), (0.045, 0.055, 0.015), 0.01), gold, 0.0)
    S.add(lambda p: d_rbox(p, P(0, 0.22, 0.18), (0.008, 0.018, 0.01), 0.003), dark, 0.0)
    return S
