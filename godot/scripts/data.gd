# 게임 데이터 — 웹 버전 DATA 그대로(수식은 함수로)
class_name D
extends RefCounted

const LAST_FLOOR := 99   # 99층 위는 옥상(ROOF) — 최종 보스
const ROOF := 100
const PRIMARY_MAX := 10
const T := 32.0
const MW := 82
const MH := 62
const BAGMAX := 12
const SLOTS := ["amulet", "weapon", "cloak", "ring1", "ring2", "belt", "boots"]
const SLOTNAME := {amulet = "목걸이", weapon = "스태프", cloak = "망토", ring1 = "반지 1", ring2 = "반지 2", belt = "허리띠", boots = "장화"}
const BAG_START := 12
const BAG_LIMIT := 36
static func bag_price(cur: int) -> int:
	var n := (cur - BAG_START) / 4
	return [800, 2000, 4000, 7000, 11000, 16000][min(n, 5)]

const PRIMARIES := {
	arcane = {name = "비전탄", color = "#c39bff", kind = "shot", desc = "적을 스스로 쫓아가는 마력탄. 조준이 서툴러도 잘 맞는다.", cd = .3, speed = 340, homing = 3.2, radius = 5},
	fire = {name = "화염구", color = "#ff7b34", kind = "shot", desc = "곧게 날아가 부딪히면 터지는 불덩이. 한 방이 묵직하다.", cd = .55, speed = 300, homing = 0, radius = 7},
	storm = {name = "번개", color = "#86e3ff", kind = "chain", desc = "조준한 쪽 적에게 전격을 계속 흘려보낸다. 누르는 동안 지속.", range = 230},
	frost = {name = "냉기 숨결", color = "#cdf2ff", kind = "cone", desc = "앞쪽으로 냉기를 뿜어 여러 적을 한꺼번에 느리게 만든다.", range = 150},
}
const PRIM_ORDER := ["arcane", "fire", "storm", "frost"]

static func prim_dmg(id: String, l: float) -> Array:
	match id:
		"arcane": return [3 * l + 2, 4 * l + 3]
		"fire": return [5 * l + 5, 5 * l + 9]
	return [0, 0]
static func prim_mana(id: String, l: float) -> float:
	match id:
		"arcane": return 3 + 1.2 * l
		"fire": return 5 + 2 * l
	return 0
static func prim_dps(id: String, l: float) -> float:
	match id:
		"storm": return 12 + 8 * l
		"frost": return 10 + 7 * l
	return 0
static func prim_manaps(id: String, l: float) -> float:
	match id:
		"storm": return 5 + 2 * l
		"frost": return 4 + 1.8 * l
	return 0

const SUBS := [
	{id = "multi", of = "arcane", name = "다중 시전", desc = "비전 계열 탄을 한 번에 1발 더 쏜다.", max = 4},
	{id = "seek", of = "arcane", name = "끈질긴 추적", desc = "적을 맞힌 탄이 다음 적을 다시 쫓는다. 레벨당 1회.", max = 3},
	{id = "siphon", of = "arcane", name = "마력 흡수", desc = "비전 계열 탄이 명중하면 마나를 조금 되찾는다.", max = 3},
	{id = "blast", of = "fire", name = "폭발", desc = "화염 계열 탄이 주변까지 터진다. 레벨마다 반경 증가.", max = 4},
	{id = "embers", of = "fire", name = "불씨", desc = "터진 자리에 불씨가 남아 밟은 적을 태운다.", max = 3},
	{id = "burn", of = "fire", name = "화상", desc = "화염에 맞은 적이 몇 초간 계속 불탄다.", max = 3},
	{id = "chain", of = "storm", name = "연쇄", desc = "전격이 근처 적에게 한 번 더 튄다.", max = 4},
	{id = "shock", of = "storm", name = "감전", desc = "전격에 맞은 적이 잠시 둔해진다.", max = 3},
	{id = "reach", of = "storm", name = "긴 전류", desc = "번개 계열 사거리가 늘어난다.", max = 3},
	{id = "widen", of = "frost", name = "냉기 확산", desc = "냉기 숨결의 폭과 길이가 늘어난다.", max = 4},
	{id = "gust", of = "frost", name = "찬바람", desc = "냉기에 닿은 적을 밀어내고 화살을 날려버린다.", max = 3},
	{id = "harden", of = "frost", name = "얼음 갑옷", desc = "냉기를 뿜는 동안 받는 피해가 줄어든다.", max = 3},
]

