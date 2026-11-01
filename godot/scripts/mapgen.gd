# 맵 — 웹 버전 genFloor / goTown / reveal / buildFlow 를 그대로 옮김.
# 좌표는 웹과 같은 픽셀 단위(타일 = 32px). 3D 로 그릴 때만 32 로 나눈다.
class_name MapGen
extends RefCounted

const T := 32.0
const MW := 82
const MH := 62
const DIR4 := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
const DIR8 := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1), Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]

var map := PackedByteArray()      # 1 = 벽, 0 = 바닥
var seen := PackedByteArray()     # 밝혀진 칸
var rooms: Array = []             # {x,y,w,h(타일), cx,cy(px), seen}
var flow := PackedInt32Array()
var floor_no := 0
var town = null                   # 마을이면 {x0,y0,w,h,pathX,pathW,crossY}
var gate = null                   # 마을 → 탑 입구 (px)
var stairs = null                 # {x,y,found}
var start := Vector2()
var torches: Array = []           # {pos:Vector2(px), wall:bool, lamp:bool}
var decor: Array = []             # {kind, p, pos(px), s}
var obst: Array = []              # {x,y,r} px
var boss_room = false
var terrace := false            # 야외 테라스 맵
var door = null                 # 테라스로 나가는 문 / 테라스에서 돌아오는 문 {x,y,found}
var alcoves: Array = []         # 벽을 판 자리 {tx, ty0, depth, kind}
var sidedoors: Array = []       # 동·서·남쪽 벽에 뚫은 문 {x,y,side,dx,dy,kind}
var tdir := "s"                 # 테라스가 탑에서 뻗어 나간 쪽
var down = null                 # 내려가는 계단(올라와서 도착한 자리 뒤 벽) {x,y,found}
var dirty := true                 # 안개·미니맵 다시 그리기

static func hash2(i: int, j: int) -> int:
	var h: int = (i * 374761393 + j * 668265263) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	h = h ^ (h >> 16)
	return h % 100

static func rnd(a: float, b: float) -> float: return a + randf() * (b - a)
static func ri(a: int, b: int) -> int: return int(floor(rnd(a, b + 1)))
static func pick(a: Array): return a[randi() % a.size()]

func at(i: int, j: int) -> int:
	if i < 0 or j < 0 or i >= MW or j >= MH: return 1
	return map[j * MW + i]

func solid_at(x: float, y: float) -> bool:
	return at(int(floor(x / T)), int(floor(y / T))) == 1

func hits(x: float, y: float, r: float) -> bool:
	for o in obst:
		if (x - o.x) * (x - o.x) + (y - o.y) * (y - o.y) < (r + o.r) * (r + o.r): return true
	for i in [-1, 0, 1]:
		for j in [-1, 0, 1]:
			if solid_at(x + i * r, y + j * r): return true
	return false

func move(o: Dictionary, dx: float, dy: float) -> void:
	if not hits(o.x + dx, o.y, o.r): o.x += dx
	if not hits(o.x, o.y + dy, o.r): o.y += dy

func los(ax: float, ay: float, bx: float, by: float) -> bool:
	var d = Vector2(bx - ax, by - ay).length(); var n = int(ceil(d / 12.0))
	for i in range(1, n):
		if solid_at(ax + (bx - ax) * i / n, ay + (by - ay) * i / n): return false
	return true

func is_seen(x: float, y: float) -> bool:
	var i = int(floor(x / T)); var j = int(floor(y / T))
	if i < 0 or j < 0 or i >= MW or j >= MH: return false
	return seen[j * MW + i] == 1

func _reset() -> void:
	map = PackedByteArray(); map.resize(MW * MH); map.fill(1)
	seen = PackedByteArray(); seen.resize(MW * MH); seen.fill(0)
	flow = PackedInt32Array(); flow.resize(MW * MH); flow.fill(-1)
	rooms = []; torches = []; decor = []; obst = []; town = null; gate = null; stairs = null; boss_room = false
	terrace = false; door = null; alcoves = []; down = null; sidedoors = []
	dirty = true

func carve(x: int, y: int, w: int, h: int) -> void:
	for j in range(y, y + h):
		for i in range(x, x + w):
			if i > 0 and j > 0 and i < MW - 1 and j < MH - 1: map[j * MW + i] = 0

func _room(x: int, y: int, w: int, h: int, s := false) -> Dictionary:
	return {x = x, y = y, w = w, h = h, cx = (x + w / 2.0) * T, cy = (y + h / 2.0) * T, seen = s}

func corridor(a: Dictionary, b: Dictionary, wd := 2) -> void:
	var x = int(floor(a.cx / T)); var y = int(floor(a.cy / T)); var tx = int(floor(b.cx / T)); var ty = int(floor(b.cy / T))
	if randf() < .5:
		while x != tx:
			carve(x, y, wd, wd); x += signi(tx - x)
		while y != ty:
			carve(x, y, wd, wd); y += signi(ty - y)
	else:
		while y != ty:
			carve(x, y, wd, wd); y += signi(ty - y)
		while x != tx:
			carve(x, y, wd, wd); x += signi(tx - x)
	carve(x, y, wd, wd)

func corridor_adj(a: Dictionary, b: Dictionary, horiz: bool) -> void:
	var wd: int = pick([2, 2, 3, 4, 4, 5])
	if horiz:
		var lo: int = max(a.y, b.y) + 1; var hi: int = min(a.y + a.h, b.y + b.h) - wd - 1
		if hi >= lo:
			var y = ri(lo, hi); var l: Dictionary = a if a.x < b.x else b; var r: Dictionary = b if a.x < b.x else a
			carve(l.x + l.w - 1, y, r.x - (l.x + l.w) + 2, wd); return
	else:
		var lo: int = max(a.x, b.x) + 1; var hi: int = min(a.x + a.w, b.x + b.w) - wd - 1
		if hi >= lo:
			var x = ri(lo, hi); var t: Dictionary = a if a.y < b.y else b; var u: Dictionary = b if a.y < b.y else a
			carve(x, t.y + t.h - 1, wd, u.y - (t.y + t.h) + 2); return
	corridor(a, b, min(wd, 3))

func build_flow(px: float, py: float) -> void:
	flow.fill(-1)
	var sx = int(floor(px / T)); var sy = int(floor(py / T))
	if sx < 0 or sy < 0 or sx >= MW or sy >= MH: return
	var q = PackedInt32Array(); q.resize(MW * MH)
	var h = 0; var t = 0; var s = sy * MW + sx
	flow[s] = 0; q[t] = s; t += 1
	while h < t:
		var c = q[h]; h += 1
		var cx = c % MW; var cy = c / MW; var d = flow[c]
		for dv in DIR4:
			var nx: int = cx + dv.x; var ny: int = cy + dv.y
			if nx < 0 or ny < 0 or nx >= MW or ny >= MH: continue
			var n = ny * MW + nx
			if map[n] != 0 or flow[n] >= 0: continue
			flow[n] = d + 1; q[t] = n; t += 1

