# 게임 규칙 전부 — 웹 버전 index.html 의 상태·전투·마법·아이템·저장을 그대로 옮김(픽셀 좌표)
class_name Game
extends Node

signal toast(msg: String)
signal ui(what: String)        # "buttons" "belt" "bag" "levelup" "end" "state" "talk"
signal rumble(ms: int, strength: float)
const GOLD_RATE := .1   # 떨어지는 금화 양(예전의 1/10)
const BOSS_HP := 35.0   # 층 보스 체력 배수(20배 → 아직 약하다는 의견으로 35배. 비전탄 다중 시전 약화와 합치면 체감 4~5배)
const COW_HP := 20.0    # 토끼 동산 쪽(괴생물·토끼왕)은 그대로
signal sfx(name: String)        # 효과음
signal saved                    # 저장할 때마다(오른쪽 위 "자동 저장 중…")

const T := 32.0
const SAVE_PATH := "user://save-v1.json"   # 예전 한 칸 저장(첫 실행 때 1번 슬롯으로 옮김)
const SLOT_N := 5
static var slot := 0
static func slot_path(i: int) -> String: return "user://slot%d.json" % i
const TAU_ := TAU
const AFF := {nova = "fire", freeze = "frost", stasis = "storm", acid = "arcane"}

var G = null       # 게임 상태(웹 G)
var P = null       # 플레이어(웹 P)
var mg := MapGen.new()
var uid := 0
var inp := {mx = 0.0, my = 0.0, firing = false, ang = 0.0}
var level_changed := false   # 맵이 바뀌면 true → 화면이 다시 만든다
var shot_h := 1.3             # 화면이 알려주는 스태프 끝 높이(탄 꼬리·불꽃 높이)
var no_save := false          # 타이틀 배경용 마을일 때는 저장하지 않음

static func rnd(a: float, b: float) -> float: return a + randf() * (b - a)
static func ri(a: int, b: int) -> int: return int(floor(rnd(a, b + 1)))
static func pick(a: Array): return a[randi() % a.size()]
static func clampf_(v: float, a: float, b: float) -> float: return a if v < a else (b if v > b else v)
static func ang_diff(a: float, b: float) -> float:
	var d = fmod(a - b, TAU)
	if d > PI: d -= TAU
	if d < -PI: d += TAU
	return d
static func hyp(x: float, y: float) -> float: return sqrt(x * x + y * y)
func nid() -> int:
	uid += 1
	return uid

# ================= 상태 =================
static func xp_need(l: int) -> int: return int(round(25 * pow(l, 1.75) + 15))

func fresh_p() -> Dictionary:
	var p = {x = 0.0, y = 0.0, r = 11.0, hp = 50.0, maxhp = 50, mp = 60.0, maxmp = 60, lv = 1, xp = 0, next = xp_need(1),
		prim = {arcane = 0, fire = 0, storm = 0, frost = 0}, subs = {}, sec = {}, secOrder = [], fusion = null, active = null,
		pot = {pothp = 2, potmp = 1, scroll = 1}, potCd = 0.0, bag = [], bagMax = D.BAG_START, stones = 0, potMax = 5, name = "견습생", eq = {amulet = null, weapon = null, cloak = null, gloves = null, ring1 = null, ring2 = null, belt = null, boots = null},
		st = {}, ep = {}, es = {}, esec = {}, bonus = {prim = {}, sub = {}, sec = {}},
		vx = 0.0, vy = 0.0, cdShot = 0.0, ward = 0.0, hardenT = 0.0, inv = 0.0, slowT = 0.0, poisonT = 0.0, poisonDps = 0.0, face = -PI / 2,
		secCd = {}, speed = 150.0, firing = false, walk = 0.0, hitT = 0.0, at = 0.0, anim = "stance", tip = null}
	p["pass"] = {}
	return p

func fresh_g(diff: String) -> Dictionary:
	return {corpses = [], anims = [], debris = [], floor = 0, resume = 1, diff = diff, state = "play", enemies = [], shots = [], eshots = [], zones = [],
		fx = [], rings = [], bolts = [], drops = [], texts = [], chests = [], npcs = [], portal = null,
		gold = 0, kills = 0, banner = {text = "", t = 0.0}, pendingLv = 0, flowT = 0.0, bossMax = 0.0, time = 0.0, coneT = 0.0, talkSeen = {}, lights = [], cone = null, tier = 0, tierMax = 0, tiers = {}, cowQ = 0, cowF = 0, redPortal = null, herds = [], tev = null,
		sb = null, shake = 0.0, lvDelay = 0.0, revT = 0.0, goldPulse = 0.0, bagNew = false, nearItem = null, portalT = 0.0,
		runSeed = randi() % 1000000, waypoints = [1], killsBy = {}, shop = [], stash = null, pull = null, townRet = null, cleared = [], fcache = {}, fcacheOrder = []}

# 몬스터·드랍이 쓰는 '레벨 층': 단계마다 +100(나이트메어 1층 = 노말 101층 몬스터). 토끼 동산은 그 단계의 85층쯤
func lvf() -> int:
	if G.floor == D.COW: return 85 + 100 * int(G.tier)
	return G.floor + 100 * int(G.tier)

func tier_name(t := -1) -> String: return D.TIERS[clampi(t if t >= 0 else int(G.tier), 0, 2)].name

func diff_d() -> Dictionary:
	for d in D.DIFFICULTIES:
		if G != null and d.id == G.diff: return d
	return D.DIFFICULTIES[0]

func has_el(el: String) -> bool:
	if P.prim.get(el, 0) > 0: return true
	return P.fusion != null and el in String(P.fusion).split("+")

func recalc() -> void:
	var pv: Dictionary = P["pass"]
	var st = {hp = 0.0, mp = 0.0, regen = 0.0, dmg = 0.0, cast = 0.0, cdr = 0.0, res = 0.0, spd = 0.0, gold = 0.0}
	var bp = {}; var bs = {}; var bc = {}
	var all: Array = []; var sets = {}
	for k in D.SLOTS:
		var it = P.eq.get(k)
		if it == null: continue
		for m in D.eff_mods(it):
			if m.k == "spd" and k != "boots": continue    # 예전 장비의 이동 속도 옵션은 장화가 아니면 무시
			all.append(m)
		if it.get("set", "") != "": sets[it.set] = sets.get(it.set, 0) + 1
	for sid in sets.keys():
		var bon: Dictionary = D.SETS[sid].bonus
		for n in bon.keys():
			if sets[sid] >= int(n):
				for b in bon[n]: all.append({k = b[0], v = b[1]})
	for m in all:
		var parts: PackedStringArray = String(m.k).split(":")
		var t = parts[0]
		if t == "prim": bp[parts[1]] = bp.get(parts[1], 0) + m.v
		elif t == "sub": bs[parts[1]] = bs.get(parts[1], 0) + m.v
		elif t == "sec": bc[parts[1]] = bc.get(parts[1], 0) + m.v
		else: st[t] = st.get(t, 0.0) + m.v
	P.st = st; P.bonus = {prim = bp, sub = bs, sec = bc}
	var fus: Array = Array(String(P.fusion).split("+")) if P.fusion != null else []
	P.ep = {}
	for k in P.prim.keys():
		P.ep[k] = min(15, P.prim[k] + bp.get(k, 0)) if (P.prim[k] > 0 or k in fus) else 0
	P.es = {}
	for sd in D.SUBS:
		var b = P.subs.get(sd.id, 0) + bs.get(sd.id, 0)
		P.es[sd.id] = min(sd.max + 3, b) if (b and has_el(sd.of)) else 0
	P.esec = {}
	for sd in D.SECONDARIES:
		var l = P.sec.get(sd.id, 0)
		P.esec[sd.id] = min(sd.max + 2, l + bc.get(sd.id, 0)) if l else 0
	P.maxhp = int(round(50 + 15 * pv.get("vigor", 0) + 3 * (P.lv - 1) + st.hp))
	P.maxmp = int(round(60 + 15 * pv.get("well", 0) + 2 * (P.lv - 1) + st.mp))
	P.hp = min(P.hp, P.maxhp); P.mp = min(P.mp, P.maxmp)
	# 이동 속도 상한: 수련(가벼운 발) 최대치보다 10 빠른 정도까지만
	P.speed = min(138 * (1 + .08 * 3) + 10, 138 * (1 + .08 * pv.get("swift", 0) + st.spd))

func set_state(s: String) -> void:
	G.state = s
	ui.emit("state")

func new_game(diff: String, slot_i := -1) -> void:
	no_save = false
	if slot_i >= 0: slot = slot_i
	G = fresh_g(diff); P = fresh_p(); recalc()
	go_town(true)

func save() -> void:
	if G == null or G.sb != null or no_save: return
	var pd = {}
	for k in ["lv", "xp", "next", "prim", "subs", "sec", "secOrder", "pass", "fusion", "active", "pot", "bag", "bagMax", "eq", "stones", "name", "potMax"]: pd[k] = P[k]
	var ret: int = int(G.townRet.floor) if G.townRet != null else 0
	G.tiers[str(G.tier)] = tier_snap()
	var f = FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({v = 3, diff = G.diff, gold = G.gold, kills = G.kills, resume = G.resume, talkSeen = G.talkSeen, P = pd, floor = G.floor, runSeed = G.runSeed, waypoints = G.waypoints, killsBy = G.killsBy, retFloor = ret, cleared = G.cleared,
			tier = G.tier, tierMax = G.tierMax, tiers = G.tiers, cowQ = G.cowQ, cowF = G.cowF, at = Time.get_unix_time_from_system()}))
		f.close(); saved.emit()

static func migrate_old() -> void:
	if FileAccess.file_exists(SAVE_PATH) and not FileAccess.file_exists(slot_path(0)):
		DirAccess.rename_absolute(SAVE_PATH, slot_path(0))

static func read_slot(i: int):
	if not FileAccess.file_exists(slot_path(i)): return null
	var f = FileAccess.open(slot_path(i), FileAccess.READ)
	if f == null: return null
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else null

# 가장 최근에 저장한 슬롯(없으면 -1)
static func latest_slot() -> int:
	var best := -1; var bt := -1.0
	for i in SLOT_N:
		var d = read_slot(i)
		if d != null and float(d.get("at", 0)) > bt:
			bt = float(d.get("at", 0)); best = i
	return best

static func free_slot() -> int:
	for i in SLOT_N:
		if not FileAccess.file_exists(slot_path(i)): return i
	return -1

static func read_save():
	var i := latest_slot()
	return read_slot(i) if i >= 0 else null

static func clear_save() -> void: delete_slot(slot)
static func delete_slot(i: int) -> void:
	if FileAccess.file_exists(slot_path(i)): DirAccess.remove_absolute(slot_path(i))

func _fix_ints(d) -> void:
	# JSON 은 숫자를 실수로 돌려준다 → 단계 값은 정수로
	for k in d.keys():
		if d[k] is float: d[k] = int(d[k])

# 단계마다 따로 가는 것: 오른 층·웨이포인트·잡은 보스·있던 곳
func tier_snap() -> Dictionary:
	return {resume = G.resume, waypoints = G.waypoints.duplicate(), cleared = G.cleared.duplicate(), floor = G.floor if G.floor != D.COW else 0,
		retFloor = int(G.townRet.floor) if G.townRet != null else 0, done = G.tiers.get(str(G.tier), {}).get("done", false)}

func tier_apply(t: int, snap) -> void:
	G.tier = t
	if snap == null or not (snap is Dictionary): snap = {resume = 1, waypoints = [1], cleared = [], floor = 0, retFloor = 0}
	G.resume = int(snap.get("resume", 1)); G.waypoints = []; G.cleared = []
	for w in snap.get("waypoints", [1]): G.waypoints.append(int(w))
	for c in snap.get("cleared", []): G.cleared.append(int(c))
	var rf := int(snap.get("retFloor", 0))
	G.townRet = {floor = rf} if rf > 0 and rf != D.COW else null
	G.fcache = {}; G.fcacheOrder = []

func tier_done(t: int) -> bool: return bool(G.tiers.get(str(t), {}).get("done", false))

# 다른 단계로 갈아타기(이 단계의 진행은 저장해 두고)
func switch_tier(t: int) -> void:
	G.tiers[str(G.tier)] = tier_snap()
	tier_apply(t, G.tiers.get(str(t), null))
	G.tiers[str(t)] = tier_snap()
	P.hp = P.maxhp; P.mp = P.maxmp
	go_town(false)
	G.banner = {text = "%s · 마법학교 앞마당" % tier_name(), t = 3.0}

func load_game(sv: Dictionary, slot_i := -1, want_tier := -1) -> void:
	no_save = false
	if slot_i >= 0: slot = slot_i
	G = fresh_g(sv.diff); P = fresh_p()
	for k in sv.P.keys(): P[k] = sv.P[k]
	P.lv = int(P.lv); P.xp = int(P.xp); P.next = int(P.next)
	for k in ["prim", "subs", "sec", "pass", "pot"]: _fix_ints(P[k])
	var eq = {amulet = null, weapon = null, cloak = null, gloves = null, ring1 = null, ring2 = null, belt = null, boots = null}
	for k in P.eq.keys(): eq[k] = P.eq[k]
	P.eq = eq
	# 예전 '영웅' 등급은 유니크로
	for it in P.bag + P.eq.values():
		if it != null:
			if it.rar == "epic": it.rar = "unique"
			it.enh = int(it.get("enh", 0)); it.lvl = int(it.lvl)
	P.bagMax = int(P.get("bagMax", D.BAG_START)); P.stones = int(P.get("stones", 0)); P.potMax = int(P.get("potMax", 5)); P.name = String(P.get("name", "견습생"))
	var rf := int(sv.get("retFloor", 0))
	if rf > 0: G.townRet = {floor = rf}
	G.gold = int(sv.get("gold", 0)); G.kills = int(sv.get("kills", 0)); G.resume = int(sv.get("resume", 1)); G.talkSeen = sv.get("talkSeen", {})
	G.runSeed = int(sv.get("runSeed", G.runSeed))
	G.killsBy = sv.get("killsBy", {})
	G.cleared = []
	for c in sv.get("cleared", []): G.cleared.append(int(c))
	if not sv.has("cleared"):
		for f in range(1, int(sv.get("resume", 1))):
			if D.boss_kind(f) != "": G.cleared.append(f)
	G.waypoints = []
	for w in sv.get("waypoints", [1]): G.waypoints.append(int(w))
	G.tier = int(sv.get("tier", 0)); G.tierMax = int(sv.get("tierMax", 0)); G.cowQ = int(sv.get("cowQ", 0)); G.cowF = int(sv.get("cowF", 0))
	G.tiers = sv.get("tiers", {})
	var fl := int(sv.get("floor", 0))
	if want_tier >= 0 and want_tier != G.tier:
		# 이어하기에서 다른 단계를 골랐다: 그 단계가 있던 곳에서
		G.tiers[str(G.tier)] = tier_snap()
		var snap = G.tiers.get(str(want_tier), null)
		tier_apply(want_tier, snap)
		fl = int(snap.get("floor", 0)) if snap is Dictionary else 0
	if fl == D.COW: fl = 0                       # 토끼 동산에서 껐으면 마을에서
	if tier_done(G.tier) and want_tier >= 0: fl = 0; G.townRet = null   # 다 깬 단계는 마을에서
	recalc(); P.hp = P.maxhp; P.mp = P.maxmp
	if fl > 0:
		# 껐다 켜도 그 층에서 다시 시작(같은 시드라 같은 구조)
		G.floor = fl; gen_floor(); ui.emit("buttons"); set_state("play")
		G.banner = {text = "%d층에서 이어서" % fl, t = 2.2}
	else: go_town(false)

func clear_level() -> void:
	G.corpses = []; G.anims = []; G.debris = []; G.chests = []; G.enemies = []; G.shots = []; G.eshots = []; G.zones = []; G.drops = []; G.fx = []
	G.rings = []; G.bolts = []; G.texts = []; G.bossMax = 0.0; G.lights = []; G.cone = null; G.herds = []; G.redPortal = null

# ================= 맵 =================
func go_town(first: bool) -> void:
	G.floor = 0; G.portal = null; G.stash = null; G.pull = null
	clear_level(); mg = MapGen.new(); mg.gen_town()
	roll_shop()
	P.vx = 0.0; P.vy = 0.0; P.ward = 0.0; P.poisonT = 0.0; P.slowT = 0.0
	var t = mg.town
	G.npcs = [
		{id = "guide", name = "루멘 교수", x = t.guide.x, y = t.guide.y, trim = "#e3b04b"},
		{id = "shop", name = "상인 미라", x = t.shop.x, y = t.shop.y, trim = "#ffd27a"},
		{id = "smith", spr = "smith", name = "카엘 교수", x = t.smith.x, y = t.smith.y, trim = "#ff9a8a"},
	]
	P.x = mg.start.x; P.y = mg.start.y
	if G.townRet != null:
		# 포탈로 왔으면 마을에도 돌아가는 포탈이 서 있다(디아블로3처럼)
		var fo: Vector2 = mg.town.fountain
		G.portal = {x = fo.x - 120, y = fo.y + 96, back = true, resume = int(G.townRet.floor), born = G.time}
		if mg.hits(G.portal.x, G.portal.y, 14): G.portal.x = fo.x - 80
		if not first:
			P.x = G.portal.x; P.y = G.portal.y + 40           # 포탈에서 걸어 나온다
	if G.cowQ >= 3 and mg.town.has("redp"): G.redPortal = {x = mg.town.redp.x, y = mg.town.redp.y, born = G.time - 1.0, red = true}
	G.banner = {text = "마법학교 앞마당" if first else "마을로 돌아왔다", t = 2.4}
	P.hp = P.maxhp; P.mp = P.maxmp
	level_changed = true
	set_state("play"); ui.emit("buttons"); save()
	if first and not G.talkSeen.has("guide"):
		get_tree().create_timer(2.6).timeout.connect(func():
			if G != null and G.floor == 0 and G.state == "play": toast.emit("루멘 교수에게 말을 걸어 보세요"))

func active_list() -> Array:
	var fus = Array(String(P.fusion).split("+")) if P.fusion != null else null
	var l: Array = []
	for k in D.PRIM_ORDER:
		if P.prim[k] > 0 and (fus == null or k in fus): l.append(k)
	if P.fusion != null: l.append(P.fusion)
	return l

func enter_tower(from := 0) -> void:
	if active_list().is_empty():
		set_state("first"); return
	G.townRet = null
	G.floor = from if from > 0 else (G.resume if G.resume else 1)
	gen_floor(); ui.emit("buttons"); set_state("play"); save()

func floor_name(f: int) -> String:
	var th: Dictionary = D.THEMES[D.theme(f)]
	return "%d층 · %s" % [f, th.name] if f % 20 == 1 else "%d층" % f

# 층 상태 기억: 다녀온 층은 몬스터·상자·떨어진 물건·밝힌 지도가 그대로(껐다 켜야 새로 생김)
func stash_floor() -> void:
	if G.floor <= 0 or G.floor == D.COW or G.sb != null: return
	var main_mg = mg; var en = G.enemies; var ch = G.chests; var dr = G.drops; var co = G.corpses
	if G.stash != null:      # 테라스에 있었으면 본층 상태를 기억
		main_mg = G.stash.mg; en = G.stash.enemies; ch = G.stash.chests; dr = G.stash.drops; co = G.stash.corpses
	G.fcache[G.floor] = {mg = main_mg, enemies = en, chests = ch, drops = dr, corpses = co, portal = G.portal if G.stash == null else G.stash.portal}
	G.fcacheOrder.erase(G.floor); G.fcacheOrder.append(G.floor)
	while G.fcacheOrder.size() > 8: G.fcache.erase(G.fcacheOrder.pop_front())

func restore_floor() -> bool:
	if not G.fcache.has(G.floor): return false
	var c: Dictionary = G.fcache[G.floor]
	clear_level(); P.vx = 0.0; P.vy = 0.0; G.npcs = []; G.stash = null; G.pull = null
	mg = c.mg; G.enemies = c.enemies; G.chests = c.chests; G.drops = c.drops; G.corpses = c.corpses; G.portal = c.portal
	G.bossMax = 0.0
	for e in G.enemies:
		if e.isBoss and not e.dead: G.bossMax += e.max
	P.x = mg.start.x; P.y = mg.start.y
	mg.dirty = true; mg.reveal(P.x, P.y); mg.build_flow(P.x, P.y); level_changed = true
	G.banner = {text = floor_name(G.floor), t = 1.8}
	return true

