# 게임 규칙 전부 — 웹 버전 index.html 의 상태·전투·마법·아이템·저장을 그대로 옮김(픽셀 좌표)
class_name Game
extends Node

signal toast(msg: String)
signal ui(what: String)        # "buttons" "belt" "bag" "levelup" "end" "state" "talk"
signal rumble(ms: int, strength: float)

const T := 32.0
const SAVE_PATH := "user://save-v1.json"
const TAU_ := TAU
const AFF := {nova = "fire", freeze = "frost", stasis = "storm", acid = "arcane"}

var G = null       # 게임 상태(웹 G)
var P = null       # 플레이어(웹 P)
var mg := MapGen.new()
var uid := 0
var inp := {mx = 0.0, my = 0.0, firing = false, ang = 0.0}
var level_changed := false   # 맵이 바뀌면 true → 화면이 다시 만든다
var no_save := false          # 타이틀 배경용 마을일 때는 저장하지 않음

static func rnd(a: float, b: float) -> float: return a + randf() * (b - a)
static func ri(a: int, b: int) -> int: return int(floor(rnd(a, b + 1)))
static func pick(a: Array): return a[randi() % a.size()]
static func clampf_(v: float, a: float, b: float) -> float: return a if v < a else (b if v > b else v)
static func ang_diff(a: float, b: float) -> float:
	var d := fmod(a - b, TAU)
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
	return {x = 0.0, y = 0.0, r = 11.0, hp = 50.0, maxhp = 50, mp = 60.0, maxmp = 60, lv = 1, xp = 0, next = xp_need(1),
		prim = {arcane = 0, fire = 0, storm = 0, frost = 0}, subs = {}, sec = {}, secOrder = [], pass = {}, fusion = null, active = null,
		pot = {pothp = 2, potmp = 1, scroll = 0}, potCd = 0.0, bag = [], eq = {weapon = null, ring1 = null, ring2 = null, cloak = null},
		st = {}, ep = {}, es = {}, esec = {}, bonus = {prim = {}, sub = {}, sec = {}},
		vx = 0.0, vy = 0.0, cdShot = 0.0, ward = 0.0, hardenT = 0.0, inv = 0.0, slowT = 0.0, poisonT = 0.0, poisonDps = 0.0, face = -PI / 2,
		secCd = {}, speed = 150.0, firing = false, walk = 0.0, hitT = 0.0, at = 0.0, anim = "stance", tip = null}

func fresh_g(diff: String) -> Dictionary:
	return {corpses = [], anims = [], debris = [], floor = 0, resume = 1, diff = diff, state = "play", enemies = [], shots = [], eshots = [], zones = [],
		fx = [], rings = [], bolts = [], drops = [], texts = [], chests = [], npcs = [], portal = null,
		gold = 0, kills = 0, banner = {text = "", t = 0.0}, pendingLv = 0, flowT = 0.0, bossMax = 0.0, time = 0.0, coneT = 0.0, talkSeen = {},
		sb = null, shake = 0.0, lvDelay = 0.0, revT = 0.0, goldPulse = 0.0, bagNew = false, nearItem = null, portalT = 0.0}

func diff_d() -> Dictionary:
	for d in D.DIFFICULTIES:
		if G != null and d.id == G.diff: return d
	return D.DIFFICULTIES[0]

func has_el(el: String) -> bool:
	if P.prim.get(el, 0) > 0: return true
	return P.fusion != null and el in String(P.fusion).split("+")

func recalc() -> void:
	var pv: Dictionary = P.pass
	var st := {hp = 0.0, mp = 0.0, regen = 0.0, dmg = 0.0, cast = 0.0, cdr = 0.0, res = 0.0, spd = 0.0, gold = 0.0}
	var bp := {}; var bs := {}; var bc := {}
	for k in D.SLOTS:
		var it = P.eq.get(k)
		if it == null: continue
		for m in it.mods:
			var parts: PackedStringArray = String(m.k).split(":")
			var t := parts[0]
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
	P.speed = 138 * (1 + .08 * pv.get("swift", 0) + st.spd)

func set_state(s: String) -> void:
	G.state = s
	ui.emit("state")

func new_game(diff: String) -> void:
	no_save = false
	G = fresh_g(diff); P = fresh_p(); recalc()
	go_town(true)

func save() -> void:
	if G == null or G.sb != null or no_save: return
	var pd := {}
	for k in ["lv", "xp", "next", "prim", "subs", "sec", "secOrder", "pass", "fusion", "active", "pot", "bag", "eq"]: pd[k] = P[k]
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify({v = 1, diff = G.diff, gold = G.gold, kills = G.kills, resume = G.resume, talkSeen = G.talkSeen, P = pd, at = Time.get_unix_time_from_system()}))

static func read_save():
	if not FileAccess.file_exists(SAVE_PATH): return null
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null: return null
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else null

static func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH): DirAccess.remove_absolute(SAVE_PATH)

func _fix_ints(d) -> void:
	# JSON 은 숫자를 실수로 돌려준다 → 단계 값은 정수로
	for k in d.keys():
		if d[k] is float: d[k] = int(d[k])

func load_game(sv: Dictionary) -> void:
	no_save = false
	G = fresh_g(sv.diff); P = fresh_p()
	for k in sv.P.keys(): P[k] = sv.P[k]
	P.lv = int(P.lv); P.xp = int(P.xp); P.next = int(P.next)
	for k in ["prim", "subs", "sec", "pass", "pot"]: _fix_ints(P[k])
	var eq := {weapon = null, ring1 = null, ring2 = null, cloak = null}
	for k in P.eq.keys(): eq[k] = P.eq[k]
	P.eq = eq
	G.gold = int(sv.get("gold", 0)); G.kills = int(sv.get("kills", 0)); G.resume = int(sv.get("resume", 1)); G.talkSeen = sv.get("talkSeen", {})
	recalc(); P.hp = P.maxhp; P.mp = P.maxmp
	go_town(false)

func clear_level() -> void:
	G.corpses = []; G.anims = []; G.debris = []; G.chests = []; G.enemies = []; G.shots = []; G.eshots = []; G.zones = []; G.drops = []; G.fx = []
	G.rings = []; G.bolts = []; G.texts = []; G.bossMax = 0.0

# ================= 맵 =================
func go_town(first: bool) -> void:
	G.floor = 0; G.portal = null
	clear_level(); mg.gen_town()
	P.vx = 0.0; P.vy = 0.0; P.ward = 0.0
	var t = mg.town
	G.npcs = [
		{id = "guide", name = "루멘 교수", x = (t.x0 + 11) * T, y = (t.y0 + t.h - 5) * T, trim = "#e3b04b"},
		{id = "shop", name = "미라 교수", x = (t.x0 + 26) * T, y = (t.y0 + 6) * T, trim = "#ffd27a"},
	]
	P.x = mg.start.x; P.y = mg.start.y
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

func enter_tower() -> void:
	if active_list().is_empty():
		set_state("first"); return
	G.floor = G.resume if G.resume else 1
	gen_floor(); ui.emit("buttons"); set_state("play"); save()