func step_toward(ex: float, ey: float, px: float, py: float) -> Vector2:
	var tx = int(floor(ex / T)); var ty = int(floor(ey / T))
	if tx < 0 or ty < 0 or tx >= MW or ty >= MH: return Vector2(px, py)
	var here = flow[ty * MW + tx]
	if here <= 1: return Vector2(px, py)
	var best = here; var bx = tx; var by = ty
	for dv in DIR8:
		var nx: int = tx + dv.x; var ny: int = ty + dv.y
		if nx < 0 or ny < 0 or nx >= MW or ny >= MH: continue
		var v = flow[ny * MW + nx]
		if v < 0 or v >= best: continue
		if dv.x != 0 and dv.y != 0 and (map[ty * MW + nx] != 0 or map[ny * MW + tx] != 0): continue
		best = v; bx = nx; by = ny
	return Vector2((bx + .5) * T, (by + .5) * T)

func reveal(px: float, py: float) -> void:
	var cx = int(floor(px / T)); var cy = int(floor(py / T)); var R = 9; var ch = false
	for j in range(cy - R, cy + R + 1):
		for i in range(cx - R, cx + R + 1):
			if i < 0 or j < 0 or i >= MW or j >= MH: continue
			var k = j * MW + i
			if seen[k] == 1: continue
			if (i - cx) * (i - cx) + (j - cy) * (j - cy) > R * R: continue
			var x = (i + .5) * T; var y = (j + .5) * T
			var d: float = max(1.0, Vector2(x - px, y - py).length())
			if los(px, py, x - (x - px) / d * 14, y - (y - py) / d * 14):
				seen[k] = 1; ch = true
	if ch: dirty = true
	if stairs != null and not stairs.found and is_seen(stairs.x, stairs.y): stairs.found = true

# 안개 값(0~255): 밝혀진 바닥, 그리고 밝혀진 칸 근처 2칸 안의 벽
func fog_bytes() -> PackedByteArray:
	var ws = PackedByteArray(); ws.resize(MW * MH); ws.fill(0)
	for k in MW * MH:
		if seen[k] == 0 or map[k] != 1: continue
		var ci = k % MW; var cj = k / MW
		for b in range(-2, 3):
			for a in range(-2, 3):
				var ii = ci + a; var jj = cj + b
				if ii >= 0 and jj >= 0 and ii < MW and jj < MH: ws[jj * MW + ii] = 1
	var out = PackedByteArray(); out.resize(MW * MH)
	for k in MW * MH:
		out[k] = 255 if (seen[k] == 1 or (map[k] == 1 and ws[k] == 1)) else 0
	return out