func gen_floor() -> void:
	if G.floor == D.COW:
		gen_cow(); return
	if restore_floor(): return
	clear_level(); P.vx = 0.0; P.vy = 0.0; G.npcs = []; G.portal = null; G.stash = null; G.pull = null
	var kind := D.boss_kind(G.floor)
	seed(G.runSeed * 131 + G.floor * 7919 + int(G.tier) * 104729)
	mg = MapGen.new()
	if G.floor == D.ROOF:
		# 옥상: 탁 트인 하늘 아래 최종 보스
		mg.gen_terrace(G.floor, true)
		P.x = mg.start.x; P.y = mg.start.y
		var r0: Dictionary = mg.rooms[0]
		var fb := spawn_floor_boss("final", r0.cx, r0.cy - 40)
		G.banner = {text = "탑의 옥상 · %s" % fb.name, t = 3.4}
		randomize(); mg.build_flow(P.x, P.y); level_changed = true
		return
	mg.gen_floor(G.floor, kind != "", kind == "" and G.floor >= 2 and randf() < .4)
	if kind != "":
		var r: Dictionary = mg.rooms[0]
		P.x = mg.start.x; P.y = mg.start.y
		if G.floor in G.cleared:
			mg.open_boss_stairs(); G.banner = {text = floor_name(G.floor), t = 2.0}
		else:
			var b := spawn_floor_boss(kind, r.cx, (r.y + 5) * T)
			G.banner = {text = "%d층 · %s" % [G.floor, b.name], t = 3.0}
	else:
		P.x = mg.start.x; P.y = mg.start.y
		for i in range(1, mg.rooms.size()):
			var r: Dictionary = mg.rooms[i]
			var n: int = min(14, int(round(r.w * r.h / 24.0)) + G.floor / 3)
			var pcx: float = r.x + rnd(2, r.w - 2); var pcy: float = r.y + rnd(2, r.h - 2)
			for k in n:
				var t = pick_type(); var pack = randf() < .6
				var ex: float = (clampf_(pcx + rnd(-3, 3), r.x + 1, r.x + r.w - 1) if pack else r.x + rnd(1, r.w - 1)) * T
				var ey: float = (clampf_(pcy + rnd(-3, 3), r.y + 1, r.y + r.h - 1) if pack else r.y + rnd(1, r.h - 1)) * T
				if not mg.hits(ex, ey, D.MONSTERS[t].r) and not mg.no_spawn(ex, ey): spawn_enemy(t, ex, ey)
		# 유니크 몬스터: 한 층에 나올까 말까(4층에 1번꼴) · 많아야 한 마리
		if G.floor >= 2 and mg.rooms.size() > 1 and randf() < .25:
			for tries in 6:
				var r: Dictionary = mg.rooms[ri(1, mg.rooms.size() - 1)]
				var t2 = pick_type(); var ex2: float = (r.x + rnd(2, r.w - 2)) * T; var ey2: float = (r.y + rnd(2, r.h - 2)) * T
				if not mg.hits(ex2, ey2, D.MONSTERS[t2].r * 1.4) and not mg.no_spawn(ex2, ey2):
					spawn_elite(t2, ex2, ey2); break
		if G.cowQ == 1 and G.floor == G.cowF and mg.stairs != null: spawn_cow_quest()
		G.chests = []
		for i in range(1, mg.rooms.size()):
			var r: Dictionary = mg.rooms[i]
			if randf() > .2: continue          # 상자: 방 다섯에 하나꼴
			var cx: float = (r.x + pick([1.6, r.w - 1.6])) * T; var cy: float = (r.y + pick([1.6, r.h - 1.6])) * T
			if hyp(cx - mg.stairs.x, cy - mg.stairs.y) < 70 or mg.near_alcove(Vector2(cx, cy)) or mg.hits(cx, cy, 16) or mg.no_spawn(cx, cy): continue
			G.chests.append({x = cx, y = cy, open = false, t = 0.0, id = nid()})
			mg.obst.append({x = cx, y = cy + 2, r = 16.0})         # 상자에 부딪힘
		G.banner = {text = floor_name(G.floor), t = 2.2}
	randomize()
	# 10층마다 웨이포인트(11·21·31…층 시작 방): 열어 두면 마을 탑 문에서 바로 갈 수 있고, 마을로 돌아가는 문 역할도 한다
	if G.floor % 10 == 1 and G.floor > 1:
		if not G.floor in G.waypoints:
			G.waypoints.append(G.floor); toast.emit("웨이포인트가 열렸어요 · 마을 탑 문에서 %d층으로 바로 올 수 있어요" % G.floor)
		G.portal = {x = P.x - 70, y = P.y, resume = G.floor, way = true}
		if mg.hits(G.portal.x, G.portal.y, 14): G.portal.x = P.x + 70
	mg.reveal(P.x, P.y); mg.build_flow(P.x, P.y)
	level_changed = true

# ================= 토끼 동산(디아블로 카우 레벨) =================
func enter_cow() -> void:
	G.townRet = null; G.portal = null
	G.floor = D.COW; gen_floor(); ui.emit("buttons"); set_state("play"); save()

func _rabbit(t: String, x: float, y: float, scale := 1.0) -> Dictionary:
	var e := spawn_enemy(t, x, y, scale)
	e.spd *= rnd(.95, 1.1)
	return e

func gen_cow() -> void:
	clear_level(); P.vx = 0.0; P.vy = 0.0; G.npcs = []; G.stash = null; G.pull = null
	randomize()                                 # 들어갈 때마다 모양·왕 자리가 바뀜
	mg = MapGen.new(); mg.gen_meadow()
	P.x = mg.start.x; P.y = mg.start.y
	# 돌아가는 붉은 포탈(출발점 옆)
	G.portal = {x = P.x - 60, y = P.y - 10, resume = 0, red = true, born = G.time - 1.0}
	if mg.hits(G.portal.x, G.portal.y, 14): G.portal.x = P.x + 60
	# 무리: 여러 마리가 붙어 다닌다
	G.herds = []
	var nh := ri(9, 12)
	for h in nh:
		var c: Vector2 = mg.far_cell(mg.start, 560.0)
		var herd = {x = c.x, y = c.y, tx = c.x, ty = c.y, t = rnd(0, 4), aggro = false}
		G.herds.append(herd)
		for k in ri(6, 10):
			var off := Vector2(rnd(-60, 60), rnd(-45, 45))
			if mg.hits(c.x + off.x, c.y + off.y, 16): off = Vector2(rnd(-20, 20), rnd(-20, 20))
			var e := _rabbit("rabbit", c.x + off.x, c.y + off.y)
			e.herd = h; e.hoff = off
	# 토끼왕: 멀리 어딘가(무리 하나가 호위)
	var kc: Vector2 = mg.far_cell(mg.start, 900.0)
	var king := _rabbit("rabbit_king", kc.x, kc.y, 14.0)
	king.isBoss = true; king.named = true; boss_setup(king, "rabbit", 2.5); king.name = "만렙 토끼왕"
	king.dmg *= 2.2; king.r = 26.0; king.xp *= 20; king.hp *= COW_HP; king.max *= COW_HP
	G.bossMax = king.max
	var kh = {x = kc.x, y = kc.y, tx = kc.x, ty = kc.y, t = 99.0, aggro = false}
	G.herds.append(kh); king.herd = G.herds.size() - 1; king.hoff = Vector2.ZERO
	for k in 8:
		var a := k * TAU / 8; var off := Vector2(cos(a) * 70, sin(a) * 52)
		var e := _rabbit("rabbit", kc.x + off.x, kc.y + off.y); e.herd = king.herd; e.hoff = off
	G.banner = {text = "토끼 동산 · %s" % tier_name(), t = 3.0}
	mg.build_flow(P.x, P.y); level_changed = true

# 괴생물 퀘스트: 그 층 끝(계단 앞)에 서 있는 만렙 토끼. 그 단계 옥상 흑마법사보다 조금 약하게
func spawn_cow_quest() -> void:
	var st = mg.stairs
	var x: float = st.x; var y: float = st.y + 70
	if mg.hits(x, y, 24): y = st.y + 40
	var e := spawn_enemy("rabbit", x, y, 1.0)
	var lf100: int = 100 + 100 * int(G.tier)
	var bd: Dictionary = D.BOSSES[15]
	var hp: float = bd.hp * diff_d().hp * (1 + .25 * (lf100 - 1)) / (1 + .25 * 14) * .8 * COW_HP
	e.hp = hp; e.max = hp
	e.dmg = bd.dmg * diff_d().dmg * (1 + .1 * (lf100 - 1)) / (1 + .1 * 14) * .8
	e.xp = int(120 * (1 + .3 * (lf100 - 5) / 5.0) * .6)
	e.isBoss = true; e.named = true; boss_setup(e, "rabbit", 2.0); e.cowq = true; e.r = 22.0; e.spd *= 1.1
	e.name = "정체 모를 괴생물 · 만렙 토끼"; e.tint = "#ffd8d0"
	G.bossMax += e.max

# 루멘 교수: 노말을 깬 뒤 괴생물 퀘스트 → 토끼 동산
func cow_talk_key() -> String:
	if int(G.tierMax) < 1: return ""
	match int(G.cowQ):
		0: return "cow_q"
		1: return "cow_wait"
		2: return "cow_open"
		_: return "cow_done"

func cow_talk_done(key: String) -> void:
	if key == "cow_q":
		G.cowQ = 1
		var f := 0
		while f == 0 or D.boss_kind(f) != "" or f % 10 == 1: f = ri(3, 96)
		G.cowF = f
		toast.emit("탑 문 웨이포인트에 빛나는 %d층이 생겼어요" % f)
	elif key == "cow_open":
		G.cowQ = 3
		G.redPortal = {x = mg.town.redp.x, y = mg.town.redp.y, born = G.time, red = true}
		toast.emit("마을 서쪽에 붉은 포탈이 열렸어요")
	save()

const NAMED_PRE := ["피에 굶주린", "썩은 왕관의", "검은 안개의", "울부짖는", "저주받은", "뼈를 씹는", "불타는 눈의", "굶주린 그림자"]

# 층 보스: 네임드(강화된 일반 몬스터) · 준보스 · 계층 보스 · 최종
func spawn_floor_boss(kind: String, x: float, y: float) -> Dictionary:
	var f: int = G.floor
	if kind == "named":
		var t := pick_type()
		var e := spawn_enemy(t, x, y, 9.0)
		e.isBoss = true; e.named = true; e.split = false; e.name = "%s %s" % [pick(NAMED_PRE), D.MONSTERS[t].name]
		e.hp *= BOSS_HP; e.max *= BOSS_HP
		e.r *= 1.35; e.dmg *= 1.8; e.xp *= 12; e.aggro = true; e.t1 = 3.0; e.spd *= 1.15
		boss_setup(e, "melee" if D.MONSTERS[t].atk == "melee" else "ranged", 1.0 + f / 100.0)
		G.bossMax += e.max
		return e
	var bd: Dictionary
	var base_f := 5
	if kind == "final": bd = D.BOSSES[15]; base_f = 15
	elif kind == "tier":
		bd = [D.BOSSES[5], D.BOSSES[10], D.BOSSES[15]][(f / 20 - 1) % 3]; base_f = [5, 10, 15][(f / 20 - 1) % 3]
	else:
		var k: int = pick([5, 10]); bd = D.BOSSES[k]; base_f = k
	var lf: int = lvf()
	var hm: float = (1 + .25 * (lf - 1)) / (1 + .25 * (base_f - 1)) * (1.5 if kind == "tier" else 1.0)
	var dm: float = (1 + .1 * (lf - 1)) / (1 + .1 * (base_f - 1))
	var b := spawn_boss(bd, x, y, bd.hp * diff_d().hp * hm * BOSS_HP)
	b.split = false; b.dmg *= dm; b.shield *= hm; b.shieldMax *= hm
	b.xp = int(120 * (1 + .3 * (lf - 5) / 5.0))
	if kind == "tier": b.name = "%s · 계층 수호자" % bd.name
	elif kind == "sub": b.name = "%s의 그림자" % bd.name if f > base_f else bd.name
	# 패턴 세기: 10·30층 준보스 < 20·40·60·80층 계층 수호자(층이 오를수록 더) < 옥상 최종
	var lvl: float = 1.2 + f / 100.0
	if kind == "tier": lvl = 1.8 + f / 50.0
	if kind == "final": lvl = 3.6
	boss_setup(b, "final" if kind == "final" else String(bd.id), lvl)
	return b

# 유니크 몬스터: 체력 5~10배 · 공격 2~3배 · 큰 몸집 · 다른 색 · 빛 · 고유 이름
const ELITE_A := ["뼈", "피", "재", "서리", "독", "그림자", "천둥", "녹슨", "검은", "울음"]
const ELITE_B := ["송곳니", "갈퀴", "발톱", "아귀", "눈", "칼날", "뿔", "이빨"]
const ELITE_COL := ["#ffd76a", "#ff7a6a", "#8affc8", "#c08aff", "#7ad8ff", "#ff9ae0"]
func spawn_elite(t: String, x: float, y: float) -> Dictionary:
	# 네임드(유니크): 체력 7배 더(35~70배) · 빠르고 아프게 · 돌진·내려찍기·베기 패턴
	var e := spawn_enemy(t, x, y, rnd(5, 10) * 7.0)
	e.elite = true; e.split = false; e.aggro = false
	e.name = "%s%s %s" % [pick(ELITE_A), pick(ELITE_B), D.MONSTERS[t].name]
	e.r *= 1.3; e.hmul = 1.45; e.dmg *= rnd(2.6, 3.4); e.xp = int(e.xp * 20); e.spd *= 1.35
	e.cd = e.cd * .55; e.tint = pick(ELITE_COL)
	boss_setup(e, "elite", .9 + G.floor / 120.0)
	return e

func drop_stone(x: float, y: float, n: int) -> void:
	for i in n: G.drops.append({id = nid(), x = x, y = y, kind = "stone", t = 0.0, vx = rnd(-70, 70), vy = rnd(-70, 70), h = 0.0, vh = rnd(110, 160)})
	toast.emit("강화석이 떨어졌다!")

func pick_type() -> String:
	var pool: Array = []
	for k in D.MONSTERS.keys():
		if D.MONSTERS[k].from <= G.floor: pool.append(k)
	var tot = 0.0; var ws: Array = []
	for k in pool:
		var w = 1.0 / (1 + .35 * (D.MONSTERS[k].from - 1)); tot += w; ws.append(w)
	var r = randf() * tot
	for i in pool.size():
		r -= ws[i]
		if r <= 0: return pool[i]
	return pool[0]

# ================= 적 =================
func spawn_enemy(type: String, x: float, y: float, scale := 1.0) -> Dictionary:
	# 층 + 내 레벨(아주 조금: 레벨당 생명 +3%·피해 +2%)
	var lf: int = lvf()
	var d: Dictionary = D.MONSTERS[type]; var f: float = (1 + .25 * (lf - 1)) * diff_d().hp * (1 + .03 * (P.lv - 1))
	var e = {id = nid(), type = type, d = d, x = x, y = y, r = float(d.r), hp = d.hp * f * scale, max = d.hp * f * scale, spd = d.spd * .92 * rnd(.9, 1.1),
		vx = 0.0, vy = 0.0, dmg = d.dmg * (1 + .1 * (lf - 1)) * diff_d().dmg * (1 + .02 * (P.lv - 1)), xp = int(round(d.xp * (1 + .3 * (lf - 1)))),
		cd = rnd(.6, d.get("cd", 1)), atkCd = 0.0, shield = d.get("shield", 0) * f, shieldMax = d.get("shield", 0) * f,
		slowT = 0.0, frozenT = 0.0, fearT = 0.0, burnT = 0.0, burnDps = 0.0, aggro = false, flash = 0.0, wob = randf() * TAU, side = 1 if randf() < .5 else -1,
		dead = false, isBoss = false, boss = "", atkT = 0.0, hitT = 0.0, at = 0.0, anim = "stance"}
	if type == "mage": e.orb = "ice" if randf() < .5 else "poison"
	G.enemies.append(e); return e

func spawn_boss(bd: Dictionary, x: float, y: float, hp_override := 0.0, r := 0.0) -> Dictionary:
	var bh: float = hp_override if hp_override > 0 else bd.hp * diff_d().hp
	var e = {id = nid(), type = "boss", boss = bd.id, name = bd.name, isBoss = true, d = {color = bd.color, undead = 1 if bd.id == "golem" else 0, atk = "melee"},
		x = x, y = y, r = r if r > 0 else float(bd.r), hp = bh, max = bh, spd = float(bd.spd), dmg = bd.dmg * diff_d().dmg, xp = 40 if (bd.id == "flesh" and hp_override > 0) else 120,
		shield = float(bd.get("shield", 0)), shieldMax = float(bd.get("shield", 0)), shieldRegen = 0.0, cd = 2.0, atkCd = 0.0, t1 = 2.0, t2 = 4.0, t3 = 6.0,
		slowT = 0.0, frozenT = 0.0, fearT = 0.0, burnT = 0.0, burnDps = 0.0, aggro = true, flash = 0.0, wob = 0.0, side = 1, split = hp_override > 0,
		vx = 0.0, vy = 0.0, dead = false, atkT = 0.0, hitT = 0.0, at = 0.0, anim = "stance"}
	G.enemies.append(e); G.bossMax += e.max; return e

static func spr_name(e: Dictionary) -> String:
	if e.isBoss and e.boss != "": return D.BOSSMAP[e.boss]
	return e.d.get("spr", D.SPRMAP.get(e.type, "skel"))

static func enemy_h(e: Dictionary) -> float:
	if e.boss == "flesh": return e.r * 1.9
	var base: float = float(e.d.get("h", D.SPRH.get(e.type, 46))) if not (e.isBoss and e.boss != "") else float(D.SPRH.get(e.boss, 46))
	return base * (1.5 if e.get("named", false) else float(e.get("hmul", 1.0)))

static func anim_dur(name: String, anim: String) -> float:
	var m: Dictionary = Actor.meta().get(name, {})
	if m.has("anims") and m.anims.has(anim): return m.anims[anim].dur / 1000.0
	return .4

func damage_enemy(e: Dictionary, amt: float, els, silent := false) -> void:
	if e.dead or amt <= 0: return
	if e.get("seal", false):
		# 봉인(무적) 중: 피해 없음
		if randf() < .15: float_text(e.x, e.y - e.r, "무적", "#c9a3ff")
		return
	if e.shield > 0:
		var a: float = min(e.shield, amt); e.shield -= a; amt -= a; e.shieldRegen = 7.0
		if e.shield <= 0: ring(e.x, e.y, e.r, e.r + 24, .3, "#9fd0ff")
	e.hp -= amt; e.flash = .08; e.aggro = true
	if e.atkT <= 0: e.hitT = min(.22, anim_dur(spr_name(e), "hit"))
	if els != null:
		if els.has("fire") and P.es.burn:
			e.burnT = 2.0 + P.es.burn; e.burnDps = max(e.burnDps, 3 * P.es.burn * (1 + .15 * P.lv))
		if els.has("frost"):
			e.slowT = max(e.slowT, 1.2); e.chillT = max(float(e.get("chillT", 0.0)), 1.3)
		if els.has("storm") and P.es.shock: e.slowT = max(e.slowT, .4 + .3 * P.es.shock)
	if not silent and amt >= 1: float_text(e.x, e.y - e.r, str(int(round(amt))), "#f3e3c0")
	if e.boss == "flesh" and not e.split and e.hp < e.max * .5 and e.hp > 0:
		split_flesh(e); return
	if e.hp <= 0: kill_enemy(e)

func split_flesh(e: Dictionary) -> void:
	e.dead = true; burst(e.x, e.y, "#c46f80", 30, 180, .7, 4); G.bossMax -= e.max
	var bd: Dictionary = D.BOSSES[10]
	for s in [-1, 1]:
		var c = spawn_boss(bd, e.x + s * 36, e.y, max(60.0, e.hp * .65), 24.0); c.t1 = 1.5 + s * .4
		c.dmg = e.dmg; boss_setup(c, "flesh", max(1.0, float(e.get("lvl", 1.2)) - .3)); c.pt = 1.0 + s * .8
	toast.emit("여왕 개미귀신이 둘로 갈라졌다!")