func gen_floor() -> void:
	clear_level(); P.vx = 0.0; P.vy = 0.0; G.npcs = []; G.portal = null
	var bd = D.BOSSES.get(G.floor)
	mg.gen_floor(G.floor, bd != null)
	if bd != null:
		var r: Dictionary = mg.rooms[0]
		P.x = mg.start.x; P.y = mg.start.y
		spawn_boss(bd, r.cx, (r.y + 5) * T)
		G.banner = {text = "%d층 · %s" % [G.floor, bd.name], t = 3.0}
	else:
		P.x = mg.start.x; P.y = mg.start.y
		for i in range(1, mg.rooms.size()):
			var r: Dictionary = mg.rooms[i]
			var n: int = min(14, int(round(r.w * r.h / 24.0)) + G.floor / 3)
			var pcx: float = r.x + rnd(2, r.w - 2); var pcy: float = r.y + rnd(2, r.h - 2)
			for k in n:
				var t := pick_type(); var pack := randf() < .6
				var ex: float = (clampf_(pcx + rnd(-3, 3), r.x + 1, r.x + r.w - 1) if pack else r.x + rnd(1, r.w - 1)) * T
				var ey: float = (clampf_(pcy + rnd(-3, 3), r.y + 1, r.y + r.h - 1) if pack else r.y + rnd(1, r.h - 1)) * T
				if not mg.hits(ex, ey, D.MONSTERS[t].r): spawn_enemy(t, ex, ey)
		G.chests = []
		for i in range(1, mg.rooms.size()):
			var r: Dictionary = mg.rooms[i]
			if randf() > .4: continue
			var cx: float = (r.x + pick([1.6, r.w - 1.6])) * T; var cy: float = (r.y + pick([1.6, r.h - 1.6])) * T
			if hyp(cx - mg.stairs.x, cy - mg.stairs.y) < 60: continue
			G.chests.append({x = cx, y = cy, open = false, t = 0.0, id = nid()})
		G.banner = {text = "%d층" % G.floor, t = 2.2}
	mg.reveal(P.x, P.y); mg.build_flow(P.x, P.y)
	level_changed = true

func pick_type() -> String:
	var pool: Array = []
	for k in D.MONSTERS.keys():
		if D.MONSTERS[k].from <= G.floor: pool.append(k)
	var tot := 0.0; var ws: Array = []
	for k in pool:
		var w := 1.0 / (1 + .35 * (D.MONSTERS[k].from - 1)); tot += w; ws.append(w)
	var r := randf() * tot
	for i in pool.size():
		r -= ws[i]
		if r <= 0: return pool[i]
	return pool[0]

# ================= 적 =================
func spawn_enemy(type: String, x: float, y: float, scale := 1.0) -> Dictionary:
	var d: Dictionary = D.MONSTERS[type]; var f: float = (1 + .25 * (G.floor - 1)) * diff_d().hp
	var e := {id = nid(), type = type, d = d, x = x, y = y, r = float(d.r), hp = d.hp * f * scale, max = d.hp * f * scale, spd = d.spd * .92 * rnd(.9, 1.1),
		vx = 0.0, vy = 0.0, dmg = d.dmg * (1 + .1 * (G.floor - 1)) * diff_d().dmg, xp = int(round(d.xp * (1 + .3 * (G.floor - 1)))),
		cd = rnd(.6, d.get("cd", 1)), atkCd = 0.0, shield = d.get("shield", 0) * f, shieldMax = d.get("shield", 0) * f,
		slowT = 0.0, frozenT = 0.0, fearT = 0.0, burnT = 0.0, burnDps = 0.0, aggro = false, flash = 0.0, wob = randf() * TAU, side = 1 if randf() < .5 else -1,
		dead = false, isBoss = false, boss = "", atkT = 0.0, hitT = 0.0, at = 0.0, anim = "stance"}
	if type == "mage": e.orb = "ice" if randf() < .5 else "poison"
	G.enemies.append(e); return e

func spawn_boss(bd: Dictionary, x: float, y: float, hp_override := 0.0, r := 0.0) -> Dictionary:
	var bh: float = hp_override if hp_override > 0 else bd.hp * diff_d().hp
	var e := {id = nid(), type = "boss", boss = bd.id, name = bd.name, isBoss = true, d = {color = bd.color, undead = 1 if bd.id == "golem" else 0, atk = "melee"},
		x = x, y = y, r = r if r > 0 else float(bd.r), hp = bh, max = bh, spd = float(bd.spd), dmg = bd.dmg * diff_d().dmg, xp = 40 if (bd.id == "flesh" and hp_override > 0) else 120,
		shield = float(bd.get("shield", 0)), shieldMax = float(bd.get("shield", 0)), shieldRegen = 0.0, cd = 2.0, atkCd = 0.0, t1 = 2.0, t2 = 4.0, t3 = 6.0,
		slowT = 0.0, frozenT = 0.0, fearT = 0.0, burnT = 0.0, burnDps = 0.0, aggro = true, flash = 0.0, wob = 0.0, side = 1, split = hp_override > 0,
		vx = 0.0, vy = 0.0, dead = false, atkT = 0.0, hitT = 0.0, at = 0.0, anim = "stance"}
	G.enemies.append(e); G.bossMax += e.max; return e

static func spr_name(e: Dictionary) -> String:
	return D.BOSSMAP[e.boss] if e.isBoss else D.SPRMAP[e.type]

static func enemy_h(e: Dictionary) -> float:
	if e.boss == "flesh": return e.r * 1.9
	return float(D.SPRH.get(e.boss if e.isBoss else e.type, 46))

static func anim_dur(name: String, anim: String) -> float:
	var m: Dictionary = Actor.meta().get(name, {})
	if m.has("anims") and m.anims.has(anim): return m.anims[anim].dur / 1000.0
	return .4

func damage_enemy(e: Dictionary, amt: float, els, silent := false) -> void:
	if e.dead or amt <= 0: return
	if e.shield > 0:
		var a: float = min(e.shield, amt); e.shield -= a; amt -= a; e.shieldRegen = 7.0
		if e.shield <= 0: ring(e.x, e.y, e.r, e.r + 24, .3, "#9fd0ff")
	e.hp -= amt; e.flash = .08; e.aggro = true
	if e.atkT <= 0: e.hitT = min(.22, anim_dur(spr_name(e), "hit"))
	if els != null:
		if els.has("fire") and P.es.burn:
			e.burnT = 2.0 + P.es.burn; e.burnDps = max(e.burnDps, 3 * P.es.burn * (1 + .15 * P.lv))
		if els.has("frost"): e.slowT = max(e.slowT, 1.2)
		if els.has("storm") and P.es.shock: e.slowT = max(e.slowT, .4 + .3 * P.es.shock)
	if not silent and amt >= 1: float_text(e.x, e.y - e.r, str(int(round(amt))), "#f3e3c0")
	if e.boss == "flesh" and not e.split and e.hp < e.max * .5 and e.hp > 0:
		split_flesh(e); return
	if e.hp <= 0: kill_enemy(e)

func split_flesh(e: Dictionary) -> void:
	e.dead = true; burst(e.x, e.y, "#c46f80", 30, 180, .7, 4); G.bossMax -= e.max
	var bd: Dictionary = D.BOSSES[10]
	for s in [-1, 1]:
		var c := spawn_boss(bd, e.x + s * 36, e.y, max(60.0, e.hp * .65), 24.0); c.t1 = 1.5 + s * .4
	toast.emit("여왕 개미귀신이 둘로 갈라졌다!")

func debris(x: float, y: float, shape: String, color: String, n := 1, sp := 120.0) -> void:
	for i in n:
		var a := rnd(0, TAU); var v := rnd(30, sp)
		G.debris.append({x = x, y = y, h = 6.0, vh = rnd(60, 150), vx = cos(a) * v, vy = sin(a) * v * .7, rot = rnd(0, TAU), vr = rnd(-12, 12), life = 5.0, shape = shape, color = color, s = rnd(1.6, 3.2)})
	if G.debris.size() > 160: G.debris = G.debris.slice(G.debris.size() - 160)

