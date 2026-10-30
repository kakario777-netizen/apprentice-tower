# 맵 만들기 — 웹 버전 genFloor / goTown 을 그대로 옮김. 단위: 1 = 타일 한 칸(웹 32px).
class_name MapGen
extends RefCounted

const MW := 82
const MH := 62
const BOSS_FLOORS := [5, 10, 15]
const DIR4 := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
const DIR8 := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1), Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]

var map := PackedByteArray()      # 1 = 벽, 0 = 바닥
var rooms: Array = []             # {x,y,w,h,cx,cy}
var flow := PackedInt32Array()
var floor_no := 0
var town = null                   # 마을이면 {x0,y0,w,h,pathX,pathW,crossY}
var gate = null                   # 마을 → 탑 입구 (Vector2)
var stairs = null                 # 다음 층 계단 (Vector2)
var start := Vector2()
var torches: Array = []           # {pos:Vector2, wall:bool, lamp:bool}
var decor: Array = []             # {kind, p, pos, s}
var obst: Array = []              # {pos, r}
var rng := RandomNumberGenerator.new()

static func hash2(i: int, j: int) -> int:
	var h: int = (i * 374761393 + j * 668265263) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	h = h ^ (h >> 16)
	return h % 100

func rnd(a: float, b: float) -> float: return rng.randf_range(a, b)
func ri(a: int, b: int) -> int: return rng.randi_range(a, b)
func pick(a: Array): return a[rng.randi() % a.size()]

func at(i: int, j: int) -> int:
	if i < 0 or j < 0 or i >= MW or j >= MH: return 1
	return map[j * MW + i]

func solid_at(x: float, y: float) -> bool:
	return at(int(floor(x)), int(floor(y))) == 1

func hits(x: float, y: float, r: float) -> bool:
	for o in obst:
		if Vector2(x, y).distance_squared_to(o.pos) < pow(r + o.r, 2): return true
	for i in [-1, 0, 1]:
		for j in [-1, 0, 1]:
			if solid_at(x + i * r, y + j * r): return true
	return false

func move(p: Vector2, d: Vector2, r: float) -> Vector2:
	if not hits(p.x + d.x, p.y, r): p.x += d.x
	if not hits(p.x, p.y + d.y, r): p.y += d.y
	return p

func los(a: Vector2, b: Vector2) -> bool:
	var n := int(ceil(a.distance_to(b) / 0.375))
	for i in range(1, n):
		var q := a.lerp(b, float(i) / n)
		if solid_at(q.x, q.y): return false
	return true

func _reset() -> void:
	map = PackedByteArray(); map.resize(MW * MH); map.fill(1)
	flow = PackedInt32Array(); flow.resize(MW * MH)
	rooms = []; torches = []; decor = []; obst = []; town = null; gate = null; stairs = null

func carve(x: int, y: int, w: int, h: int) -> void:
	for j in range(y, y + h):
		for i in range(x, x + w):
			if i > 0 and j > 0 and i < MW - 1 and j < MH - 1: map[j * MW + i] = 0

func _room(x: int, y: int, w: int, h: int) -> Dictionary:
	return {x = x, y = y, w = w, h = h, cx = x + w / 2.0, cy = y + h / 2.0}

func corridor(a: Dictionary, b: Dictionary, wd := 2) -> void:
	var x := int(a.cx); var y := int(a.cy); var tx := int(b.cx); var ty := int(b.cy)
	if rng.randf() < .5:
		while x != tx:
			carve(x, y, wd, wd)
			x += signi(tx - x)
		while y != ty:
			carve(x, y, wd, wd)
			y += signi(ty - y)
	else:
		while y != ty:
			carve(x, y, wd, wd)
			y += signi(ty - y)
		while x != tx:
			carve(x, y, wd, wd)
			x += signi(tx - x)
	carve(x, y, wd, wd)

func corridor_adj(a: Dictionary, b: Dictionary, horiz: bool) -> void:
	var wd: int = pick([2, 2, 3, 4, 4, 5])
	if horiz:
		var lo: int = max(a.y, b.y) + 1; var hi: int = min(a.y + a.h, b.y + b.h) - wd - 1
		if hi >= lo:
			var y := ri(lo, hi); var l: Dictionary = a if a.x < b.x else b; var r: Dictionary = b if a.x < b.x else a
			carve(l.x + l.w - 1, y, r.x - (l.x + l.w) + 2, wd); return
	else:
		var lo: int = max(a.x, b.x) + 1; var hi: int = min(a.x + a.w, b.x + b.w) - wd - 1
		if hi >= lo:
			var x := ri(lo, hi); var t: Dictionary = a if a.y < b.y else b; var u: Dictionary = b if a.y < b.y else a
			carve(x, t.y + t.h - 1, wd, u.y - (t.y + t.h) + 2); return
	corridor(a, b, min(wd, 3))