# ---------------- 마을 ----------------
func gen_town() -> void:
	# 디아블로 마을처럼: 둥글고 울퉁불퉁한 공터 + 굽은 흙길
	_reset(); floor_no = 0
	var cx := 41; var cy := 31; var rx := 19.0; var ry := 12.0
	var ph := [randf() * TAU, randf() * TAU, randf() * TAU]
	for j in MH:
		for i in MW:
			var dx := (i + .5 - cx) / rx; var dy := (j + .5 - cy) / ry
			var a := atan2(dy, dx)
			var wob := 1.0 + .13 * sin(a * 3 + ph[0]) + .08 * sin(a * 5 + ph[1]) + .05 * sin(a * 9 + ph[2])
			if dx * dx + dy * dy < wob * wob: map[j * MW + i] = 0
	# 북쪽 탑 문까지 올라가는 길목
	var top := cy - int(ry) - 3
	carve(cx - 2, top, 4, cy - top)
	carve(cx - 5, top + 1, 10, 4)          # 탑 입구 앞 작은 돌 광장
	var x0 := cx - int(rx) - 2; var y0 := top; var w := int(rx) * 2 + 4; var h := cy + int(ry) + 3 - top
	rooms.append(_room(x0, y0, w, h, true))
	seen.fill(1)
	gate = Vector2(cx * T, (top + .5) * T)
	var fountain := Vector2(cx * T, (cy + 1) * T)
	var shop := Vector2((cx + 11) * T, (cy - 4) * T)
	var guide := Vector2((cx - 10) * T, (cy + 5) * T)
	var smith := Vector2((cx - 11) * T, (cy - 4) * T)     # 서쪽 마법진 위 강화 교수
	# 마법진 둘레는 늘 탁 트인 공터로(숲에 묻히지 않게)
	for jj in range(cy - 9, cy + 1):
		for ii in range(cx - 16, cx - 6):
			if Vector2(ii + .5, jj + .5).distance_to(smith / T) < 3.6: map[jj * MW + ii] = 0
	start = Vector2(cx * T, (cy + 9) * T)
	# 서쪽 끝: 토끼 동산으로 가는 붉은 포탈 자리(늘 비워 둠)
	var redp := Vector2((cx - 15) * T, (cy + 1) * T)
	for jj in range(cy - 3, cy + 5):
		for ii in range(cx - 19, cx - 11):
			if Vector2(ii + .5, jj + .5).distance_to(redp / T) < 2.8: map[jj * MW + ii] = 0
	# 흙길: 문→분수, 분수→상점, 분수→루멘 교수, 분수→남쪽 시작점, 상점↔루멘 교수 바깥 고리
	var path := PackedByteArray(); path.resize(MW * MH); path.fill(0)
	var curve := func(a: Vector2, b: Vector2, bend: float, wd: float):
		var mid := (a + b) / 2 + (b - a).orthogonal().normalized() * bend * T
		for k in 60:
			var t := k / 59.0
			var p: Vector2 = a.lerp(mid, t).lerp(mid.lerp(b, t), t)
			var r: float = wd * (1.0 + .25 * sin(t * 7.0 + bend))
			for jj in range(int(p.y / T - r) - 1, int(p.y / T + r) + 2):
				for ii in range(int(p.x / T - r) - 1, int(p.x / T + r) + 2):
					if ii < 0 or jj < 0 or ii >= MW or jj >= MH: continue
					if Vector2(ii + .5, jj + .5).distance_to(p / T) < r: path[jj * MW + ii] = 1
	curve.call(gate, fountain, rnd(-2.5, 2.5), 1.6)
	for jj in range(top, top + 5):
		for ii in range(cx - 5, cx + 5): path[jj * MW + ii] = 1
	curve.call(fountain, shop + Vector2(-24, 30), rnd(-4, 4), 1.3)
	curve.call(fountain, guide + Vector2(20, -10), rnd(-4, 4), 1.3)
	curve.call(fountain, start + Vector2(0, 40), rnd(-3, 3), 1.4)
	curve.call(shop + Vector2(0, 40), guide + Vector2(40, 30), rnd(5, 8), 1.0)
	curve.call(fountain, smith + Vector2(40, 10), rnd(-3, 3), 1.2)
	# 분수 둘레 광장
	for jj in range(cy - 4, cy + 6):
		for ii in range(cx - 4, cx + 5):
			if Vector2(ii + .5, jj + .5).distance_to(fountain / T) < 4.2: path[jj * MW + ii] = 1
	# 상인 미라는 매대 왼쪽 앞에 선다(매대에 가려 허리가 잘리지 않게)
	var merchant := shop + Vector2(-64, 34)
	town = {x0 = x0, y0 = y0, w = w, h = h, path = path, cx = cx, cy = cy, guide = guide, shop = merchant, stall = shop, smith = smith, fountain = fountain, redp = redp}
	obst.append({x = fountain.x, y = fountain.y, r = 46.0})
	obst.append({x = shop.x - 18, y = shop.y + 8, r = 22.0}); obst.append({x = shop.x + 18, y = shop.y + 8, r = 22.0})
	decor.append({kind = "fountain", pos = fountain})
	decor.append({kind = "stall", pos = shop + Vector2(0, 10)})
	decor.append({kind = "circle", pos = smith + Vector2(0, 14)})
	# 교수·상인 주변 소품(3D 모델) — 부딪힘 판정도 함께
	var mdl := func(name: String, pos: Vector2, rot: float, sc: float, r: float):
		decor.append({kind = "model", name = name, pos = pos, rot = rot, s = sc})
		if r > 0: obst.append({x = pos.x, y = pos.y, r = r})
	mdl.call("Anvil", smith + Vector2(66, 4), -.4, 1.0, 16.0)
	mdl.call("WeaponStand", smith + Vector2(-70, -12), .5, .9, 18.0)
	mdl.call("Workbench", smith + Vector2(4, -66), 0.0, .85, 24.0)
	mdl.call("CandleStick_Stand", smith + Vector2(-46, -46), 0.0, .9, 8.0)
	mdl.call("CandleStick_Stand", smith + Vector2(50, -46), 0.0, .9, 8.0)
	mdl.call("Bench", guide + Vector2(58, 18), -1.3, .8, 16.0)
	mdl.call("BookStand", guide + Vector2(-44, -14), .6, .8, 10.0)
	mdl.call("Book_Stack_1", guide + Vector2(-30, 22), .3, 1.6, 0.0)
	mdl.call("Barrel_Apples", shop + Vector2(52, 20), 0.0, .85, 13.0)
	mdl.call("Crate_Wooden", shop + Vector2(78, 6), .3, .75, 13.0)
	mdl.call("Bag", merchant + Vector2(-26, 8), .8, .9, 0.0)
	mdl.call("Vase_2", shop + Vector2(40, 46), 0.0, .8, 9.0)
	# 나무·덤불·꽃: 길이 아닌 곳에 자연스럽게
	const TREES := ["oak1", "oak2", "oak3", "oak4", "birch1", "birch3", "pine1", "pine2"]
	var placed := 0; var tries := 0
	while placed < 11 and tries < 400:
		tries += 1
		var ti := ri(x0 + 2, x0 + w - 3); var tj := ri(y0 + 3, y0 + h - 3)
		if at(ti, tj) != 0 or path[tj * MW + ti] or at(ti, tj + 1) != 0: continue
		var p := Vector2((ti + .5) * T, (tj + .5) * T)
		if p.distance_to(fountain) < 150 or p.distance_to(redp) < 110 or p.distance_to(shop) < 90 or p.distance_to(guide) < 90 or p.distance_to(smith) < 120 or p.distance_to(merchant) < 80 or p.distance_to(start) < 80 or p.distance_to(gate) < 260: continue
		var far := true
		for o in obst:
			if Vector2(o.x, o.y).distance_to(p) < 70: far = false
		if not far: continue
		decor.append({kind = "prop", p = TREES[hash2(ti, tj) % TREES.size()], pos = p + Vector2(0, 8), s = rnd(.85, 1.2) * .95})
		obst.append({x = p.x, y = p.y + 6, r = 12.0}); placed += 1
	const PL := ["flower1", "flower2", "fern1", "leaf1", "grass1", "grass3", "rock1", "shrub1"]
	for k in 40:
		var ti := ri(x0, x0 + w); var tj := ri(y0, y0 + h)
		if at(ti, tj) != 0 or path[tj * MW + ti]: continue
		if Vector2((ti + .5) * T, (tj + .5) * T).distance_to(gate) < 220: continue     # 탑 입구 앞은 깨끗하게
		if Vector2((ti + .5) * T, (tj + .5) * T).distance_to(redp) < 70: continue
		decor.append({kind = "prop", p = pick(PL), pos = Vector2((ti + rnd(.1, .9)) * T, (tj + rnd(.1, .9)) * T), s = .8})
	# 등불: 길가를 따라
	for q in [[fountain + Vector2(-110, -40), 0], [fountain + Vector2(110, 60), 0], [shop + Vector2(-60, 50), 0], [guide + Vector2(60, -40), 0]]:
		var p: Vector2 = q[0]
		if not solid_at(p.x, p.y): torches.append({pos = p, wall = false, lamp = true})
	build_flow(start.x, start.y)