func fx_anim(name: String, x: float, y: float, size: float, life := 0.0, rot := 0.0) -> void:
	if not Actor.meta().has(name): return
	G.anims.append({name = name, x = x, y = y, size = size, t = 0.0, life = life if life > 0 else anim_dur(name, "idle"), rot = rot})
	if G.anims.size() > 60: G.anims.pop_front()

func smoke(x: float, y: float, n: int, c := "#2a2430") -> void:
	for i in n:
		G.fx.append({x = x + rnd(-8, 8), y = y + rnd(-8, 8), vx = rnd(-20, 20), vy = rnd(-40, -10), life = rnd(.7, 1.2), max = 1.2, color = c, size = rnd(4, 8), smoke = 1})

func kill_enemy(e: Dictionary) -> void:
	if e.dead: return
	e.dead = true; G.kills += 1
	var nm := spr_name(e)
	var corpse := false
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
			var a := i / 3.0 * TAU; var ix: float = e.x + cos(a) * 14; var iy: float = e.y + sin(a) * 14
			if mg.hits(ix, iy, 8):
				ix = e.x; iy = e.y
			var im := spawn_enemy(e.d.split, ix, iy, .8); im.aggro = true; im.xp = 1
	var roll := randf()
	if roll < .10: G.drops.append({x = e.x, y = e.y, kind = "hp", t = 0.0, id = nid()})
	elif roll < .25: G.drops.append({x = e.x, y = e.y, kind = "mp", t = 0.0, id = nid()})
	if randf() < .5 or e.isBoss:
		G.drops.append({x = e.x + rnd(-8, 8), y = e.y + rnd(-8, 8), kind = "gold", v = int(round((60 if e.isBoss else ri(1, 3) + G.floor) * diff_d().reward * (1 + P.st.gold))), t = 0.0, vx = rnd(-90, 90), vy = rnd(-90, 90), h = 0.0, vh = rnd(70, 120), id = nid()})
	if not e.isBoss and e.xp > 1 and randf() < (.07 if (e.type == "demon" or e.type == "mage") else .03): drop_item(e.x, e.y)
	if e.isBoss and not e.split:
		drop_item(e.x - 10, e.y, "epic"); drop_item(e.x + 10, e.y, "rare")
	if e.isBoss and e.split and not _other_boss_alive(e):
		drop_item(e.x - 10, e.y, "epic"); drop_item(e.x + 10, e.y, "rare")
	if e.isBoss and not _other_boss_alive(null): boss_cleared()

func _other_boss_alive(ex) -> bool:
	for o in G.enemies:
		if o.isBoss and not o.dead and (ex == null or not is_same(o, ex)): return true
	return false

func boss_cleared() -> void:
	var r: Dictionary = mg.rooms[0]
	mg.stairs = {x = r.cx + 70, y = r.cy, found = true}
	if G.floor < D.LAST_FLOOR: G.portal = {x = r.cx - 70, y = r.cy, resume = G.floor + 1}
	G.eshots = []
	for e in G.enemies:
		if not e.dead: kill_enemy(e)
	G.banner = {text = "흑마법사를 쓰러뜨렸다!" if G.floor >= D.LAST_FLOOR else "보스 격파! 계단이 열렸다", t = 3.0}
	G.drops.append({x = r.cx + 30, y = r.cy, kind = "hp", t = 0.0, id = nid()})
	G.drops.append({x = r.cx - 30, y = r.cy, kind = "mp", t = 0.0, id = nid()})

func enemy_shot(e: Dictionary, kind: String, ang: float, speed: float, extra := {}) -> void:
	var s := {x = e.x + cos(ang) * e.r, y = e.y + sin(ang) * e.r, vx = cos(ang) * speed, vy = sin(ang) * speed, dmg = e.dmg, r = 5.0, life = 4.0, kind = kind, homing = 0.0, blast = 0.0, id = nid()}
	for k in extra.keys(): s[k] = extra[k]
	G.eshots.append(s)

func enemy_fire(e: Dictionary) -> void:
	var a := atan2(P.y - e.y, P.x - e.x); e.atkT = anim_dur(spr_name(e), "attack")
	match e.d.atk:
		"arrow": enemy_shot(e, "arrow", a + rnd(-.05, .05), 270, {r = 4.0, life = 2.0})
		"orb": enemy_shot(e, e.orb, a, 130, {r = 7.0, homing = 1.6, life = 5.0})
		"fireball": enemy_shot(e, "fire", a, 190, {r = 9.0, life = 3.0, blast = 45.0})

func boss_ai(e: Dictionary, dt: float, d: float) -> void:
	e.t1 -= dt; e.t2 -= dt; e.t3 -= dt
	if e.shieldMax:
		e.shieldRegen -= dt
		if e.shield <= 0 and e.shieldRegen <= -2:
			e.shield = e.shieldMax * .4; ring(e.x, e.y, e.r, e.r + 30, .4, "#c9a3ff")
	if e.boss == "golem":
		if e.t1 <= 0:
			e.t1 = 6.0
			for i in 3:
				var a := rnd(0, TAU); var s := spawn_enemy(pick(["skel", "skel", "archer"]), e.x + cos(a) * 60, e.y + sin(a) * 60); s.aggro = true; s.xp = 1
			ring(e.x, e.y, 10, 70, .5, "#e6dcc4")
		if e.t2 <= 0 and d < 260:
			e.t2 = 4.5; G.zones.append({kind = "warn", x = e.x, y = e.y, r = 120.0, life = .9, max = .9, dmg = e.dmg * 1.3})
	elif e.boss == "flesh":
		if e.t1 <= 0:
			e.t1 = 2.6 if e.split else 2.2
			var a := atan2(P.y - e.y, P.x - e.x); var n := 3 if e.split else 5
			for i in n: enemy_shot(e, "spit", a + (i - (n - 1) / 2.0) * .22, 170, {r = 7.0, dmg = e.dmg * .6, life = 3.0})
		if not e.split and e.t2 <= 0:
			e.t2 = 7.0
			for i in 2:
				var s := spawn_enemy("zombie", e.x + rnd(-50, 50), e.y + rnd(30, 60)); s.aggro = true; s.xp = 1
	elif e.boss == "warlock":
		if e.t1 <= 0:
			e.t1 = 2.8
			for i in 3:
				var a := atan2(P.y - e.y, P.x - e.x) + (i - 1) * .6
				enemy_shot(e, "skull", a, 150, {r = 9.0, homing = 2.2, life = 5.0, dmg = e.dmg * .7})
		if e.t2 <= 0:
			e.t2 = 8.0
			for i in 3:
				var t: String = pick(["imp", "imp", "skel", "mage"]); var s := spawn_enemy(t, e.x + rnd(-70, 70), e.y + rnd(-40, 40)); s.aggro = true; s.xp = 1
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
	var dx: float = P.x - e.x; var dy: float = P.y - e.y; var d: float = max(1.0, hyp(dx, dy))
	if not e.aggro:
		if (d < 360 and mg.los(e.x, e.y, P.x, P.y)) or d < 150: e.aggro = true
		else: return
	var sp: float = e.spd * (.5 if e.slowT > 0 else 1.0) * (.35 if in_stasis(e) else 1.0)
	var goal: Vector2
	var see: bool = d < 520 and mg.los(e.x, e.y, P.x, P.y)
	if e.fearT > 0: goal = Vector2(e.x - dx, e.y - dy)
	elif e.isBoss:
		boss_ai(e, dt, d)
		if e.dead: return
		if e.boss == "warlock":
			goal = Vector2(e.x - dx, e.y - dy) if d < 220 else (Vector2(P.x, P.y) if d > 320 else Vector2(e.x - dy * e.side, e.y + dx * e.side))
			sp *= .55
		else: goal = Vector2(P.x, P.y)
	elif e.d.atk != "melee" and see and d < e.d.range:
		e.cd -= dt
		if e.cd <= 0:
			enemy_fire(e); e.cd = e.d.cd * rnd(.8, 1.2)
		if d < e.d.range * .45: goal = Vector2(e.x - dx, e.y - dy)
		else:
			if randf() < dt * .4: e.side *= -1
			goal = Vector2(e.x - dy * e.side, e.y + dx * e.side); sp *= .6
	else:
		goal = Vector2(P.x, P.y) if (see and d < 240) else mg.step_toward(e.x, e.y, P.x, P.y)
		if e.d.has("erratic"):
			var w := sin(G.time * 5 + e.wob) * .9
			goal = Vector2(goal.x + (-(goal.y - e.y)) * w, goal.y + (goal.x - e.x) * w)
			if d < 40 and e.atkCd > .3: goal = Vector2(e.x - dx, e.y - dy)
	var gx: float = goal.x - e.x; var gy: float = goal.y - e.y; var gl := hyp(gx, gy)
	var tvx := 0.0; var tvy := 0.0
	if gl > 1 and not (e.d.atk == "melee" and d < e.r + P.r):
		tvx = gx / gl * sp; tvy = gy / gl * sp
	var ka := 1.0 - exp(-(3.0 if e.isBoss else 4.5) * dt)
	e.vx += (tvx - e.vx) * ka; e.vy += (tvy - e.vy) * ka; mg.move(e, e.vx * dt, e.vy * dt)
	if d < e.r + P.r + 4 and e.atkCd <= 0 and e.fearT <= 0:
		hurt_player(e.dmg); e.atkCd = 1.0; e.atkT = anim_dur(spr_name(e), "attack")