const FUSIONS := {
	"arcane+fire": {name = "불꽃 유도탄", kind = "shot", color = "#ffa24a", desc = "적을 쫓아가 터지는 화염탄. 두 계열 강화가 모두 붙는다."},
	"fire+storm": {name = "화염 채찍", kind = "chain", color = "#ffc35a", desc = "불붙은 전격이 적 사이를 튀어 다닌다."},
	"fire+frost": {name = "증기 분사", kind = "cone", color = "#f4f1ea", desc = "뜨거운 증기를 넓게 뿜어 태우고 느리게 만든다."},
	"arcane+storm": {name = "구전탄", kind = "shot", color = "#9fe8ff", desc = "맞으면 주변으로 전격이 튀는 유도 구체."},
	"arcane+frost": {name = "서리 유도탄", kind = "shot", color = "#bfe9ff", desc = "적을 쫓아가 얼려 버리는 차가운 탄."},
	"frost+storm": {name = "빙뇌 광선", kind = "beam", color = "#d9f6ff", desc = "일직선으로 꿰뚫는 굵은 광선. 줄지어 선 적에게 강하다."},
}

static func secondary_slots(lv: int) -> int: return 3 if lv >= 12 else 2

const SECONDARIES := [
	{id = "blink", name = "순간이동", lv = 2, desc = "가 본 곳 중 적에게서 가장 먼 곳으로 즉시 이동한다.", max = 1, cd = 5},
	{id = "ward", name = "마력 보호막", lv = 2, desc = "피해를 대신 받아주는 막을 두른다.", max = 5, cd = 14},
	{id = "stasis", name = "시간의 원", lv = 3, desc = "원 안의 적은 느려지고, 나는 생명과 마나가 빠르게 찬다.", max = 5, cd = 20},
	{id = "freeze", name = "순간 빙결", lv = 3, desc = "주변 적을 잠시 통째로 얼린다.", max = 5, cd = 16},
	{id = "nova", name = "화염 고리", lv = 2, desc = "사방으로 불꽃을 터뜨려 적을 밀쳐내고 탄을 지운다.", max = 5, cd = 9},
	{id = "acid", name = "산성비", lv = 3, desc = "가장 가까운 적 위에 산성 구름을 띄운다.", max = 5, cd = 11},
	{id = "purge", name = "정화의 빛", lv = 4, desc = "언데드가 큰 피해를 입고 겁에 질려 달아난다.", max = 5, cd = 18},
]
static func sec(id: String) -> Dictionary:
	for s in SECONDARIES:
		if s.id == id: return s
	return {}
static func sec_mana(id: String, l: float) -> float:
	match id:
		"blink": return 10
		"ward": return 40
		"stasis": return 30
		"freeze": return 25 + 4 * l
		"nova": return 20 + 4 * l
		"acid": return 25
		"purge": return 35
	return 0
static func sec_amt(l: float) -> float: return 20 * pow(2, l - 1)          # ward
static func sec_dur(id: String, l: float) -> float: return 4 + l if id == "stasis" else 1.5 + .5 * l
static func sec_dmg(id: String, l: float) -> float: return 14 * l if id == "nova" else 22 * l
static func sec_dps(l: float) -> float: return 8 + 8 * l                     # acid

const PASSIVES := [
	{id = "vigor", name = "강인함", desc = "최대 생명 +15", max = 10},
	{id = "well", name = "깊은 마력", desc = "최대 마나 +15", max = 10},
	{id = "calm", name = "명상", desc = "마나 회복 속도 +25%", max = 5},
	{id = "quick", name = "빠른 시전", desc = "탄 발사 속도 +12%", max = 5},
	{id = "thrift", name = "절약 시전", desc = "주 마법 마나 소모 -10%", max = 5},
	{id = "focus", name = "정신 집중", desc = "보조 마법 재사용 대기 -12%", max = 4},
	{id = "might", name = "공성 마법", desc = "모든 마법 피해 +12%", max = 5},
	{id = "swift", name = "가벼운 발", desc = "이동 속도 +8%", max = 3},
]