func debris(x: float, y: float, shape: String, color: String, n := 1, sp := 120.0) -> void:
	for i in n:
		var a = rnd(0, TAU); var v = rnd(30, sp)
		G.debris.append({x = x, y = y, h = 6.0, vh = rnd(60, 150), vx = cos(a) * v, vy = sin(a) * v * .7, rot = rnd(0, TAU), vr = rnd(-12, 12), life = 5.0, shape = shape, color = color, s = rnd(1.6, 3.2)})
	if G.debris.size() > 160: G.debris = G.debris.slice(G.debris.size() - 160)

func fx_anim(name: String, x: float, y: float, size: float, life := 0.0, rot := 0.0, h := -1.0) -> void:
	if not Actor.meta().has(name): return
	var a = {name = name, x = x, y = y, size = size, t = 0.0, life = life if life > 0 else anim_dur(name, "idle"), rot = rot}
	if h >= 0: a.h = h
	G.anims.append(a)
	if G.anims.size() > 60: G.anims.pop_front()

func smoke(x: float, y: float, n: int, c := "#2a2430") -> void:
	for i in n:
		G.fx.append({x = x + rnd(-8, 8), y = y + rnd(-8, 8), vx = rnd(-20, 20), vy = rnd(-40, -10), life = rnd(.7, 1.2), max = 1.2, color = c, size = rnd(4, 8), smoke = 1})

func kill_enemy(e: Dictionary) -> void:
	if e.dead: return
	e.dead = true; G.kills += 1
	sfx.emit("roar" if (e.isBoss or e.get("elite", false)) else "die")
	var kk: String = e.name if e.isBoss else e.type
	G.killsBy[kk] = G.killsBy.get(kk, 0) + 1
	var nm = spr_name(e)
	var corpse = false
	if Actor.meta().has(nm) and Actor.meta()[nm].anims.has("die"):
		G.corpses.append({id = nid(), name = nm, x = e.x, y = e.y, ang = atan2(P.y - e.y, P.x - e.x), t = 0.0, H = enemy_h(e)})
		if G.corpses.size() > 40: G.corpses.pop_front()
		corpse = true
	if corpse:
		if e.type == "demon" or e.type == "imp": smoke(e.x, e.y, 6, "#3a2020")
	elif e.type in ["skel", "archer", "mage"]:
		debris(e.x, e.y, "bone", "#d8ccb2", 5); debris(e.x, e.y, "skull", "#e6dcc8", 1)
	if e.type == "imp" or e.type == "demon":
		burst(e.x, e.y, "#ffb050", 22 if e.type == "demon" else 8, 160, .6, 2)
	elif e.type == "shade":
		for i in 10: G.fx.append({x = e.x + rnd(-8, 8), y = e.y, vx = rnd(-15, 15), vy = -rnd(30, 70), life = 1.0, max = 1.0, color = "#9a7acc", size = rnd(2, 4)})
	elif e.isBoss:
		debris(e.x, e.y, "blob", e.d.color, 20, 200); smoke(e.x, e.y, 16)
	burst(e.x, e.y, e.d.color, 40 if e.isBoss else 12, 220 if e.isBoss else 120, .5, 3)
	gain_xp(e.xp)
	if e.d.has("split"):
		for i in 3:
			var a = i / 3.0 * TAU; var ix: float = e.x + cos(a) * 14; var iy: float = e.y + sin(a) * 14
			if mg.hits(ix, iy, 8):
				ix = e.x; iy = e.y
			var im = spawn_enemy(e.d.split, ix, iy, .8); im.aggro = true; im.xp = 1
	var roll = randf()
	if roll < .10: G.drops.append({x = e.x, y = e.y, kind = "hp", t = 0.0, id = nid()})
	elif roll < .25: G.drops.append({x = e.x, y = e.y, kind = "mp", t = 0.0, id = nid()})
	if randf() < .5 or e.isBoss:
		G.drops.append({x = e.x + rnd(-8, 8), y = e.y + rnd(-8, 8), kind = "gold", v = max(1, int(round((300 + lvf() * 30 if e.isBoss else (ri(2, 6) + lvf()) * 4) * diff_d().reward * (1 + P.st.gold) * GOLD_RATE))), t = 0.0, vx = rnd(-90, 90), vy = rnd(-90, 90), h = 0.0, vh = rnd(70, 120), id = nid()})
	if not e.isBoss and lvf() >= 20 and randf() < (.006 if lvf() >= 50 else .003): drop_stone(e.x, e.y, 1)
	# 한 층을 다 돌아야 3~4개 주울까 말까
	var ip: float = (.022 if (e.type == "demon" or e.type == "mage") else .013) * (.7 if lvf() < 5 else 1.0)
	if not e.isBoss and not e.get("elite", false) and e.xp > 1 and randf() < ip: drop_item(e.x, e.y)
	if e.get("elite", false):
		# 유니크 몬스터: 장비 1~2개(좋은 등급 쪽으로) + 낮은 확률로 강화석
		drop_item(e.x - 8, e.y, roll_rarity(3.0 if lvf() >= 5 else 1.0, "magic"))
		if lvf() >= 5 and randf() < .2: drop_item(e.x + 8, e.y, "", 2.0)
		var ep: float = .08 if lvf() < 10 else (.3 if lvf() < 30 else .45)
		if randf() < ep: drop_stone(e.x, e.y, 2 if (lvf() >= 40 and randf() < .2) else 1)
	if e.get("cowq", false):
		# 괴생물(만렙 토끼) 처치 → 마을로 가는 포탈
		G.cowQ = 2; G.eshots = []
		G.portal = {x = e.x, y = e.y - 10, resume = G.floor, born = G.time}
		if mg.hits(G.portal.x, G.portal.y, 14): G.portal = {x = P.x, y = P.y - 50, resume = G.floor, born = G.time}
		G.banner = {text = "괴생물을 처치했다! 포탈이 열렸다", t = 3.0}
		toast.emit("마을로 돌아가 루멘 교수에게 알려 주세요")
		for i in 2: drop_item(e.x + rnd(-14, 14), e.y + rnd(-6, 6), roll_rarity(5.0, "magic"))
		save(); return
	if e.type == "rabbit_king":
		G.eshots = []
		G.banner = {text = "토끼왕을 쓰러뜨렸다! · 토끼 동산 정복", t = 3.4}
		# 왕의 드랍은 80층 보스 수준
		var f80: int = 80 + 100 * int(G.tier)
		for i in 3:
			if i < 2 or randf() < .5: drop_item(e.x + rnd(-16, 16), e.y + rnd(-8, 8), roll_rarity(5.0, "magic", f80))
		if randf() < .6: drop_stone(e.x, e.y + 10, ri(1, 2))
		return
	var boss_loot: bool = e.isBoss and (not e.split or not _other_boss_alive(e))
	if boss_loot:
		var fin: bool = G.floor == D.ROOF
		drop_item(e.x - 10, e.y, "unique" if fin else roll_rarity(5.0, "magic"))
		if randf() < .5: drop_item(e.x + 10, e.y, "", 2.5)
		# 강화석: 초반엔 귀하게, 30층부터는 보스가 거의 항상 1~3개
		if lvf() < 10:
			if randf() < .3: drop_stone(e.x, e.y + 10, 1)
		elif lvf() < 30:
			if randf() < .8: drop_stone(e.x, e.y + 10, ri(1, 2))
		else: drop_stone(e.x, e.y + 10, ri(1, 3))
	if e.isBoss and G.floor != D.COW and not _other_boss_alive(null): boss_cleared()

func _other_boss_alive(ex) -> bool:
	for o in G.enemies:
		if o.isBoss and not o.dead and (ex == null or not is_same(o, ex)): return true
	return false

func boss_cleared() -> void:
	var r: Dictionary = mg.rooms[0]
	if G.floor == D.ROOF:
		G.eshots = []
		for e in G.enemies:
			if not e.dead: kill_enemy(e)
		G.banner = {text = "흑마법사를 쓰러뜨렸다!", t = 3.0}
		var snap := tier_snap(); snap.done = true; G.tiers[str(G.tier)] = snap
		if int(G.tier) >= int(G.tierMax) and G.tierMax < 2: G.tierMax = int(G.tier) + 1
		save()
		get_tree().create_timer(3.0).timeout.connect(func(): game_over(true))
		return
	if not G.floor in G.cleared: G.cleared.append(G.floor)
	mg.open_boss_stairs(); level_changed = true
	if G.floor < D.LAST_FLOOR and G.floor % 10 == 0: G.portal = {x = r.cx - 70, y = r.cy, resume = G.floor + 1}
	G.eshots = []
	for e in G.enemies:
		if not e.dead: kill_enemy(e)
	G.banner = {text = "보스 격파! 계단이 열렸다", t = 3.0}
	G.drops.append({x = r.cx + 30, y = r.cy, kind = "hp", t = 0.0, id = nid()})
	G.drops.append({x = r.cx - 30, y = r.cy, kind = "mp", t = 0.0, id = nid()})

func enemy_shot(e: Dictionary, kind: String, ang: float, speed: float, extra := {}) -> void:
	var s = {x = e.x + cos(ang) * e.r, y = e.y + sin(ang) * e.r, vx = cos(ang) * speed, vy = sin(ang) * speed, dmg = e.dmg, r = 5.0, life = 4.0, kind = kind, homing = 0.0, blast = 0.0, id = nid()}
	for k in extra.keys(): s[k] = extra[k]
	G.eshots.append(s)

func enemy_fire(e: Dictionary) -> void:
	var a = atan2(P.y - e.y, P.x - e.x); e.atkT = anim_dur(spr_name(e), "attack")
	sfx.emit("arrow" if e.d.atk == "arrow" else "eorb")
	match e.d.atk:
		"arrow": enemy_shot(e, "arrow", a + rnd(-.05, .05), 270, {r = 4.0, life = 2.0})
		"orb": enemy_shot(e, e.d.get("orb", e.get("orb", "ice")), a, 130, {r = 7.0, homing = 1.6, life = 5.0})
		"fireball": enemy_shot(e, "fire", a, 190, {r = 9.0, life = 3.0, blast = float(e.d.get("blast", 45))})
		"skull": enemy_shot(e, "skull", a, 150, {r = 8.0, homing = 2.0, life = 5.0})

func boss_ai(e: Dictionary, dt: float, d: float) -> void:
	e.t1 -= dt; e.t2 -= dt; e.t3 -= dt
	if e.shieldMax:
		e.shieldRegen -= dt
		if e.shield <= 0 and e.shieldRegen <= -2:
			e.shield = e.shieldMax * .4; ring(e.x, e.y, e.r, e.r + 30, .4, "#c9a3ff")
	if e.has("pk"): return
	if e.boss == "golem":
		if e.t1 <= 0:
			e.t1 = 6.0
			for i in 3:
				var a = rnd(0, TAU); var s = spawn_enemy(pick(["skel", "skel", "archer"]), e.x + cos(a) * 60, e.y + sin(a) * 60); s.aggro = true; s.xp = 1
			ring(e.x, e.y, 10, 70, .5, "#e6dcc4")
		if e.t2 <= 0 and d < 260:
			e.t2 = 4.5; G.zones.append({kind = "warn", x = e.x, y = e.y, r = 120.0, life = .9, max = .9, dmg = e.dmg * 1.3})
	elif e.boss == "flesh":
		if e.t1 <= 0:
			e.t1 = 2.6 if e.split else 2.2
			var a = atan2(P.y - e.y, P.x - e.x); var n = 3 if e.split else 5
			for i in n: enemy_shot(e, "spit", a + (i - (n - 1) / 2.0) * .22, 170, {r = 7.0, dmg = e.dmg * .6, life = 3.0})
		if not e.split and e.t2 <= 0:
			e.t2 = 7.0
			for i in 2:
				var s = spawn_enemy("zombie", e.x + rnd(-50, 50), e.y + rnd(30, 60)); s.aggro = true; s.xp = 1
	elif e.boss == "warlock":
		if e.t1 <= 0:
			e.t1 = 2.8
			for i in 3:
				var a = atan2(P.y - e.y, P.x - e.x) + (i - 1) * .6
				enemy_shot(e, "skull", a, 150, {r = 9.0, homing = 2.2, life = 5.0, dmg = e.dmg * .7})
		if e.t2 <= 0:
			e.t2 = 8.0
			for i in 3:
				var t: String = pick(["imp", "imp", "skel", "mage"]); var s = spawn_enemy(t, e.x + rnd(-70, 70), e.y + rnd(-40, 40)); s.aggro = true; s.xp = 1
			ring(e.x, e.y, 10, 80, .5, "#8a4be0")
		if e.t3 <= 0:
			e.t3 = 6.0; var r: Dictionary = mg.rooms[0]
			for k in 12:
				var nx: float = (r.x + rnd(2, r.w - 2)) * T; var ny: float = (r.y + rnd(2, r.h - 2)) * T
				if not mg.hits(nx, ny, e.r) and hyp(nx - P.x, ny - P.y) > 200:
					burst(e.x, e.y, "#8a4be0", 16, 140, .4, 3); e.x = nx; e.y = ny; burst(nx, ny, "#8a4be0", 16, 140, .4, 3); break

func upd_enemy(e: Dictionary, dt: float) -> void:
	e.flash = max(0.0, e.flash - dt); e.wob += dt * 6; e.atkCd -= dt
	if e.burnT > 0:
		e.burnT -= dt
		if randf() < dt * 8: G.fx.append({x = e.x + rnd(-e.r, e.r) * .6, y = e.y, vx = 0.0, vy = -40.0, life = .4, max = .4, color = "#ff8a3a", size = 2.0})
		damage_enemy(e, e.burnDps * dt, null, true)
		if e.dead: return
	if e.frozenT > 0:
		e.frozenT -= dt; e.vx = 0.0; e.vy = 0.0; return
	e.slowT -= dt; e.fearT -= dt
	if e.has("chillT"): e.chillT -= dt
	if e.has("pk") and e.aggro and not e.dead:
		if boss_pat(e, dt): return
	if e.get("slam", false):
		e.t2 -= dt
		if e.t2 <= 0 and e.aggro and hyp(P.x - e.x, P.y - e.y) < 150:
			e.t2 = rnd(3.5, 5.0); G.zones.append({kind = "warn", x = e.x, y = e.y, r = 95.0, life = .9, max = .9, dmg = e.dmg * 1.2})
	elif e.get("named", false):
		e.t1 -= dt
		if e.t1 <= 0:
			e.t1 = 11.0; ring(e.x, e.y, 10, 70, .5, e.d.color)
			for i in 2:
				var a = rnd(0, TAU); var s = spawn_enemy(e.type, e.x + cos(a) * 50, e.y + sin(a) * 50); s.aggro = true; s.xp = 1
	var dx: float = P.x - e.x; var dy: float = P.y - e.y; var d: float = max(1.0, hyp(dx, dy))
	if e.has("herd") and int(e.herd) < G.herds.size():
		var hd: Dictionary = G.herds[e.herd]
		if e.aggro: hd.aggro = true
		elif hd.aggro: e.aggro = true
		elif (d < 330 and mg.los(e.x, e.y, P.x, P.y)) or d < 160:
			e.aggro = true; hd.aggro = true
		else:
			var gx0: float = hd.x + e.hoff.x - e.x; var gy0: float = hd.y + e.hoff.y - e.y; var gl0 := hyp(gx0, gy0)
			var tv := Vector2.ZERO
			if gl0 > 6: tv = Vector2(gx0, gy0) / gl0 * min(e.spd * .45, gl0 * 2.0)
			var k0 = 1.0 - exp(-3.0 * dt)
			e.vx += (tv.x - e.vx) * k0; e.vy += (tv.y - e.vy) * k0; mg.move(e, e.vx * dt, e.vy * dt)
			return
	if not e.aggro:
		if (d < 360 and mg.los(e.x, e.y, P.x, P.y)) or d < 150: e.aggro = true
		elif e.get("wander", false):
			# 혼자 어슬렁: 가끔 새 자리를 골라 천천히 걸어감
			e.wt -= dt
			if e.wt <= 0 or hyp(e.wx - e.x, e.wy - e.y) < 8:
				e.wt = rnd(2.5, 5.0)
				var a := rnd(0, TAU); var nx: float = e.x + cos(a) * rnd(60, 160); var ny: float = e.y + sin(a) * rnd(60, 160)
				if not mg.hits(nx, ny, e.r): e.wx = nx; e.wy = ny
			var gx0: float = e.wx - e.x; var gy0: float = e.wy - e.y; var gl0 := hyp(gx0, gy0)
			var tv := Vector2.ZERO
			if gl0 > 4: tv = Vector2(gx0, gy0) / gl0 * e.spd * .4
			var k0 = 1.0 - exp(-3.0 * dt)
			e.vx += (tv.x - e.vx) * k0; e.vy += (tv.y - e.vy) * k0; mg.move(e, e.vx * dt, e.vy * dt)
			return
		else: return
	var sp: float = e.spd * (.4 if e.get("chillT", 0.0) > 0 else (.5 if e.slowT > 0 else 1.0)) * (.35 if in_stasis(e) else 1.0)
	var goal: Vector2
	var see: bool = d < 520 and mg.los(e.x, e.y, P.x, P.y)
	if e.fearT > 0: goal = Vector2(e.x - dx, e.y - dy)
	elif e.isBoss and not e.get("named", false):
		boss_ai(e, dt, d)
		if e.dead: return
		if e.boss == "warlock":
			goal = Vector2(e.x - dx, e.y - dy) if d < 220 else (Vector2(P.x, P.y) if d > 320 else Vector2(e.x - dy * e.side, e.y + dx * e.side))
			sp *= .55
		else: goal = Vector2(P.x, P.y)
	elif e.d.atk != "melee" and see and d < e.d.range:
		e.cd -= dt * (.6 if e.get("chillT", 0.0) > 0 else 1.0)       # 얼어 둔해지면 쏘는 것도 느려짐
		if e.cd <= 0:
			enemy_fire(e); e.cd = e.d.cd * rnd(.8, 1.2)
		if d < e.d.range * .45: goal = Vector2(e.x - dx, e.y - dy)
		else:
			if randf() < dt * .4: e.side *= -1
			goal = Vector2(e.x - dy * e.side, e.y + dx * e.side); sp *= .6
	else:
		goal = Vector2(P.x, P.y) if (see and d < 240) else mg.step_toward(e.x, e.y, P.x, P.y)
		if e.d.has("erratic"):
			var w = sin(G.time * 5 + e.wob) * .9
			goal = Vector2(goal.x + (-(goal.y - e.y)) * w, goal.y + (goal.x - e.x) * w)
			if d < 40 and e.atkCd > .3: goal = Vector2(e.x - dx, e.y - dy)
	var gx: float = goal.x - e.x; var gy: float = goal.y - e.y; var gl = hyp(gx, gy)
	var tvx = 0.0; var tvy = 0.0
	if gl > 1 and not (e.d.atk == "melee" and d < e.r + P.r):
		tvx = gx / gl * sp; tvy = gy / gl * sp
	var ka = 1.0 - exp(-(3.0 if e.isBoss else 4.5) * dt)
	e.vx += (tvx - e.vx) * ka; e.vy += (tvy - e.vy) * ka; mg.move(e, e.vx * dt, e.vy * dt)
	if d < e.r + P.r + 4 and e.atkCd <= 0 and e.fearT <= 0:
		hurt_player(e.dmg); e.atkCd = 1.0; e.atkT = anim_dur(spr_name(e), "attack")
		match e.d.get("onhit", ""):
			"poison":
				P.poisonT = 4.0; P.poisonDps = max(P.poisonDps, e.dmg * .4)
			"slow": P.slowT = 1.2

func in_stasis(o: Dictionary) -> bool:
	for z in G.zones:
		if z.kind == "stasis" and hyp(o.x - z.x, o.y - z.y) < z.r: return true
	return false

# ================= 플레이어 공격 =================
# 레벨이 오를 때마다 공격 마법 기본 피해 +1~2(번갈아): 탄 한 발당 / 지속형은 초당 3배
func lv_bonus() -> float: return floor(1.5 * (P.lv - 1))