func in_stasis(o: Dictionary) -> bool:
	for z in G.zones:
		if z.kind == "stasis" and hyp(o.x - z.x, o.y - z.y) < z.r: return true
	return false

# ================= 플레이어 공격 =================
func attack_of(id: String) -> Dictionary:
	var L: Dictionary = P.ep; var might: float = (1 + .12 * P.pass.get("might", 0)) * (1 + P.st.dmg); var thrift: float = 1 - .1 * P.pass.get("thrift", 0)
	if D.PRIMARIES.has(id):
		var d: Dictionary = D.PRIMARIES[id]; var l: float = L.get(id, 0)
		var a := {id = id, kind = d.kind, color = d.color, els = {id: true}, name = d.name}
		if d.kind == "shot":
			var dm := D.prim_dmg(id, l)
			a.dmg = [dm[0] * might, dm[1] * might]; a.mana = D.prim_mana(id, l) * thrift; a.cd = d.cd; a.speed = float(d.speed); a.homing = float(d.homing); a.r = float(d.radius)
		else:
			a.dps = D.prim_dps(id, l) * might; a.manaps = D.prim_manaps(id, l) * thrift; a.range = float(d.range)
		return a
	var f: Dictionary = D.FUSIONS[id]; var ee: PackedStringArray = id.split("+"); var p: float = L.get(ee[0], 0) + L.get(ee[1], 0)
	var a := {id = id, kind = f.kind, color = f.color, els = {ee[0]: true, ee[1]: true}, name = f.name}
	match f.kind:
		"shot":
			a.dmg = [(2 * p + 3) * might, (3 * p + 6) * might]; a.mana = (6 + 2 * p) * thrift; a.cd = .38; a.speed = 320.0; a.homing = 3.0; a.r = 7.0
		"chain":
			a.dps = (14 + 8 * p) * might; a.manaps = (8 + 2.4 * p) * thrift; a.range = 240.0
		"cone":
			a.dps = (12 + 7 * p) * might; a.manaps = (8 + 2.2 * p) * thrift; a.range = 165.0
		_:
			a.dps = (16 + 8 * p) * might; a.manaps = (9 + 2.6 * p) * thrift; a.range = 360.0
	return a

func act_color() -> String: return attack_of(P.active).color if P.active != null else "#c39bff"
func act_name() -> String: return attack_of(P.active).name if P.active != null else "마법 없음"

func nearest_enemy(x: float, y: float, range: float, need_los: bool, exclude):
	var best = null; var bd := range * range
	for e in G.enemies:
		if e.dead or (exclude != null and is_same(e, exclude)): continue
		if e.d.has("hidden") and hyp(e.x - P.x, e.y - P.y) > 110: continue
		var d: float = (e.x - x) * (e.x - x) + (e.y - y) * (e.y - y)
		if d < bd and (not need_los or mg.los(x, y, e.x, e.y)):
			bd = d; best = e
	return best

func fire(dt: float, ang: float) -> void:
	var a := attack_of(P.active); var quick: float = (1 + .12 * P.pass.get("quick", 0)) * (1 + P.st.cast)
	if a.kind == "shot":
		if P.cdShot > 0: return
		if P.mp < a.mana:
			P.cdShot = .25; return
		P.mp -= a.mana; P.cdShot = a.cd / quick
		var n: int = 1 + (P.es.get("multi", 0) if a.els.has("arcane") else 0)
		for i in n:
			var an := ang + (i - (n - 1) / 2.0) * .2
			G.shots.append({id = nid(), x = P.x + cos(an) * 14, y = P.y + sin(an) * 14, vx = cos(an) * a.speed, vy = sin(an) * a.speed, speed = a.speed,
				dmg = a.dmg, r = a.r, life = 1.6, homing = a.homing, els = a.els, color = a.color, seek = P.es.get("seek", 0) if a.els.has("arcane") else 0, hitSet = {}})
		return
	var cost: float = a.manaps * dt
	if P.mp < cost: return
	P.mp -= cost
	if a.kind == "chain":
		var range: float = a.range + 40 * P.es.get("reach", 0)
		var target = null; var bd := range
		for e in G.enemies:
			if e.dead: continue
			var dd := hyp(e.x - P.x, e.y - P.y)
			if dd > range: continue
			if absf(ang_diff(atan2(e.y - P.y, e.x - P.x), ang)) > .65: continue
			if dd < bd and mg.los(P.x, P.y, e.x, e.y):
				bd = dd; target = e
		if target == null:
			G.bolts.append({pts = jag(P.x, P.y, P.x + cos(ang) * 60, P.y + sin(ang) * 60, 4), color = a.color, life = .05}); return
		var from := Vector2(P.x, P.y); var cur = target; var hit := {}; var mult := 1.0
		var links: int = 1 + P.es.get("chain", 0) + (1 if a.els.size() > 1 else 0)
		for i in links:
			if cur == null: break
			G.bolts.append({pts = jag(from.x, from.y, cur.x, cur.y, 7), color = a.color, life = .06})
			damage_enemy(cur, a.dps * dt * mult, a.els, true); hit[cur.id] = true
			from = Vector2(cur.x, cur.y); mult *= .75
			var nx = null; var nd := 150.0
			for e in G.enemies:
				if e.dead or hit.has(e.id): continue
				var dd := hyp(e.x - from.x, e.y - from.y)
				if dd < nd:
					nd = dd; nx = e
			cur = nx
	elif a.kind == "cone":
		var half: float = .32 + .12 * P.es.get("widen", 0); var range: float = a.range + 25 * P.es.get("widen", 0)
		for e in G.enemies:
			if e.dead: continue
			var dd := hyp(e.x - P.x, e.y - P.y)
			if dd > range + e.r: continue
			if absf(ang_diff(atan2(e.y - P.y, e.x - P.x), ang)) > half + .1: continue
			if not mg.los(P.x, P.y, e.x, e.y): continue
			damage_enemy(e, a.dps * dt, a.els, true)
			if P.es.get("gust", 0) and not e.isBoss:
				var k: float = 60 * P.es.gust * dt; mg.move(e, (e.x - P.x) / max(dd, 1.0) * k, (e.y - P.y) / max(dd, 1.0) * k)
		if P.es.get("gust", 0):
			G.eshots = G.eshots.filter(func(s): return not (s.kind == "arrow" and hyp(s.x - P.x, s.y - P.y) < range and absf(ang_diff(atan2(s.y - P.y, s.x - P.x), ang)) < half))
		if P.es.get("harden", 0): P.hardenT = .15
		G.coneT += dt
		if G.coneT > .016:
			G.coneT = 0.0
			for i in 3:
				var an := ang + rnd(-half, half); var sp := rnd(.6, 1) * range * 2.4
				G.fx.append({x = P.x + cos(ang) * 12, y = P.y + sin(ang) * 12, vx = cos(an) * sp, vy = sin(an) * sp, life = .38, max = .38, color = a.color, size = rnd(3, 6), cone = 1, wall = 1})
	else:
		var len := 0.0; var step := 8.0
		while len < a.range and not mg.solid_at(P.x + cos(ang) * len, P.y + sin(ang) * len): len += step
		var ex: float = P.x + cos(ang) * len; var ey: float = P.y + sin(ang) * len
		for e in G.enemies:
			if e.dead: continue
			var t := clampf_((e.x - P.x) * cos(ang) + (e.y - P.y) * sin(ang), 0, len)
			var px: float = P.x + cos(ang) * t; var py: float = P.y + sin(ang) * t
			if hyp(e.x - px, e.y - py) < e.r + 9: damage_enemy(e, a.dps * dt, a.els, true)
		G.bolts.append({pts = [Vector2(P.x, P.y), Vector2(ex, ey)], color = a.color, life = .04, beam = 1})
		G.bolts.append({pts = jag(P.x, P.y, ex, ey, 10), color = "#86e3ff", life = .04})