const DIFFICULTIES := [
	{id = "easy", name = "견습생", desc = "몬스터가 약하고 덜 아프다. 처음 해본다면 여기서.", hp = .8, dmg = .75, reward = 1.0, color = "#7fb2ff"},
	{id = "norm", name = "졸업반", desc = "원래 의도한 난이도. 경험치와 금화가 조금 더 나온다.", hp = 1.15, dmg = 1.05, reward = 1.25, color = "#e3b04b"},
	{id = "hard", name = "대마법사", desc = "몬스터가 훨씬 단단하고 아프다. 그만큼 보상도 크다.", hp = 1.7, dmg = 1.45, reward = 1.6, color = "#ff6a5a"},
]

const SHOP := [
	{id = "pothp", name = "생명 물약", desc = "생명을 45% 즉시 회복", price = 40, max = 5},
	{id = "potmp", name = "마나 물약", desc = "마나를 60% 즉시 회복", price = 40, max = 5},
	{id = "scroll", name = "귀환 주문서", desc = "탑 어디서든 마을로 가는 문을 연다", price = 120, max = 3},
]
static func shop(id: String) -> Dictionary:
	for s in SHOP:
		if s.id == id: return s
	return {}

const MONSTERS := {
	skel = {name = "해골 병사", hp = 14, spd = 62, r = 12, dmg = 6, atk = "melee", xp = 4, color = "#e6dcc4", undead = 1, from = 1},
	zombie = {name = "시체 일꾼", hp = 30, spd = 38, r = 14, dmg = 9, atk = "melee", xp = 6, color = "#7f9b62", undead = 1, from = 1},
	archer = {name = "해골 사수", hp = 12, spd = 50, r = 12, dmg = 5, atk = "arrow", range = 300, cd = 2.2, xp = 6, color = "#d8c8a0", undead = 1, from = 2},
	bat = {name = "고블린", hp = 9, spd = 128, r = 9, dmg = 4, atk = "melee", xp = 3, color = "#5a4470", erratic = 1, undead = 1, from = 2},
	imp = {name = "불개미", hp = 7, spd = 118, r = 8, dmg = 4, atk = "melee", xp = 2, color = "#ff6a3d", from = 3},
	mage = {name = "해골 술사", hp = 16, spd = 45, r = 12, dmg = 7, atk = "orb", range = 290, cd = 2.8, shield = 30, xp = 12, color = "#9fd0ff", undead = 1, from = 4},
	shade = {name = "모래 개미귀신", hp = 24, spd = 92, r = 13, dmg = 8, atk = "melee", xp = 10, color = "#6b5a8a", hidden = 1, from = 6},
	demon = {name = "화염 비룡", hp = 60, spd = 52, r = 18, dmg = 12, atk = "fireball", range = 270, cd = 3, split = "imp", xp = 20, color = "#ff4a1c", from = 7},
	# 9층부터 나오는 변종(같은 그림을 색·크기·성질만 바꿔서)
	skel_knight = {name = "해골 기사", hp = 40, spd = 50, r = 14, dmg = 11, atk = "melee", xp = 14, color = "#aeb8e6", undead = 1, from = 9, spr = "skel", h = 56, tint = "#b4c0f0"},
	ice_mage = {name = "서리 술사", hp = 22, spd = 45, r = 12, dmg = 9, atk = "orb", orb = "ice", range = 300, cd = 2.4, shield = 40, xp = 16, color = "#9fd0ff", undead = 1, from = 12, spr = "mage", h = 50, tint = "#a8d0ff"},
	plague = {name = "역병 시체", hp = 46, spd = 40, r = 15, dmg = 10, atk = "melee", onhit = "poison", xp = 15, color = "#8fbf4a", undead = 1, from = 14, spr = "zombie", h = 50, tint = "#b0e070"},
	ice_ant = {name = "얼음 개미", hp = 14, spd = 120, r = 9, dmg = 7, atk = "melee", onhit = "slow", xp = 6, color = "#bfe9ff", from = 16, spr = "fire_ant", h = 26, tint = "#a0dcff"},
	goblin_chief = {name = "고블린 두목", hp = 40, spd = 110, r = 12, dmg = 12, atk = "melee", erratic = 1, xp = 18, color = "#ff9a80", from = 18, spr = "goblin", h = 44, tint = "#ffa890"},
	fire_archer = {name = "불화살 사수", hp = 20, spd = 52, r = 12, dmg = 9, atk = "fireball", blast = 28, range = 320, cd = 2.0, xp = 14, color = "#ffb060", undead = 1, from = 20, spr = "archer", h = 48, tint = "#ffbe8a"},
	ice_wyvern = {name = "서리 비룡", hp = 90, spd = 55, r = 18, dmg = 15, atk = "orb", orb = "ice", range = 280, cd = 2.6, xp = 30, color = "#9fd8ff", from = 25, spr = "wyvern_fire", h = 62, tint = "#90c8ff"},
	dune_lord = {name = "모래 군주", hp = 70, spd = 85, r = 16, dmg = 14, atk = "melee", hidden = 1, xp = 26, color = "#e0c080", from = 30, spr = "antlion", h = 46, tint = "#ffe6b0"},
	lich_adept = {name = "리치 견습생", hp = 50, spd = 60, r = 13, dmg = 14, atk = "skull", range = 320, cd = 3.0, shield = 60, xp = 30, color = "#b77bff", undead = 1, from = 35, spr = "lich", h = 54, tint = "#d8b8ff"},
}
const BOSSES := {
	5: {id = "golem", name = "묘지기 미노타우로스", hp = 650, r = 30, spd = 42, color = "#9b927f", dmg = 16},
	10: {id = "flesh", name = "여왕 개미귀신", hp = 1300, r = 34, spd = 50, color = "#c46f80", dmg = 18},
	15: {id = "warlock", name = "흑마법사 벨로르", hp = 1200, r = 20, spd = 80, color = "#8a4be0", dmg = 20, shield = 250},
}