# ---------------- 토끼 동산(디아블로 카우 레벨) ----------------
# 크기는 늘 같고 모양만 매번 다름: 여러 갈래로 뻗은 너른 풀밭 + 군데군데 나무 섬. 둘레는 숲.
var open_cells: Array = []
func gen_meadow() -> void:
	_reset(); floor_no = 150
	var B := 4
	# 무작위로 걷는 일꾼 여럿이 둥글게 파 나간다(서로 이어지게 같은 자리에서 출발)
	var c0 := Vector2i(ri(B + 8, MW - B - 9), ri(B + 8, MH - B - 9))
	var pts: Array = [c0]
	var target := int((MW - 2 * B) * (MH - 2 * B) * .5)
	var dug := 0; var guard := 0
	while dug < target and guard < 4000:
		guard += 1
		var p: Vector2i = pts[randi() % pts.size()]
		var a := randf() * TAU; var L := ri(4, 9)
		var q := Vector2i(clampi(p.x + int(cos(a) * L), B + 3, MW - B - 4), clampi(p.y + int(sin(a) * L), B + 3, MH - B - 4))
		var r := rnd(2.2, 4.6)
		for jj in range(int(q.y - r) - 1, int(q.y + r) + 2):
			for ii in range(int(q.x - r) - 1, int(q.x + r) + 2):
				if ii <= B or jj <= B or ii >= MW - B - 1 or jj >= MH - B - 1: continue
				if Vector2(ii - q.x, jj - q.y).length() < r and map[jj * MW + ii] == 1:
					map[jj * MW + ii] = 0; dug += 1
		pts.append(q)
	# 둘레를 부드럽게(세포 자동자 두 번)
	for it in 2:
		var nm := map.duplicate()
		for j in range(1, MH - 1):
			for i in range(1, MW - 1):
				var n := 0
				for dv in DIR8:
					if at(i + dv.x, j + dv.y) == 1: n += 1
				if map[j * MW + i] == 1 and n <= 3: nm[j * MW + i] = 0
				elif map[j * MW + i] == 0 and n >= 6: nm[j * MW + i] = 1
		map = nm
	# 나무 섬(몇 칸짜리 숲 덩어리) — 넓은 곳에만
	for k in ri(8, 13):
		var ci := ri(B + 4, MW - B - 5); var cj := ri(B + 4, MH - B - 5)
		var ok := true
		for dj in range(-3, 4):
			for di in range(-3, 4):
				if at(ci + di, cj + dj) != 0: ok = false
		if not ok or Vector2(ci - c0.x, cj - c0.y).length() < 6: continue
		for dj in range(0, ri(1, 3)):
			for di in range(0, ri(1, 3)): map[(cj + dj) * MW + ci + di] = 1
	# 출발점에서 닿는 곳만 남기기
	var st := c0
	if map[st.y * MW + st.x] == 1:
		for j in MH:
			for i in MW:
				if map[j * MW + i] == 0: st = Vector2i(i, j)
	var reach := PackedByteArray(); reach.resize(MW * MH); reach.fill(0)
	var q2: Array = [st]; reach[st.y * MW + st.x] = 1
	while q2.size():
		var c: Vector2i = q2.pop_back()
		for dv in DIR4:
			var n2: Vector2i = c + dv
			if at(n2.x, n2.y) == 0 and reach[n2.y * MW + n2.x] == 0:
				reach[n2.y * MW + n2.x] = 1; q2.append(n2)
	open_cells = []
	var mnx := MW; var mny := MH; var mxx := 0; var mxy := 0
	for j in MH:
		for i in MW:
			if map[j * MW + i] == 0 and reach[j * MW + i] == 0: map[j * MW + i] = 1
			elif map[j * MW + i] == 0:
				open_cells.append(Vector2i(i, j)); mnx = min(mnx, i); mny = min(mny, j); mxx = max(mxx, i); mxy = max(mxy, j)
	rooms.append(_room(mnx, mny, mxx - mnx + 1, mxy - mny + 1, true))
	seen.fill(1)
	start = Vector2((st.x + .5) * T, (st.y + .5) * T)
	var path := PackedByteArray(); path.resize(MW * MH); path.fill(0)
	town = {x0 = 7, y0 = 7, w = MW - 14, h = MH - 14, path = path, cx = st.x, cy = st.y, meadow = true}
	# 꽃·풀·바위
	const PL := ["flower1", "flower2", "fern1", "leaf1", "grass1", "grass3", "rock1", "shrub1", "flower1", "grass1"]
	for k in 90:
		var c: Vector2i = open_cells[randi() % open_cells.size()]
		var p := Vector2((c.x + rnd(.1, .9)) * T, (c.y + rnd(.1, .9)) * T)
		if p.distance_to(start) < 90: continue
		decor.append({kind = "prop", p = pick(PL), pos = p, s = .8})
	# 화톳불 몇 개(달빛 아래 붉게)
	for k in 7:
		var c: Vector2i = open_cells[randi() % open_cells.size()]
		var p := Vector2((c.x + .5) * T, (c.y + .5) * T)
		if not hits(p.x, p.y, 20): torches.append({pos = p, wall = false, lamp = true}); obst.append({x = p.x, y = p.y, r = 12.0})
	build_flow(start.x, start.y)

func far_cell(from: Vector2, min_d: float) -> Vector2:
	for k in 200:
		var c: Vector2i = open_cells[randi() % open_cells.size()]
		var p := Vector2((c.x + .5) * T, (c.y + .5) * T)
		if p.distance_to(from) >= min_d and not hits(p.x, p.y, 24): return p
	var c2: Vector2i = open_cells[randi() % open_cells.size()]
	return Vector2((c2.x + .5) * T, (c2.y + .5) * T)