func jag(x1: float, y1: float, x2: float, y2: float, amp: float) -> Array:
	var pts: Array = [Vector2(x1, y1)]; var n: int = max(3, int(hyp(x2 - x1, y2 - y1) / 18))
	var nx := -(y2 - y1); var ny := x2 - x1; var l: float = max(hyp(nx, ny), 1.0)
	for i in range(1, n):
		var t := float(i) / n; var o := rnd(-amp, amp)
		pts.append(Vector2(x1 + (x2 - x1) * t + nx / l * o, y1 + (y2 - y1) * t + ny / l * o))
	pts.append(Vector2(x2, y2)); return pts

func shot_hit(s: Dictionary, e: Dictionary) -> bool:
	var dmg := rnd(s.dmg[0], s.dmg[1]); damage_enemy(e, dmg, s.els); s.hitSet[e.id] = true
	if s.els.has("arcane") and P.es.get("siphon", 0): P.mp = min(P.maxmp, P.mp + 1.2 * P.es.siphon)
	if s.els.has("fire"):
		var bl: int = P.es.get("blast", 0); var rad: float = 28 + 18 * bl if bl else 0.0
		burst(s.x, s.y, "#ff8a3a", 8 + bl * 3, 140, .35, 3); burst(s.x, s.y, "#fff0b0", 4, 60, .2, 4); smoke(s.x, s.y, 2 + bl); fx_anim("fx_blast", s.x, s.y + 10, 34 + bl * 10)
		if rad:
			ring(s.x, s.y, 6, rad, .25, "#ffb05a")
			for o in G.enemies:
				if o.dead or is_same(o, e): continue
				if hyp(o.x - s.x, o.y - s.y) < rad + o.r: damage_enemy(o, dmg * .6, s.els, true)
		for i in P.es.get("embers", 0):
			G.zones.append({kind = "ember", x = s.x + rnd(-20, 20), y = s.y + rnd(-20, 20), r = 16.0, life = 3.0, max = 3.0, dps = 4 + 3 * P.es.embers + P.lv * .5})
	if s.els.has("storm"):
		var from = e; var hit := {e.id: true}
		for i in 1 + P.es.get("chain", 0):
			var n = nearest_enemy(from.x, from.y, 120, false, null)
			if n == null or hit.has(n.id): break
			hit[n.id] = true
			G.bolts.append({pts = jag(from.x, from.y, n.x, n.y, 6), color = "#9fe8ff", life = .12}); damage_enemy(n, dmg * .5, s.els, true); from = n
	if s.els.has("frost"):
		burst(s.x, s.y, "#cdf2ff", 6, 90, .3, 2); fx_anim("fx_spark_blue", s.x, s.y + 8, 26)
	if s.els.has("arcane") and not s.els.has("fire") and not s.els.has("frost"): fx_anim("fx_spark_orange", s.x, s.y + 8, 22)
	if s.seek > 0:
		s.seek -= 1
		var n = nearest_enemy(s.x, s.y, 300, true, e)
		if n != null:
			s.life = 1.4; return false
	return true

# ================= 보조 마법 =================
func sec_cd_max(id: String) -> float:
	return D.sec(id).cd * (1 - .12 * P.pass.get("focus", 0)) * (1 - P.st.cdr)

func cast_sec(id: String) -> void:
	if G == null or G.state != "play": return
	var l: int = P.esec.get(id, 0) if P.esec.get(id, 0) else P.sec.get(id, 0)
	if not l: return
	if P.secCd.get(id, 0.0) > 0: return
	var m := D.sec_mana(id, l)
	if P.mp < m:
		toast.emit("마나가 부족해요"); return
	P.mp -= m; P.secCd[id] = sec_cd_max(id)
	var pw: float = 1 + .08 * P.lv
	match id:
		"blink":
			var live: Array = G.enemies.filter(func(e): return not e.dead)
			var best = null; var bs := -1.0
			for r in mg.rooms:
				if not r.seen: continue
				for k in 6:
					var x: float = (r.x + rnd(1.5, r.w - 1.5)) * T if k else r.cx
					var y: float = (r.y + rnd(1.5, r.h - 1.5)) * T if k else r.cy
					if mg.hits(x, y, P.r): continue
					var md := 900.0
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
				var d := hyp(e.x - P.x, e.y - P.y)
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
	if d > 3: P.hitT = .2
	if d > 0:
		rumble.emit(160 if d > 15 else 90, .9 if d > 15 else .5)
		float_text(P.x, P.y - 16, str(int(round(d))), "#ff6b6b")
	G.shake = .15
	if P.hp <= 0:
		P.hp = 0.0; game_over(false)

func gain_xp(n: float) -> void:
	var v := int(round(n * diff_d().reward)); P.xp += v
	while P.xp >= P.next:
		P.xp -= P.next; P.lv += 1; P.next = xp_need(P.lv); G.pendingLv += 1; G.lvDelay = .75; lv_fx(); recalc()
		P.hp = min(P.maxhp, P.hp + P.maxhp * .2); P.mp = min(P.maxmp, P.mp + P.maxmp * .3)