# 그림 이름·크기(웹 SPRMAP / BOSSMAP / SPRH)
const SPRMAP := {skel = "skel", archer = "archer", mage = "mage", zombie = "zombie", bat = "goblin", imp = "fire_ant", shade = "antlion_small", demon = "wyvern_fire"}
const BOSSMAP := {golem = "minotaur", flesh = "antlion", warlock = "lich"}
const SPRH := {skel = 46, archer = 46, mage = 48, zombie = 46, bat = 34, imp = 24, shade = 22, demon = 60, golem = 86, warlock = 74}

# ---------------- 장비 ----------------
const RAR := {
	magic = {name = "마법", color = "#6f9cff", mods = [1, 2], mult = 1.0},
	rare = {name = "희귀", color = "#ffd76a", mods = [3, 4], mult = 1.25},
	epic = {name = "영웅", color = "#ff9a3a", mods = [4, 5], mult = 1.6},
}
const BASES := [
	{id = "staff", slot = "weapon", names = ["참나무 지팡이", "흑단 지팡이", "뼈 지팡이", "별빛 지팡이", "용목 지팡이"], imp = {k = "dmg", v = .08}},
	{id = "wand", slot = "weapon", names = ["자작나무 완드", "수정 완드", "은 완드", "유리 완드", "달빛 완드"], imp = {k = "cast", v = .08}},
	{id = "ring", slot = "ring", names = ["구리 반지", "은 반지", "금 반지", "흑요석 반지", "월장석 반지"], imp = null},
	{id = "cloak", slot = "cloak", names = ["양모 망토", "가죽 망토", "비단 망토", "그림자 망토", "불사조 망토"], imp = {k = "res", v = .04}},
	{id = "amulet", slot = "amulet", names = ["은 목걸이", "호박 목걸이", "수정 목걸이", "별빛 목걸이", "용의 눈 목걸이"], imp = null},
	{id = "belt", slot = "belt", names = ["가죽 허리띠", "징 박힌 허리띠", "은사 허리띠", "수호자 허리띠", "거인 허리띠"], imp = {k = "hp", v = 6}},
	{id = "boots", slot = "boots", names = ["천 신발", "가죽 장화", "여행자 장화", "바람 장화", "구름 장화"], imp = {k = "spd", v = .03}},
]
static func base(id: String) -> Dictionary:
	for b in BASES:
		if b.id == id: return b
	return BASES[0]
const PREFIX := {prim = {arcane = "비전의", fire = "불꽃의", storm = "번개의", frost = "서리의"}, hp = "튼튼한", mp = "깊은", regen = "샘솟는", dmg = "날카로운", cast = "재빠른", cdr = "명상가의", res = "단단한", spd = "바람의", gold = "욕심쟁이의", sub = "숙련된", sec = "학자의"}
const RARENAMES := ["황혼", "망령", "폭풍", "잿빛", "월광", "심연", "서약", "유성", "파수", "은하"]
const EPICNAMES := {weapon = ["대현자의 지팡이", "벼락 삼킨 가지", "첫 불씨", "겨울 왕의 홀"], ring = ["시간 매듭", "일곱 번째 별", "잊힌 맹세"], cloak = ["밤의 장막", "불사조의 깃", "유령 걸음"],
	amulet = ["별의 심장", "마녀의 눈물", "현자의 숨결"], belt = ["거신의 띠", "피의 서약"], boots = ["바람 걸음", "그림자 발자국"]}