# ---------------- 탑의 층(몬스터·상자는 game.gd 에서) ----------------
func gen_floor(fl: int, boss: bool, want_door := false) -> void:
	_reset(); floor_no = fl
	if boss:
		boss_room = true
		var w = 26; var h = 20; var x = MW / 2 - w / 2; var y = MH / 2 - h / 2
		carve(x, y, w, h); rooms.append(_room(x, y, w, h, true))
		for p in [[x+5,y+5],[x+w-7,y+5],[x+5,y+h-7],[x+w-7,y+h-7]]:
			for j in 2:
				for i in 2: map[(p[1] + j) * MW + p[0] + i] = 1
		for j in range(y - 1, y + h + 1):
			for i in range(x - 1, x + w + 1): seen[j * MW + i] = 1
		start = Vector2((x + w / 2.0) * T, (y + h - 3) * T)
		down = carve_alcove(rooms[0], 2, "down")
		if down != null:
			down.found = true; start = Vector2(down.x, down.y + 52)
	else:
		var cols = 4; var rows = 3; var cw = (MW - 2) / cols; var ch = (MH - 2) / rows
		var cells: Array = []
		for gy in rows:
			for gx in cols:
				var w = ri(11, min(17, cw - 3)); var h = ri(8, min(14, ch - 3))
				var x = 1 + gx * cw + ri(1, cw - w - 1); var y = 1 + gy * ch + ri(1, ch - h - 1)
				cells.append({id = cells.size(), gx = gx, gy = gy, on = true, room = _room(x, y, w, h)})
		var at_c = func(gx, gy):
			for c in cells:
				if c.gx == gx and c.gy == gy and c.on: return c
			return null
		var nb = func(c) -> Array:
			var out: Array = []
			for dv in DIR4:
				var n = at_c.call(c.gx + dv.x, c.gy + dv.y)
				if n != null: out.append(n)
			return out
		var connected = func() -> bool:
			var onl: Array = cells.filter(func(cc): return cc.on)
			var sn = {onl[0].id: true}; var q: Array = [onl[0]]
			while q.size():
				for n in nb.call(q.pop_back()):
					if not sn.has(n.id):
						sn[n.id] = true
						q.append(n)
			return sn.size() == onl.size()
		for k in 2:
			var c = pick(cells.filter(func(cc): return cc.on))
			c.on = false
			if not connected.call(): c.on = true
		var on: Array = cells.filter(func(cc): return cc.on)
		var start_c = pick(on)
		var vis = {start_c.id: true}; var stack: Array = [start_c]; var edges: Array = []
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
				var dup = false
				for e in edges:
					if (e[0].id == c.id and e[1].id == n.id) or (e[0].id == n.id and e[1].id == c.id):
						dup = true
						break
				if not dup and randf() < .6: edges.append([c, n])
		for e in edges.duplicate():
			if randf() < .25: edges.append(e)
		rooms = [start_c.room]
		for c in on:
			if c.id != start_c.id: rooms.append(c.room)
		for r in rooms: carve(r.x, r.y, r.w, r.h)
		# 방마다 쓰임새(연구실·숙소·감옥·서고·창고·의식실)와 모양(기둥·모서리 깎기) — 통로는 그 뒤에 뚫어서 늘 이어짐
		for i in rooms.size():
			var r: Dictionary = rooms[i]
			r.theme = _pick_theme(r) if i > 0 else "plain"
			if r.theme in ["plain", "storage", "ritual"] and r.w >= 12 and r.h >= 9 and randf() < .45: _shape_pillars(r)
			elif randf() < .4: _shape_octagon(r, ri(2, 3))
		for e in edges: corridor_adj(e[0].room, e[1].room, e[0].gy == e[1].gy)
		# 올라온 계단: 벽을 팔 수 있는 방을 시작 방으로 삼고, 그 북쪽 벽 계단 앞에서 시작 — 다시 내려갈 수 있다
		for idx in rooms.size():
			down = carve_alcove(rooms[idx], 2, "down")
			if down != null:
				if idx != 0:
					var tmp = rooms[0]; rooms[0] = rooms[idx]; rooms[idx] = tmp
				break
		var s: Dictionary = rooms[0]
		start = Vector2(s.cx, s.cy); s.seen = true
		if down != null:
			down.found = true; start = Vector2(down.x, down.y + 52)
		build_flow(start.x, start.y)
		var far: Dictionary = rooms[1]; var fd = -1
		for r in rooms:
			var d = flow[int(floor(r.cy / T)) * MW + int(floor(r.cx / T))]
			if d > fd:
				fd = d
				far = r
		# 계단: 가장 먼 방의 북쪽 벽을 파서 만든다(안 되면 다음으로 먼 방)
		var order: Array = rooms.duplicate()
		order.sort_custom(func(a, b): return flow[int(a.cy / T) * MW + int(a.cx / T)] > flow[int(b.cy / T) * MW + int(b.cx / T)])
		for r in order:
			if r == rooms[0]: continue
			stairs = carve_alcove(r, 2, "stairs")
			if stairs != null: break
		if stairs == null: stairs = {x = far.cx, y = far.cy, found = false, alcove = false}
		if want_door:
			# 테라스로 나가는 문: 탑의 동·서·남·북 맨 끝 방의 바깥 벽에만
			var dirs := ["n", "e", "w", "s"]; dirs.shuffle()
			for dname in dirs:
				var cand: Array = rooms.slice(1)
				match dname:
					"n": cand.sort_custom(func(a, b): return a.y < b.y)
					"s": cand.sort_custom(func(a, b): return a.y + a.h > b.y + b.h)
					"e": cand.sort_custom(func(a, b): return a.x + a.w > b.x + b.w)
					"w": cand.sort_custom(func(a, b): return a.x < b.x)
				for r in cand.slice(0, 2):
					if stairs.get("alcove", false) and absf(r.cx - stairs.x) < r.w * T and absf(r.cy - stairs.y) < r.h * T and dname == "n": continue
					door = carve_side_door(r, dname, "door")
					if door != null:
						door.dir = dname; break
				if door != null: break
	_decorate()

# 방 북쪽 벽을 2칸 너비로 판다(계단은 2칸 깊이, 문은 1칸)
func carve_alcove(r: Dictionary, depth: int, kind: String):
	var xs: Array = range(r.x + 2, r.x + r.w - 3)
	xs.shuffle()
	for x in xs:
		var ok := true
		for j in range(r.y - depth - 1, r.y):
			for i in range(x - 1, x + 3):
				if at(i, j) != 1: ok = false
		if not ok or at(x, r.y) != 0 or at(x + 1, r.y) != 0: continue
		if r.y - depth - 1 < 1: continue
		for j in range(r.y - depth, r.y):
			for i in range(x, x + 2): map[j * MW + i] = 0
		alcoves.append({tx = x, ty0 = r.y - depth, depth = depth, kind = kind})
		return {x = (x + 1) * T, y = r.y * T, found = false, alcove = true, kind = kind}
	return null

# 동·서·남쪽 벽에 2칸 너비 문(바깥으로 2칸 짜리 통로)을 뚫는다
const SIDE_D := {n = Vector2i(0, -1), e = Vector2i(1, 0), w = Vector2i(-1, 0), s = Vector2i(0, 1)}
func carve_side_door(r: Dictionary, side: String, kind: String):
	if side == "n": return carve_alcove(r, 1, kind)
	var d: Vector2i = SIDE_D[side]
	var cands: Array = []
	if side == "e" or side == "w":
		for j in range(r.y + 2, r.y + r.h - 3): cands.append(j)
	else:
		for i in range(r.x + 2, r.x + r.w - 3): cands.append(i)
	cands.shuffle()
	for c in cands:
		var cells: Array = []
		var inside: Array = []
		if side == "e":
			for k in [0, 1]:
				for q in [0, 1]: cells.append(Vector2i(r.x + r.w + q, c + k))
				inside.append(Vector2i(r.x + r.w - 1, c + k))
		elif side == "w":
			for k in [0, 1]:
				for q in [1, 2]: cells.append(Vector2i(r.x - q, c + k))
				inside.append(Vector2i(r.x, c + k))
		else:
			for k in [0, 1]:
				for q in [0, 1]: cells.append(Vector2i(c + k, r.y + r.h + q))
				inside.append(Vector2i(c + k, r.y + r.h - 1))
		var ok := true
		for cc in cells:
			if cc.x < 2 or cc.y < 2 or cc.x > MW - 3 or cc.y > MH - 3 or at(cc.x, cc.y) != 1: ok = false
			# 바로 옆이 다른 바닥이면(다른 방·통로와 붙음) 안 됨
			for dv in DIR4:
				var nb: Vector2i = cc + dv
				if at(nb.x, nb.y) == 0 and not (nb in inside): ok = false
		for ii in inside:
			if at(ii.x, ii.y) != 0: ok = false
		if not ok: continue
		for cc in cells: map[cc.y * MW + cc.x] = 0
		var pos: Vector2
		if side == "e": pos = Vector2((r.x + r.w) * T, (c + 1) * T)
		elif side == "w": pos = Vector2(r.x * T, (c + 1) * T)
		else: pos = Vector2((c + 1) * T, (r.y + r.h) * T)
		var dd := {x = pos.x, y = pos.y, found = false, alcove = false, side = side, dx = float(d.x), dy = float(d.y), kind = kind}
		sidedoors.append(dd)
		return dd
	return null

# 보스를 쓰러뜨리면 보스 방 북쪽 벽에 계단이 열린다
func open_boss_stairs() -> void:
	var r: Dictionary = rooms[0]
	stairs = carve_alcove(r, 2, "stairs")
	if stairs == null: stairs = {x = r.cx + 70, y = r.cy, found = true, alcove = false}
	stairs.found = true
	dirty = true