func attack_of(id: String) -> Dictionary:
	var lvb: float = lv_bonus()
	var L: Dictionary = P.ep; var might: float = (1 + .12 * P["pass"].get("might", 0)) * (1 + P.st.dmg); var thrift: float = 1 - .1 * P["pass"].get("thrift", 0)
	if D.PRIMARIES.has(id):
		var d: Dictionary = D.PRIMARIES[id]; var l: float = L.get(id, 0)
		var a = {id = id, kind = d.kind, color = d.color, els = {id: true}, name = d.name}
		if d.kind == "shot":
			var dm = D.prim_dmg(id, l)
			a.dmg = [(dm[0] + lvb) * might, (dm[1] + lvb) * might]; a.mana = D.prim_mana(id, l) * thrift; a.cd = d.cd; a.speed = float(d.speed); a.homing = float(d.homing); a.r = float(d.radius)
		else:
			a.dps = (D.prim_dps(id, l) + lvb * 3) * might; a.manaps = D.prim_manaps(id, l) * thrift; a.range = float(d.range)
		return a
	var f: Dictionary = D.FUSIONS[id]; var ee: PackedStringArray = id.split("+"); var p: float = L.get(ee[0], 0) + L.get(ee[1], 0)
	var a = {id = id, kind = f.kind, color = f.color, els = {ee[0]: true, ee[1]: true}, name = f.name}
	match f.kind:
		"shot":
			a.dmg = [(2 * p + 3 + lvb) * might, (3 * p + 6 + lvb) * might]; a.mana = (6 + 2 * p) * thrift; a.cd = .38; a.speed = 320.0; a.homing = 3.0; a.r = 7.0
		"chain":
			a.dps = (14 + 8 * p + lvb * 3) * might; a.manaps = (8 + 2.4 * p) * thrift; a.range = 240.0
		"cone":
			a.dps = (12 + 7 * p + lvb * 3) * might; a.manaps = (8 + 2.2 * p) * thrift; a.range = 152.0
		_:
			a.dps = (16 + 8 * p + lvb * 3) * might; a.manaps = (9 + 2.6 * p) * thrift; a.range = 360.0
	return a

func act_color() -> String: return attack_of(P.active).color if P.active != null else "#c39bff"
func act_name() -> String: return attack_of(P.active).name if P.active != null else "마법 없음"

func nearest_enemy(x: float, y: float, range: float, need_los: bool, exclude):
	var best = null; var bd = range * range
	for e in G.enemies:
		if e.dead or (exclude != null and is_same(e, exclude)): continue
		if e.d.has("hidden") and hyp(e.x - P.x, e.y - P.y) > 110: continue
		var d: float = (e.x - x) * (e.x - x) + (e.y - y) * (e.y - y)
		if d < bd and (not need_los or mg.los(x, y, e.x, e.y)):
			bd = d; best = e
	return best

func fire(dt: float, ang: float) -> void:
	var a = attack_of(P.active); var quick: float = (1 + .12 * P["pass"].get("quick", 0)) * (1 + P.st.cast)
	if a.kind == "shot":
		if P.cdShot > 0: return
		if P.mp < a.mana:
			P.cdShot = .25; return
		P.mp -= a.mana; P.cdShot = a.cd / quick
		sfx.emit("fire" if a.els.has("fire") else "arcane")
		var n: int = 1 + (P.es.get("multi", 0) if a.els.has("arcane") else 0)
		# 다중 시전: 발 수는 늘지만 한 발 피해는 줄어든다(5발이어도 합쳐서 2배 남짓)
		var mk: float = 1.0 / (1.0 + .35 * (n - 1))
		var sdm: Array = [a.dmg[0] * mk, a.dmg[1] * mk]
		for i in n:
			var an = ang + (i - (n - 1) / 2.0) * .2
			G.shots.append({id = nid(), x = P.x + cos(an) * 14, y = P.y + sin(an) * 14, vx = cos(an) * a.speed, vy = sin(an) * a.speed, speed = a.speed,
				dmg = sdm, r = a.r, life = 1.6, homing = a.homing, els = a.els, color = a.color, seek = P.es.get("seek", 0) if a.els.has("arcane") else 0, hitSet = {}})
		return
	var cost: float = a.manaps * dt
	if P.mp < cost: return
	P.mp -= cost
	if a.kind == "chain":
		var range: float = a.range + 40 * P.es.get("reach", 0)
		var target = null; var bd = range
		for e in G.enemies:
			if e.dead: continue
			var dd = hyp(e.x - P.x, e.y - P.y)
			if dd > range: continue
			if absf(ang_diff(atan2(e.y - P.y, e.x - P.x), ang)) > .65: continue
			if dd < bd and mg.los(P.x, P.y, e.x, e.y):
				bd = dd; target = e
		if target == null:
			# 적이 없어도 조준한 방향 끝(사거리 또는 벽)까지 전기가 뻗는다
			var ln := 0.0
			while ln < range and not mg.solid_at(P.x + cos(ang) * ln, P.y + sin(ang) * ln): ln += 8
			var ex: float = P.x + cos(ang) * ln; var ey: float = P.y + sin(ang) * ln
			G.bolts.append({pts = [Vector2(P.x, P.y), Vector2(ex, ey)], color = a.color, life = .06, elec = 1, from_p = 1})
			if randf() < .5: G.fx.append({x = ex, y = ey, vx = rnd(-60, 60), vy = rnd(-60, 60), life = .2, max = .2, color = "#e8fbff", size = 2.0, h = shot_h})
			return
		var from = Vector2(P.x, P.y); var cur = target; var hit = {}; var mult = 1.0
		# 번개 = 쓸어 담기: 기본으로 둘째 적까지 튐
		var links: int = 2 + P.es.get("chain", 0) + (1 if a.els.size() > 1 else 0)
		for i in links:
			if cur == null: break
			G.bolts.append({pts = [from, Vector2(cur.x, cur.y)], color = a.color, life = .06, elec = 1, from_p = 1 if i == 0 else 0})
			if randf() < .6: G.fx.append({x = cur.x, y = cur.y, vx = rnd(-70, 70), vy = rnd(-70, 70), life = .22, max = .22, color = "#e8fbff", size = 2.2, h = shot_h})
			damage_enemy(cur, a.dps * dt * mult, a.els, true); hit[cur.id] = true
			from = Vector2(cur.x, cur.y); mult *= .8
			var nx = null; var nd = 150.0
			for e in G.enemies:
				if e.dead or hit.has(e.id): continue
				var dd = hyp(e.x - from.x, e.y - from.y)
				if dd < nd:
					nd = dd; nx = e
			cur = nx
	elif a.kind == "cone":
		var half: float = .32 + .12 * P.es.get("widen", 0); var range: float = a.range + 25 * P.es.get("widen", 0)
		for e in G.enemies:
			if e.dead: continue
			var dd = hyp(e.x - P.x, e.y - P.y)
			if dd > range + e.r: continue
			if absf(ang_diff(atan2(e.y - P.y, e.x - P.x), ang)) > half + .1: continue
			if not mg.los(P.x, P.y, e.x, e.y): continue
			damage_enemy(e, a.dps * dt, a.els, true)
			if P.es.get("gust", 0) and not e.isBoss:
				var k: float = 60 * P.es.gust * dt; mg.move(e, (e.x - P.x) / max(dd, 1.0) * k, (e.y - P.y) / max(dd, 1.0) * k)
		if P.es.get("gust", 0):
			G.eshots = G.eshots.filter(func(s): return not (s.kind == "arrow" and hyp(s.x - P.x, s.y - P.y) < range and absf(ang_diff(atan2(s.y - P.y, s.x - P.x), ang)) < half))
		if P.es.get("harden", 0): P.hardenT = .15
		# 고깔은 내 몸에 붙어 따라다닌다(뷰가 매 프레임 이 값으로 그림). 벽에 닿으면 거기까지만.
		var ln := 16.0
		while ln < range and not mg.solid_at(P.x + cos(ang) * ln, P.y + sin(ang) * ln): ln += 8
		G.cone = {ang = ang, half = half, len = min(range, ln + 14), color = a.color, t = G.time}
		G.coneT += dt
		if G.coneT > .03:
			G.coneT = 0.0
			for i in 2:
				var sp = rnd(.8, 1.1) * range * 1.9
				# rel: 나를 기준으로 (각도, 거리) — 내가 움직여도 고깔 안에 그대로 있다
				G.fx.append({rel = 1, a = rnd(-half, half) * .85, d = rnd(14, 30), dv = sp, x = P.x, y = P.y, vx = 0.0, vy = 0.0, life = .32, max = .32,
					color = "#ffffff" if i == 0 else a.color, size = rnd(1.2, 2.2) if i == 0 else rnd(3, 5), hv = rnd(-.35, .35), mist = 0 if i == 0 else 1, lim = G.cone.len})
	else:
		var len = 0.0; var step = 8.0
		while len < a.range and not mg.solid_at(P.x + cos(ang) * len, P.y + sin(ang) * len): len += step
		var ex: float = P.x + cos(ang) * len; var ey: float = P.y + sin(ang) * len
		for e in G.enemies:
			if e.dead: continue
			var t = clampf_((e.x - P.x) * cos(ang) + (e.y - P.y) * sin(ang), 0, len)
			var px: float = P.x + cos(ang) * t; var py: float = P.y + sin(ang) * t
			if hyp(e.x - px, e.y - py) < e.r + 9: damage_enemy(e, a.dps * dt, a.els, true)
		G.bolts.append({pts = [Vector2(P.x, P.y), Vector2(ex, ey)], color = a.color, life = .04, beam = 1})
		G.bolts.append({pts = jag(P.x, P.y, ex, ey, 10), color = "#86e3ff", life = .04})

func jag(x1: float, y1: float, x2: float, y2: float, amp: float) -> Array:
	var pts: Array = [Vector2(x1, y1)]; var n: int = max(3, int(hyp(x2 - x1, y2 - y1) / 18))
	var nx = -(y2 - y1); var ny = x2 - x1; var l: float = max(hyp(nx, ny), 1.0)
	for i in range(1, n):
		var t = float(i) / n; var o = rnd(-amp, amp)
		pts.append(Vector2(x1 + (x2 - x1) * t + nx / l * o, y1 + (y2 - y1) * t + ny / l * o))
	pts.append(Vector2(x2, y2)); return pts

func shot_hit(s: Dictionary, e: Dictionary) -> bool:
	var dmg = rnd(s.dmg[0], s.dmg[1]); damage_enemy(e, dmg, s.els); s.hitSet[e.id] = true
	sfx.emit("hit")
	if s.els.has("arcane") and P.es.get("siphon", 0): P.mp = min(P.maxmp, P.mp + 1.2 * P.es.siphon)
	if s.els.has("fire"):
		var bl: int = P.es.get("blast", 0); var rad: float = 26.0 + 18 * bl      # 화염 = 묵직한 한 방 + 기본 작은 폭발
		sfx.emit("boom"); fire_explode(s.x, s.y, 1.0 + .25 * bl)
		if rad:
			ring(s.x, s.y, 6, rad, .25, "#ffb05a")
			for o in G.enemies:
				if o.dead or is_same(o, e): continue
				if hyp(o.x - s.x, o.y - s.y) < rad + o.r: damage_enemy(o, dmg * .6, s.els, true)
		for i in P.es.get("embers", 0):
			G.zones.append({kind = "ember", x = s.x + rnd(-20, 20), y = s.y + rnd(-20, 20), r = 16.0, life = 3.0, max = 3.0, dps = 4 + 3 * P.es.embers + P.lv * .5})
	if s.els.has("storm"):
		var from = e; var hit = {e.id: true}
		for i in 1 + P.es.get("chain", 0):
			var n = nearest_enemy(from.x, from.y, 120, false, null)
			if n == null or hit.has(n.id): break
			hit[n.id] = true
			G.bolts.append({pts = jag(from.x, from.y, n.x, n.y, 6), color = "#9fe8ff", life = .12}); damage_enemy(n, dmg * .5, s.els, true); from = n
	if s.els.has("frost"):
		burst(s.x, s.y, "#cdf2ff", 6, 90, .3, 2, shot_h * .8); fx_anim("fx_spark_blue", s.x, s.y + 8, 26, 0.0, 0.0, shot_h * .8)
	if s.els.has("arcane") and not s.els.has("fire") and not s.els.has("frost"): fx_anim("fx_spark_orange", s.x, s.y + 8, 22, 0.0, 0.0, shot_h * .8)
	if s.seek > 0:
		s.seek -= 1; s.dmg = [s.dmg[0] * .65, s.dmg[1] * .65]      # 다시 쫓아갈 때마다 약해짐
		var n = nearest_enemy(s.x, s.y, 300, true, e)
		if n != null:
			s.life = 1.4; return false
	return true

# ================= 보조 마법 =================
func sec_cd_max(id: String) -> float:
	return D.sec(id).cd * (1 - .12 * P["pass"].get("focus", 0)) * (1 - P.st.cdr)

func cast_sec(id: String) -> void:
	if G == null or G.state != "play": return
	var l: int = P.esec.get(id, 0) if P.esec.get(id, 0) else P.sec.get(id, 0)
	if not l: return
	if P.secCd.get(id, 0.0) > 0: return
	var m = D.sec_mana(id, l)
	if P.mp < m:
		toast.emit("마나가 부족해요"); return
	P.mp -= m; P.secCd[id] = sec_cd_max(id)
	sfx.emit(id)
	var pw: float = 1 + .08 * P.lv
	match id:
		"blink":
			var live: Array = G.enemies.filter(func(e): return not e.dead)
			var best = null; var bs = -1.0
			for r in mg.rooms:
				if not r.seen: continue
				for k in 6:
					var x: float = (r.x + rnd(1.5, r.w - 1.5)) * T if k else r.cx
					var y: float = (r.y + rnd(1.5, r.h - 1.5)) * T if k else r.cy
					if mg.hits(x, y, P.r): continue
					var md = 900.0
					for e in live: md = min(md, hyp(e.x - x, e.y - y))
					if hyp(x - P.x, y - P.y) < 120: md *= .4
					if md > bs:
						bs = md; best = Vector2(x, y)
			if best != null:
				burst(P.x, P.y, "#c39bff", 20, 160, .4, 3); P.x = best.x; P.y = best.y; burst(P.x, P.y, "#c39bff", 20, 160, .4, 3); mg.build_flow(P.x, P.y)
		"ward":
			P.ward = D.sec_amt(l); ring(P.x, P.y, P.r, P.r + 20, .35, "#7fb2ff")
		"stasis":
			G.zones.append({kind = "stasis", x = P.x, y = P.y, r = 120.0, life = D.sec_dur(id, l), max = D.sec_dur(id, l)})
		"freeze":
			ring(P.x, P.y, 10, 175, .4, "#cdf2ff"); fx_anim("fx_freeze", P.x, P.y + 20, 120, .5)
			for e in G.enemies:
				if not e.dead and hyp(e.x - P.x, e.y - P.y) < 175 + e.r: e.frozenT = D.sec_dur(id, l) * (.4 if e.isBoss else 1.0)
		"nova":
			ring(P.x, P.y, 10, 150, .35, "#ff8a3a"); burst(P.x, P.y, "#ff8a3a", 30, 260, .45, 3)
			for e in G.enemies:
				if e.dead: continue
				var d = hyp(e.x - P.x, e.y - P.y)
				if d < 150 + e.r:
					damage_enemy(e, D.sec_dmg(id, l) * pw, {fire = true})
					if not e.isBoss:
						for k in 6: mg.move(e, (e.x - P.x) / max(d, 1.0) * 14, (e.y - P.y) / max(d, 1.0) * 14)
			G.eshots = G.eshots.filter(func(b): return hyp(b.x - P.x, b.y - P.y) > 150)
		"acid":
			var t = nearest_enemy(P.x, P.y, 380, true, null)
			var x: float = t.x if t != null else P.x + cos(P.face) * 120; var y: float = t.y if t != null else P.y + sin(P.face) * 120
			G.zones.append({kind = "acid", x = x, y = y, r = 70.0, life = 5.0, max = 5.0, dps = D.sec_dps(l) * pw})
		"purge":
			ring(P.x, P.y, 10, 260, .5, "#fff2c2")
			for e in G.enemies:
				if e.dead or not e.d.get("undead", 0): continue
				if hyp(e.x - P.x, e.y - P.y) < 260:
					damage_enemy(e, D.sec_dmg(id, l) * pw, null); e.fearT = 1.0 if e.isBoss else 3.0 + l

# ================= 피해/경험치 =================
func hurt_player(d: float) -> void:
	if P.inv > 0 or G.state != "play" or (G.sb != null and G.sb.god): return
	if P.hardenT > 0: d *= 1 - .2 * P.es.get("harden", 0)
	d *= 1 - min(.5, P.st.res)
	if P.ward > 0:
		var a: float = min(P.ward, d); P.ward -= a; d -= a
	P.hp -= d; P.inv = .25
	if d > 1: sfx.emit("phurt")
	if d > 3: P.hitT = .2
	if d > 0:
		rumble.emit(160 if d > 15 else 90, .9 if d > 15 else .5)
		float_text(P.x, P.y - 16, str(int(round(d))), "#ff6b6b")
	G.shake = .15
	if P.hp <= 0:
		P.hp = 0.0; game_over(false)

func gain_xp(n: float) -> void:
	var v = int(round(n * diff_d().reward)); P.xp += v
	var up := false
	while P.xp >= P.next:
		sfx.emit("levelup"); P.xp -= P.next; P.lv += 1; P.next = xp_need(P.lv); G.pendingLv += 1; G.lvDelay = .45; lv_fx(); recalc()
		P.hp = min(P.maxhp, P.hp + P.maxhp * .2); P.mp = min(P.maxmp, P.mp + P.maxmp * .3); up = true
	if up: levelup_blast()

# 레벨업 충격파(원작처럼): 주변 적 모두에게 한 번에 큰 피해 + 밀쳐내기
func levelup_blast() -> void:
	var R := 230.0; var dmg: float = (30 + 8 * P.lv + 5 * lvf()) * (1 + P.st.dmg)
	sfx.emit("boom"); rumble.emit(200, .8); G.shake = .3
	ring(P.x, P.y, 10, R, .55, "#ffe49a"); ring(P.x, P.y, 6, R * .7, .4, "#fff6d8"); ring(P.x, P.y, 20, R * 1.1, .7, "#e3b04b")
	fx_anim("fx_blast", P.x, P.y + 10, 150, .6)
	for i in 60:
		var a = rnd(0, TAU); var sp = rnd(200, 420)
		G.fx.append({x = P.x, y = P.y, vx = cos(a) * sp, vy = sin(a) * sp, life = .6, max = .6, color = pick(["#ffe49a", "#fff6d8", "#e3b04b"]), size = rnd(2, 4), h = .4})
	for e in G.enemies:
		if e.dead: continue
		var d = hyp(e.x - P.x, e.y - P.y)
		if d > R + e.r: continue
		damage_enemy(e, dmg * (1.0 - .35 * d / R), {arcane = true})
		if not e.isBoss and d > 1: mg.move(e, (e.x - P.x) / d * 46, (e.y - P.y) / d * 46)
	G.eshots = G.eshots.filter(func(s_): return hyp(s_.x - P.x, s_.y - P.y) > R)