# 층 구성: 5층마다 보스(5 네임드 · 10 준보스 · 15 네임드 · 20 계층 보스 반복), 20층마다 분위기
static func boss_kind(f: int) -> String:
	if f == ROOF: return "final"
	if f % 20 == 0: return "tier"
	if f % 10 == 0: return "sub"
	if f % 5 == 0: return "named"
	return ""
static func theme(f: int) -> int: return clampi((f - 1) / 20, 0, 4)
const THEMES := [
	{name = "돌의 회랑", amb = Color(.46, .41, .56), tint = Color(1, 1, 1), torch = Color(1, .6, .3), floor = "floor2"},
	{name = "이끼 낀 지하묘지", amb = Color(.36, .46, .4), tint = Color(.82, .95, .84), torch = Color(.95, .75, .4), floor = "floor"},
	{name = "잿불의 층", amb = Color(.52, .34, .3), tint = Color(1.05, .82, .74), torch = Color(1, .42, .18), floor = "floor2"},
	{name = "별빛 서고", amb = Color(.36, .38, .62), tint = Color(.8, .84, 1.1), torch = Color(.55, .7, 1), floor = "floor"},
	{name = "검은 첨탑", amb = Color(.42, .3, .5), tint = Color(.78, .7, .9), torch = Color(.8, .4, 1), floor = "floor2"},
]

static func mod_text(m: Dictionary) -> String:
	var parts: PackedStringArray = String(m.k).split(":")
	var t = parts[0]; var v = m.v
	if t == "prim": return "%s +%s" % [PRIMARIES[parts[1]].name, str(v)]
	if t == "sub":
		for s in SUBS:
			if s.id == parts[1]: return "%s +%s" % [s.name, str(v)]
	if t == "sec": return "%s +%s" % [sec(parts[1]).name, str(v)]
	var pct = int(round(float(v) * 100))
	match t:
		"hp": return "최대 생명 +%d" % int(round(v))
		"mp": return "최대 마나 +%d" % int(round(v))
		"regen": return "마나 회복 +%d%%" % pct
		"dmg": return "마법 피해 +%d%%" % pct
		"cast": return "시전 속도 +%d%%" % pct
		"cdr": return "보조 마법 대기 -%d%%" % pct
		"res": return "받는 피해 -%d%%" % pct
		"spd": return "이동 속도 +%d%%" % pct
		"gold": return "금화 획득 +%d%%" % pct
	return t

const TALK := {
	guide = [
		"왔구나, 졸업 예정자. 마지막 시험은 저 탑이다. 흑마법사 벨로르가 꼭대기 15층에 진을 쳤지.",
		"왼손으로 걷고 오른손으로 마법을 쏴라. 오른쪽 화면을 짧게 누르고만 있으면 가까운 적을 알아서 노린다.",
		"적을 쓰러뜨리면 경험이 쌓이고, 레벨이 오를 때마다 셋 중 하나를 고를 수 있다. 한 계열을 깊게 파는 편이 대체로 강하지.",
		"주 마법 두 가지를 익히면 융합 마법을 고를 수 있다. 융합을 고르면 다른 계열은 더 배울 수 없으니 신중해라.",
		"방 구석의 보물상자도 열어 봐라. 금화나 물약, 가끔은 마법 장비가 들어 있다. 물약은 미라 교수에게서도 살 수 있고.",
		"장비는 파랑(마법), 노랑(희귀), 주황(영웅) 순으로 귀하다. 스킬 단계를 올려 주는 옵션이 붙기도 하지. 왼쪽 위 가방에서 갈아 끼워라.",
		"5층과 10층의 문지기를 쓰러뜨리면 마을로 돌아오는 푸른 문이 열린다. 쓰러지더라도 우리가 데려오겠지만, 금화 절반은 각오해라.",
		"준비가 되면 북쪽의 탑 문으로 들어가라. 들어가기 전에 첫 마법을 하나 고르게 될 거다.",
	],
	shop = ["어서 와. 필요한 걸 골라. 쓰지 않는 장비는 마을에서 가방을 열면 나한테 팔 수 있어."],
}

static func col(hex: String, a := 1.0) -> Color:
	var c = Color(hex); c.a = a; return c