# ---------------- 야외 테라스 ----------------
const OPP := {n = "s", s = "n", e = "w", w = "e"}
func gen_terrace(fl: int, roof := false, dir := "s") -> void:
	_reset(); floor_no = fl; terrace = true; tdir = dir
	var w: int; var h: int
	if roof:
		w = 30; h = 22
	elif dir == "e" or dir == "w":
		w = ri(14, 22); h = ri(20, 30)             # 동·서: 세로로 긴 테라스
	else:
		w = ri(26, 42); h = ri(12, 19)             # 남·북: 가로로 긴 테라스
	var x := MW / 2 - w / 2; var y := MH / 2 - h / 2
	carve(x, y, w, h); var R := _room(x, y, w, h, true); rooms.append(R)
	var shape: String = "rect" if roof else pick(["rect", "round", "L", "cross", "garden", "pillars"])
	R.shape = shape
	var back: String = OPP[dir]
	match shape:
		"round":
			for j in range(y, y + h):
				for i in range(x, x + w):
					var dx := (i + .5 - (x + w / 2.0)) / (w / 2.0); var dy := (j + .5 - (y + h / 2.0)) / (h / 2.0)
					if dx * dx + dy * dy > 1.08: map[j * MW + i] = 1
		"L":
			# 탑 쪽(문 쪽)이 아닌 모서리 하나를 막는다
			var qx := x if randf() < .5 else x + w / 2; var qy := y if back == "s" else y + h / 2
			if back == "n": qy = y + h / 2
			for j in range(qy, qy + h / 2):
				for i in range(qx, qx + w / 2): map[j * MW + i] = 1
		"cross":
			var cw := w / 3; var ch := h / 3
			for q in [[x, y], [x + w - cw, y], [x, y + h - ch], [x + w - cw, y + h - ch]]:
				for j in range(q[1], q[1] + ch):
					for i in range(q[0], q[0] + cw): map[j * MW + i] = 1
		"garden":
			for py in range(y + 3, y + h - 4, 5):
				for px in range(x + 3, x + w - 4, 6):
					for j in 2:
						for i in 3: map[(py + j) * MW + px + i] = 1
		"pillars":
			for py in range(y + 2, y + h - 2, 4):
				for px in range(x + 3, x + w - 2, 5): map[py * MW + px] = 1
	seen.fill(1)
	if roof:
		start = Vector2(R.cx, (y + h - 3) * T)
	else:
		door = carve_side_door(R, back, "back")
		if door == null and back != "n": door = carve_alcove(R, 1, "back")
		if door == null: door = {x = R.cx, y = (y + 1) * T, found = true, alcove = false, kind = "back"}
		var dv: Vector2 = Vector2(door.get("dx", 0.0), door.get("dy", -1.0))
		start = Vector2(door.x, door.y) - dv * 46
		if solid_at(start.x, start.y): start = Vector2(R.cx, R.cy)
	for c in [[x + 1, y + 1], [x + w - 2, y + 1], [x + 1, y + h - 2], [x + w - 2, y + h - 2]]:
		if at(c[0], c[1]) == 0: torches.append({pos = Vector2((c[0] + .5) * T, (c[1] + .5) * T), wall = false, lamp = true})
	const PL := ["flower1", "flower2", "fern1", "shrub1", "shrub2", "grass1", "grass3", "rock1", "rock2"]
	for k in 30:
		var p := Vector2((x + rnd(1, w - 1)) * T, (y + rnd(2, h - 1)) * T)
		if not hits(p.x, p.y, 8) and (door == null or p.distance_to(Vector2(door.x, door.y)) > 60): decor.append({kind = "prop", p = pick(PL), pos = p, s = .8})
	build_flow(start.x, start.y)

func near_alcove(p: Vector2, r := 80.0) -> bool:
	for a in alcoves:
		var m := Vector2((a.tx + 1) * T, (a.ty0 + a.depth) * T)
		if absf(p.x - m.x) < r and p.y > m.y - 10 and p.y - m.y < r * 1.4: return true
		if absf(p.x - m.x) < 48 and p.y <= m.y and p.y > a.ty0 * T - 4: return true
	return false

# 방 가장자리 근처에 통로(방 밖의 바닥)가 이어지면 true — 통로 입구는 비워 둔다
func near_opening(r: Dictionary, p: Vector2, rad := 2) -> bool:
	var ti := int(p.x / T); var tj := int(p.y / T)
	for dj in range(-rad, rad + 1):
		for di in range(-rad, rad + 1):
			var i := ti + di; var j := tj + dj
			if at(i, j) != 0: continue
			if i < r.x or i >= r.x + r.w or j < r.y or j >= r.y + r.h: return true
	return false

const THEME_W := {plain = 28, lab = 14, dorm = 12, prison = 10, library = 14, storage = 12, ritual = 8}
func _pick_theme(r: Dictionary) -> String:
	var tot := 0
	for k in THEME_W: tot += THEME_W[k]
	for tries in 4:
		var x := randi() % tot
		for k in THEME_W:
			x -= THEME_W[k]
			if x < 0:
				if k in ["dorm", "prison", "library", "lab"] and (r.w < 10 or r.h < 8): break
				return k
	return "plain"

func _shape_pillars(r: Dictionary) -> void:
	r.shape = "pillars"
	for py in range(r.y + 3, r.y + r.h - 2, 4):
		for px in range(r.x + 3, r.x + r.w - 2, 4):
			map[py * MW + px] = 1

func _shape_octagon(r: Dictionary, c: int) -> void:
	r.shape = "octagon"
	for j in c:
		for i in c - j:
			for q in [[r.x + i, r.y + j], [r.x + r.w - 1 - i, r.y + j], [r.x + i, r.y + r.h - 1 - j], [r.x + r.w - 1 - i, r.y + r.h - 1 - j]]:
				map[q[1] * MW + q[0]] = 1

# ---------- 방 꾸미기(3D 소품) ----------
const FS := .74     # 가구 크기(사람 키에 맞춤)
func _mdl(name: String, p: Vector2, rot := 0.0, sc := FS, r_obst := 0.0, h := 0.0) -> void:
	decor.append({kind = "model", name = name, pos = p, rot = rot, s = sc, h = h})
	if r_obst > 0: obst.append({x = p.x, y = p.y, r = r_obst})

func _free(r: Dictionary, p: Vector2, rad: float) -> bool:
	if solid_at(p.x, p.y) or near_alcove(p, 60) or near_opening(r, p, 2): return false
	for o in obst:
		if p.distance_to(Vector2(o.x, o.y)) < rad + o.r: return false
	return true

func _has_alcove(r: Dictionary) -> bool:
	for a in alcoves:
		if a.tx >= r.x - 1 and a.tx <= r.x + r.w and a.ty0 + a.depth == r.y: return true
	return false