# ================= 레벨업 선택지 =================
func build_options() -> Array:
	var o: Array = []
	var learned: Array = D.PRIM_ORDER.filter(func(k): return P.prim[k] > 0)
	var fus = Array(String(P.fusion).split("+")) if P.fusion != null else null
	for id in D.PRIM_ORDER:
		var d: Dictionary = D.PRIMARIES[id]; var l: int = P.prim[id]
		if l >= D.PRIMARY_MAX: continue
		if fus != null and not id in fus: continue
		var w = 4.0 if l else (.3 if learned.size() else 1.3)
		o.append({icon = {t = "el", el = id}, w = w, tag = "주 마법 (융합 강화)" if fus != null else "주 마법", title = "%s %d단계" % [d.name, l + 1] if l else "%s 배우기" % d.name, desc = d.desc, color = d.color, kind = "prim", id = id})
	for s in D.SUBS:
		var l: int = P.subs.get(s.id, 0)
		if l >= s.max or not has_el(s.of): continue
		if fus != null and not s.of in fus: continue
		o.append({icon = {t = "sub", el = s.of, id = s.id}, w = 3.2, tag = "%s 강화" % D.PRIMARIES[s.of].name, title = "%s %d단계" % [s.name, l + 1], desc = s.desc, color = D.PRIMARIES[s.of].color, kind = "sub", id = s.id})
	if fus == null:
		for i in learned.size():
			for j in range(i + 1, learned.size()):
				var pair = [learned[i], learned[j]]; pair.sort()
				var key: String = "%s+%s" % pair; var f: Dictionary = D.FUSIONS[key]
				o.append({icon = {t = "fusion", a = pair[0], b = pair[1]}, w = 2.4, tag = "융합 마법", title = f.name, desc = f.desc + " 고르면 다른 주 마법은 더 이상 나오지 않아요.", color = f.color, kind = "fusion", id = key})
	var slots = D.secondary_slots(P.lv)
	for s in D.SECONDARIES:
		var l: int = P.sec.get(s.id, 0); var af = AFF.get(s.id); var rel: bool = af != null and has_el(af)
		if l:
			if l < s.max: o.append({icon = {t = "sec", id = s.id}, w = 2.6 if rel else 1.4, tag = "보조 마법", title = "%s %d단계" % [s.name, l + 1], desc = s.desc, color = "#e3b04b", kind = "sec", id = s.id})
		elif P.secOrder.size() < slots and P.lv >= s.lv:
			var tag = "보조 마법 · %s 계열 (%d/%d칸)" % [D.PRIMARIES[af].name, P.secOrder.size() + 1, slots] if rel else "보조 마법 (%d/%d칸)" % [P.secOrder.size() + 1, slots]
			o.append({icon = {t = "sec", id = s.id}, w = 3.5 if rel else (.45 if af != null else 1.2), tag = tag, title = "%s 배우기" % s.name, desc = s.desc, color = "#e3b04b", kind = "secnew", id = s.id})
	for s in D.PASSIVES:
		var l: int = P["pass"].get(s.id, 0)
		if l >= s.max: continue
		o.append({icon = {t = "pass", id = s.id}, w = 1.2, tag = "수련", title = "%s %d단계" % [s.name, l + 1], desc = s.desc, color = "#a395b3", kind = "pass", id = s.id})
	var out: Array = []
	while out.size() < 3 and o.size():
		var tot = 0.0
		for x in o: tot += x.w
		var r = randf() * tot; var k = 0
		while k < o.size():
			r -= o[k].w
			if r <= 0: break
			k += 1
		out.append(o.pop_at(min(k, o.size() - 1)))
	return out

func apply_option(o: Dictionary) -> void:
	match o.kind:
		"prim": P.prim[o.id] += 1
		"sub": P.subs[o.id] = P.subs.get(o.id, 0) + 1
		"fusion":
			P.fusion = o.id; P.active = o.id
		"sec": P.sec[o.id] = P.sec.get(o.id, 0) + 1
		"secnew":
			P.sec[o.id] = 1; P.secOrder.append(o.id)
		"pass":
			P["pass"][o.id] = P["pass"].get(o.id, 0) + 1; recalc()
	G.pendingLv -= 1
	ui.emit("buttons")
	if G.pendingLv > 0: ui.emit("levelup")
	else: set_state("play")

func pick_first(id: String, nm := "") -> void:
	if nm.strip_edges() != "": P.name = nm.strip_edges().left(12)
	P.prim[id] = 1; P.active = id
	G.banner = {text = "%s을(를) 익혔다" % D.PRIMARIES[id].name, t = 2.0}
	enter_tower()

# ================= 장비 =================
func roll_mod(slot: String, used: Dictionary, lvl: int, mult: float, strong: bool, want := "") -> Dictionary:
	var my_els: Array = D.PRIM_ORDER.filter(func(k): return P.prim[k] > 0)
	var pool: Array = []
	var add = func(k: String, w: float, v: Callable):
		if used.has(k): return
		if want == "pre" and not D.is_pre(k): return
		if want == "suf" and D.is_pre(k): return
		pool.append({k = k, w = w, v = v})
	var sc = 1 + lvl * .08
	mult *= 1 + .15 * D.tier(lvl)       # 높은 층에서 나온 옵션일수록 수치도 크다
	for el in D.PRIM_ORDER:
		var mine: bool = el in my_els
		if slot == "weapon": add.call("prim:" + el, 5.0 if mine else .6, func(): return ri(1, 3 if strong else 2))
		elif slot == "ring" or slot == "amulet": add.call("prim:" + el, (1.5 if slot == "ring" else 1.1) if mine else .3, func(): return 1)
	for sd in D.SUBS:
		var mine: bool = sd.of in my_els
		add.call("sub:" + sd.id, ((1.1 if slot in ["weapon", "gloves"] else .5) if mine else .08), func(): return ri(1, 2 if strong else 1))
	for sd in D.SECONDARIES:
		if slot in ["ring", "cloak", "amulet", "belt", "gloves"]: add.call("sec:" + sd.id, 1.4 if P.sec.get(sd.id, 0) else .15, func(): return 1)
	add.call("hp", 3.0 if slot in ["cloak", "belt"] else 1.6, func(): return int(round(rnd(8, 16) * sc * mult)))
	add.call("mp", 2.5 if slot in ["ring", "amulet"] else 1.4, func(): return int(round(rnd(8, 16) * sc * mult)))
	add.call("regen", 1.4, func(): return snappedf(rnd(.08, .18) * mult, .01))
	add.call("dmg", 2.4 if slot == "weapon" else (1.4 if slot == "gloves" else 1.0), func(): return snappedf(rnd(.05, .12) * mult, .01))
	add.call("cast", 1.8 if slot in ["weapon", "gloves"] else .8, func(): return snappedf(rnd(.04, .1) * mult, .01))
	add.call("cdr", .9, func(): return snappedf(rnd(.05, .1) * mult, .01))
	add.call("res", 2.4 if slot == "cloak" else (1.6 if slot in ["belt", "boots"] else .6), func(): return snappedf(rnd(.03, .07) * mult, .01))
	if slot == "boots": add.call("spd", 2.4, func(): return snappedf(rnd(.02, .04), .01))   # 이동 속도는 장화에만, 조금씩
	add.call("gold", .8, func(): return snappedf(rnd(.1, .3) * mult, .01))
	if pool.is_empty(): return {}
	var tot = 0.0
	for o in pool: tot += o.w
	var r = randf() * tot
	for o in pool:
		r -= o.w
		if r <= 0: return {k = o.k, v = o.v.call()}
	return {k = pool[0].k, v = pool[0].v.call()}

func _afx_name(k: String, lvl: int) -> String:
	var parts: PackedStringArray = k.split(":")
	if parts[0] == "prim": return D.PREFIX.prim[parts[1]]
	var a: Dictionary = D.AFX.get(parts[0], {})
	if a.is_empty() or a.n.is_empty(): return D.PREFIX.get(parts[0], "")
	return a.n[D.tier(lvl)]

# 고정 옵션(유니크·세트) 한 줄 → 실제 수치
func _fixed_mod(spec: Array, lvl: int) -> Dictionary:
	var k: String = spec[0]
	if k == "prim:mine":
		var mine: Array = D.PRIM_ORDER.filter(func(x): return P.prim[x] > 0)
		k = "prim:" + (pick(mine) if mine.size() else pick(D.PRIM_ORDER))
	var lo: float = float(spec[1]); var hi: float = float(spec[2]) if spec.size() > 2 else lo
	if D.is_skill(k): return {k = k, v = ri(int(lo), int(hi))}
	if k == "hp" or k == "mp": return {k = k, v = int(round(rnd(lo, hi) * (1 + lvl * .03)))}
	return {k = k, v = snappedf(rnd(lo, hi), .01)}

func item_value(it: Dictionary) -> int:
	# 파는 값 — 금화 버는 속도에 맞춰 넉넉하게(상점에서 사는 값은 이것의 2.5배쯤)
	var R: Dictionary = D.RAR[it.rar]
	var v: float = (30 + int(it.lvl) * 14) * R.val * (1 + .18 * it.mods.size()) * 7 * (1 + .3 * int(it.get("enh", 0)))
	return int(round(v / 5.0)) * 5

func make_item(rar: String, lvl: int, base_id := "") -> Dictionary:
	if rar == "epic": rar = "unique"
	var spec = null; var set_id := ""
	if rar == "unique":
		# 저층에서는 약한 유니크만(층 + 10 이하 요구 레벨)
		var c: Array = D.UNIQUES.filter(func(u): return (base_id == "" or u.base == base_id or D.base(u.base).slot == D.base(base_id).slot) and int(u.get("lv", 1)) <= lvl + 10)
		if c.is_empty(): c = D.UNIQUES.filter(func(u): return int(u.get("lv", 1)) <= lvl + 10)
		if c.is_empty(): c = D.UNIQUES
		spec = pick(c); base_id = spec.base
	elif rar == "set":
		var c: Array = []
		for sid in D.SETS.keys():
			for pc in D.SETS[sid].pieces:
				if base_id == "" or pc.base == base_id or D.base(pc.base).slot == D.base(base_id).slot: c.append([sid, pc])
		if c.is_empty():
			for sid in D.SETS.keys():
				for pc in D.SETS[sid].pieces: c.append([sid, pc])
		var ch = pick(c); set_id = ch[0]; spec = ch[1]; base_id = spec.base
	var base: Dictionary = D.base(base_id) if base_id != "" else pick(D.BASES + [D.base("ring"), D.base("staff")])
	if rar == "normal" and base.imp == null: rar = "magic"     # 반지·목걸이는 노말이 없다
	var R: Dictionary = D.RAR[rar]; var tier: int = D.tier(lvl)
	var it = {uid = "%d%d" % [Time.get_ticks_msec(), randi() % 10000], base = base.id, slot = base.slot, rar = rar, lvl = lvl, mods = [], enh = 0}
	var used = {}
	if base.imp != null:
		var iv: float = base.imp.v if base.imp.k == "spd" else base.imp.v * (1 + lvl * .05)
		it.mods.append({k = base.imp.k, v = snappedf(iv, .01) if base.imp.v < 1 else int(round(iv))}); used[base.imp.k] = true
	var bn: String = base.names[tier]
	match rar:
		"unique", "set":
			for m in spec.mods:
				var fm = _fixed_mod(m, lvl)
				if used.has(fm.k):
					for x in it.mods:
						if x.k == fm.k: x.v = x.v + fm.v
				else:
					it.mods.append(fm); used[fm.k] = true
			it.name = spec.name
			if set_id != "": it.set = set_id
		"magic":
			var n = ri(R.mods[0], R.mods[1]); var pre = ""; var suf = ""
			var wants: Array = (["pre", "suf"] if n == 2 else [pick(["pre", "suf"])])
			for w in wants:
				var m = roll_mod(base.slot, used, lvl, R.mult, false, w)
				if m.is_empty(): continue
				used[m.k] = true; it.mods.append(m)
				if w == "pre": pre = _afx_name(m.k, lvl)
				else: suf = _afx_name(m.k, lvl)
			it.name = ("%s의 " % suf if suf != "" else "") + ("%s " % pre if pre != "" else "") + bn
		"rare":
			var n = ri(R.mods[0], R.mods[1]); var np := 0; var ns := 0
			for i in n:
				var w := "" if (np < 3 and ns < 3) else ("suf" if np >= 3 else "pre")
				var m = roll_mod(base.slot, used, lvl, R.mult, false, w)
				if m.is_empty(): break
				used[m.k] = true; it.mods.append(m)
				if D.is_pre(m.k): np += 1
				else: ns += 1
			it.name = "%s %s" % [pick(D.RARENAMES), pick(D.RARENOUN[base.slot])]
			it.bname = bn
		_:
			it.name = bn
	it.value = item_value(it)
	return it

# 등급 굴리기(디아블로식): 저층은 노말·매직이 대부분, 레어는 가끔, 세트·유니크는 50~60층쯤부터 보일 듯 말 듯
# luck: 보스·유니크 몬스터·상자는 좋은 등급 확률을 몇 배로
# 단계(나이트메어·헬)는 레벨 층이 100씩 높아 1층부터 다시 차근차근 오르고, 상한도 단계마다 조금씩 높다
func roll_rarity(luck := 1.0, min_rar := "normal", f_over := -1) -> String:
	var f: float = max(1, lvf() if f_over < 0 else f_over)
	var tb: float = 1.0 + .5 * int(G.tier)
	var pu: float = (.0006 if f < 20 else (.002 if f < 50 else min(.03 * tb, .008 + (f - 50) * .0004))) * luck
	var ps: float = (.001 if f < 15 else (.005 if f < 40 else min(.035 * tb, .012 + (f - 40) * .0004))) * luck
	# 초반(5층 전)은 흰템 위주: 매직은 드물게, 레어는 거의 없음 → 15층 즈음 원래 확률까지 서서히
	var ramp: float = clampf((f - 3.0) / 12.0, 0.0, 1.0) if int(G.tier) == 0 else 1.0
	var pr: float = max(.0015, min(.22 * (1 + .25 * int(G.tier)), .03 + f * .0016) * ramp * ramp) * luck
	var pm: float = lerpf(.06, min(.5, .26 + f * .0025), ramp) * sqrt(luck)
	pu *= ramp * ramp; ps *= ramp * ramp          # 세트·유니크도 초반엔 사실상 안 나옴
	var r := randf(); var out := "normal"
	if r < pu: out = "unique"
	elif r < pu + ps: out = "set"
	elif r < pu + ps + pr: out = "rare"
	elif r < pu + ps + pr + pm: out = "magic"
	if D.RAR_ORDER.find(out) < D.RAR_ORDER.find(min_rar): out = min_rar
	return out

func drop_item(x: float, y: float, rar := "", luck := 1.0) -> Dictionary:
	var it = make_item(rar if rar != "" else roll_rarity(luck), lvf())
	G.drops.append({id = nid(), x = x, y = y, kind = "item", it = it, t = 0.0, vx = rnd(-80, 80), vy = rnd(-80, 80), h = 0.0, vh = rnd(100, 150)})
	if it.rar in ["set", "unique"]: toast.emit("%s 아이템이 떨어졌다!" % D.RAR[it.rar].name)
	return it

static func sum_mods(it) -> Dictionary:
	var o = {}
	if it != null:
		for m in D.eff_mods(it): o[m.k] = o.get(m.k, 0) + m.v
	return o
static func sum_score(it) -> int: return it.mods.size() + D.RAR_ORDER.find(it.rar) + int(it.get("enh", 0))

func set_count(sid: String) -> int:
	var n := 0
	for k in D.SLOTS:
		var it = P.eq.get(k)
		if it != null and it.get("set", "") == sid: n += 1
	return n

func equip(i: int, slot: String) -> void:
	var it = P.bag[i]; var old = P.eq[slot]; P.eq[slot] = it; P.bag.remove_at(i)
	if old != null: P.bag.insert(i, old)
	recalc(); ui.emit("buttons"); sfx.emit("equip"); toast.emit("%s 착용" % it.name)

func unequip(slot: String) -> bool:
	if P.bag.size() >= P.bagMax:
		toast.emit("가방이 가득 찼어요"); return false
	P.bag.append(P.eq[slot]); P.eq[slot] = null; recalc(); ui.emit("buttons"); return true

# 강화: 강화석 1개 · 성공하면 +1(옵션 +20%, 스킬 +1), 실패하면 강화석만 사라진다
func enhance(it) -> String:
	if not D.can_enhance(it): return "no"
	var e: int = int(it.get("enh", 0))
	if e >= D.ENH_MAX: return "max"
	if int(P.get("stones", 0)) <= 0: return "nostone"
	P.stones -= 1
	if randi() % 100 < D.enh_rate(e):
		it.enh = e + 1; it.value = item_value(it); recalc(); save(); sfx.emit("ok"); sfx.emit("levelup"); return "ok"
	save(); sfx.emit("fail"); return "fail"

func sell(i: int) -> void:
	sfx.emit("sell"); G.gold += P.bag[i].value; P.bag.remove_at(i); save()

func discard(i: int) -> void:
	var x = P.bag[i]; P.bag.remove_at(i)
	G.drops.append({id = nid(), x = P.x + rnd(-20, 20), y = P.y + 30, kind = "item", it = x, t = 0.0, vx = 0.0, vy = 0.0, h = 0.0, vh = 0.0, noPick = 1})

# 물약 최대 소지 수(물약 주머니로 늘림, 최대 10) · 포탈 주문서는 5
func pot_max(id: String) -> int: return int(P.get("potMax", 5)) if id != "scroll" else D.shop("scroll").max
const POUCH_PRICE := [6000, 12000, 25000, 45000, 80000]
func pouch_price() -> int: return POUCH_PRICE[clampi(int(P.get("potMax", 5)) - 5, 0, 4)]
func buy_pouch() -> bool:
	if int(P.get("potMax", 5)) >= 10: return false
	var pr := pouch_price()
	if G.gold < pr:
		toast.emit("금화가 모자라요"); return false
	G.gold -= pr; P.potMax = int(P.get("potMax", 5)) + 1; sfx.emit("sell"); save(); toast.emit("물약을 %d개까지 들 수 있어요" % P.potMax); return true

func buy(id: String) -> void:
	var it = D.shop(id)
	if G.gold < it.price or P.pot.get(id, 0) >= pot_max(id): return
	G.gold -= it.price; P.pot[id] = P.pot.get(id, 0) + 1; save(); ui.emit("belt"); sfx.emit("sell")

# ================= 층 이동 / 종료 =================
func open_chest(c: Dictionary) -> void:
	c.open = true; sfx.emit("chest"); ring(c.x, c.y, 4, 34, .35, "#ffd76a"); burst(c.x, c.y - 6, "#ffd76a", 18, 140, .5, 2.5)
	# 금화: 한두 닢부터 우르르까지 들쭉날쭉(대부분 조금, 가끔 많이)
	var rr := randf(); var n: int = ri(1, 2) if rr < .45 else (ri(3, 5) if rr < .8 else (ri(6, 10) if rr < .95 else ri(12, 18)))
	if randf() < .15: n = 0
	var v: int = max(1, int(round((6 + lvf() * 3) * diff_d().reward * GOLD_RATE * rnd(.6, 1.4))))
	for i in n: G.drops.append({id = nid(), x = c.x, y = c.y + 6, kind = "gold", v = v, t = .5, vx = rnd(-130, 130) * (.5 + n / 18.0), vy = rnd(-40, 150) * (.5 + n / 18.0), h = 8.0, vh = rnd(140, 220)})
	if randf() < (.08 if lvf() < 5 else .13): drop_item(c.x, c.y, "", 1.5 if lvf() >= 5 else 1.0)
	if lvf() >= 25 and randf() < .05: drop_stone(c.x, c.y, 1)
	var r = randf()
	if r < .45: G.drops.append({id = nid(), x = c.x, y = c.y, kind = pick(["pothp", "pothp", "potmp"]), t = 0.0, vx = rnd(-60, 60), vy = rnd(40, 90), h = 0.0, vh = 110.0})
	elif r < .55: G.drops.append({id = nid(), x = c.x, y = c.y, kind = "scroll", t = 0.0, vx = rnd(-60, 60), vy = rnd(40, 90), h = 0.0, vh = 110.0})

