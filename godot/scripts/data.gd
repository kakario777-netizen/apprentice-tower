# 게임 데이터 — 웹 버전 DATA 그대로(수식은 함수로)
class_name D
extends RefCounted

const LAST_FLOOR := 99   # 99층 위는 옥상(ROOF) — 최종 보스
const ROOF := 100
const COW := 150         # 토끼 동산(디아블로 카우 레벨 자리) — 층 번호 대신 쓰는 표시
# 단계(디아블로 노말·나이트메어·헬): 옥상 보스를 잡으면 다음 단계가 열린다.
# 다음 단계는 1층부터 다시 오르지만 몬스터 레벨은 직전 단계 100층 바로 다음부터(층 + 100×단계).
const TIERS := [
	{name = "노말", color = "#e8e2d4"},
	{name = "나이트메어", color = "#ff9a4a"},
	{name = "헬", color = "#ff4a4a"},
]
const PRIMARY_MAX := 10
const T := 32.0
const MW := 82
const MH := 62
const BAGMAX := 12
const SLOTS := ["amulet", "weapon", "cloak", "gloves", "ring1", "ring2", "belt", "boots"]
const SLOTNAME := {amulet = "목걸이", weapon = "무기", cloak = "망토", gloves = "장갑", ring1 = "반지 1", ring2 = "반지 2", belt = "허리띠", boots = "장화"}
static func slot_name(slot: String) -> String: return "반지" if slot == "ring" else SLOTNAME.get(slot, slot)
const BAG_START := 12
const BAG_LIMIT := 42
const BAG_STEP := 6
static func bag_price(cur: int) -> int:
	var n := (cur - BAG_START) / BAG_STEP
	return [3000, 8000, 18000, 35000, 60000][min(n, 4)]