func build_flow(from: Vector2) -> void:
	flow.fill(-1)
	var sx := int(from.x); var sy := int(from.y)
	if sx < 0 or sy < 0 or sx >= MW or sy >= MH: return
	var q := PackedInt32Array(); q.resize(MW * MH)
	var h := 0; var t := 0; var s := sy * MW + sx
	flow[s] = 0; q[t] = s; t += 1
	while h < t:
		var c := q[h]; h += 1
		var cx := c % MW; var cy := c / MW; var d := flow[c]
		for dv in DIR4:
			var nx: int = cx + dv.x; var ny: int = cy + dv.y
			if nx < 0 or ny < 0 or nx >= MW or ny >= MH: continue
			var n := ny * MW + nx
			if map[n] != 0 or flow[n] >= 0: continue
			flow[n] = d + 1; q[t] = n; t += 1

# ---------------- 마을 ----------------
func gen_town() -> void:
	_reset(); floor_no = 0
	var x0 := 24; var y0 := 20; var w := 34; var h := 20
	carve(x0, y0, w, h); carve(x0 + 16, y0 - 2, 2, 2)
	rooms.append(_room(x0, y0, w, h))
	town = {x0 = x0, y0 = y0, w = w, h = h, pathX = x0 + 15, pathW = 4, crossY = y0 + 9}
	gate = Vector2(x0 + 17, y0 - 1)
	var cx := float(x0 + 17)
	obst.append({pos = Vector2(cx, y0 + 10), r = 44 / 32.0})
	obst.append({pos = Vector2(x0 + 26, y0 + 7.3), r = 26 / 32.0})
	decor.append({kind = "fountain", pos = Vector2(cx, y0 + 10)})
	decor.append({kind = "stall", pos = Vector2(x0 + 26, y0 + 7.3)})
	const TREES := ["oak1", "oak2", "oak3", "oak4", "birch1", "birch3", "pine1", "pine2"]
	for t in [[x0+3,y0+3],[x0+6,y0+15],[x0+30,y0+16],[x0+31,y0+3],[x0+3,y0+10],[x0+21,y0+17],[x0+9,y0+2]]:
		var p := Vector2(t[0], t[1])
		decor.append({kind = "prop", p = TREES[hash2(t[0], t[1]) % TREES.size()], pos = p, s = rnd(.85, 1.2)})
		obst.append({pos = p + Vector2(0, 6 / 32.0), r = 12 / 32.0})
	const PL := ["flower1", "flower2", "fern1", "leaf1", "grass1", "grass3"]
	for k in 26:
		decor.append({kind = "prop", p = pick(PL), pos = Vector2(x0 + rnd(1, w - 1), y0 + rnd(1, h - 1)), s = .8})
	for t in [[x0+13,y0+4],[x0+21,y0+4],[x0+13,y0+16],[x0+21,y0+16]]:
		torches.append({pos = Vector2(t[0], t[1]), wall = false, lamp = true})
	for k in 4:
		torches.append({pos = Vector2(x0 + 4 + k * 9, y0), wall = true, lamp = false})
	start = Vector2(cx, y0 + h - 3)
	build_flow(start)