# 바깥 테라스: 탑의 그 쪽(동서남북)으로 뻗은 야외 공간. 들어갈 때마다 가벼운 일이 있기도 하고 없기도 하다
const TERRACE_EV := [["fight", 30], ["quiet", 14], ["survive", 15], ["corpse", 15], ["named", 15], ["empty", 11]]
func enter_terrace(force_ev := "") -> void:
	var dv := Vector2(mg.door.get("dx", 0.0), mg.door.get("dy", -1.0))
	G.stash = {mg = mg, enemies = G.enemies, chests = G.chests, drops = G.drops, corpses = G.corpses, px = mg.door.x - dv.x * 48, py = mg.door.y - dv.y * 48, portal = G.portal}
	G.enemies = []; G.chests = []; G.drops = []; G.corpses = []; G.shots = []; G.eshots = []; G.zones = []; G.portal = null
	var dir: String = mg.door.get("dir", "n")
	randomize()
	mg = MapGen.new(); mg.gen_terrace(G.floor, false, dir)
	var r: Dictionary = mg.rooms[0]
	var tot := 0
	for e in TERRACE_EV: tot += e[1]
	var roll := randi() % tot; var ev: String = "fight"
	for e in TERRACE_EV:
		roll -= e[1]
		if roll < 0:
			ev = e[0]; break
	if ev == "survive" and G.floor < 3: ev = "fight"
	if force_ev != "": ev = force_ev
	var spot := func(min_d: float) -> Vector2:
		for k in 60:
			var p := Vector2((r.x + rnd(1.5, r.w - 1.5)) * T, (r.y + rnd(1.5, r.h - 1.5)) * T)
			if not mg.hits(p.x, p.y, 16) and hyp(p.x - mg.start.x, p.y - mg.start.y) > min_d: return p
		return Vector2(r.cx, r.cy)
	var nm := {fight = "바깥 테라스", quiet = "바깥 테라스 · 고요한 바람", survive = "바깥 테라스 · 포위!", corpse = "바깥 테라스 · 누군가 쓰러져 있다", named = "바깥 테라스 · 무언가 배회한다", empty = "바깥 테라스 · 아무도 없다"}
	match ev:
		"fight", "quiet":
			var n: int = min(10, 3 + G.floor / 4) if ev == "fight" else ri(2, 3)
			for k in n:
				var t := pick_type(); var p: Vector2 = spot.call(150.0)
				spawn_enemy(t, p.x, p.y)
			if ev == "fight":
				for k in ri(1, 2):
					var p: Vector2 = spot.call(90.0)
					G.chests.append({x = p.x, y = p.y, open = false, t = 0.0, id = nid()}); mg.obst.append({x = p.x, y = p.y + 2, r = 16.0})
		"survive":
			G.tev = {kind = "survive", t = 60.0, delay = 2.5, sp = 0.0, sec = 61}
		"corpse":
			# 먼저 온 모험가의 유해: 장비·금화·물약이 흩어져 있다(상자 없음)
			var c: Vector2 = spot.call(200.0)
			mg.decor.append({kind = "prop", p = "skeleton1", pos = c, s = .85}); mg.decor.append({kind = "prop", p = "bones3", pos = c + Vector2(20, 10), s = .7})
			for i in ri(1, 2): drop_item(c.x + rnd(-24, 24), c.y + rnd(-14, 14), "", 1.6)
			for i in ri(3, 8): G.drops.append({id = nid(), x = c.x + rnd(-30, 30), y = c.y + rnd(-18, 18), kind = "gold", v = max(1, int(round((4 + lvf() * 2) * GOLD_RATE * 3))), t = .5})
			if randf() < .7: G.drops.append({id = nid(), x = c.x + rnd(-20, 20), y = c.y + 18, kind = pick(["pothp", "potmp", "scroll"]), t = .5})
			for k in ri(0, 2):
				var p: Vector2 = spot.call(220.0); spawn_enemy(pick_type(), p.x, p.y)
		"named":
			var p: Vector2 = spot.call(220.0)
			var e := spawn_elite(pick_type(), p.x, p.y); e.wander = true; e.wx = p.x; e.wy = p.y; e.wt = 0.0
		"empty":
			for k in 3:
				var p: Vector2 = spot.call(80.0)
				mg.decor.append({kind = "model", name = pick(["Bench", "Vase_2", "Barrel"]), pos = p, rot = rnd(0, TAU), s = .7}); mg.obst.append({x = p.x, y = p.y, r = 14.0})
	P.x = mg.start.x; P.y = mg.start.y; P.vx = 0.0; P.vy = 0.0
	G.banner = {text = "%d층 · %s" % [G.floor, nm[ev]], t = 2.4}
	if ev == "survive": toast.emit("60초 동안 버텨라!")
	mg.build_flow(P.x, P.y); level_changed = true

# 테라스 버티기: 60초 동안 사방에서 몰려온다. 버티면 보상
func upd_terrace_event(dt: float) -> void:
	var ev = G.get("tev")
	if ev == null or G.stash == null: return
	if ev.delay > 0:
		ev.delay -= dt; return
	ev.t -= dt
	var sec: int = int(ceil(ev.t))
	if sec != ev.sec and sec >= 0:
		ev.sec = sec; G.banner = {text = "버티기 · %d초" % sec, t = 1.1}
	ev.sp -= dt
	if ev.sp <= 0 and ev.t > 3:
		ev.sp = lerp(2.4, 1.1, 1.0 - ev.t / 60.0)
		var r: Dictionary = mg.rooms[0]
		for k in ri(1, 3):
			for tries in 20:
				var p := Vector2((r.x + rnd(1.5, r.w - 1.5)) * T, (r.y + rnd(1.5, r.h - 1.5)) * T)
				if not mg.hits(p.x, p.y, 16) and hyp(p.x - P.x, p.y - P.y) > 220:
					var e := spawn_enemy(pick_type(), p.x, p.y); e.aggro = true; e.xp = int(e.xp * .5)
					smoke(p.x, p.y, 4); break
	if ev.t <= 0:
		G.tev = null
		for e in G.enemies:
			if not e.dead:
				e.dead = true; smoke(e.x, e.y, 5)
		G.banner = {text = "버텨냈다!", t = 2.6}; sfx.emit("levelup")
		for i in 3: drop_item(P.x + rnd(-40, 40), P.y - 30 + rnd(-20, 20), "", 2.5)
		for i in ri(6, 10): G.drops.append({id = nid(), x = P.x + rnd(-50, 50), y = P.y + rnd(-40, 30), kind = "gold", v = max(1, int(round((6 + lvf() * 3) * GOLD_RATE * 2))), t = .5, vx = rnd(-80, 80), vy = rnd(-60, 60), h = 4.0, vh = rnd(100, 160)})
		G.drops.append({id = nid(), x = P.x, y = P.y + 30, kind = "pothp", t = .5})

func leave_terrace() -> void:
	var st = G.stash
	if st == null: return
	mg = st.mg; G.enemies = st.enemies; G.chests = st.chests; G.drops = st.drops; G.corpses = st.corpses; G.portal = st.portal
	G.shots = []; G.eshots = []; G.zones = []; G.stash = null; G.tev = null
	P.x = st.px; P.y = st.py; P.vx = 0.0; P.vy = 0.0
	mg.dirty = true; mg.build_flow(P.x, P.y); level_changed = true

func _portal_go() -> void:
	if G.portal == null: return
	if G.portal.get("back", false):
		portal_back(); return
	if G.portal.get("tp", false):
		G.townRet = {floor = G.floor, live = true, mg = mg, enemies = G.enemies, chests = G.chests, drops = G.drops, corpses = G.corpses, stash = G.stash, px = G.portal.ox, py = G.portal.oy, herds = G.herds, bossMax = G.bossMax}
	else: stash_floor()
	if G.floor != D.COW and int(G.portal.resume) != D.COW: G.resume = max(G.resume, int(G.portal.resume))
	go_town(false)

# 마을의 포탈 → 떠났던 그 자리로(꺼졌다 켜진 뒤라면 그 층 처음 자리로)
func portal_back() -> void:
	var r = G.townRet; G.townRet = null
	G.portal = null; G.npcs = []
	if r.get("live", false):
		clear_level()
		G.floor = int(r.floor); mg = r.mg; G.enemies = r.enemies; G.chests = r.chests; G.drops = r.drops; G.corpses = r.corpses; G.stash = r.stash
		G.herds = r.get("herds", []); G.bossMax = r.get("bossMax", 0.0)
		P.x = r.px; P.y = r.py; P.vx = 0.0; P.vy = 0.0
		G.portal = {x = r.px, y = r.py - 34, vis = true, born = G.time, close_at = G.time + 1.0}
		mg.dirty = true; mg.build_flow(P.x, P.y); level_changed = true
		G.banner = {text = "%s · 포탈로 돌아왔다" % ("토끼 동산" if G.floor == D.COW else ("옥상" if G.floor == D.ROOF else "%d층" % G.floor)), t = 2.0}
	else:
		G.floor = int(r.floor); gen_floor()
	ring(P.x, P.y, 4, 40, .5, "#7fb2ff")
	ui.emit("buttons"); set_state("play"); save()

# 내려가기: 아래층의 올라가는 계단 앞에 선다(1층에서는 마을 탑 문 앞)
func prev_floor() -> void:
	stash_floor()
	if G.floor <= 1:
		G.resume = max(G.resume, 1); go_town(false)
		if mg.gate != null:
			P.x = mg.gate.x; P.y = mg.gate.y + 80
		mg.build_flow(P.x, P.y); return
	G.floor -= 1; P.ward = 0.0; gen_floor()
	var st = mg.stairs
	if st != null:
		st.found = true; P.x = st.x; P.y = st.y + 52
		mg.reveal(P.x, P.y); mg.build_flow(P.x, P.y)
	G.banner = {text = floor_name(G.floor), t = 1.8}
	save()

func next_floor() -> void:
	if G.floor >= D.ROOF:
		game_over(true); return
	stash_floor()
	G.floor += 1; G.resume = G.floor; P.hp = min(P.maxhp, P.hp + P.maxhp * .3); P.mp = P.maxmp; P.ward = 0.0; gen_floor(); save()

var end_win := false
func game_over(win: bool) -> void:
	end_win = win
	set_state("win" if win else "dead")
	ui.emit("end")

func revive() -> void:
	G.townRet = null; G.gold -= G.gold / 2; P.poisonT = 0.0; P.slowT = 0.0; recalc(); go_town(false)

# ================= 효과 =================
func burst(x: float, y: float, color: String, n: int, sp: float, life: float, size: float, h := -1.0) -> void:
	for i in n:
		var a = rnd(0, TAU); var v = rnd(.3, 1) * sp
		var f = {x = x, y = y, vx = cos(a) * v, vy = sin(a) * v, life = life * rnd(.6, 1), max = life, color = color, size = size * rnd(.6, 1.3)}
		if h >= 0: f.h = h
		G.fx.append(f)
	if G.fx.size() > 900: G.fx = G.fx.slice(G.fx.size() - 900)

# 화염구 폭발: 번쩍 → 불덩이가 부풀어 오르고 → 불티가 튀고 → 연기·그을음
func fire_explode(x: float, y: float, k := 1.0) -> void:
	var h: float = shot_h * .7
	G.fx.append({flash = 1, x = x, y = y, vx = 0.0, vy = 0.0, life = .2, max = .2, color = "#fff3d0", size = 34.0 * k, h = h})
	for i in int(16 * k):
		var a = rnd(0, TAU); var v = rnd(40, 150) * k
		G.fx.append({flame = 1, big = 1, x = x + cos(a) * 4, y = y + sin(a) * 4, vx = cos(a) * v, vy = sin(a) * v, life = rnd(.35, .6), max = .6, color = "#ff8a3a", size = rnd(7, 12) * k, h = h + rnd(-.1, .35)})
	for i in int(26 * k):
		var a = rnd(0, TAU); var v = rnd(160, 340) * k
		G.fx.append({x = x, y = y, vx = cos(a) * v, vy = sin(a) * v, life = rnd(.25, .55), max = .55, color = pick(["#fff3c4", "#ffd27a", "#ffae4a"]), size = rnd(1.2, 2.2), h = h + rnd(-.2, .5)})
	for i in int(5 * k):
		G.fx.append({x = x + rnd(-14, 14) * k, y = y + rnd(-14, 14) * k, vx = rnd(-18, 18), vy = rnd(-35, -10), life = rnd(.8, 1.3), max = 1.3, color = "#3a2a26", size = rnd(7, 11) * k, smoke = 1})
	ring(x, y, 8, 62 * k, .32, "#ffb05a"); ring(x, y, 4, 38 * k, .22, "#fff0b0")
	fx_anim("fx_blast", x, y + 10, 64 * k, 0.0, 0.0, h)
	G.zones.append({kind = "scorch", x = x, y = y, r = 20.0 * k, life = 2.5, max = 2.5})
	G.lights.append({x = x, y = y, life = .32, max = .32, color = "#ffa54a", en = 5.0 * k})
	G.shake = max(G.shake, .1 * k); rumble.emit(60, .35)
	if G.fx.size() > 900: G.fx = G.fx.slice(G.fx.size() - 900)

func lv_fx() -> void:
	rumble.emit(120, .4); ring(P.x, P.y, 8, 90, .6, "#e3b04b"); ring(P.x, P.y, 4, 50, .45, "#fff2c2")
	for i in 40:
		var a = rnd(0, TAU)
		G.fx.append({x = P.x + cos(a) * rnd(0, 16), y = P.y + rnd(-4, 10), vx = cos(a) * rnd(10, 40), vy = -rnd(60, 190), life = rnd(.6, 1.1), max = 1.1, color = pick(["#e3b04b", "#fff2c2", "#ffd27a"]), size = rnd(1.5, 3.5)})
	G.banner = {text = "레벨 업!", t = 1.4}

func ring(x: float, y: float, r0: float, r1: float, life: float, color: String) -> void:
	G.rings.append({x = x, y = y, r0 = r0, r1 = r1, life = life, max = life, color = color})

func float_text(x: float, y: float, t: String, color: String) -> void:
	G.texts.append({x = x + rnd(-6, 6), y = y, t = t, color = color, life = .7})
	if G.texts.size() > 60: G.texts.pop_front()

# ================= 물약·주문서 =================
func use_pot(id: String) -> void:
	if G == null or G.state != "play" or not (P.pot.get(id, 0) > 0): return
	if id == "scroll":
		if G.floor == 0: return
		P.pot.scroll -= 1
		G.portal = {x = P.x + cos(P.face) * 50, y = P.y + sin(P.face) * 50, resume = G.floor, tp = true, ox = P.x, oy = P.y, born = G.time}
		if mg.hits(G.portal.x, G.portal.y, 12):
			G.portal.x = P.x; G.portal.y = P.y + 40
		ring(G.portal.x, G.portal.y, 4, 40, .5, "#7fb2ff"); sfx.emit("portal"); toast.emit("마을로 가는 포탈이 열렸어요"); ui.emit("belt"); save(); return
	if P.potCd > 0: return
	if id == "pothp":
		if P.hp >= P.maxhp:
			toast.emit("생명이 가득 차 있어요"); return
		fx_anim("fx_heal", P.x, P.y + 6, 50); var v: float = P.maxhp * .45; P.hp = min(P.maxhp, P.hp + v)
		float_text(P.x, P.y - 18, "+%d" % int(round(v)), "#ff8a8a"); burst(P.x, P.y, "#ff6a75", 14, 90, .5, 2.5)
	else:
		if P.mp >= P.maxmp:
			toast.emit("마나가 가득 차 있어요"); return
		var v: float = P.maxmp * .6; P.mp = min(P.maxmp, P.mp + v)
		float_text(P.x, P.y - 18, "+%d" % int(round(v)), "#8ab0ff"); burst(P.x, P.y, "#6f9cff", 14, 90, .5, 2.5)
	P.pot[id] -= 1; P.potCd = .8; ui.emit("belt"); sfx.emit("drink")

func swap_active() -> void:
	var l = active_list()
	if l.size() < 2: return
	P.active = l[(l.find(P.active) + 1) % l.size()]; ui.emit("buttons"); toast.emit(attack_of(P.active).name)

func near_npc():
	if G.npcs == null: return null
	for n in G.npcs:
		if hyp(P.x - n.x, P.y - n.y) < 54: return n
	return null