const PRIMARIES := {
	arcane = {name = "비전탄", color = "#c39bff", kind = "shot", desc = "적을 스스로 쫓아가는 마력탄. 조준이 서툴러도 잘 맞는다.", cd = .5, speed = 205, homing = 3.2, radius = 5},
	fire = {name = "화염구", color = "#ff7b34", kind = "shot", desc = "곧게 날아가 부딪히면 터지는 불덩이. 한 방이 묵직하다.", cd = .55, speed = 300, homing = 0, radius = 7},
	storm = {name = "번개", color = "#86e3ff", kind = "chain", desc = "조준한 쪽 적에게 전격을 계속 흘려보낸다. 누르는 동안 지속.", range = 230},
	frost = {name = "냉기 숨결", color = "#cdf2ff", kind = "cone", desc = "앞쪽으로 냉기를 뿜어 여러 적을 한꺼번에 느리게 만든다.", range = 138},
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
	{id = "pothp", name = "생명 물약", desc = "생명을 45% 즉시 회복", price = 400, max = 5},
	{id = "potmp", name = "마나 물약", desc = "마나를 60% 즉시 회복", price = 400, max = 5},
	{id = "scroll", name = "포탈 주문서", desc = "마을로 갔다가 그 자리로 돌아오는 포탈", price = 1200, max = 5},
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
	# 토끼 동산·괴생물 퀘스트(직접 나오지 않음: from = 999)
	rabbit = {name = "만렙 토끼", hp = 60, spd = 72, r = 16, dmg = 13, atk = "melee", xp = 26, color = "#ece6dc", from = 999, spr = "rabbit", h = 70},
	rabbit_king = {name = "만렙 토끼왕", hp = 60, spd = 66, r = 22, dmg = 13, atk = "melee", xp = 26, color = "#f0c060", from = 999, spr = "rabbit_king", h = 70},
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

# ---------------- 장비(디아블로식: 노말 · 매직 · 레어 · 세트 · 유니크) ----------------
const RAR := {
	normal = {name = "노말", color = "#e8e2d4", mods = [0, 0], mult = .8, val = .5},
	magic = {name = "매직", color = "#6f9cff", mods = [1, 2], mult = 1.0, val = 1.0},
	rare = {name = "레어", color = "#ffe066", mods = [3, 5], mult = 1.25, val = 1.9},
	set = {name = "세트", color = "#4fe06a", mods = [0, 0], mult = 1.4, val = 3.0},
	unique = {name = "유니크", color = "#d8a35a", mods = [0, 0], mult = 1.6, val = 4.0},
}
const RAR_ORDER := ["normal", "magic", "rare", "set", "unique"]
const BASES := [
	{id = "staff", slot = "weapon", names = ["참나무 지팡이", "흑단 지팡이", "뼈 지팡이", "별빛 지팡이", "용목 지팡이"], imp = {k = "dmg", v = .08}},
	{id = "wand", slot = "weapon", names = ["자작나무 완드", "수정 완드", "은 완드", "유리 완드", "달빛 완드"], imp = {k = "cast", v = .08}},
	{id = "sceptre", slot = "weapon", names = ["청동 홀", "철 홀", "은 홀", "룬 홀", "왕의 홀"], imp = {k = "cdr", v = .06}},
	{id = "ring", slot = "ring", names = ["구리 반지", "은 반지", "금 반지", "흑요석 반지", "월장석 반지"], imp = null},
	{id = "cloak", slot = "cloak", names = ["양모 망토", "가죽 망토", "비단 망토", "그림자 망토", "불사조 망토"], imp = {k = "res", v = .04}},
	{id = "robe", slot = "cloak", names = ["수습생 로브", "학자 로브", "비단 로브", "마도 로브", "대현자 로브"], imp = {k = "mp", v = 8}},
	{id = "amulet", slot = "amulet", names = ["은 목걸이", "호박 목걸이", "수정 목걸이", "별빛 목걸이", "용의 눈 목걸이"], imp = null},
	{id = "gloves", slot = "gloves", names = ["천 장갑", "가죽 장갑", "사슬 장갑", "룬 장갑", "용린 장갑"], imp = {k = "cast", v = .03}},
	{id = "belt", slot = "belt", names = ["가죽 허리띠", "징 박힌 허리띠", "은사 허리띠", "수호자 허리띠", "거인 허리띠"], imp = {k = "hp", v = 6}},
	{id = "boots", slot = "boots", names = ["천 신발", "가죽 장화", "여행자 장화", "바람 장화", "구름 장화"], imp = {k = "spd", v = .02}},
]
static func base(id: String) -> Dictionary:
	for b in BASES:
		if b.id == id: return b
	return BASES[0]
static func tier(lvl: int) -> int: return clampi(lvl / 12, 0, 4)
const PREFIX := {prim = {arcane = "비전의", fire = "불꽃의", storm = "번개의", frost = "서리의"}, hp = "튼튼한", mp = "깊은", regen = "샘솟는", dmg = "날카로운", cast = "재빠른", cdr = "명상가의", res = "단단한", spd = "바람의", gold = "욕심쟁이의", sub = "숙련된", sec = "학자의"}
# 접두사(이름 앞) · 접미사(이름 맨 앞 "~의") — 아이템 레벨이 높을수록 센 이름
const AFX := {
	dmg = {pre = true, n = ["날카로운", "예리한", "잔혹한", "파멸의", "학살자의"]},
	mp = {pre = true, n = ["푸른", "깊은", "심연의", "무한한", "별바다의"]},
	res = {pre = true, n = ["단단한", "강철", "금강", "수호자의", "철벽"]},
	gold = {pre = true, n = ["욕심쟁이의", "탐욕스러운", "황금빛", "부호의", "용의 보물"]},
	sub = {pre = true, n = ["숙련된", "능숙한", "노련한", "달인의", "대가의"]},
	sec = {pre = true, n = ["학자의", "연구자의", "교수의", "대학자의", "현자의"]},
	prim = {pre = true, n = []},
	hp = {pre = false, n = ["여우", "늑대", "곰", "거인", "티탄"]},
	regen = {pre = false, n = ["샘물", "강물", "폭포", "바다", "폭풍해"]},
	cast = {pre = false, n = ["재치", "신속", "질풍", "번개", "찰나"]},
	spd = {pre = false, n = ["사슴", "표범", "바람", "유성", "순간"]},
	cdr = {pre = false, n = ["명상", "통찰", "지혜", "현자", "시간"]},
}
static func is_pre(k: String) -> bool: return AFX.get(k.split(":")[0], {pre = true}).pre
const RARENAMES := ["황혼", "망령", "폭풍", "잿빛", "월광", "심연", "서약", "유성", "파수", "은하", "핏빛", "서리", "흑요", "천둥", "고요"]
const RARENOUN := {weapon = ["가지", "송곳", "지휘봉", "뿔", "홀"], ring = ["고리", "매듭", "눈동자", "약속"], amulet = ["부적", "목줄", "심장", "눈물"], cloak = ["장막", "날개", "외투", "그늘"],
	gloves = ["손아귀", "손길", "발톱", "주먹"], belt = ["허리끈", "사슬", "띠", "매듭"], boots = ["걸음", "발굽", "질주", "발자국"]}
# 유니크: 이름·옵션 고정(수치는 범위 안에서) · 강화 가능
const UNIQUES := [
	{name = "벼락 삼킨 가지", lv = 55, base = "staff", mods = [["prim:storm", 2, 2], ["dmg", .15, .25], ["cast", .1, .15], ["sub:chain", 1, 1]]},
	{name = "첫 불씨", lv = 50, base = "staff", mods = [["prim:fire", 2, 2], ["sub:burn", 1, 2], ["dmg", .15, .22], ["mp", 20, 35]]},
	{name = "대현자의 지팡이", lv = 65, base = "staff", mods = [["prim:arcane", 2, 2], ["sub:multi", 1, 1], ["mp", 30, 50], ["regen", .2, .3]]},
	{name = "겨울 왕의 홀", lv = 55, base = "sceptre", mods = [["prim:frost", 2, 2], ["sub:widen", 1, 1], ["cdr", .1, .15], ["res", .05, .08]]},
	{name = "속삭이는 완드", lv = 30, base = "wand", mods = [["prim:mine", 1, 1], ["cast", .15, .22], ["mp", 15, 30], ["gold", .2, .35]]},
	{name = "시간 매듭", lv = 45, base = "ring", mods = [["cdr", .12, .18], ["sec:stasis", 1, 1], ["cast", .05, .08]]},
	{name = "일곱 번째 별", lv = 1, base = "ring", mods = [["dmg", .08, .12], ["mp", 15, 25], ["gold", .2, .4]]},
	{name = "별의 심장", lv = 40, base = "amulet", mods = [["prim:mine", 1, 1], ["hp", 25, 40], ["regen", .15, .25]]},
	{name = "마녀의 눈물", lv = 35, base = "amulet", mods = [["mp", 30, 50], ["sec:freeze", 1, 1], ["dmg", .08, .12]]},
	{name = "밤의 장막", lv = 30, base = "cloak", mods = [["res", .1, .15], ["regen", .12, .2], ["sec:blink", 1, 1]]},
	{name = "불사조의 깃", lv = 45, base = "robe", mods = [["hp", 30, 50], ["prim:fire", 1, 1], ["res", .06, .1]]},
	{name = "마법사의 손길", lv = 1, base = "gloves", mods = [["cast", .1, .15], ["dmg", .06, .1], ["mp", 15, 25]]},
	{name = "얼음 손아귀", lv = 35, base = "gloves", mods = [["prim:frost", 1, 1], ["sub:harden", 1, 1], ["res", .05, .08]]},
	{name = "거신의 띠", lv = 1, base = "belt", mods = [["hp", 40, 70], ["res", .05, .08]]},
	{name = "바람 걸음", lv = 25, base = "boots", mods = [["spd", .05, .07], ["cast", .05, .08]]},
	{name = "그림자 발자국", lv = 1, base = "boots", mods = [["spd", .03, .05], ["sec:blink", 1, 1], ["res", .04, .06]]},
]
# 세트: 같은 세트를 여러 개 끼면 추가 효과(초록색)
const SETS := {
	apprentice = {name = "견습생의 유산", pieces = [
		{name = "견습생의 지팡이", base = "staff", mods = [["dmg", .1, .1], ["mp", 15, 15]]},
		{name = "견습생의 망토", base = "cloak", mods = [["res", .05, .05], ["hp", 15, 15]]},
		{name = "견습생의 반지", base = "ring", mods = [["regen", .15, .15], ["mp", 10, 10]]}],
		bonus = {2: [["mp", 30]], 3: [["dmg", .15], ["cast", .1]]}},
	phoenix = {name = "불새의 의복", pieces = [
		{name = "불새의 목걸이", base = "amulet", mods = [["hp", 20, 20], ["dmg", .06, .06]]},
		{name = "불새의 로브", base = "robe", mods = [["res", .06, .06], ["mp", 20, 20]]},
		{name = "불새의 장갑", base = "gloves", mods = [["cast", .08, .08]]},
		{name = "불새의 장화", base = "boots", mods = [["spd", .04, .04]]}],
		bonus = {2: [["prim:fire", 1]], 3: [["res", .08]], 4: [["dmg", .2], ["hp", 40]]}},
	star = {name = "별지기의 장신구", pieces = [
		{name = "별지기의 목걸이", base = "amulet", mods = [["mp", 25, 25]]},
		{name = "별지기의 반지", base = "ring", mods = [["regen", .15, .15]]},
		{name = "별지기의 허리띠", base = "belt", mods = [["hp", 25, 25], ["cdr", .05, .05]]}],
		bonus = {2: [["regen", .3]], 3: [["cdr", .15], ["sub:multi", 1]]}},
	frost = {name = "서리 군주의 갑주", pieces = [
		{name = "서리 군주의 망토", base = "cloak", mods = [["res", .08, .08], ["hp", 20, 20]]},
		{name = "서리 군주의 장갑", base = "gloves", mods = [["dmg", .06, .06]]},
		{name = "서리 군주의 장화", base = "boots", mods = [["spd", .03, .03], ["res", .03, .03]]}],
		bonus = {2: [["prim:frost", 1]], 3: [["res", .12], ["cdr", .1]]}},
}
# 강화(강화석 1개씩): 성공률은 점점 낮아짐 · 한 번 성공할 때마다 옵션 +20%, 스킬 +1
const ENH_RATE := [100, 85, 70, 55, 40, 25, 10, 8, 6, 5]
static func enh_rate(lv: int) -> int: return ENH_RATE[min(lv, ENH_RATE.size() - 1)]
const ENH_MAX := 10
static func can_enhance(it) -> bool: return it != null and (it.rar == "unique" or it.rar == "set")
static func is_skill(k: String) -> bool: return k.begins_with("prim:") or k.begins_with("sub:") or k.begins_with("sec:")
static func eff_mods(it) -> Array:
	var e: int = int(it.get("enh", 0))
	if e <= 0: return it.mods
	var out: Array = []
	for m in it.mods:
		var k: String = m.k; var v = m.v
		if is_skill(k): v = int(v) + e
		elif k == "hp" or k == "mp": v = int(round(float(v) * (1 + .2 * e)))
		elif k == "spd": v = snappedf(float(v) * (1 + .05 * e), .01)   # 이동 속도는 강화해도 조금만
		else: v = snappedf(float(v) * (1 + .2 * e), .01)
		out.append({k = k, v = v})
	return out

# 층 구성: 5층마다 보스(5 네임드 · 10 준보스 · 15 네임드 · 20 계층 보스 반복), 20층마다 분위기
static func boss_kind(f: int) -> String:
	if f == ROOF: return "final"
	if f % 20 == 0: return "tier"
	if f % 10 == 0: return "sub"
	if f % 5 == 0: return "named"
	return ""
static func theme(f: int) -> int: return clampi((f - 1) / 20, 0, 4)
const THEMES := [
	{name = "돌의 회랑", amb = Color(.46, .41, .56), tint = Color(.92, .9, 1), torch = Color(1, .6, .3), floor = "floor2", fp = "stone_tiles_02", wp = "large_sandstone_blocks"},
	{name = "이끼 낀 지하묘지", amb = Color(.36, .46, .4), tint = Color(.82, .95, .84), torch = Color(.95, .75, .4), floor = "floor", fp = "mossy_cobblestone", wp = "rock_wall_08"},
	{name = "잿불의 층", amb = Color(.52, .34, .3), tint = Color(1.0, .85, .78), torch = Color(1, .42, .18), floor = "floor2", fp = "embedded_rock_floor", wp = "castle_brick_07"},
	{name = "별빛 서고", amb = Color(.36, .38, .62), tint = Color(.82, .86, 1.08), torch = Color(.55, .7, 1), floor = "floor", fp = "herringbone_brick", wp = "medieval_blocks_03"},
	{name = "검은 첨탑", amb = Color(.42, .3, .5), tint = Color(.8, .72, .9), torch = Color(.8, .4, 1), floor = "floor2", fp = "worn_tile_floor", wp = "stone_brick_wall_001"},
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
		"왔구나, 졸업 예정자. 마지막 시험은 저 탑이다. 흑마법사 벨로르가 꼭대기 옥상에 진을 쳤지.",
		"왼손으로 걷고 오른손으로 마법을 쏴라. 오른쪽 화면을 짧게 누르고만 있으면 가까운 적을 알아서 노린다.",
		"적을 쓰러뜨리면 경험이 쌓이고, 레벨이 오를 때마다 셋 중 하나를 고를 수 있다. 한 계열을 깊게 파는 편이 대체로 강하지.",
		"주 마법 두 가지를 익히면 융합 마법을 고를 수 있다. 융합을 고르면 다른 계열은 더 배울 수 없으니 신중해라.",
		"방 구석의 보물상자도 열어 봐라. 금화나 물약, 가끔은 마법 장비가 들어 있다. 물약은 상인 미라에게서도 살 수 있고.",
		"장비는 흰색(노말), 파랑(매직), 노랑(레어), 초록(세트), 금빛(유니크) 순으로 귀하다. 세트는 여러 개를 함께 끼면 효과가 붙고, 유니크와 세트는 마을 서쪽 마법진의 강화 교수가 강화석으로 강화해 준다.",
		"포탈 주문서를 쓰면 그 자리에 마을로 가는 포탈이 열린다. 마을에 생긴 포탈로 들어가면 떠났던 자리로 그대로 돌아가지. 하나는 줄 테니, 다음부터는 상인 미라에게 사라.",
		"준비가 되면 북쪽의 탑 문으로 들어가라. 들어가기 전에 첫 마법을 하나 고르게 될 거다.",
	],
	shop = ["어서 와. 필요한 걸 골라. 쓰지 않는 장비는 '물건 판매'를 눌러 나한테 팔면 돼."],
	cow_q = [
		"마침 잘 왔다. 탑에 정체 모를 괴생물이 나타났다는 소식이다. 귀가 길고… 도끼를 들었다더군.",
		"탑 문의 웨이포인트에서 혼자 빛나는 층이 보일 거다. 그 층 끝에 녀석이 있다. 가서 처치하고 와라.",
	],
	cow_wait = ["탑 문의 웨이포인트에서 혼자 빛나는 층으로 가라. 그 층 끝에 괴생물이 있다."],
	cow_open = [
		"해치웠다고? …그런데 네가 간 사이에 마을 서쪽에 이상한 포탈이 생겼다. 붉게 일렁이는 게 영 수상해.",
		"아까 그 괴생물들이 그 너머에서 몰려온 모양이다. 들어가서 해결해라. 무리 지어 다니니 조심하고.",
	],
	cow_done = ["그 붉은 포탈은 닫히지가 않는구나. 들어갈 때마다 동산 모양이 바뀐다더군. 토끼왕은 아직 거기 있을 거다."],
	smith = ["강화석을 가져왔나? 유니크나 세트 장비라면 이 마법진 위에서 더 강하게 만들어 주지. 단계가 오를수록 성공하기 어려워지니 각오하고."],
}

static func col(hex: String, a := 1.0) -> Color:
	var c = Color(hex); c.a = a; return c