# ---------------- 탑의 층 ----------------
func gen_floor(fl: int) -> void:
	_reset(); floor_no = fl
	if fl in BOSS_FLOORS:
		var w := 26; var h := 20; var x := MW / 2 - w / 2; var y := MH / 2 - h / 2
		carve(x, y, w, h); rooms.append(_room(x, y, w, h))
		for p in [[x+5,y+5],[x+w-7,y+5],[x+5,y+h-7],[x+w-7,y+h-7]]:
			for j in 2:
				for i in 2: map[(p[1] + j) * MW + p[0] + i] = 1
		start = Vector2(x + w / 2.0, y + h - 3)
		stairs = Vector2(x + w / 2.0, y + 4)   # 1단계: 보스 대신 계단만
	else:
		var cols := 4; var rows := 3; var cw := (MW - 2) / cols; var ch := (MH - 2) / rows
		var cells: Array = []
		for gy in rows:
			for gx in cols:
				var w := ri(11, min(17, cw - 3)); var h := ri(8, min(14, ch - 3))
				var x := 1 + gx * cw + ri(1, cw - w - 1); var y := 1 + gy * ch + ri(1, ch - h - 1)
				cells.append({id = cells.size(), gx = gx, gy = gy, on = true, room = _room(x, y, w, h)})
		var at_c := func(gx, gy):
			for c in cells:
				if c.gx == gx and c.gy == gy and c.on: return c
			return null
		var nb := func(c) -> Array:
			var out: Array = []
			for dv in DIR4:
				var n = at_c.call(c.gx + dv.x, c.gy + dv.y)
				if n != null: out.append(n)
			return out
		var connected := func() -> bool:
			var on: Array = cells.filter(func(cc): return cc.on)
			var seen := {on[0].id: true}; var q: Array = [on[0]]
			while q.size():
				for n in nb.call(q.pop_back()):
					if not seen.has(n.id):
						seen[n.id] = true
						q.append(n)
			return seen.size() == on.size()
		for k in 2:
			var c = pick(cells.filter(func(cc): return cc.on))
			c.on = false
			if not connected.call(): c.on = true
		var on: Array = cells.filter(func(c): return c.on)
		var start_c = pick(on)
		var vis := {start_c.id: true}; var stack: Array = [start_c]; var edges: Array = []
		while stack.size():
			var c = stack[-1]
			var opts: Array = nb.call(c).filter(func(n): return not vis.has(n.id))
			if opts.is_empty():
				stack.pop_back()
				continue
			var n = pick(opts); vis[n.id] = true; edges.append([c, n]); stack.append(n)
		for c in on:
			for n in nb.call(c):
				if n.gx < c.gx or n.gy < c.gy: continue
				var dup := false
				for e in edges:
					if (e[0] == c and e[1] == n) or (e[0] == n and e[1] == c):
						dup = true
						break
				if not dup and rng.randf() < .6: edges.append([c, n])
		for e in edges.duplicate():
			if rng.randf() < .25: edges.append(e)
		rooms = [start_c.room]
		for c in on:
			if c != start_c: rooms.append(c.room)
		for r in rooms: carve(r.x, r.y, r.w, r.h)
		for e in edges: corridor_adj(e[0].room, e[1].room, e[0].gy == e[1].gy)
		var s: Dictionary = rooms[0]
		start = Vector2(s.cx, s.cy)
		build_flow(start)
		var far: Dictionary = rooms[1]; var fd := -1
		for r in rooms:
			var d := flow[int(r.cy) * MW + int(r.cx)]
			if d > fd:
				fd = d
				far = r
		stairs = Vector2(far.cx, far.cy)
	_decorate()
	build_flow(start)

func _decorate() -> void:
	var boss: bool = floor_no in BOSS_FLOORS
	const PROPS := ["barrel1", "barrel2", "dcrate1", "dcrate2", "barrel1", "lectern1", "statue1", "statue2", "chain1", "dcrate2"]
	const BONES := ["bones1", "bones2", "bones3", "bones4", "bones5", "skulls", "skeleton1", "skeleton2"]
	for r in rooms:
		var n: int = max(2, r.w / 5)
		for k in n:
			var tx: int = r.x + int(round((k + .5) * r.w / n)); var ty: int = r.y - 1
			if at(tx, ty) == 1 and at(tx, ty + 1) == 0:
				torches.append({pos = Vector2(tx + .5, r.y), wall = true, lamp = false})
		if not boss:
			for k in ri(0, 3):
				var p := Vector2(r.x + rnd(1.2, r.w - 1.2), r.y + .75)
				var pn: String = pick(PROPS)
				var close := false
				for d in decor:
					if d.kind == "prop" and absf(d.pos.x - p.x) < 1.25 and absf(d.pos.y - p.y) < 1.25: close = true
				if close: continue
				decor.append({kind = "prop", p = pn, pos = p, s = .85 if pn.begins_with("statue") else .8})
				if not pn.begins_with("chain"): obst.append({pos = p, r = 10 / 32.0})
		for k in ri(2, 6):
			if rng.randf() < .55:
				var p := Vector2(r.x + rnd(1, r.w - 1), r.y + rnd(1, r.h - 1))
				decor.append({kind = "prop", p = BONES[hash2(int(p.x * 7), int(p.y * 7)) % BONES.size()], pos = p, s = .75})

# 벽 칸의 테두리 비트: 1=북쪽이 바닥, 2=동, 4=남, 8=서. 바닥과 닿지 않은 벽은 -1
func wall_bits(i: int, j: int) -> int:
	if at(i, j) != 1: return -1
	var near := false
	for dv in DIR8:
		if at(i + dv.x, j + dv.y) == 0:
			near = true
			break
	if not near: return -1
	return (1 if at(i, j-1) == 0 else 0) | (2 if at(i+1, j) == 0 else 0) | (4 if at(i, j+1) == 0 else 0) | (8 if at(i-1, j) == 0 else 0)