# ================= 매 프레임 =================
func update(dt: float) -> void:
	G.time += dt
	if G.banner.t > 0: G.banner.t -= dt
	if G.shake > 0: G.shake -= dt
	recalc()
	var sp: float = P.speed * (.6 if P.slowT > 0 else 1.0)
	var kp = 1.0 - exp(-7.0 * dt)
	P.vx += (inp.mx * sp - P.vx) * kp; P.vy += (inp.my * sp - P.vy) * kp; mg.move(P, P.vx * dt, P.vy * dt)
	if inp.firing or hyp(inp.mx, inp.my) > .2: P.face = inp.ang if inp.firing else atan2(inp.my, inp.mx)
	P.firing = inp.firing
	P.cdShot -= dt; P.inv -= dt; P.slowT -= dt; P.hardenT -= dt; P.potCd -= dt
	var spd = hyp(P.vx, P.vy); P.walk += spd * dt * .11
	if spd > 60 and randf() < dt * 9:
		G.fx.append({x = P.x + rnd(-4, 4), y = P.y + P.r, vx = rnd(-12, 12), vy = rnd(-14, -4), life = .4, max = .4, color = "#5a4a6a" if G.floor else "#6a7a5a", size = rnd(1.5, 2.6), dust = 1})
	if G.floor == 0 and mg.gate != null and G.pull == null:
		# 탑 문: 계단처럼 걸어 들어간다(보랏빛 속으로)
		if hyp(P.x - mg.gate.x, P.y - mg.gate.y) < 40 and P.y >= mg.gate.y - 4:
			sfx.emit("door")
			G.pull = {t = 0.0, fx = P.x, fy = P.y, tx = mg.gate.x, ty = mg.gate.y - 46, what = "gate", dur = 1.3}
	for c in G.chests:
		if c.open:
			c.t += dt; continue
		if c.get("opening", -1.0) >= 0:
			c.opening += dt
			if c.opening >= .5: open_chest(c)        # 0.5초 뒤 뚜껑이 열리며 쏟아진다
			continue
		if hyp(P.x - c.x, P.y - c.y) < 34:
			c.opening = 0.0; sfx.emit("creak")
	# 포탈: 다가가면 천천히 걸어 들어가며 화면이 어두워진다
	if G.portal != null and G.portal.get("vis", false) and G.time > G.portal.get("close_at", 0.0) + .6: G.portal = null
	if G.portal != null and G.pull == null and not G.portal.get("vis", false) and G.time - G.portal.get("born", -9.0) > .5 and hyp(P.x - G.portal.x, P.y - (G.portal.y + 8)) < 30:
		sfx.emit("portal")
		G.pull = {t = 0.0, fx = P.x, fy = P.y, tx = G.portal.x, ty = G.portal.y - 4, what = "portal", dur = 1.1}
	upd_terrace_event(dt)
	for hd in G.herds:
		if hd.aggro: continue
		hd.t -= dt
		if hd.t <= 0:
			hd.t = rnd(3.0, 7.0)
			var a := rnd(0, TAU); var L := rnd(40, 140)
			var nx: float = hd.x + cos(a) * L; var ny: float = hd.y + sin(a) * L
			if not mg.hits(nx, ny, 40): hd.tx = nx; hd.ty = ny
		var ddx: float = hd.tx - hd.x; var ddy: float = hd.ty - hd.y; var dl := hyp(ddx, ddy)
		if dl > 2:
			hd.x += ddx / dl * min(28.0 * dt, dl); hd.y += ddy / dl * min(28.0 * dt, dl)
	if G.floor == 0 and G.redPortal != null and G.pull == null and hyp(P.x - G.redPortal.x, P.y - (G.redPortal.y + 8)) < 30:
		sfx.emit("portal")
		G.pull = {t = 0.0, fx = P.x, fy = P.y, tx = G.redPortal.x, ty = G.redPortal.y - 4, what = "cow", dur = 1.1}
	for k in P.secCd.keys(): P.secCd[k] = max(0.0, P.secCd[k] - dt)
	var stas = in_stasis(P)
	P.mp = min(P.maxmp, P.mp + (8 * (1 + .25 * P["pass"].get("calm", 0) + P.st.regen) + .3 * P.lv + (10 if stas else 0)) * dt)
	P.hp = min(P.maxhp, P.hp + (.4 + (4 if stas else 0)) * dt)
	if P.poisonT > 0:
		P.poisonT -= dt; P.hp = max(1.0, P.hp - P.poisonDps * dt)
	if G.sb != null:
		if G.sb.god: P.hp = P.maxhp
		if G.sb.mana: P.mp = P.maxmp
		if G.sb.nocd:
			for k in P.secCd.keys(): P.secCd[k] = 0.0
	if inp.firing and P.active != null and G.floor > 0: fire(dt, inp.ang)
	G.revT -= dt
	if G.revT <= 0:
		mg.reveal(P.x, P.y); G.revT = .12
	for r in mg.rooms:
		if not r.seen and P.x > r.x * T and P.x < (r.x + r.w) * T and P.y > r.y * T and P.y < (r.y + r.h) * T: r.seen = true
	# 계단·테라스 문: 회색 반원 안에 들어서면 빨려 들어가듯 걸어 들어가며 화면이 어두워진다
	if G.pull != null:
		# 계단은 천천히 한 걸음씩 걸어 올라(내려)간다
		G.pull.t += dt
		var dur: float = G.pull.get("dur", 1.0)
		var k: float = min(1.0, G.pull.t / (dur * .92))
		var pf: float = G.pull.get("face", -PI / 2)
		P.x = lerp(G.pull.fx, G.pull.tx, k); P.y = lerp(G.pull.fy, G.pull.ty, k); P.vx = cos(pf) * 40.0; P.vy = sin(pf) * 40.0; P.face = pf
		_set_anim(P, "run"); P.at += dt * .85     # 실제로 한 걸음씩 걷는 동작
		if G.pull.t >= dur:
			var what: String = G.pull.what; G.pull = null
			match what:
				"gate":
					if (G.waypoints.size() > 1 or int(G.cowQ) == 1) and not active_list().is_empty():
						P.x = mg.gate.x; P.y = mg.gate.y + 60; set_state("gate"); ui.emit("gate")
					else:
						P.x = mg.gate.x; P.y = mg.gate.y + 60; enter_tower()
				"portal": _portal_go()
				"cow": enter_cow()
				"stairs": next_floor()
				"down": prev_floor()
				"door": enter_terrace()
				"back": leave_terrace()
		return
	if G.floor > 0:
		for o in [[mg.stairs, "stairs"], [mg.down, "down"], [mg.door, "back" if mg.terrace else "door"]]:
			var st = o[0]
			if st == null: continue
			if st.get("side", "") != "":
				# 동·서·남쪽 문: 문턱에 닿으면 그쪽으로 걸어 나간다
				if hyp(P.x - st.x, P.y - st.y) < 30:
					sfx.emit("door")
					G.pull = {t = 0.0, fx = P.x, fy = P.y, tx = st.x + st.dx * 46, ty = st.y + st.dy * 46, what = o[1], dur = 1.0, face = atan2(st.dy, st.dx)}
					return
				continue
			var near: bool = hyp(P.x - st.x, P.y - st.y) < (44 if st.get("alcove", false) else 20) and P.y >= st.y - 4
			if near and (st.get("alcove", false) or o[1] == "stairs"):
				var stair: bool = o[1] == "stairs" or o[1] == "down"
				sfx.emit("stairs" if stair else "door")
				G.pull = {t = 0.0, fx = P.x, fy = P.y, tx = st.x, ty = st.y - (58 if stair else 24), what = o[1], dur = 1.6 if stair else 1.0}
				return
	G.flowT -= dt
	if G.flowT <= 0:
		mg.build_flow(P.x, P.y); G.flowT = .25

	# 적
	if not (G.sb != null and G.sb.still):
		for e in G.enemies:
			if not e.dead: upd_enemy(e, dt)
	for e in G.enemies:
		if e.dead: continue
		e.at += dt
		if e.frozenT > 0:
			e.at -= dt; continue
		if e.atkT > 0:
			e.atkT -= dt; _set_anim(e, "attack")
		elif e.hitT > 0:
			e.hitT -= dt; _set_anim(e, "hit")
		else: _set_anim(e, "run" if hyp(e.vx, e.vy) > 10 else "stance")
	for c in G.corpses: c.t += dt
	G.corpses = G.corpses.filter(func(c): return c.t < 9)
	for a in G.anims: a.t += dt
	G.anims = G.anims.filter(func(a): return a.t < a.life)
	P.at += dt
	if P.hitT > 0: P.hitT -= dt
	_set_anim(P, "hit" if P.hitT > 0 else ("run" if hyp(P.vx, P.vy) > 22 else "stance"))   # 시전도 한 손 스태프 자세 그대로(끝만 빛남)
	if P.anim == "attack" and P.at >= anim_dur("player", "attack"): P.at = 0.0
	var live: Array = G.enemies.filter(func(e): return not e.dead)
	for i in live.size():
		for j in range(i + 1, live.size()):
			var a: Dictionary = live[i]; var b: Dictionary = live[j]; var dx: float = b.x - a.x; var dy: float = b.y - a.y; var d = hyp(dx, dy); var m: float = a.r + b.r
			if d > 0 and d < m:
				var k = (m - d) / 2 / d
				if not a.isBoss: mg.move(a, -dx * k, -dy * k)
				if not b.isBoss: mg.move(b, dx * k, dy * k)
	G.enemies = live.filter(func(e): return not e.dead)

	# 내 탄
	for s in G.shots:
		if s.homing:
			var t = null; var bd = 360.0 * 360.0
			for e in G.enemies:
				if e.dead or s.hitSet.has(e.id): continue
				if e.d.has("hidden") and hyp(e.x - P.x, e.y - P.y) > 110: continue
				var q: float = (e.x - s.x) * (e.x - s.x) + (e.y - s.y) * (e.y - s.y)
				if q < bd:
					bd = q; t = e
			if t != null:
				var want = atan2(t.y - s.y, t.x - s.x); var cur = atan2(s.vy, s.vx)
				var na = cur + clampf_(ang_diff(want, cur), -s.homing * dt, s.homing * dt)
				s.vx = cos(na) * s.speed; s.vy = sin(na) * s.speed
		s.x += s.vx * dt; s.y += s.vy * dt; s.life -= dt
		if mg.solid_at(s.x, s.y):
			s.life = 0.0
			if s.els.has("fire"):
				fire_explode(s.x - s.vx * dt * 2, s.y - s.vy * dt * 2, .7); sfx.emit("boom")
			continue
		if s.els.has("fire"):
			# 불덩이 꼬리: 뒤로 흩어지며 커지고 노랑→주황→검붉게 식는 불꽃
			for i in 3:
				G.fx.append({flame = 1, x = s.x + rnd(-3, 3), y = s.y + rnd(-3, 3), vx = -s.vx * .12 + rnd(-25, 25), vy = -s.vy * .12 + rnd(-25, 25), life = rnd(.22, .36), max = .36,
					color = "#ff8a3a", size = rnd(4.5, 7.0), h = shot_h + rnd(-.06, .1)})
		elif randf() < .5: G.fx.append({x = s.x, y = s.y, vx = rnd(-20, 20), vy = rnd(-20, 20), life = .25, max = .25, color = s.color, size = s.r * .6, h = shot_h})
		for e in G.enemies:
			if e.dead or s.hitSet.has(e.id): continue
			if hyp(e.x - s.x, e.y - s.y) < e.r + s.r:
				if shot_hit(s, e): s.life = 0.0
				break
	G.shots = G.shots.filter(func(s): return s.life > 0)

	# 적 탄
	for s in G.eshots:
		if s.homing:
			var want = atan2(P.y - s.y, P.x - s.x); var cur = atan2(s.vy, s.vx); var sp2 = hyp(s.vx, s.vy)
			var na = cur + clampf_(ang_diff(want, cur), -s.homing * dt, s.homing * dt); s.vx = cos(na) * sp2; s.vy = sin(na) * sp2
		var stf = .35 if in_stasis(s) else 1.0
		s.x += s.vx * dt * stf; s.y += s.vy * dt * stf; s.life -= dt
		var boom = false
		if mg.solid_at(s.x, s.y):
			s.life = 0.0; boom = true
		elif hyp(P.x - s.x, P.y - s.y) < P.r + s.r:
			s.life = 0.0; boom = true; hurt_player(s.dmg)
			if s.kind == "ice": P.slowT = 1.6
			if s.kind == "poison":
				P.poisonT = 4.0; P.poisonDps = s.dmg * .7
		if boom:
			var colr: String = {fire = "#ff6a2a", ice = "#9fd0ff", poison = "#8fd14f", skull = "#b77bff", spit = "#d98a9a"}.get(s.kind, "#d8c8a0")
			burst(s.x, s.y, colr, 6, 90, .3, 2)
			if s.blast:
				ring(s.x, s.y, 4, s.blast, .25, "#ff6a2a")
				if hyp(P.x - s.x, P.y - s.y) < s.blast and P.inv <= 0: hurt_player(s.dmg * .5)
		if G.state != "play": return
	G.eshots = G.eshots.filter(func(s): return s.life > 0)

	# 구역
	var fired: Array = []
	for z in G.zones:
		if z.get("pre", 0.0) > 0:
			z.pre -= dt; continue          # 아직 나타나기 전(차례차례 터지는 장판)
		z.life -= dt
		if z.kind == "tele" and z.life <= 0: fired.append(z)
		if z.kind == "pool":
			z.tick -= dt
			if z.tick <= 0 and hyp(P.x - z.x, P.y - z.y) < z.r:
				z.tick = .5; hurt_player(z.dps * .5)
		if z.kind == "ember" or z.kind == "acid":
			for e in G.enemies:
				if not e.dead and hyp(e.x - z.x, e.y - z.y) < z.r + e.r: damage_enemy(e, z.dps * dt, {fire = true} if z.kind == "ember" else null, true)
			if z.kind == "acid" and randf() < dt * 30:
				G.fx.append({x = z.x + rnd(-z.r, z.r) * .9, y = z.y - 30 + rnd(-10, 10), vx = 0.0, vy = 180.0, life = .25, max = .25, color = "#a6e34f", size = 2.0, rain = 1})
		if z.kind == "warn" and z.life <= 0:
			ring(z.x, z.y, 10, z.r, .3, "#e6dcc4"); burst(z.x, z.y, "#9b927f", 24, 240, .4, 4)
			if hyp(P.x - z.x, P.y - z.y) < z.r: hurt_player(z.dmg)
	G.zones = G.zones.filter(func(z): return z.life > 0)
	for z in fired: tele_fire(z)
	for l in G.lights: l.life -= dt
	G.lights = G.lights.filter(func(l): return l.life > 0)

	# 아이템
	for d in G.drops:
		d.t += dt
		if d.kind == "item" and P.bag.size() >= P.bagMax and hyp(P.x - d.x, P.y - d.y) < 16:
			if not d.get("warned", false):
				toast.emit("가방이 가득 찼어요"); d.warned = true
			continue
		if d.has("vx"):
			if not mg.hits(d.x + d.vx * dt, d.y, 3): d.x += d.vx * dt
			else: d.vx *= -.5
			if not mg.hits(d.x, d.y + d.vy * dt, 3): d.y += d.vy * dt
			else: d.vy *= -.5
			d.vx *= 1 - 3 * dt; d.vy *= 1 - 3 * dt
			d.vh -= 420 * dt; d.h += d.vh * dt
			if d.h < 0:
				d.h = 0.0; d.vh = -d.vh * .4
				if absf(d.vh) < 20: d.vh = 0.0
		var dd = hyp(P.x - d.x, P.y - d.y)
		if d.get("noPick", 0):
			if dd > 70: d.noPick = 0
			else: continue
		var full_item: bool = d.kind == "item" and P.bag.size() >= P.bagMax
		if full_item and dd < 40: d.noPick = 1          # 가방이 꽉 찼으면 한 번 끌려왔다가 그 자리에 멈춘다
		if dd < 95 and d.t > 1.5 and not full_item:        # 떨어지고 1.5초 뒤에 싹 끌려온다
			var k: float = min(1.0, (95 - dd) / 95 * 8 * dt + .02); d.x += (P.x - d.x) * k * 3; d.y += (P.y - d.y) * k * 3
		if dd < 16 and d.t > 1.2:
			d.got = true
			if d.kind in ["hp", "mp", "pothp", "potmp", "scroll"]: sfx.emit("pickup")
			if d.kind == "hp":
				var v: float = P.maxhp * .25; P.hp = min(P.maxhp, P.hp + v); float_text(P.x, P.y - 18, "+%d" % int(round(v)), "#ff8a8a")
			elif d.kind == "mp":
				var v: float = P.maxmp * .35; P.mp = min(P.maxmp, P.mp + v); float_text(P.x, P.y - 18, "+%d" % int(round(v)), "#8ab0ff")
			elif d.kind == "stone":
				sfx.emit("gem"); P.stones = int(P.get("stones", 0)) + 1; float_text(P.x, P.y - 22, "강화석 +1", "#bfe6ff"); ring(d.x, d.y, 2, 22, .3, "#bfe6ff")
			elif d.kind in ["pothp", "potmp", "scroll"]:
				var it = D.shop(d.kind)
				if P.pot.get(d.kind, 0) < pot_max(d.kind):
					P.pot[d.kind] = P.pot.get(d.kind, 0) + 1; float_text(P.x, P.y - 20, it.name, "#fff2c2"); ui.emit("belt")
				else:
					G.gold += 10; float_text(P.x, P.y - 20, "가득 참 · 금화 +10", "#ffd76a")
				ring(d.x, d.y, 2, 16, .25, "#fff2c2")
			elif d.kind == "item":
				if P.bag.size() >= P.bagMax:
					d.got = false
					if not d.get("warned", false):
						toast.emit("가방이 가득 찼어요"); d.warned = true
					continue
				P.bag.append(d.it); G.bagNew = true; ui.emit("bagbtn"); sfx.emit("item")
				float_text(P.x, P.y - 24, d.it.name, D.RAR[d.it.rar].color); ring(d.x, d.y, 2, 22, .3, D.RAR[d.it.rar].color)
			else:
				sfx.emit("coin" if randf() < .5 else "coin2"); G.gold += d.v; G.goldPulse = .35; float_text(P.x + 8, P.y - 20, "+%d" % d.v, "#ffd76a")
				for i in 8:
					var a = rnd(0, TAU)
					G.fx.append({x = d.x, y = d.y, vx = cos(a) * rnd(40, 110), vy = sin(a) * rnd(40, 110) - 30, life = .45, max = .45, color = pick(["#ffd76a", "#fff3c4", "#e3b04b"]), size = rnd(1.2, 2.4)})
				ring(d.x, d.y, 2, 16, .25, "#ffd76a")
	G.drops = G.drops.filter(func(d): return not d.get("got", false) and d.t < 40)

	# 이펙트
	for d in G.debris:
		d.vh -= 420 * dt; d.h += d.vh * dt
		if d.h < 0:
			d.h = 0.0; d.vh *= -.35; d.vx *= .55; d.vy *= .55; d.vr *= .5
			if absf(d.vh) < 15: d.vh = 0.0
		var nx: float = d.x + d.vx * dt; var ny: float = d.y + d.vy * dt
		if not mg.solid_at(nx, ny):
			d.x = nx; d.y = ny
		else:
			d.vx *= -.4; d.vy *= -.4
		d.rot += d.vr * dt
		if d.h == 0 and d.vh == 0: d.life -= dt * .4
	G.debris = G.debris.filter(func(d): return d.life > 0)
	if G.portal != null: G.portalT += dt
	for f in G.fx:
		f.life -= dt
		if f.has("rel"):
			f.d += f.dv * dt; f.dv *= 1 - 1.5 * dt
			var ca: float = G.cone.ang if G.cone != null else P.face
			f.x = P.x + cos(ca + f.a) * f.d; f.y = P.y + sin(ca + f.a) * f.d
			if f.d > f.lim: f.life = 0.0
			continue
		f.x += f.vx * dt; f.y += f.vy * dt
		if not f.has("rain") and not f.has("smoke"):
			f.vx *= 1 - 3 * dt; f.vy *= 1 - 3 * dt
		if f.has("wall") and mg.solid_at(f.x, f.y): f.life = 0.0
	G.fx = G.fx.filter(func(f): return f.life > 0)
	for r in G.rings: r.life -= dt
	G.rings = G.rings.filter(func(r): return r.life > 0)
	for b in G.bolts: b.life -= dt
	G.bolts = G.bolts.filter(func(b): return b.life > 0)
	for t in G.texts:
		t.life -= dt; t.y -= 30 * dt
	G.texts = G.texts.filter(func(t): return t.life > 0)
	if G.pendingLv > 0 and G.state == "play":
		G.lvDelay -= dt
		if G.lvDelay <= 0:
			set_state("levelup"); ui.emit("levelup")

func _set_anim(o: Dictionary, a: String) -> void:
	if o.anim != a:
		o.anim = a; o.at = 0.0

# ================= 샌드박스 =================
func sand_start() -> void:
	new_game("easy"); G.sb = {god = true, mana = true, nocd = false, still = false}
	P.prim.arcane = 1; P.active = "arcane"; G.resume = 1; enter_tower()

func sand_goto(f: int) -> void:
	G.floor = f; gen_floor()

func sand_spawn(id: String) -> void:
	var m: Dictionary = D.MONSTERS[id]
	for i in 3:
		var a = rnd(0, TAU); var x: float = P.x + cos(a) * 180; var y: float = P.y + sin(a) * 180
		if mg.hits(x, y, m.r):
			x = P.x + cos(a) * 60; y = P.y + sin(a) * 60
		if mg.hits(x, y, m.r):
			x = P.x; y = P.y - 40
		var e = spawn_enemy(id, x, y); e.aggro = true

func sand_boss(f: int) -> void:
	var bd: Dictionary = D.BOSSES[f]; var x: float = P.x; var y: float = P.y - 200
	if mg.hits(x, y, bd.r): y = P.y + 200
	if mg.hits(x, y, bd.r):
		x = P.x; y = P.y - 60
	spawn_boss(bd, x, y)

# ================= 상점 =================
func roll_shop() -> void:
	# 마을에 올 때마다 바뀌는 싼 장비 몇 개(옵션 적은 마법 등급)
	G.shop = []
	var lv: int = max(1, G.resume - 3 + 100 * int(G.tier))
	for i in 4:
		var it := make_item("magic" if i < 3 else pick(["magic", "magic", "rare"]), lv)
		it.value = item_value(it)
		it.price = int(round(it.value * 3 / 10.0)) * 10        # 파는 값 = 사는 값의 1/3
		G.shop.append(it)

func buy_item(i: int) -> bool:
	var it = G.shop[i]
	if G.gold < it.price:
		toast.emit("금화가 모자라요"); return false
	if P.bag.size() >= P.bagMax:
		toast.emit("가방이 가득 찼어요"); return false
	G.gold -= it.price; it.erase("price"); P.bag.append(it); G.shop.remove_at(i); G.bagNew = true; save()
	toast.emit("%s 구입" % it.name); return true

func buy_bag() -> bool:
	if P.bagMax >= D.BAG_LIMIT: return false
	var price := D.bag_price(P.bagMax)
	if G.gold < price:
		toast.emit("금화가 모자라요"); return false
	G.gold -= price; P.bagMax = min(D.BAG_LIMIT, P.bagMax + D.BAG_STEP); save(); toast.emit("가방이 %d칸이 됐어요" % P.bagMax); return true

# ================= 보스 패턴 =================
# 로스트아크·디아4·메이플식: 빨간 장판(예고) → 터짐. 원형·도넛(안/밖)·직선 돌진·부채꼴 베기·땅 가르기·운석·십자 광선·
# 회전 탄막·가시 방사·끌어당기기·순간이동·소환·안전지대·(최종) 봉인 무적.
# lvl: 1 = 5층 네임드, 1.3 = 10·30층, 2.2~3.4 = 20·40·60·80층 계층 수호자, 3.6 = 옥상 최종
const PAT := {
	golem = ["slam", "charge", "quake", "cleave", "inout", "summon", "shards", "pull", "charge"],
	flesh = ["spikes", "acidrain", "quake", "charge", "summon", "cleave", "spin", "acidrain"],
	warlock = ["skulls", "blink", "cross", "meteor", "spin", "inout", "summon", "rings"],
	final = ["skulls", "blink", "cross", "meteor", "spin", "inout", "summon", "rings", "spikes", "quake"],
	melee = ["charge", "slam", "cleave", "quake", "spikes", "inout"],
	ranged = ["spikes", "spin", "meteor", "cleave", "skulls", "rings"],
	elite = ["charge", "slam", "cleave", "charge"],
	rabbit = ["charge", "slam", "quake", "charge"],
}

func boss_setup(e: Dictionary, pool: String, lvl: float) -> void:
	e.pk = pool; e.lvl = lvl; e.pt = 2.2 if pool != "elite" else 1.5
	e.cast = 0.0; e.dash = null; e.spin = null; e.last = ""; e.q = []; e.stun = 0.0; e.pullT = 0.0

func _tt(e: Dictionary, k := 1.0) -> float:
	return max(.55, 1.05 - .09 * float(e.lvl)) * k

# 예고 장판 하나. shape: circle(r) · donut(r0,r) · line(ang,len,w) · fan(ang,half,len) · safe(spots,sr)
func tele(shape: String, x: float, y: float, delay: float, dmg: float, ex := {}) -> Dictionary:
	var z := {kind = "tele", shape = shape, x = x, y = y, life = delay, max = delay, dmg = dmg, pre = 0.0, cap = .45}
	for k in ex.keys(): z[k] = ex[k]
	G.zones.append(z); return z

func in_tele(z: Dictionary, px: float, py: float, pr: float) -> bool:
	var dx: float = px - z.x; var dy: float = py - z.y; var d := hyp(dx, dy)
	match z.shape:
		"circle": return d < z.r + pr * .5
		"donut": return d > z.r0 - pr * .5 and d < z.r + pr * .5
		"line":
			var t: float = dx * cos(z.ang) + dy * sin(z.ang); var o: float = absf(-dx * sin(z.ang) + dy * cos(z.ang))
			return t > -pr and t < z.len + pr and o < z.w + pr * .5
		"fan": return d < z.len + pr * .5 and absf(ang_diff(atan2(dy, dx), z.ang)) < z.half
		"safe":
			for q in z.spots:
				if hyp(px - q.x, py - q.y) < z.sr: return false
			return true
	return false