# ================= 레벨업 선택지 =================
func build_options() -> Array:
	var o: Array = []
	var learned: Array = D.PRIM_ORDER.filter(func(k): return P.prim[k] > 0)
	var fus = Array(String(P.fusion).split("+")) if P.fusion != null else null
	for id in D.PRIM_ORDER:
		var d: Dictionary = D.PRIMARIES[id]; var l: int = P.prim[id]
		if l >= D.PRIMARY_MAX: continue
		if fus != null and not id in fus: continue
		var w := 4.0 if l else (.3 if learned.size() else 1.3)
		o.append({icon = {t = "el", el = id}, w = w, tag = "주 마법 (융합 강화)" if fus != null else "주 마법", title = "%s %d단계" % [d.name, l + 1] if l else "%s 배우기" % d.name, desc = d.desc, color = d.color, kind = "prim", id = id})
	for s in D.SUBS:
		var l: int = P.subs.get(s.id, 0)
		if l >= s.max or not has_el(s.of): continue
		if fus != null and not s.of in fus: continue
		o.append({icon = {t = "sub", el = s.of, id = s.id}, w = 3.2, tag = "%s 강화" % D.PRIMARIES[s.of].name, title = "%s %d단계" % [s.name, l + 1], desc = s.desc, color = D.PRIMARIES[s.of].color, kind = "sub", id = s.id})
	if fus == null:
		for i in learned.size():
			for j in range(i + 1, learned.size()):
				var pair := [learned[i], learned[j]]; pair.sort()
				var key: String = "%s+%s" % pair; var f: Dictionary = D.FUSIONS[key]
				o.append({icon = {t = "fusion", a = pair[0], b = pair[1]}, w = 2.4, tag = "융합 마법", title = f.name, desc = f.desc + " 고르면 다른 주 마법은 더 이상 나오지 않아요.", color = f.color, kind = "fusion", id = key})
	var slots := D.secondary_slots(P.lv)
	for s in D.SECONDARIES:
		var l: int = P.sec.get(s.id, 0); var af = AFF.get(s.id); var rel: bool = af != null and has_el(af)
		if l:
			if l < s.max: o.append({icon = {t = "sec", id = s.id}, w = 2.6 if rel else 1.4, tag = "보조 마법", title = "%s %d단계" % [s.name, l + 1], desc = s.desc, color = "#e3b04b", kind = "sec", id = s.id})
		elif P.secOrder.size() < slots and P.lv >= s.lv:
			var tag := "보조 마법 · %s 계열 (%d/%d칸)" % [D.PRIMARIES[af].name, P.secOrder.size() + 1, slots] if rel else "보조 마법 (%d/%d칸)" % [P.secOrder.size() + 1, slots]
			o.append({icon = {t = "sec", id = s.id}, w = 3.5 if rel else (.45 if af != null else 1.2), tag = tag, title = "%s 배우기" % s.name, desc = s.desc, color = "#e3b04b", kind = "secnew", id = s.id})
	for s in D.PASSIVES:
		var l: int = P.pass.get(s.id, 0)
		if l >= s.max: continue
		o.append({icon = {t = "pass", id = s.id}, w = 1.2, tag = "수련", title = "%s %d단계" % [s.name, l + 1], desc = s.desc, color = "#a395b3", kind = "pass", id = s.id})
	var out: Array = []
	while out.size() < 3 and o.size():
		var tot := 0.0
		for x in o: tot += x.w
		var r := randf() * tot; var k := 0
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
			P.pass[o.id] = P.pass.get(o.id, 0) + 1; recalc()
	G.pendingLv -= 1
	ui.emit("buttons")
	if G.pendingLv > 0: ui.emit("levelup")
	else: set_state("play")

func pick_first(id: String) -> void:
	P.prim[id] = 1; P.active = id
	G.banner = {text = "%s을(를) 익혔다" % D.PRIMARIES[id].name, t = 2.0}
	enter_tower()

# ================= 장비 =================
func roll_mod(slot: String, used: Dictionary, lvl: int, mult: float, epic: bool) -> Dictionary:
	var my_els: Array = D.PRIM_ORDER.filter(func(k): return P.prim[k] > 0)
	var pool: Array = []
	var add := func(k: String, w: float, v: Callable):
		if not used.has(k): pool.append({k = k, w = w, v = v})
	var sc := 1 + lvl * .08
	for el in D.PRIM_ORDER:
		var mine: bool = el in my_els
		if slot == "weapon": add.call("prim:" + el, 5.0 if mine else .6, func(): return ri(1, 3 if epic else 2))
		elif slot == "ring": add.call("prim:" + el, 1.5 if mine else .3, func(): return 1)
	for sd in D.SUBS:
		var mine: bool = sd.of in my_els
		add.call("sub:" + sd.id, ((1.1 if slot == "weapon" else .5) if mine else .08), func(): return ri(1, 2 if epic else 1))
	for sd in D.SECONDARIES:
		if slot == "ring" or slot == "cloak": add.call("sec:" + sd.id, 1.4 if P.sec.get(sd.id, 0) else .15, func(): return 1)
	add.call("hp", 3.0 if slot == "cloak" else 1.6, func(): return int(round(rnd(8, 16) * sc * mult)))
	add.call("mp", 2.5 if slot == "ring" else 1.4, func(): return int(round(rnd(8, 16) * sc * mult)))
	add.call("regen", 1.4, func(): return snappedf(rnd(.08, .18) * mult, .01))
	add.call("dmg", 2.4 if slot == "weapon" else 1.0, func(): return snappedf(rnd(.05, .12) * mult, .01))
	add.call("cast", 1.8 if slot == "weapon" else .8, func(): return snappedf(rnd(.04, .1) * mult, .01))
	add.call("cdr", .9, func(): return snappedf(rnd(.05, .1) * mult, .01))
	add.call("res", 2.4 if slot == "cloak" else .6, func(): return snappedf(rnd(.03, .07) * mult, .01))
	add.call("spd", 1.4 if slot == "cloak" else .5, func(): return snappedf(rnd(.03, .07) * mult, .01))
	add.call("gold", .8, func(): return snappedf(rnd(.1, .3) * mult, .01))
	var tot := 0.0
	for o in pool: tot += o.w
	var r := randf() * tot
	for o in pool:
		r -= o.w
		if r <= 0: return {k = o.k, v = o.v.call()}
	return {k = pool[0].k, v = pool[0].v.call()}

func make_item(rar: String, lvl: int, base_id := "") -> Dictionary:
	var base: Dictionary = D.base(base_id) if base_id != "" else pick([D.BASES[0], D.BASES[1], D.BASES[2], D.BASES[2], D.BASES[3]])
	var R: Dictionary = D.RAR[rar]; var tier: int = min(4, int(lvl / 3.5))
	var it := {uid = "%d%d" % [Time.get_ticks_msec(), randi() % 10000], base = base.id, slot = base.slot, rar = rar, lvl = lvl, mods = []}
	var used := {}
	if base.imp != null:
		it.mods.append({k = base.imp.k, v = snappedf(base.imp.v * (1 + lvl * .05), .01)}); used[base.imp.k] = true
	var n := ri(R.mods[0], R.mods[1])
	if rar == "epic" and base.slot == "weapon":
		var my_els: Array = D.PRIM_ORDER.filter(func(k): return P.prim[k] > 0)
		var el: String = pick(my_els) if my_els.size() else pick(D.PRIM_ORDER)
		it.mods.append({k = "prim:" + el, v = 2}); used["prim:" + el] = true
	while it.mods.size() < n + (1 if base.imp != null else 0):
		var m := roll_mod(base.slot, used, lvl, R.mult, rar == "epic"); used[m.k] = true; it.mods.append(m)
	var bn: String = base.names[tier]
	if rar == "magic":
		var m = it.mods[0]
		for x in it.mods:
			if base.imp == null or x.k != base.imp.k:
				m = x; break
		var parts: PackedStringArray = String(m.k).split(":")
		var pf: String = D.PREFIX.prim[parts[1]] if parts[0] == "prim" else D.PREFIX[parts[0]]
		it.name = "%s %s" % [pf, bn]
	elif rar == "rare": it.name = "%s의 %s" % [pick(D.RARENAMES), bn]
	else: it.name = pick(D.EPICNAMES[base.slot])
	it.value = int(round((8 + lvl * 3) * R.mult * (3 if rar == "epic" else (1.8 if rar == "rare" else 1.0))))
	return it