# 북쪽 벽을 따라 늘어놓기(문·계단 자리는 비움)
func _along_north(r: Dictionary, names: Array, step: float, rad: float, sc := FS) -> Array:
	var out: Array = []
	var x: float = r.x + 1.0
	while x < r.x + r.w - 1:
		var p := Vector2((x + step / 2.0) * T, (r.y + .45) * T)
		if _free(r, p, rad):
			_mdl(names[out.size() % names.size()], p, 0.0, sc, rad); out.append(p)
		x += step
	return out

func _on_table(p: Vector2, hw: float, hd: float, h: float, items: Array, n: int) -> void:
	for k in n:
		_mdl(pick(items), p + Vector2(rnd(-hw, hw), rnd(-hd, hd)), rnd(0, TAU), FS * rnd(.9, 1.15), 0.0, h)

func _decorate_theme(r: Dictionary) -> void:
	var c := Vector2(r.cx, r.cy)
	if r.theme == "prison" and _has_alcove(r): r.theme = "storage"      # 계단·문이 있는 벽엔 감방을 만들지 않음
	match r.theme:
		"lab":
			# 연구실: 가운데 큰 탁자 + 약병·책·촛불, 벽에는 장식장과 약병 선반, 구석에 솥
			if _free(r, c, 34):
				_mdl("Table_Large", c, 0.0, FS, 30.0); _on_table(c, 22, 6, .81 * FS, ["Bottle_1", "Potion_1", "Potion_2", "Potion_4", "Book_5", "Scroll_2", "Candle_1", "SmallBottles_1"], ri(5, 8))
				_mdl("Chair_1", c + Vector2(-20, 22), PI, FS, 0.0); _mdl("Chair_1", c + Vector2(18, 22), PI, FS, 0.0)
			for p in _along_north(r, ["Cabinet", "Cabinet"], 2.4, 18):
				if randf() < .7: _mdl("Shelf_Small_Bottles", p + Vector2(0, -3), 0.0, FS, 0.0, 1.0 * FS)
			var cp := Vector2((r.x + 1.6) * T, (r.y + r.h - 1.8) * T)
			if _free(r, cp, 20):
				_mdl("Cauldron", cp, 0.0, FS * 1.1, 18.0); decor.append({kind = "glowpt", pos = cp, col = Color(.45, 1, .4), h = .55})
			var bp := Vector2((r.x + r.w - 1.6) * T, (r.y + 2.2) * T)
			if _free(r, bp, 12): _mdl("BookStand", bp, -PI / 2, FS, 10.0)
			var sp := Vector2((r.x + r.w - 1.6) * T, (r.y + r.h - 1.8) * T)
			if _free(r, sp, 12): _mdl("CandleStick_Stand", sp, 0.0, FS, 9.0)
		"dorm":
			# 오래된 숙소: 나무 바닥, 북쪽 벽에 침대 줄, 사이사이 협탁, 의자·통
			r.wood = true
			var x: float = r.x + 1.0; var k := 0
			while x + 1.6 < r.x + r.w - 1:
				var p := Vector2((x + .8) * T, (r.y + .95) * T)
				if _free(r, p, 22):
					_mdl("Bed_Twin1" if k % 2 == 0 else "Bed_Twin2", p, 0.0, FS, 0.0)
					obst.append({x = p.x, y = p.y - 6, r = 18.0}); obst.append({x = p.x, y = p.y + 14, r = 16.0})
					var ns := Vector2((x + 2.05) * T, (r.y + .45) * T)
					if _free(r, ns, 9): _mdl("Nightstand_Shelf", ns, 0.0, FS, 8.0)
					if randf() < .6: _mdl("Candle_1", ns + Vector2(rnd(-3, 3), 0), 0.0, FS, 0.0, 1.22 * FS)
				x += 2.5; k += 1
			for i in ri(2, 4):
				var p := Vector2((r.x + rnd(1.5, r.w - 1.5)) * T, (r.y + rnd(3.2, r.h - 1.2)) * T)
				if _free(r, p, 14): _mdl(pick(["Stool", "Stool", "Barrel", "Crate_Wooden", "Bucket_Wooden_1"]), p, rnd(0, TAU), FS, 10.0)
			var cb := Vector2((r.x + r.w - .5) * T, (r.y + r.h / 2.0) * T)
			if _free(r, cb, 16): _mdl("Cabinet", cb, -PI / 2, FS, 14.0)
		"prison":
			# 감옥: 북쪽 벽에 쇠창살 감방(한 칸만 열림), 안에는 사슬·양동이·뼈
			var depth := 3; var cw := 3
			var y1: float = (r.y + depth) * T
			var ncell: int = (r.w - 1) / cw
			var open_i: int = randi() % max(1, ncell)
			for ci in ncell:
				var x0: float = (r.x + .5 + ci * cw) * T; var x1: float = x0 + cw * T
				if ci == open_i:
					decor.append({kind = "bars", a = Vector2(x0, y1), b = Vector2(x0 + cw * T * .35, y1)}); _bar_obst(Vector2(x0, y1), Vector2(x0 + cw * T * .35, y1))
					decor.append({kind = "bars", a = Vector2(x1 - cw * T * .3, y1), b = Vector2(x1, y1)}); _bar_obst(Vector2(x1 - cw * T * .3, y1), Vector2(x1, y1))
				else:
					decor.append({kind = "bars", a = Vector2(x0, y1), b = Vector2(x1, y1)}); _bar_obst(Vector2(x0, y1), Vector2(x1, y1))
				decor.append({kind = "bars", a = Vector2(x1, r.y * T), b = Vector2(x1, y1)}); _bar_obst(Vector2(x1, r.y * T), Vector2(x1, y1))
				var inn := Vector2((x0 + x1) / 2.0, (r.y + 1.3) * T)
				_mdl("Chain_Coil", inn + Vector2(rnd(-12, 12), -8), rnd(0, TAU), FS, 0.0)
				if randf() < .6: _mdl("Bucket_Wooden_1", inn + Vector2(rnd(-16, 16), 10), rnd(0, TAU), FS, 0.0)
				if randf() < .7: decor.append({kind = "prop", p = pick(["bones1", "bones3", "skulls", "skeleton1"]), pos = inn + Vector2(rnd(-14, 14), rnd(0, 14)), s = .7})
			decor.append({kind = "bars", a = Vector2((r.x + .5) * T, r.y * T), b = Vector2((r.x + .5) * T, y1)}); _bar_obst(Vector2((r.x + .5) * T, r.y * T), Vector2((r.x + .5) * T, y1))
			for i in ri(1, 2):
				var p := Vector2((r.x + rnd(1.5, r.w - 1.5)) * T, (r.y + rnd(depth + 1.5, r.h - 1)) * T)
				if _free(r, p, 14): _mdl(pick(["Cage_Small", "Crate_Metal", "Barrel"]), p, rnd(0, TAU), FS, 12.0)
		"library":
			# 서고: 북쪽 벽 가득 책장, 옆벽 아치 선반, 가운데 독서 탁자
			_along_north(r, ["Bookcase_2"], 1.0, 14)
			if _free(r, c, 34):
				_mdl("Table_Large", c, 0.0, FS, 30.0); _on_table(c, 22, 6, .81 * FS, ["Book_5", "Book_Stack_1", "Scroll_2", "Candle_1", "BookGroup_Medium_1"], ri(4, 7))
				_mdl("Chair_1", c + Vector2(-18, -20), 0.0, FS, 0.0); _mdl("Chair_1", c + Vector2(16, 22), PI, FS, 0.0)
			for sd in [-1, 1]:
				var p := Vector2((r.x + (.45 if sd < 0 else r.w - .45)) * T, (r.y + r.h * .5) * T)
				if _free(r, p, 14): _mdl("Shelf_Arch", p + Vector2(0, 0), PI / 2 * -sd, FS, 12.0, .61 * FS)
			for i in ri(1, 3):
				var p := Vector2((r.x + rnd(1.5, r.w - 1.5)) * T, (r.y + rnd(2.5, r.h - 1)) * T)
				if _free(r, p, 10): _mdl(pick(["BookGroup_Medium_2", "Book_Stack_1", "BookStand"]), p, rnd(0, TAU), FS, 6.0)
		"storage":
			# 창고: 구석마다 상자·통 무더기
			for corner in [Vector2(r.x + 1.3, r.y + 1.2), Vector2(r.x + r.w - 1.3, r.y + 1.2), Vector2(r.x + 1.3, r.y + r.h - 1.3), Vector2(r.x + r.w - 1.3, r.y + r.h - 1.3)]:
				if randf() < .25: continue
				for k in ri(2, 4):
					var p: Vector2 = (corner + Vector2(rnd(-.7, .7), rnd(-.6, .6))) * T
					if _free(r, p, 13): _mdl(pick(["Crate_Wooden", "Crate_Metal", "Barrel", "Barrel", "Pot_1", "Rope_1", "Bucket_Wooden_1"]), p, rnd(-.4, .4), FS, 13.0)
			var bh := Vector2(r.cx, (r.y + .5) * T)
			if _free(r, bh, 20): _mdl("Barrel_Holder", bh, 0.0, FS, 18.0)
		"ritual":
			# 의식실: 바닥에 붉은 마법진, 둘레에 촛대
			decor.append({kind = "circle", pos = c, red = true})
			for k in 6:
				var a := k * TAU / 6 + .3
				var p := c + Vector2(cos(a) * 70, sin(a) * 52)
				if _free(r, p, 10): _mdl("CandleStick_Stand", p, 0.0, FS, 8.0)