func tele_fire(z: Dictionary) -> void:
	var col: String = z.get("col", "#e6dcc4")
	match z.shape:
		"circle":
			ring(z.x, z.y, 6, z.r, .3, col); burst(z.x, z.y, col, int(10 + z.r / 6), 60 + z.r * 2, .4, 3)
		"donut":
			ring(z.x, z.y, z.r0, z.r, .35, col)
			for k in 10:
				var a := k * TAU / 10 + rnd(0, .5); var rr: float = rnd(z.r0, z.r)
				burst(z.x + cos(a) * rr, z.y + sin(a) * rr, col, 4, 120, .35, 3)
		"line":
			for k in int(z.len / 40):
				var t := (k + .5) * 40.0
				burst(z.x + cos(z.ang) * t, z.y + sin(z.ang) * t, col, 3, 90, .3, 3)
		"fan":
			for k in 8:
				var a: float = z.ang + rnd(-z.half, z.half); var rr: float = rnd(20, z.len)
				burst(z.x + cos(a) * rr, z.y + sin(a) * rr, col, 4, 110, .3, 3)
		"safe":
			G.shake = .5
			for k in 24:
				burst(P.x + rnd(-300, 300), P.y + rnd(-220, 220), col, 4, 140, .4, 3)
	if z.get("warn_only", false): return
	G.shake = max(G.shake, .18); sfx.emit("boom" if z.shape != "line" else "hit")
	if in_tele(z, P.x, P.y, P.r): hurt_player(min(z.dmg, P.maxhp * z.cap))
	if z.has("pool"):
		G.zones.append({kind = "pool", x = z.x, y = z.y, r = z.r * .9, life = z.pool, max = z.pool, dps = z.dmg * .3, tick = 0.0, col = z.get("pcol", "#8fd14f")})

func _add_pos(e: Dictionary, rad: float) -> Vector2:
	for k in 12:
		var a := rnd(0, TAU); var p := Vector2(e.x + cos(a) * rad * rnd(.7, 1.2), e.y + sin(a) * rad * rnd(.7, 1.2))
		if not mg.hits(p.x, p.y, 14) and not mg.no_spawn(p.x, p.y): return p
	return Vector2(e.x, e.y)

func _shot_kind(e: Dictionary) -> String:
	match e.pk:
		"flesh": return "spit"
		"warlock", "final": return "skull"
		"golem": return "spike"
	match e.d.get("atk", "melee"):
		"orb": return String(e.d.get("orb", e.get("orb", "ice")))
		"fireball": return "fire"
		"skull": return "skull"
	return "spike"

# 매 프레임. true 를 돌려주면 이번 프레임은 패턴이 몸을 잡고 있으니 평소 이동은 건너뜀
func boss_pat(e: Dictionary, dt: float) -> bool:
	var lv: float = e.lvl
	# 미뤄 둔 일(연속 탄막 등)
	for qi in range(e.q.size() - 1, -1, -1):
		var it: Dictionary = e.q[qi]; it.t -= dt
		if it.t <= 0:
			e.q.remove_at(qi); _pat_then(e, it)
	if e.pk == "final": _final_phase(e, dt)
	if e.hp < e.max * .4 and not e.get("enr", false):
		e.enr = true; e.spd *= 1.18; ring(e.x, e.y, e.r, e.r + 50, .5, "#ff5a4a")
		if e.isBoss: G.banner = {text = "%s 이(가) 분노했다!" % e.get("name", "보스"), t = 1.6}
	if e.dash != null:
		var ds: Dictionary = e.dash; ds.t -= dt
		var step: float = ds.spd * dt; var ox: float = e.x; var oy: float = e.y
		mg.move(e, cos(ds.ang) * step, sin(ds.ang) * step)
		e.vx = cos(ds.ang) * ds.spd * .2; e.vy = sin(ds.ang) * ds.spd * .2
		if randf() < dt * 25: smoke(e.x, e.y + 6, 1, "#4a4038")
		if not ds.hit and hyp(P.x - e.x, P.y - e.y) < e.r + P.r + 8:
			ds.hit = true; hurt_player(min(ds.dmg, P.maxhp * .45)); mg.move(P, cos(ds.ang) * 30, sin(ds.ang) * 30)
		var moved := hyp(e.x - ox, e.y - oy)
		if ds.t <= 0 or moved < step * .3:
			e.dash = null
			if moved < step * .3:
				# 벽에 쾅: 잠깐 휘청 + (강한 보스는) 파편이 사방으로
				burst(e.x, e.y, "#b8a888", 22, 200, .4, 3); G.shake = .3; e.stun = .7; sfx.emit("boom")
				if lv >= 2: _radial(e, int(8 + 2 * lv), "spike", 170.0, e.dmg * .5, rnd(0, 1))
			if ds.n > 1:
				e.q.append({t = .35, k = "recharge", n = ds.n - 1})
		return true
	if e.stun > 0:
		e.stun -= dt; e.vx = 0.0; e.vy = 0.0; return true
	if e.spin != null:
		var sp: Dictionary = e.spin; sp.t -= dt; sp.cd -= dt; sp.ang += sp.rate * dt
		if sp.cd <= 0:
			sp.cd = sp.every
			for k in sp.arms: enemy_shot(e, sp.kind, sp.ang + k * TAU / sp.arms, sp.speed, {r = 7.0, dmg = sp.dmg, life = 3.2})
		if sp.t <= 0: e.spin = null
		e.vx = 0.0; e.vy = 0.0
		return true
	if e.pullT > 0:
		e.pullT -= dt
		var dx: float = e.x - P.x; var dy: float = e.y - P.y; var dl: float = max(1.0, hyp(dx, dy))
		if dl > e.r + P.r + 10: mg.move(P, dx / dl * 105 * dt, dy / dl * 105 * dt)
		if randf() < dt * 30: G.fx.append({x = P.x + rnd(-20, 20), y = P.y + rnd(-20, 20), vx = dx / dl * 120, vy = dy / dl * 120, life = .3, max = .3, color = "#c9a3ff", size = 2.0})
	if e.cast > 0:
		e.cast -= dt; e.vx *= .8; e.vy *= .8
		return true
	var d := hyp(P.x - e.x, P.y - e.y)
	e.pt -= dt * (1.35 if e.get("enr", false) else 1.0)
	if e.pt <= 0 and d < 560 and not e.get("seal", false):
		var pool: Array = PAT[e.pk]
		var p: String = pick(pool)
		for k in 4:
			if p != e.last: break
			p = pick(pool)
		e.last = p
		_pat(e, p, d)
		e.pt = 3.6 / (.55 + .45 * lv) * rnd(.85, 1.2) + e.cast
		if e.pk == "elite": e.pt += 1.6
		# 강한 보스는 가끔 패턴 두 개를 겹쳐 씀
		if lv >= 2.5 and e.get("enr", false) and randf() < .35:
			e.q.append({t = e.cast * .6, k = "extra"})
	return false

# 벽에 닿기 전까지의 길이
func _ray_len(x: float, y: float, ang: float, mx: float) -> float:
	var l := 0.0
	while l < mx and not mg.solid_at(x + cos(ang) * l, y + sin(ang) * l): l += 10.0
	return l

func _radial(e: Dictionary, n: int, kind: String, speed: float, dmg: float, off := 0.0) -> void:
	for k in n: enemy_shot(e, kind, off + k * TAU / n, speed, {r = 7.0, dmg = dmg, life = 3.4})
	ring(e.x, e.y, e.r, e.r + 40, .3, "#ffdca0")

func _pat(e: Dictionary, p: String, d: float) -> void:
	var lv: float = e.lvl; var dm: float = e.dmg; var tt := _tt(e)
	var a := atan2(P.y - e.y, P.x - e.x)
	var col := "#e6dcc4"
	match e.pk:
		"flesh": col = "#b6e06a"
		"warlock", "final": col = "#c08aff"
	match p:
		"slam":
			# 내려찍기 → (강하면) 바깥으로 퍼지는 충격파
			var r1: float = e.r + 80 + 10 * lv
			e.cast = tt; tele("circle", e.x, e.y, tt, dm * 1.5, {r = r1, col = col})
			if lv >= 1.8: tele("donut", e.x, e.y, tt + .55, dm * 1.2, {r0 = r1, r = r1 + 110 + 15 * lv, col = col})
		"charge":
			e.cast = tt
			tele("line", e.x, e.y, tt, 0.0, {ang = a, len = _ray_len(e.x, e.y, a, 400.0), w = e.r + 10, warn_only = true})
			var n: int = 1 + (1 if lv >= 2 else 0) + (1 if e.get("enr", false) else 0)
			e.q.append({t = tt, k = "dash", ang = a, n = n})
		"quake":
			# 땅 가르기: 나를 향해 이어 터지는 충격(강하면 세 갈래)
			e.cast = .55
			var dirs: Array = [a] if lv < 2.4 else [a - .45, a, a + .45]
			for aa in dirs:
				for k in int(6 + lv * 2):
					var q := Vector2(e.x, e.y) + Vector2(cos(aa), sin(aa)) * (55 + k * 40)
					if mg.solid_at(q.x, q.y): break
					tele("circle", q.x, q.y, tt * .75, dm * 1.2, {r = 32.0 + 3 * lv, pre = .1 + k * .085, col = col})
		"cleave":
			# 앞을 크게 베기(강하면 뒤까지 한 번 더)
			e.cast = tt * .85
			tele("fan", e.x, e.y, tt * .85, dm * 1.7, {ang = a, half = .62 + .05 * lv, len = e.r + 150 + 10 * lv, col = col})
			if lv >= 1.8: tele("fan", e.x, e.y, tt * .7, dm * 1.7, {ang = a + PI, half = .62 + .05 * lv, len = e.r + 150 + 10 * lv, pre = tt * .85, col = col})
		"inout":
			# 메이플식 안/밖: 붙어 있다가 떨어지거나, 떨어져 있다가 파고들거나
			var r1: float = e.r + 105.0
			e.cast = tt + 1.0
			var big: float = r1 + 300
			if randf() < .5:
				tele("circle", e.x, e.y, tt + .25, dm * 1.6, {r = r1, col = col}); tele("donut", e.x, e.y, tt * .9, dm * 1.6, {r0 = r1, r = big, pre = tt + .25, col = col})
			else:
				tele("donut", e.x, e.y, tt + .25, dm * 1.6, {r0 = r1, r = big, col = col}); tele("circle", e.x, e.y, tt * .9, dm * 1.6, {r = r1, pre = tt + .25, col = col})
		"summon":
			var alive := 0
			for o in G.enemies:
				if not o.dead and o.get("minion", false): alive += 1
			if alive >= int(4 + 2 * lv):
				_pat(e, "slam", d); return
			e.cast = .6; ring(e.x, e.y, 10, 90, .5, col)
			var types: Array = {golem = ["skel", "skel", "archer", "skel_knight"], flesh = ["zombie", "zombie", "plague", "imp"], warlock = ["imp", "skel", "mage", "ice_mage"], final = ["imp", "skel_knight", "mage", "fire_archer"]}.get(e.pk, [e.type])
			for k in int(2 + lv):
				var t: String = pick(types)
				if not D.MONSTERS.has(t) or D.MONSTERS[t].from > max(G.floor, 1) + 10: t = "skel"
				var pp := _add_pos(e, 70.0)
				var s = spawn_enemy(t, pp.x, pp.y); s.aggro = true; s.xp = 1; s.minion = true
				smoke(pp.x, pp.y, 4)
		"shards", "spikes":
			# 가시 방사: 한 바퀴 빙 둘러 쏨, 강하면 엇갈린 파도 여러 번
			e.cast = .5
			var n: int = int(10 + 3 * lv); var waves: int = 1 + (1 if lv >= 1.8 else 0) + (1 if lv >= 3 else 0)
			for w in waves: e.q.append({t = .3 + w * .45, k = "radial", n = n, off = w * PI / n + rnd(0, .3), kind = _shot_kind(e), dmg = dm * .55})
		"spin":
			e.spin = {t = 2.0 + .4 * lv, cd = 0.0, every = max(.07, .17 - .025 * lv), ang = a, rate = (1.5 + .25 * lv) * pick([-1, 1]), arms = 2 + int(lv), speed = 140.0 + 15 * lv, dmg = dm * .45, kind = _shot_kind(e)}
		"meteor", "acidrain":
			# 하늘에서 떨어짐: 내 주변으로 차례차례(산성비는 독 웅덩이를 남김)
			e.cast = .7
			var n: int = int(4 + 2 * lv)
			for k in n:
				var q := Vector2(P.x, P.y) if k == 0 else Vector2(P.x + rnd(-150, 150), P.y + rnd(-120, 120))
				var ex := {r = rnd(44, 58), pre = k * (.22 - .02 * min(lv, 3.0)), col = "#ff8a3a" if p == "meteor" else "#a6e34f"}
				if p == "acidrain": ex.pool = 3.0
				tele("circle", q.x, q.y, tt + .25, dm * 1.3, ex)
		"cross":
			# 십자 광선(강하면 X 로 한 번 더)
			e.cast = tt + .3
			var a0 := a if randf() < .5 else a + PI / 4
			for k in 4: tele("line", e.x, e.y, tt + .3, dm * 1.6, {ang = a0 + k * PI / 2, len = _ray_len(e.x, e.y, a0 + k * PI / 2, 560.0), w = 26.0, col = col})
			if lv >= 2.4:
				for k in 4: tele("line", e.x, e.y, tt * .8, dm * 1.6, {ang = a0 + PI / 4 + k * PI / 2, len = _ray_len(e.x, e.y, a0 + PI / 4 + k * PI / 2, 560.0), w = 26.0, pre = tt + .3, col = col})
		"rings":
			# 퍼져 나가는 고리: 터진 고리 안쪽으로 파고들어야 함
			e.cast = .6
			var rr: float = e.r + 10.0
			for k in int(3 + lv):
				tele("donut", e.x, e.y, .75, dm * 1.1, {r0 = rr, r = rr + 85, pre = .2 + k * (.55 - .05 * min(lv, 3.0)), col = col})
				rr += 85
		"skulls":
			e.cast = .45
			for k in int(2 + lv): enemy_shot(e, "skull", a + (k - (1 + lv) / 2.0) * .35, 150, {r = 9.0, homing = 2.0 + .2 * lv, life = 5.0, dmg = dm * .7})
		"blink":
			var r: Dictionary = mg.rooms[0]
			for k in 14:
				var nx: float = (r.x + rnd(2, r.w - 2)) * T; var ny: float = (r.y + rnd(2, r.h - 2)) * T
				if not mg.hits(nx, ny, e.r) and hyp(nx - P.x, ny - P.y) > 160 and hyp(nx - P.x, ny - P.y) < 380:
					burst(e.x, e.y, col, 16, 140, .4, 3); e.x = nx; e.y = ny; burst(nx, ny, col, 16, 140, .4, 3); break
			if lv >= 2: e.q.append({t = .3, k = "pat", p = pick(["skulls", "rings", "cross"])})
		"pull":
			# 끌어당긴 뒤 내려찍기
			e.cast = 1.5; e.pullT = 1.3
			tele("circle", e.x, e.y, 1.5, dm * 1.8, {r = e.r + 95.0, col = "#c9a3ff"})
			G.banner = {text = "끌려간다! 버텨서 빠져나오자", t = 1.2}
		"safe":
			_pat_safe(e, 2)

func _pat_safe(e: Dictionary, n: int) -> void:
	# 안전지대: 방 전체가 터지고 초록 원 안만 안전
	var r: Dictionary = mg.rooms[0]; var spots: Array = []
	for k in 40:
		if spots.size() >= n: break
		var q := Vector2((r.x + rnd(2.5, r.w - 2.5)) * T, (r.y + rnd(2.5, r.h - 2.5)) * T)
		var ok: bool = not mg.hits(q.x, q.y, 30) and hyp(q.x - P.x, q.y - P.y) > 110 and hyp(q.x - P.x, q.y - P.y) < 420
		for s2 in spots:
			if hyp(q.x - s2.x, q.y - s2.y) < 200: ok = false
		if ok: spots.append(q)
	if spots.is_empty(): spots.append(Vector2(r.cx, r.cy + 80))
	e.cast = 1.0
	tele("safe", r.cx, r.cy, 3.0, P.maxhp * .7, {spots = spots, sr = 58.0, cap = .75, col = "#c08aff"})
	G.banner = {text = "초록 원 안으로 피하세요!", t = 1.8}

func _pat_then(e: Dictionary, it: Dictionary) -> void:
	if e.dead: return
	match it.k:
		"dash":
			e.dash = {ang = it.ang, t = .85, spd = 470.0 + 30 * float(e.lvl), hit = false, dmg = e.dmg * 1.7, n = it.n}
			sfx.emit("roar")
		"recharge":
			var a := atan2(P.y - e.y, P.x - e.x); var tt := _tt(e, .75)
			e.cast = tt; tele("line", e.x, e.y, tt, 0.0, {ang = a, len = _ray_len(e.x, e.y, a, 400.0), w = e.r + 10, warn_only = true})
			e.q.append({t = tt, k = "dash", ang = a, n = it.n})
		"radial": _radial(e, it.n, it.kind, 165.0 + 10 * float(e.lvl), it.dmg, it.off)
		"pat": _pat(e, it.p, hyp(P.x - e.x, P.y - e.y))
		"extra":
			var pool: Array = ["meteor", "spikes", "skulls", "quake"]
			_pat(e, pick(pool), hyp(P.x - e.x, P.y - e.y)); e.cast = min(e.cast, .3)

# 옥상 최종 보스: 체력 66%·33% 에서 봉인(무적) → 방 구석의 봉인 수호자들을 모두 쓰러뜨려야 풀림.
# 봉인 중엔 안전지대 패턴을 되풀이. 풀리면 잠깐 그로기(크게 때릴 기회). 10% 아래는 마지막 발악.
func _final_phase(e: Dictionary, dt: float) -> void:
	for ph in [[.66, "ph1", 3], [.33, "ph2", 4]]:
		if e.hp < e.max * ph[0] and not e.get(ph[1], false):
			e[ph[1]] = true; _seal(e, ph[2])
	if e.get("seal", false):
		e.sealT -= dt; e.sealFx = float(e.get("sealFx", 0.0)) - dt
		if e.sealFx <= 0:
			e.sealFx = .6; ring(e.x, e.y, e.r + 4, e.r + 26, .5, "#c9a3ff")
		var alive := 0
		for g in G.enemies:
			if not g.dead and g.get("guard", false): alive += 1
		if alive == 0:
			e.seal = false; e.stun = 2.5; e.cast = 0.0; e.spin = null
			G.banner = {text = "봉인이 깨졌다! 지금이 기회!", t = 2.0}; ring(e.x, e.y, 10, 200, .6, "#fff2c2"); sfx.emit("levelup")
		elif e.sealT <= 0 and e.cast <= 0:
			e.sealT = 9.0; _pat_safe(e, 2 if alive > 2 else 1)
	if e.hp < e.max * .1 and not e.get("desp", false):
		e.desp = true; e.lvl = 4.2; e.pt = .5
		G.banner = {text = "흑마법사가 마지막 힘을 끌어모은다!", t = 2.0}

func _seal(e: Dictionary, n: int) -> void:
	e.seal = true; e.sealT = 5.0; e.dash = null; e.spin = null
	var r: Dictionary = mg.rooms[0]
	var corners: Array = [Vector2(r.x + 3, r.y + 3), Vector2(r.x + r.w - 3, r.y + 3), Vector2(r.x + 3, r.y + r.h - 3), Vector2(r.x + r.w - 3, r.y + r.h - 3)]
	corners.shuffle()
	for k in n:
		var c: Vector2 = corners[k] * T
		if mg.hits(c.x, c.y, 16): c = _add_pos(e, 200.0)
		var g := spawn_enemy("mage", c.x, c.y, 14.0)
		g.guard = true; g.aggro = true; g.spd = 0.0; g.name = "봉인의 수호자"; g.tint = "#c9a3ff"; g.hmul = 1.25; g.xp = 1; g.minion = true
		ring(c.x, c.y, 10, 60, .5, "#c9a3ff")
	e.x = r.cx; e.y = r.cy - 40
	G.banner = {text = "봉인! 구석의 수호자를 모두 쓰러뜨려라", t = 2.4}; sfx.emit("roar")