func roll_rarity(bonus := 0.0) -> String:
	var r := randf() - bonus
	return "epic" if r < .06 else ("rare" if r < .32 else "magic")

func drop_item(x: float, y: float, rar := "") -> Dictionary:
	var it := make_item(rar if rar != "" else roll_rarity(G.floor * .006), G.floor)
	G.drops.append({id = nid(), x = x, y = y, kind = "item", it = it, t = 0.0, vx = rnd(-80, 80), vy = rnd(-80, 80), h = 0.0, vh = rnd(100, 150)})
	return it

static func sum_mods(it) -> Dictionary:
	var o := {}
	if it != null:
		for m in it.mods: o[m.k] = o.get(m.k, 0) + m.v
	return o
static func sum_score(it) -> int: return it.mods.size() + (3 if it.rar == "epic" else (1 if it.rar == "rare" else 0))

func equip(i: int, slot: String) -> void:
	var it = P.bag[i]; var old = P.eq[slot]; P.eq[slot] = it; P.bag.remove_at(i)
	if old != null: P.bag.insert(i, old)
	recalc(); ui.emit("buttons"); toast.emit("%s 착용" % it.name)

func unequip(slot: String) -> bool:
	if P.bag.size() >= D.BAGMAX:
		toast.emit("가방이 가득 찼어요"); return false
	P.bag.append(P.eq[slot]); P.eq[slot] = null; recalc(); ui.emit("buttons"); return true

func sell(i: int) -> void:
	G.gold += P.bag[i].value; P.bag.remove_at(i); save()

func discard(i: int) -> void:
	var x = P.bag[i]; P.bag.remove_at(i)
	G.drops.append({id = nid(), x = P.x + rnd(-20, 20), y = P.y + 30, kind = "item", it = x, t = 0.0, vx = 0.0, vy = 0.0, h = 0.0, vh = 0.0, noPick = 1})

func buy(id: String) -> void:
	var it := D.shop(id)
	if G.gold < it.price or P.pot.get(id, 0) >= it.max: return
	G.gold -= it.price; P.pot[id] = P.pot.get(id, 0) + 1; save(); ui.emit("belt")

# ================= 층 이동 / 종료 =================
func open_chest(c: Dictionary) -> void:
	c.open = true; ring(c.x, c.y, 4, 34, .35, "#ffd76a"); burst(c.x, c.y - 6, "#ffd76a", 18, 140, .5, 2.5)
	var n := ri(5, 9); var v: int = max(1, int(round((1 + G.floor * .6) * diff_d().reward)))
	for i in n: G.drops.append({id = nid(), x = c.x, y = c.y, kind = "gold", v = v, t = 0.0, vx = rnd(-130, 130), vy = rnd(-130, 130), h = 0.0, vh = rnd(90, 160)})
	if randf() < .35: drop_item(c.x, c.y, roll_rarity(.05 + G.floor * .006))
	var r := randf()
	if r < .45: G.drops.append({id = nid(), x = c.x, y = c.y, kind = pick(["pothp", "pothp", "potmp"]), t = 0.0, vx = rnd(-60, 60), vy = rnd(40, 90), h = 0.0, vh = 110.0})
	elif r < .55: G.drops.append({id = nid(), x = c.x, y = c.y, kind = "scroll", t = 0.0, vx = rnd(-60, 60), vy = rnd(40, 90), h = 0.0, vh = 110.0})

func next_floor() -> void:
	if G.floor >= D.LAST_FLOOR:
		game_over(true); return
	G.floor += 1; G.resume = G.floor; P.hp = min(P.maxhp, P.hp + P.maxhp * .3); P.mp = P.maxmp; P.ward = 0.0; gen_floor(); save()

var end_win := false
func game_over(win: bool) -> void:
	end_win = win
	set_state("win" if win else "dead")
	if win: clear_save()
	ui.emit("end")

func revive() -> void:
	G.gold -= G.gold / 2; P.poisonT = 0.0; P.slowT = 0.0; recalc(); go_town(false)

# ================= 효과 =================
func burst(x: float, y: float, color: String, n: int, sp: float, life: float, size: float) -> void:
	for i in n:
		var a := rnd(0, TAU); var v := rnd(.3, 1) * sp
		G.fx.append({x = x, y = y, vx = cos(a) * v, vy = sin(a) * v, life = life * rnd(.6, 1), max = life, color = color, size = size * rnd(.6, 1.3)})
	if G.fx.size() > 700: G.fx = G.fx.slice(G.fx.size() - 700)

func lv_fx() -> void:
	rumble.emit(120, .4); ring(P.x, P.y, 8, 90, .6, "#e3b04b"); ring(P.x, P.y, 4, 50, .45, "#fff2c2")
	for i in 40:
		var a := rnd(0, TAU)
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
		G.portal = {x = P.x + cos(P.face) * 50, y = P.y + sin(P.face) * 50, resume = G.floor}
		if mg.hits(G.portal.x, G.portal.y, 12):
			G.portal.x = P.x; G.portal.y = P.y + 40
		ring(G.portal.x, G.portal.y, 4, 40, .5, "#7fb2ff"); toast.emit("귀환문이 열렸어요"); ui.emit("belt"); save(); return
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
	P.pot[id] -= 1; P.potCd = .8; ui.emit("belt")

