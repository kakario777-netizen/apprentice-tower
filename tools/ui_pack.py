# GPT UI·아이콘 → godot/art/ui(원본 크기) + 옛 아이콘 이름(godot/ui/*.png)을 새 그림으로 교체
import sys, os, glob
from PIL import Image
src, root = sys.argv[1], sys.argv[2]
F = {os.path.splitext(os.path.basename(p))[0]: p for p in glob.glob(src + '/**/*.png', recursive=True)}
out = os.path.join(root, 'art/ui'); os.makedirs(out, exist_ok=True)
HUD = ['ui_hud_hp_frame', 'ui_hud_hp_fill', 'ui_hud_mp_frame', 'ui_hud_mp_fill', 'ui_hud_level_ring', 'ui_hud_minimap_frame',
       'ui_hud_btn_pause', 'ui_hud_btn_bag', 'ui_hud_newdot', 'ui_hud_belt_slot', 'ui_hud_skill_main', 'ui_hud_skill_sub', 'ui_hud_cooldown',
       'ui_hud_stick_base', 'ui_hud_stick_knob', 'ui_hud_aim_base', 'ui_hud_aim_knob', 'ui_hud_boss_frame', 'ui_hud_boss_fill', 'ui_hud_banner', 'ui_rarity_frame']
for k in HUD:
    im = Image.open(F[k]).convert('RGBA')
    w, h = im.size
    if w > 600 or h > 600: im = im.resize((w // 2, h // 2), Image.LANCZOS)      # 큰 틀은 절반(폰 화면 크기에 충분)
    im.save(os.path.join(out, k + '.png'), optimize=True)
def put(name, icon, size):
    im = Image.open(F[icon]).convert('RGBA').resize((size, size), Image.LANCZOS)
    im.save(os.path.join(root, 'ui', name + '.png'), optimize=True)
EL = {'arcane': 'arcane', 'fire': 'fire', 'storm': 'storm', 'frost': 'frost'}
for e, i in EL.items():
    for p in ['', '_p']: put('el_%s%s' % (e, p), 'icon_sk_' + i, 162)
FUS = {'arcane_fire': 'firehoming', 'fire_storm': 'firewhip', 'fire_frost': 'steam', 'arcane_storm': 'ballbolt', 'arcane_frost': 'frosthoming', 'frost_storm': 'icebeam'}
SUB = {'multi': 'multi', 'seek': 'seek', 'siphon': 'drain', 'blast': 'blast', 'embers': 'ember', 'burn': 'burn', 'chain': 'chain', 'shock': 'shock',
       'reach': 'longarc', 'widen': 'frostspread', 'gust': 'chill', 'harden': 'iceamor'}
SEC = {'blink': 'blink', 'ward': 'ward', 'stasis': 'timecircle', 'freeze': 'flashfreeze', 'nova': 'firering', 'acid': 'acidrain', 'purge': 'holylight'}
PAS = {'vigor': 'vigor', 'well': 'deepmana', 'calm': 'meditate', 'quick': 'quickcast', 'thrift': 'thrift', 'focus': 'focus', 'might': 'siege', 'swift': 'lightfoot'}
for d, pre, ip in [(FUS, 'fus_', 'icon_sk_'), (SUB, 'sub_', 'icon_sk_'), (SEC, 'sec_', 'icon_sk_'), (PAS, 'pass_', 'icon_ps_')]:
    for k, i in d.items():
        for p in ['', '_p']: put(pre + k + p, ip + i, 162)
RAR = {'normal': 1, 'magic': 2, 'rare': 3, 'set': 4, 'unique': 5}
for b in ['staff', 'wand', 'sceptre', 'ring', 'cloak', 'robe', 'amulet', 'gloves', 'belt', 'boots']:
    for r, t in RAR.items(): put('gear_%s_%s' % (b, r), 'icon_%s_%d' % (b, t), 128)
put('item_pothp', 'icon_pot_hp', 128); put('item_potmp', 'icon_pot_mp', 128); put('item_scroll', 'icon_scroll_portal', 128)
put('bag', 'ui_hud_btn_bag', 128)
# 장비 칸 빈 자리 흐린 그림(시트: 목걸이 스태프 망토 장갑 반지 반지 허리띠 장화)
g = Image.open(F['ui_bag_eq_ghost']).convert('RGBA'); cw = g.size[0] // 8
for n, c in {'amulet': 0, 'weapon': 1, 'cloak': 2, 'gloves': 3, 'ring': 4, 'belt': 6, 'boots': 7}.items():
    g.crop((c * cw, 0, (c + 1) * cw, g.size[1])).resize((128, 128), Image.LANCZOS).save(os.path.join(root, 'ui', 'slot_%s.png' % n), optimize=True)
print('ok')