func _bar_obst(a: Vector2, b: Vector2) -> void:
	var n: int = max(1, int(a.distance_to(b) / 12))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n); obst.append({x = p.x, y = p.y, r = 7.0})

# 방과 통로가 만나는 곳(북·동·서쪽)에 나무 문틀(가끔 열린 문짝)
func _doorframes() -> void:
	for r in rooms:
		for side in ["n", "e", "w"]:
			var run: Array = []
			var cells: Array = []
			if side == "n":
				for i in range(r.x, r.x + r.w): cells.append(Vector2i(i, r.y - 1))
			else:
				var xx: int = r.x + r.w if side == "e" else r.x - 1
				for j in range(r.y, r.y + r.h): cells.append(Vector2i(xx, j))
			cells.append(Vector2i(-99, -99))
			for cc in cells:
				var open: bool = cc.x >= 0 and at(cc.x, cc.y) == 0
				if open:
					for a in alcoves:
						if cc.x >= a.tx and cc.x < a.tx + 2 and cc.y >= a.ty0 and cc.y < a.ty0 + a.depth: open = false
				if open: run.append(cc)
				else:
					if run.size() >= 2 and run.size() <= 3 and randf() < .65:
						var m: Vector2 = (Vector2(run[0]) + Vector2(run[-1])) / 2.0 + Vector2(.5, .5)
						var pos := Vector2(m.x * T, (r.y) * T) if side == "n" else Vector2((r.x + r.w if side == "e" else r.x) * T, m.y * T)
						decor.append({kind = "doorframe", pos = pos, side = side, wd = run.size() * T, leaf = randf() < .6})
					run = []

func _decorate() -> void:
	const PROPS := ["barrel1", "barrel2", "dcrate1", "dcrate2", "barrel1", "lectern1", "statue1", "statue2", "chain1", "dcrate2"]
	const BONES := ["bones1", "bones2", "bones3", "bones4", "bones5", "skulls", "skeleton1", "skeleton2"]
	for r in rooms:
		var n: int = max(2, r.w / 5)
		for k in n:
			var tx: int = r.x + int(round((k + .5) * r.w / n)); var ty: int = r.y - 1
			if at(tx, ty) == 1 and at(tx, ty + 1) == 0 and not near_alcove(Vector2((tx + .5) * T, r.y * T + 4), 40):
				torches.append({pos = Vector2((tx + .5) * T, r.y * T), wall = true, lamp = false})
		if not boss_room and r.get("theme", "plain") != "plain":
			_decorate_theme(r)
		elif not boss_room:
			for k in ri(0, 3):
				var p = Vector2((r.x + rnd(1.2, r.w - 1.2)) * T, (r.y + .75) * T)
				var pn: String = pick(PROPS)
				var close = false
				for d in decor:
					if d.kind == "prop" and absf(d.pos.x - p.x) < 40 and absf(d.pos.y - p.y) < 40: close = true
				if close or near_alcove(p) or near_opening(r, p): continue
				decor.append({kind = "prop", p = pn, pos = p, s = .85 if pn.begins_with("statue") else .8})
				if not pn.begins_with("chain"): obst.append({x = p.x, y = p.y, r = 14.0})
		if r.get("theme", "plain") in ["lab", "library", "dorm"]: continue
		for k in ri(2, 6):
			if randf() < .55:
				var p = Vector2((r.x + rnd(1, r.w - 1)) * T, (r.y + rnd(1, r.h - 1)) * T)
				if near_alcove(p) or near_opening(r, p): continue
				decor.append({kind = "prop", p = BONES[hash2(int(p.x), int(p.y)) % BONES.size()], pos = p, s = .75})
	if not boss_room and not terrace: _doorframes()

# 벽 칸의 테두리 비트: 1=북쪽이 바닥, 2=동, 4=남, 8=서. 바닥과 닿지 않은 벽은 -1
func wall_bits(i: int, j: int) -> int:
	if at(i, j) != 1: return -1
	var near = false
	for dv in DIR8:
		if at(i + dv.x, j + dv.y) == 0:
			near = true
			break
	if not near: return -1
	return (1 if at(i, j-1) == 0 else 0) | (2 if at(i+1, j) == 0 else 0) | (4 if at(i, j+1) == 0 else 0) | (8 if at(i-1, j) == 0 else 0)