func swap_active() -> void:
	var l := active_list()
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
	var kp := 1.0 - exp(-7.0 * dt)
	P.vx += (inp.mx * sp - P.vx) * kp; P.vy += (inp.my * sp - P.vy) * kp; mg.move(P, P.vx * dt, P.vy * dt)
	if inp.firing or hyp(inp.mx, inp.my) > .2: P.face = inp.ang if inp.firing else atan2(inp.my, inp.mx)
	P.firing = inp.firing
	P.cdShot -= dt; P.inv -= dt; P.slowT -= dt; P.hardenT -= dt; P.potCd -= dt
	var spd := hyp(P.vx, P.vy); P.walk += spd * dt * .11
	if spd > 60 and randf() < dt * 9:
		G.fx.append({x = P.x + rnd(-4, 4), y = P.y + P.r, vx = rnd(-12, 12), vy = rnd(-14, -4), life = .4, max = .4, color = "#5a4a6a" if G.floor else "#6a7a5a", size = rnd(1.5, 2.6), dust = 1})
	if G.floor == 0 and mg.gate != null:
		if hyp(P.x - mg.gate.x, P.y - mg.gate.y) < 26:
			P.y += 30; P.vy = 0.0; enter_tower(); return
	for c in G.chests:
		if c.open:
			c.t += dt; continue
		if hyp(P.x - c.x, P.y - c.y) < 26: open_chest(c)
	if G.portal != null and hyp(P.x - G.portal.x, P.y - G.portal.y) < 22:
		G.resume = G.portal.resume; go_town(false); return
	for k in P.secCd.keys(): P.secCd[k] = max(0.0, P.secCd[k] - dt)
	var stas := in_stasis(P)
	P.mp = min(P.maxmp, P.mp + (8 * (1 + .25 * P.pass.get("calm", 0) + P.st.regen) + .3 * P.lv + (10 if stas else 0)) * dt)
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
	if mg.stairs != null and G.floor > 0:
		if hyp(P.x - mg.stairs.x, P.y - mg.stairs.y) < 20:
			next_floor(); return
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
	_set_anim(P, "hit" if P.hitT > 0 else ("attack" if (P.firing and P.active != null and G.floor > 0) else ("run" if hyp(P.vx, P.vy) > 22 else "stance")))
	if P.anim == "attack" and P.at >= anim_dur("player", "attack"): P.at = 0.0
	var live: Array = G.enemies.filter(func(e): return not e.dead)
	for i in live.size():
		for j in range(i + 1, live.size()):
			var a: Dictionary = live[i]; var b: Dictionary = live[j]; var dx: float = b.x - a.x; var dy: float = b.y - a.y; var d := hyp(dx, dy); var m: float = a.r + b.r
			if d > 0 and d < m:
				var k := (m - d) / 2 / d
				if not a.isBoss: mg.move(a, -dx * k, -dy * k)
				if not b.isBoss: mg.move(b, dx * k, dy * k)
	G.enemies = live.filter(func(e): return not e.dead)

	# 내 탄
	for s in G.shots:
		if s.homing:
			var t = null; var bd := 360.0 * 360.0
			for e in G.enemies:
				if e.dead or s.hitSet.has(e.id): continue
				if e.d.has("hidden") and hyp(e.x - P.x, e.y - P.y) > 110: continue
				var q: float = (e.x - s.x) * (e.x - s.x) + (e.y - s.y) * (e.y - s.y)
				if q < bd:
					bd = q; t = e
			if t != null:
				var want := atan2(t.y - s.y, t.x - s.x); var cur := atan2(s.vy, s.vx)
				var na := cur + clampf_(ang_diff(want, cur), -s.homing * dt, s.homing * dt)
				s.vx = cos(na) * s.speed; s.vy = sin(na) * s.speed
		s.x += s.vx * dt; s.y += s.vy * dt; s.life -= dt
		if mg.solid_at(s.x, s.y):
			s.life = 0.0
			if s.els.has("fire"): burst(s.x, s.y, "#ff8a3a", 6, 100, .3, 3)
			continue
		if randf() < .5: G.fx.append({x = s.x, y = s.y, vx = rnd(-20, 20), vy = rnd(-20, 20), life = .25, max = .25, color = s.color, size = s.r * .6})
		for e in G.enemies:
			if e.dead or s.hitSet.has(e.id): continue
			if hyp(e.x - s.x, e.y - s.y) < e.r + s.r:
				if shot_hit(s, e): s.life = 0.0
				break
	G.shots = G.shots.filter(func(s): return s.life > 0)

	# 적 탄
	for s in G.eshots:
		if s.homing:
			var want := atan2(P.y - s.y, P.x - s.x); var cur := atan2(s.vy, s.vx); var sp2 := hyp(s.vx, s.vy)
			var na := cur + clampf_(ang_diff(want, cur), -s.homing * dt, s.homing * dt); s.vx = cos(na) * sp2; s.vy = sin(na) * sp2
		var stf := .35 if in_stasis(s) else 1.0
		s.x += s.vx * dt * stf; s.y += s.vy * dt * stf; s.life -= dt
		var boom := false
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
	for z in G.zones:
		z.life -= dt
		if z.kind == "ember" or z.kind == "acid":
			for e in G.enemies:
				if not e.dead and hyp(e.x - z.x, e.y - z.y) < z.r + e.r: damage_enemy(e, z.dps * dt, {fire = true} if z.kind == "ember" else null, true)
			if z.kind == "acid" and randf() < dt * 30:
				G.fx.append({x = z.x + rnd(-z.r, z.r) * .9, y = z.y - 30 + rnd(-10, 10), vx = 0.0, vy = 180.0, life = .25, max = .25, color = "#a6e34f", size = 2.0, rain = 1})
		if z.kind == "warn" and z.life <= 0:
			ring(z.x, z.y, 10, z.r, .3, "#e6dcc4"); burst(z.x, z.y, "#9b927f", 24, 240, .4, 4)
			if hyp(P.x - z.x, P.y - z.y) < z.r: hurt_player(z.dmg)
	G.zones = G.zones.filter(func(z): return z.life > 0)

	# 아이템
	for d in G.drops:
		d.t += dt
		if d.kind == "item" and P.bag.size() >= D.BAGMAX and hyp(P.x - d.x, P.y - d.y) < 16:
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
		var dd := hyp(P.x - d.x, P.y - d.y)
		if d.get("noPick", 0):
			if dd > 70: d.noPick = 0
			else: continue
		if dd < 95 and d.t > .35:
			var k: float = min(1.0, (95 - dd) / 95 * 8 * dt + .02); d.x += (P.x - d.x) * k * 3; d.y += (P.y - d.y) * k * 3
		if dd < 16:
			d.got = true
			if d.kind == "hp":
				var v: float = P.maxhp * .25; P.hp = min(P.maxhp, P.hp + v); float_text(P.x, P.y - 18, "+%d" % int(round(v)), "#ff8a8a")
			elif d.kind == "mp":
				var v: float = P.maxmp * .35; P.mp = min(P.maxmp, P.mp + v); float_text(P.x, P.y - 18, "+%d" % int(round(v)), "#8ab0ff")
			elif d.kind in ["pothp", "potmp", "scroll"]:
				var it := D.shop(d.kind)
				if P.pot.get(d.kind, 0) < it.max:
					P.pot[d.kind] = P.pot.get(d.kind, 0) + 1; float_text(P.x, P.y - 20, it.name, "#fff2c2"); ui.emit("belt")
				else:
					G.gold += 8; float_text(P.x, P.y - 20, "가득 참 · 금화 +8", "#ffd76a")
				ring(d.x, d.y, 2, 16, .25, "#fff2c2")
			elif d.kind == "item":
				if P.bag.size() >= D.BAGMAX:
					d.got = false
					if not d.get("warned", false):
						toast.emit("가방이 가득 찼어요"); d.warned = true
					continue
				P.bag.append(d.it); G.bagNew = true; ui.emit("bagbtn")
				float_text(P.x, P.y - 24, d.it.name, D.RAR[d.it.rar].color); ring(d.x, d.y, 2, 22, .3, D.RAR[d.it.rar].color)
			else:
				G.gold += d.v; G.goldPulse = .35; float_text(P.x + 8, P.y - 20, "+%d" % d.v, "#ffd76a")
				for i in 8:
					var a := rnd(0, TAU)
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
		f.life -= dt; f.x += f.vx * dt; f.y += f.vy * dt
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
		var a := rnd(0, TAU); var x: float = P.x + cos(a) * 180; var y: float = P.y + sin(a) * 180
		if mg.hits(x, y, m.r):
			x = P.x + cos(a) * 60; y = P.y + sin(a) * 60
		if mg.hits(x, y, m.r):
			x = P.x; y = P.y - 40
		var e := spawn_enemy(id, x, y); e.aggro = true

func sand_boss(f: int) -> void:
	var bd: Dictionary = D.BOSSES[f]; var x: float = P.x; var y: float = P.y - 200
	if mg.hits(x, y, bd.r): y = P.y + 200
	if mg.hits(x, y, bd.r):
		x = P.x; y = P.y - 60
	spawn_boss(bd, x, y)
