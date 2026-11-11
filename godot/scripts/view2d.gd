# 2D 화면(위에서 비스듬히 내려다보는 3/4 탑뷰). 게임 규칙(game.gd)의 픽셀 좌표를 그대로 그린다.
# 바닥은 위에서 본 그대로, 벽·소품·캐릭터는 앞면이 보이게 세워서 그리고 y(발 위치) 순서로 겹친다.
# 빛: 어둡게 깐 뒤(CanvasModulate) 플레이어·횃불·마법 주변만 밝힘. 효과·경고 장판은 어둠 영향을 받지 않는 위층.
class_name View2D
extends Node2D

const T := 32.0
const WALL_H := 46.0        # 벽 앞면 높이(px)
const LOW_H := 15.0         # 방 아래쪽 테두리 벽(캐릭터를 가리지 않게 낮게)
const HZ := 26.0            # 3D 높이 1 → 화면 위로 몇 px
const PF := .35             # 소품 그림 배율(웹판과 같음)

var game: Game
var mg: MapGen
var cam := Camera2D.new()
var dark := CanvasModulate.new()
var ground := Node2D.new()      # 바닥(한 번 그려 두고 층이 바뀔 때만 다시)
var under := Node2D.new()       # 바닥에 붙는 것(그림자·장판·마법진) — 매 프레임
var ys := Node2D.new()          # 벽 줄·소품·캐릭터: 발 위치 순서로 겹침
var top := CanvasLayer.new()    # 효과·경고(어둠 영향 없음)
var fx_mix := Node2D.new()
var fx_add := Node2D.new()
var fog := Sprite2D.new()
var plight := PointLight2D.new()
var lpool: Array = []           # 횃불·마법 빛(가까운 것만 켬)
var actors := {}                # id → Actor2D
var player: Actor2D
var t := 0.0
var shake := Vector2()
static var GLOW: Texture2D
static var LTEX: Texture2D
static var TEX := {}
static var S2D := {}

static func tx(path: String) -> Texture2D:
	if not TEX.has(path):
		TEX[path] = load(path) if ResourceLoader.exists(path) else null
	return TEX[path]

static func glow_tex() -> Texture2D:
	if GLOW == null:
		var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.add_point(.35, Color(1, 1, 1, .55)); g.add_point(.7, Color(1, 1, 1, .15)); g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill = GradientTexture2D.FILL_RADIAL; gt.fill_from = Vector2(.5, .5); gt.fill_to = Vector2(1, .5); gt.width = 128; gt.height = 128
		GLOW = gt
	return GLOW

static func light_tex() -> Texture2D:
	if LTEX == null:
		var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.add_point(.5, Color(.55, .55, .55, 1)); g.set_color(g.get_point_count() - 1, Color(0, 0, 0, 1))
		var gt := GradientTexture2D.new(); gt.gradient = g; gt.fill = GradientTexture2D.FILL_RADIAL; gt.fill_from = Vector2(.5, .5); gt.fill_to = Vector2(1, .5); gt.width = 256; gt.height = 256
		LTEX = gt
	return LTEX

static func s2d() -> Dictionary:
	if S2D.is_empty():
		var f = FileAccess.open("res://sprites2d/sprites2d.json", FileAccess.READ)
		if f: S2D = JSON.parse_string(f.get_as_text())
	return S2D

func _ready() -> void:
	add_child(dark)
	ground.z_index = -20; add_child(ground); ground.draw.connect(_draw_ground)
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	under.z_index = -10; add_child(under); under.draw.connect(_draw_under)
	ys.y_sort_enabled = true; ys.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS; add_child(ys)
	add_child(cam); cam.make_current()
	plight.texture = light_tex(); plight.texture_scale = 2.4; plight.energy = 1.15; plight.color = Color(1, .9, .78)
	add_child(plight)
	for i in 14:
		var L := PointLight2D.new(); L.texture = light_tex(); L.visible = false; add_child(L); lpool.append(L)
	top.layer = 1; top.follow_viewport_enabled = true; add_child(top)
	fx_mix.z_index = 1; top.add_child(fx_mix); fx_mix.draw.connect(_draw_fx_mix)
	var am := CanvasItemMaterial.new(); am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fx_add.material = am; fx_add.z_index = 2; top.add_child(fx_add); fx_add.draw.connect(_draw_fx_add)
	fog.centered = false; fog.scale = Vector2(T, T); fog.z_index = 10; fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var fm := ShaderMaterial.new(); var fsh := Shader.new()
	fsh.code = "shader_type canvas_item;\nvoid fragment(){ float v = texture(TEXTURE, UV).r; COLOR = vec4(.012, .01, .025, smoothstep(.95, .2, v)); }"
	fm.shader = fsh; fog.material = fm
	top.add_child(fog)

# 화면 좌표(HUD 이름표 등)
func to_screen(x: float, y: float, up := 0.0) -> Vector2:
	return get_viewport().get_canvas_transform() * Vector2(x, y - up * .8)

# ---------------- 층 다시 만들기 ----------------
func rebuild() -> void:
	mg = game.mg
	for c in ys.get_children(): c.queue_free()
	actors.clear(); player = null
	items = ItemsLayer.new(); items.v = self; ys.add_child(items)
	var town: bool = mg.town != null
	if town: dark.color = Color(.42, .45, .62)
	elif mg.terrace: dark.color = Color(.4, .42, .6)
	else:
		var th: Dictionary = D.THEMES[D.theme(max(1, game.G.floor))]
		dark.color = Color(th.amb).lerp(Color(.3, .28, .36), .3) * .9
	plight.color = Color(1, .9, .78); plight.texture_scale = 2.6 if not town else 2.0
	ground.queue_redraw()
	# 벽: 줄마다 하나(y 순서로 캐릭터와 겹치게)
	if not town:
		for j in MapGen.MH:
			var row := WallRow.new(); row.v = self; row.j = j; row.position = Vector2(0, (j + 1) * T); row.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			ys.add_child(row)
	else:
		_forest()
	_decor()
	for tch in mg.torches: _torch(tch)
	player = Actor2D.new(); player.setup("player", 46); ys.add_child(player)
	fog.texture = World.fog_tex
	sync(0.0)

func _wall_tex() -> Texture2D:
	var wn: String = "stone_wall_04" if mg.terrace else String(D.THEMES[D.theme(max(1, game.G.floor))].wp)
	return tx("res://tex/%s_d.jpg" % wn)
func _floor_tex() -> Texture2D:
	if mg.terrace: return tx("res://tex/stone_tiles_d.jpg")
	return tx("res://tex/%s_d.jpg" % String(D.THEMES[D.theme(max(1, game.G.floor))].fp))

# 사진 질감에서 타일 한 칸(4×4칸에 한 장)
func _cell(tex: Texture2D, i: int, j: int, n := 4) -> Rect2:
	var w: float = tex.get_width() / float(n); var h: float = tex.get_height() / float(n)
	return Rect2(posmod(i, n) * w, posmod(j, n) * h, w, h)

func _draw_ground() -> void:
	if mg == null: return
	var town = mg.town
	var ft: Texture2D; var pt: Texture2D = null; var outt: Texture2D = null
	if town != null:
		ft = tx("res://tex/forrest_ground_01_d.jpg"); pt = tx("res://tex/cobblestone_floor_001_d.jpg"); outt = tx("res://tex/brown_mud_leaves_01_d.jpg")
	else: ft = _floor_tex()
	var wood := {}
	for r in mg.rooms:
		if r.get("wood", false):
			for j in range(r.y, r.y + r.h):
				for i in range(r.x, r.x + r.w): wood[j * MapGen.MW + i] = true
	var woodt := tx("res://tex/old_planks_02_d.jpg")
	for j in MapGen.MH:
		for i in MapGen.MW:
			var rc := Rect2(i * T, j * T, T + .5, T + .5)
			var v := mg.at(i, j)
			if v == 0:
				var tex2: Texture2D = ft
				if town != null and town.path[j * MapGen.MW + i] == 1: tex2 = pt
				elif wood.has(j * MapGen.MW + i) and woodt: tex2 = woodt
				if tex2: draw_texture_rect_region_g(tex2, rc, _cell(tex2, i, j))
				# 벽 옆 그늘(AO)
				if town == null:
					if mg.at(i, j - 1) == 1: _shade(rc, 0)
					if mg.at(i - 1, j) == 1: _shade(rc, 1)
					if mg.at(i + 1, j) == 1: _shade(rc, 2)
			elif town != null and outt:
				ground.draw_texture_rect_region(outt, rc, _cell(outt, i, j), Color(.6, .6, .6))
	# 계단 자리(벽을 판 곳)
	for a in mg.alcoves:
		var x0: float = a.tx * T; var y0: float = a.ty0 * T; var y1: float = (a.ty0 + a.depth) * T
		if a.kind == "stairs" or a.kind == "down":
			var n := 7
			for k in n:
				var yy: float = y1 - (k + 1) * (y1 - y0) / n
				var sh: float = (1.0 - .1 * k) if a.kind == "stairs" else (.7 - .09 * k)
				ground.draw_rect(Rect2(x0, yy, 2 * T, (y1 - y0) / n + .5), Color(.42 * sh, .4 * sh, .45 * sh))
				ground.draw_line(Vector2(x0, yy), Vector2(x0 + 2 * T, yy), Color(1, 1, 1, .18 * sh), 1.5)
		else:
			ground.draw_rect(Rect2(x0, y0, 2 * T, y1 - y0), Color(.08, .1, .16))

func draw_texture_rect_region_g(tex: Texture2D, rc: Rect2, src: Rect2) -> void:
	ground.draw_texture_rect_region(tex, rc, src)

func _shade(rc: Rect2, side: int) -> void:
	for k in 4:
		var a: float = .22 * (1.0 - k / 4.0)
		match side:
			0: ground.draw_rect(Rect2(rc.position.x, rc.position.y + k * 3, rc.size.x, 3), Color(0, 0, 0, a))
			1: ground.draw_rect(Rect2(rc.position.x + k * 3, rc.position.y, 3, rc.size.y), Color(0, 0, 0, a * .8))
			2: ground.draw_rect(Rect2(rc.end.x - (k + 1) * 3, rc.position.y, 3, rc.size.y), Color(0, 0, 0, a * .8))

# 벽 한 줄(타일 j). 위 덮개(어둡게) + 바닥 쪽으로 보이는 앞면
class WallRow extends Node2D:
	var v: View2D
	var j := 0
	func _draw() -> void:
		var mg: MapGen = v.mg
		var wt: Texture2D = v._wall_tex()
		var oy: float = -(j + 1) * T
		for i in MapGen.MW:
			var w := mg.wall_bits(i, j)
			if mg.at(i, j) != 1: continue
			var x: float = i * T; var y: float = j * T + oy
			if w < 0:
				# 벽 속(안 보이는 곳): 어둠으로 덮어 뒤쪽 바닥이 비치지 않게
				draw_rect(Rect2(x, y - WALL_H, T + .5, T + .5), Color(.02, .016, .03))
				continue
			var H: float = LOW_H * 1.35 if mg.terrace else (LOW_H if (w & 1) else WALL_H)
			# 앞면(아래쪽이 바닥이면)
			if w & 4:
				if wt: draw_texture_rect_region(wt, Rect2(x, y + T - H, T + .5, H), v._cell(wt, i, 0 if H > 20 else 1, 4), Color(.92, .9, .95))
				else: draw_rect(Rect2(x, y + T - H, T + .5, H), Color(.4, .38, .45))
				draw_rect(Rect2(x, y + T - 5, T + .5, 5), Color(0, 0, 0, .35))
				draw_rect(Rect2(x, y + T - H, T + .5, 2), Color(1, 1, 1, .1))
			# 위 덮개
			var tr := Rect2(x, y - H, T + .5, T + .5)
			if wt: draw_texture_rect_region(wt, tr, v._cell(wt, i + 2, j, 4), Color(.38, .36, .42))
			else: draw_rect(tr, Color(.2, .19, .24))
			var ec := Color(.75, .72, .8, .35)
			if w & 1: draw_line(Vector2(x, y - H), Vector2(x + T, y - H), ec, 1.5)
			if w & 8: draw_line(Vector2(x, y - H), Vector2(x, y - H + T), ec, 1.2)
			if w & 2: draw_line(Vector2(x + T, y - H), Vector2(x + T, y - H + T), ec, 1.2)

# 마을: 벽 자리에 나무와 덤불(2D 그림)
func _forest() -> void:
	const FOREST := ["pine1", "pine2", "pine3", "pine4", "oak1", "oak3", "pine1", "oak4", "birch2", "pine3"]
	const PL := ["shrub1", "shrub2", "shrub3", "grass1", "grass2", "grass3"]
	var tw = mg.town
	for j in range(max(0, tw.y0 - 7), min(MapGen.MH, tw.y0 + tw.h + 4)):
		for i in range(max(0, tw.x0 - 7), min(MapGen.MW, tw.x0 + tw.w + 7)):
			if mg.at(i, j) != 1: continue
			var h := MapGen.hash2(i, j); var edge: bool = mg.wall_bits(i, j) >= 0
			if tw.get("meadow", false) and (not edge or (i + j) % 2 != 0): continue
			if not edge and h % 2 == 0: continue
			var p := Vector2((i + .5) * T + ((h >> 3) % 9 - 4) * 2, (j + .85) * T)
			var south := false
			for k in range(1, 6):
				if mg.at(i, j - k) == 0: south = true
			if south: _prop(PL[h % PL.size()], p, 1.0)
			else: _prop(FOREST[h % FOREST.size()], p, .8 + (h % 5) * .08)

# ---------------- 소품 ----------------
func _prop(n: String, p: Vector2, sc := 1.0) -> Node2D:
	var M := World.props_meta()
	if not M.has(n): return null
	var m: Dictionary = M[n]
	var s := Sprite2D.new(); s.texture = tx("res://assets/props/%s.png" % n)
	s.centered = false; s.scale = Vector2.ONE * PF * sc
	s.offset = Vector2(-m.ax, -m.ay); s.position = p
	ys.add_child(s); return s

func _model(name: String, p: Vector2, rot: float, sc: float, h: float) -> Node2D:
	var M := s2d()
	if not M.has(name): return null
	var m: Dictionary = M[name]
	var k: int = posmod(int(round(rot / (PI / 2))), 4)
	var a: Array = m.a[k]
	var s := Sprite2D.new(); s.texture = tx("res://sprites2d/%s_%d.png" % [name, k])
	if s.texture == null: return null
	s.centered = false; s.scale = Vector2.ONE * (T / float(m.ppt)) * sc
	s.offset = Vector2(-a[0], -a[1]); s.position = p + Vector2(0, -h * HZ)
	if h > .05: s.z_index = 1
	ys.add_child(s); return s

func _decor() -> void:
	for d in mg.decor:
		match d.kind:
			"prop": _prop(d.p, d.pos, d.get("s", 1.0))
			"model": _model(d.name, d.pos, d.get("rot", 0.0), d.get("s", 1.0), d.get("h", 0.0))
			"fountain", "stall":
				var n2: Node2D = _model("Stall_Empty" if d.kind == "stall" else "Well", d.pos, 0.0, 1.0, 0.0)
				if n2 == null: _shape_node(d)
			"bars", "doorframe", "circle", "glowpt": _shape_node(d)
	if mg.gate != null: _shape_node({kind = "gate", pos = mg.gate})

# 그림이 없는 것은 도형으로(쇠창살·문틀·마법진·탑 입구 임시)
func _shape_node(d: Dictionary) -> void:
	var n := Shape.new(); n.d = d; n.v = self
	var p: Vector2 = d.get("pos", Vector2.ZERO)
	if d.kind == "bars":
		var a: Vector2 = d.get("a", p); var b: Vector2 = d.get("b", p)
		p = Vector2((a.x + b.x) / 2, max(a.y, b.y))
	if d.kind == "doorframe" and d.side != "n": p += Vector2(0, d.wd / 2.0 + 2)
	if d.kind == "circle" or d.kind == "glowpt":
		n.z_index = -1
	n.position = p; ys.add_child(n)

class Shape extends Node2D:
	var d: Dictionary
	var v: View2D
	func _process(_dt: float) -> void:
		if d.kind in ["circle", "glowpt", "gate", "fountain"]: queue_redraw()
	func _draw() -> void:
		var o: Vector2 = position
		match d.kind:
			"bars":
				var a: Vector2 = d.a - o; var b: Vector2 = d.b - o
				var L: float = a.distance_to(b); var n: int = max(2, int(L / 7))
				var H := 40.0
				for k in n + 1:
					var q: Vector2 = a.lerp(b, float(k) / n)
					draw_line(q, q + Vector2(0, -H), Color(.12, .12, .14), 2.6)
					draw_line(q + Vector2(-.8, 0), q + Vector2(-.8, -H), Color(.55, .55, .6, .6), .8)
				for yy in [-3.0, -H * .55, -H]:
					draw_line(a + Vector2(0, yy), b + Vector2(0, yy), Color(.1, .1, .12), 3.0)
			"doorframe":
				# 방 입구 나무 문틀: 북쪽 문은 기둥 둘 + 위 가로대, 동·서쪽 문은 벽을 따라 세로로
				var p0: Vector2 = d.pos - o; var W: float = d.wd; var H := WALL_H + 2
				var wc := Color(.36, .26, .18); var hl := Color(.55, .42, .3)
				if d.side == "n":
					for sx in [-1, 1]:
						var x: float = p0.x + sx * (W / 2 + 3)
						draw_rect(Rect2(x - 3.5, p0.y - H, 7, H), wc); draw_rect(Rect2(x - 3.5, p0.y - H, 2, H), hl)
					draw_rect(Rect2(p0.x - W / 2 - 8, p0.y - H - 6, W + 16, 7), wc); draw_rect(Rect2(p0.x - W / 2 - 8, p0.y - H - 6, W + 16, 2), hl)
				else:
					var x: float = p0.x
					for sy in [-1, 1]:
						var y: float = p0.y + sy * (W / 2 + 2)
						draw_rect(Rect2(x - 3, y - H, 6, H), wc); draw_rect(Rect2(x - 3, y - H, 2, H), hl)
					draw_rect(Rect2(x - 3, p0.y - W / 2 - 4 - H, 6, W + 8), wc)
			"circle":
				var red: bool = d.get("red", false)
				var c := Color(1, .3, .25) if red else Color(.6, .5, 1)
				var tt: float = v.t
				draw_arc(Vector2.ZERO, 44, 0, TAU, 48, Color(c, .55), 2.0)
				draw_arc(Vector2.ZERO, 36, tt * .5, tt * .5 + TAU, 48, Color(c, .35), 1.5)
				for k in 6:
					var aa: float = tt * .3 + k * TAU / 6
					draw_line(Vector2(cos(aa), sin(aa)) * 36, Vector2(cos(aa + TAU / 3), sin(aa + TAU / 3)) * 36, Color(c, .3), 1.2)
			"glowpt":
				draw_texture_rect(View2D.glow_tex(), Rect2(-20, -20, 40, 40), false, Color(Color(d.get("col", "#ffd27a")), .35 + .1 * sin(v.t * 3)))
			"gate":
				# 탑 입구(임시 그림): 돌 벽 + 아치 + 보랏빛 문
				var W := 300.0; var H := 150.0
				draw_rect(Rect2(-W / 2, -H, W, H), Color(.26, .24, .3))
				for k in 12: draw_rect(Rect2(-W / 2 + k * W / 12 + 2, -H - 14, W / 12 - 6, 14), Color(.26, .24, .3))
				draw_rect(Rect2(-W / 2, -H, W, 6), Color(1, 1, 1, .08))
				var pts := PackedVector2Array([Vector2(-34, 0), Vector2(-34, -70)])
				for k in 9: pts.append(Vector2(-cos(PI * k / 8) * 34, -70 - sin(PI * k / 8) * 34))
				pts.append(Vector2(34, 0))
				draw_colored_polygon(pts, Color(.35, .15, .55))
				draw_texture_rect(View2D.glow_tex(), Rect2(-60, -120, 120, 120), false, Color(.8, .5, 1, .5 + .1 * sin(v.t * 2)))
				draw_polyline(pts, Color(.55, .5, .6), 4.0)
			"fountain":
				draw_circle(Vector2.ZERO, 40, Color(.3, .3, .34)); draw_circle(Vector2.ZERO, 32, Color(.2, .35, .5))
			"stall":
				draw_rect(Rect2(-40, -50, 80, 50), Color(.4, .28, .18))

func _torch(tch: Dictionary) -> void:
	var p: Vector2 = tch.pos
	if tch.lamp:
		var s := _prop("brazier", p + Vector2(0, 14), .55)
	var n := Torch.new(); n.lamp = tch.lamp; n.v = self; n.position = p + (Vector2(0, -WALL_H * .55 + 2) if tch.wall else Vector2(0, -2))
	n.ph = randf() * TAU; n.z_index = 1 if tch.wall else 0
	ys.add_child(n)

class Torch extends Node2D:
	var lamp := false
	var v: View2D
	var ph := 0.0
	func _process(_dt: float) -> void: queue_redraw()
	func _draw() -> void:
		var fl: float = .85 + .15 * sin(v.t * 11 + ph) + .08 * sin(v.t * 23 + ph * 2)
		var fy: float = -6.0 if not lamp else -10.0
		if not lamp:
			draw_rect(Rect2(-1.5, 2, 3, 9), Color(.16, .12, .14)); draw_rect(Rect2(-3, -1, 6, 5), Color(.29, .21, .15))
		var pts := PackedVector2Array([Vector2(-4 * fl, fy + 5), Vector2(-2, fy - 6 * fl), Vector2(sin(v.t * 9 + ph) * 1.5, fy - 10 * fl), Vector2(2, fy - 6 * fl), Vector2(4 * fl, fy + 5)])
		draw_colored_polygon(pts, Color(1, .54, .16))
		draw_circle(Vector2(0, fy), 2.2 * fl, Color(1, .88, .55))

# ---------------- 매 프레임 ----------------
func sync(dt: float) -> void:
	if game.G == null or mg == null: return
	t += dt
	var G = game.G; var P = game.P
	game.shot_h = 1.5
	# 플레이어
	if player:
		player.position = Vector2(P.x, P.y + 2)
		player.face = P.face; player.set_anim(P.anim); player.at = P.at
		var blink: bool = P.inv > 0 and int(G.time * 30) % 2 == 1
		player.modulate = Color(2.2, 2.2, 2.2) if blink else Color.WHITE
		player.queue_redraw()
		P.tip = {x = P.x + cos(P.face) * 16, y = P.y - 30 + sin(P.face) * 6}
	# NPC·적·시체
	var live := {}
	for n in G.npcs:
		var key: String = "n" + String(n.id); live[key] = true
		var a: Actor2D = _actor(key, n.get("spr", n.id), 46.0)
		if n.has("tint"): a.tint = Color(n.tint).lerp(Color.WHITE, .45)
		a.position = Vector2(n.x, n.y + 13); a.face = atan2(P.y - n.y, P.x - n.x); a.at = G.time + n.x; a.visible = true; a.queue_redraw()
	for e in G.enemies:
		var key := "e%d" % e.id; live[key] = true
		var a: Actor2D = _actor(key, Game.spr_name(e), Game.enemy_h(e))
		var vis: bool = mg.is_seen(e.x, e.y)
		a.visible = vis
		if not vis: continue
		a.position = Vector2(e.x, e.y)
		a.face = atan2(e.y - P.y, e.x - P.x) if e.fearT > 0 else atan2(P.y - e.y, P.x - e.x)
		if e.has("herd") and not e.aggro and Game.hyp(e.vx, e.vy) > 6: a.face = atan2(e.vy, e.vx)
		a.set_anim(e.anim); a.at = e.at
		var alpha := 1.0
		if e.d.has("hidden"):
			var dp: float = Game.hyp(P.x - e.x, P.y - e.y)
			alpha = 1.0 if dp < 110 else (.35 if dp < 170 else .06)
		var c: Color = Color(e.tint).lerp(Color.WHITE, .25) * 1.15 if e.get("elite", false) else (Color(e.d.tint) if e.d.has("tint") else Color.WHITE)
		if e.flash > 0: c = Color(2.4, 2.4, 2.4)
		elif e.frozenT > 0: c = Color(.62, .86, 1.35)
		elif e.shield > 0: c = Color(.85, .9, 1.2)
		c.a = alpha
		a.modulate = c; a.shadow = alpha > .5
		a.queue_redraw()
	for c in G.corpses:
		var key := "c%d" % c.id; live[key] = true
		var a: Actor2D = _actor(key, c.name, c.H)
		a.position = Vector2(c.x, c.y); a.face = c.ang; a.set_anim("die"); a.at = c.t
		a.visible = mg.is_seen(c.x, c.y)
		var al: float = max(0.0, 1 - (c.t - 6) / 3) if c.t > 6 else 1.0
		a.modulate = Color(1, 1, 1, al); a.shadow = c.t < 1.0; a.z_index = -1
		a.queue_redraw()
	for k in actors.keys():
		if not live.has(k):
			actors[k].queue_free(); actors.erase(k)
	_sync_items(G, P)
	# 카메라
	var target := Vector2(P.x, P.y - 18)
	if G.state == "title": target += Vector2(sin(t * .12) * 160 + 96, -96 - sin(t * .07) * 48)
	shake = Vector2(Game.rnd(-3, 3), Game.rnd(-3, 3)) * G.shake * 6 if G.shake > 0 else Vector2()
	if dt == 0 or cam.position.distance_to(target) > 300: cam.position = target
	else: cam.position = cam.position.lerp(target, 1.0 - exp(-12.0 * dt))
	cam.offset = shake
	cam.zoom = Vector2.ONE * 1.05
	plight.position = Vector2(P.x, P.y - 20); plight.visible = mg.town == null or true
	_lights(G, P)
	if World.fog_tex != null and fog.texture != World.fog_tex: fog.texture = World.fog_tex
	fog.visible = mg.town == null and not mg.terrace
	under.queue_redraw(); fx_mix.queue_redraw(); fx_add.queue_redraw()

func _actor(key: String, sname: String, h: float) -> Actor2D:
	if actors.has(key): return actors[key]
	var a := Actor2D.new(); a.setup(sname, h); ys.add_child(a); actors[key] = a
	return a

# 상자·떨어진 물건·계단·문은 매 프레임 직접 그림(가벼움)
var items := ItemsLayer.new()
func _sync_items(G, P) -> void:
	# 가까운 아이템 찾기(HUD 줍기 안내)
	var bd := 140.0; G.nearItem = null
	for d in G.drops:
		if d.kind == "item":
			var q: float = Game.hyp(P.x - d.x, P.y - d.y)
			if q < bd:
				bd = q; G.nearItem = d
	items.queue_redraw()

class ItemsLayer extends Node2D:
	var v: View2D
	const LOOT := {gold = "loot_coins", pothp = "loot_hp", potmp = "loot_mp", scroll = "loot_scroll", stone = "loot_gem"}
	const GEAR := {staff = "loot_staff", wand = "loot_wand", sceptre = "loot_staff", ring = "loot_ring", amulet = "loot_ring", cloak = "loot_cloak", robe = "loot_cloak", gloves = "loot_cloak", belt = "loot_ring", boots = "loot_cloak"}
	func _draw() -> void:
		var game: Game = v.game; var G = game.G; var mg: MapGen = v.mg
		var M: Dictionary = Actor.meta()
		# 상자
		for c in G.chests:
			if not mg.is_seen(c.x, c.y): continue
			var n: String = "chest_o" if c.open else "chest_c"
			var pm: Dictionary = World.props_meta().get(n, {})
			var tex := View2D.tx("res://assets/props/%s.png" % n)
			if tex and not pm.is_empty():
				var k := PF * 1.0
				draw_texture_rect(tex, Rect2(c.x - pm.ax * k, c.y + 4 - pm.ay * k, pm.w * k, pm.h * k), false)
			if not c.open:
				var pul: float = .5 + .5 * sin(G.time * 3.0 + c.x)
				draw_texture_rect(View2D.glow_tex(), Rect2(c.x - 26, c.y - 30, 52, 52), false, Color(1, .8, .35, .2 + .25 * pul))
		# 떨어진 물건
		for d in G.drops:
			if not mg.is_seen(d.x, d.y): continue
			var b: float = sin(G.time * 5 + d.x) * 2
			if d.kind == "hp" or d.kind == "mp":
				var col := Color("#ff4a5a") if d.kind == "hp" else Color("#5a8cff")
				draw_texture_rect(View2D.glow_tex(), Rect2(d.x - 14, d.y - 22 + b, 28, 28), false, Color(col, .7))
				draw_circle(Vector2(d.x, d.y - 8 + b), 4.5, col)
				continue
			var ln: String = GEAR.get(d.it.base, "loot_cloak") if d.kind == "item" else LOOT.get(d.kind, "")
			if d.kind == "item":
				var rc := Color(D.RAR[d.it.rar].color)
				if d.it.rar in ["normal", "magic"]:
					draw_texture_rect(View2D.glow_tex(), Rect2(d.x - 18, d.y - 12, 36, 24), false, Color(rc, .3))
				else:
					var bw: float = 12.0 if d.it.rar in ["unique", "set"] else 8.0
					draw_rect(Rect2(d.x - bw / 2, d.y - 90, bw, 90), Color(rc, .22))
					draw_texture_rect(View2D.glow_tex(), Rect2(d.x - 26, d.y - 18, 52, 36), false, Color(rc, .5))
			if not M.has(ln): continue
			var m: Dictionary = M[ln]
			var tw: float = 14.0 if d.kind == "gold" else ((12.0 if d.it.base == "ring" else 22.0) if d.kind == "item" else 14.0)
			var k: float = tw / max(m.cw, m.ch)
			var tex := View2D.tx("res://assets/sprites/%s.png" % ln)
			if tex == null: continue
			var hh: float = d.get("h", 0.0) * HZ
			draw_texture_rect_region(tex, Rect2(d.x - m.anchor[0] * k, d.y - m.anchor[1] * k - hh + (0.0 if d.kind == "gold" else b * .5), m.cw * k, m.ch * k), Rect2(0, 0, m.cw, m.ch))
		# 계단(바닥에 둔 것)
		if mg.stairs != null and G.floor > 0 and not mg.stairs.get("alcove", false) and mg.is_seen(mg.stairs.x, mg.stairs.y):
			var st = mg.stairs
			var pm: Dictionary = World.props_meta().get("stairs_down", {})
			var tex := View2D.tx("res://assets/props/stairs_down.png")
			if tex and not pm.is_empty():
				var k := PF * .5
				draw_texture_rect(tex, Rect2(st.x - pm.w / 2.0 * k, st.y + 18 - pm.h * .62 * k, pm.w * k, pm.h * k), false)
		# 문(귀환문·파란 문)
		for pr in [[G.get("redPortal"), true], [G.portal, false]]:
			var po = pr[0]
			if po == null: continue
			var red: bool = pr[1] or po.get("red", false)
			var age: float = G.time - po.get("born", -9.0)
			var kk: float = ease(clamp(age / .5, 0.0, 1.0), .4)
			if po.has("close_at"): kk *= 1.0 - clamp((G.time - po.close_at) / .5, 0.0, 1.0)
			var c := Color(1, .35, .3) if red else Color(.45, .7, 1)
			var cen := Vector2(po.x, po.y - 26)
			draw_set_transform(cen, 0, Vector2(kk, kk))
			draw_texture_rect(View2D.glow_tex(), Rect2(-40, -48, 80, 96), false, Color(c, .55))
			for r in 4:
				var a0: float = G.time * (2.0 + r * .5) + r
				draw_arc(Vector2.ZERO, 22 - r * 4.5, a0, a0 + TAU * .7, 24, Color(c.lightened(.3 * r / 3.0), .8), 2.0)
			draw_set_transform(Vector2.ZERO)

# ---------------- 빛 ----------------
func _lights(G, P) -> void:
	var cand: Array = []
	var cp: Vector2 = cam.position
	for tch in mg.torches:
		var p: Vector2 = tch.pos
		if p.distance_to(cp) < 700 and (mg.town != null or mg.terrace or mg.is_seen(p.x, p.y + 8)):
			cand.append([p + Vector2(0, -10), Color(D.THEMES[D.theme(max(1, G.floor))].torch) if G.floor > 0 else Color(1, .62, .32), 1.25 if not tch.lamp else 1.1, 1.1, true])
	for s in G.shots: cand.append([Vector2(s.x, s.y - 30), Color(s.color), .6, 1.0, false])
	for l in G.lights:
		var k: float = l.life / l.max
		cand.append([Vector2(l.x, l.y - 20), Color(l.color), 1.2, l.en * k * k * .8, false])
	for sd in mg.sidedoors:
		cand.append([Vector2(sd.x, sd.y), Color(1, .8, .5) if sd.kind == "back" else Color(.55, .72, 1), 1.0, 1.0, false])
	cand.sort_custom(func(a, b): return a[0].distance_to(cp) < b[0].distance_to(cp))
	for i in lpool.size():
		var L: PointLight2D = lpool[i]
		if i >= cand.size():
			L.visible = false; continue
		var c: Array = cand[i]
		L.visible = true; L.position = c[0]; L.color = c[1]; L.texture_scale = c[2]
		L.energy = c[3] * ((.85 + .15 * sin(t * 11 + i) + .08 * sin(t * 23 + i * 2)) if c[4] else 1.0)

# ---------------- 바닥에 붙는 것 ----------------
func _draw_under() -> void:
	var G = game.G
	if G == null or mg == null: return
	var c := under
	# 발밑 그림자
	if player: c.draw_set_transform(Vector2(game.P.x, game.P.y + 2), 0, Vector2(1, .45)); c.draw_texture_rect(glow_tex(), Rect2(-14, -14, 28, 28), false, Color(0, 0, 0, .55)); c.draw_set_transform(Vector2.ZERO)
	for z in G.zones:
		if z.kind == "scorch":
			var k: float = z.life / z.max
			c.draw_texture_rect(glow_tex(), Rect2(z.x - z.r * 1.3, z.y - z.r * 1.3, z.r * 2.6, z.r * 2.6), false, Color(.05, .03, .02, .45 * min(1.0, k * 2)))
	# 계단·문 앞 반원
	for st in [mg.stairs, mg.door, mg.down]:
		if st == null or G.floor == 0 or not st.get("alcove", false) or not mg.is_seen(st.x, st.y + 8): continue
		var pul: float = .5 + .5 * sin(G.time * 2.4)
		c.draw_arc(Vector2(st.x, st.y), 44, 0, PI, 24, Color(.85, .85, .9, .35 + .15 * pul), 2.0)

# ---------------- 효과(위층, 어둠 영향 없음) ----------------
func _y(x: float, y: float, h: float) -> Vector2: return Vector2(x, y - h * HZ)

func _draw_fx_mix() -> void:
	var G = game.G
	if G == null or mg == null: return
	var c := fx_mix
	for f in G.fx:
		var a: float = f.life / f.max
		if f.has("dust") or f.has("smoke"):
			var col := Color(f.color); col.a = a * (.38 if f.has("smoke") else .6)
			c.draw_circle(_y(f.x, f.y, f.get("h", 0.0)), f.size * ((2.2 - a * 1.2) if f.has("smoke") else 1.0), col)
	for d in G.debris:
		if not mg.is_seen(d.x, d.y): continue
		var col := Color(d.color); col.a = min(1.0, d.life)
		c.draw_circle(Vector2(d.x, d.y - d.h), 2.5 if d.shape == "bone" else (4.0 if d.shape == "skull" else d.s), col)
	for z in G.zones:
		var a: float = min(1.0, z.life / max(z.max, .001) * 3)
		match z.kind:
			"stasis":
				c.draw_circle(Vector2(z.x, z.y), z.r, Color(.63, .47, 1, .1 * a)); c.draw_arc(Vector2(z.x, z.y), z.r, 0, TAU, 40, Color(.78, .67, 1, .6 * a), 2.5)
			"acid": c.draw_circle(Vector2(z.x, z.y), z.r, Color(.47, .75, .24, .18 * a))
			"warn":
				var tt: float = 1 - z.life / z.max
				c.draw_arc(Vector2(z.x, z.y), z.r, 0, TAU, 40, Color(.9, .35, .27, .85), 2.5); c.draw_circle(Vector2(z.x, z.y), z.r * tt, Color(.9, .35, .27, .22))
			"tele":
				if z.get("pre", 0.0) <= 0: _tele(c, z)
			"pool":
				var pc := Color(z.col); c.draw_circle(Vector2(z.x, z.y), z.r, Color(pc, .22 * a)); c.draw_arc(Vector2(z.x, z.y), z.r, 0, TAU, 32, Color(pc, .5 * a), 2.0)
	for s in G.eshots:
		var ang: float = atan2(s.vy, s.vx); var p := _y(s.x, s.y, .9)
		if s.kind == "arrow":
			c.draw_line(p - Vector2(cos(ang), sin(ang)) * 10, p, Color("#e8dcc0"), 2.0)
		elif s.kind == "spike":
			c.draw_line(p - Vector2(cos(ang), sin(ang)) * 16, p + Vector2(cos(ang), sin(ang)) * 4, Color("#d8cbb0"), 4.5)
	# 냉기 고깔
	var cn = G.get("cone")
	if cn != null and G.time - cn.t < .08 and G.state == "play":
		var P = game.P; var o := _y(P.x, P.y, 1.2)
		var pts := PackedVector2Array([o])
		for k in 13:
			var aa: float = cn.ang - cn.half + cn.half * 2 * k / 12.0
			pts.append(o + Vector2(cos(aa), sin(aa) * .8) * cn.len)
		c.draw_colored_polygon(pts, Color(Color(cn.color), .12))

const TELE_C := Color(.95, .3, .24)
func _tele(c: CanvasItem, z: Dictionary) -> void:
	var tt: float = clampf(1 - z.life / max(z.max, .001), 0, 1)
	var edge := Color(TELE_C, .9); var fill := Color(TELE_C, .16 + .14 * tt); var faint := Color(TELE_C, .07)
	var o := Vector2(z.x, z.y)
	match z.shape:
		"circle":
			c.draw_circle(o, z.r, faint); c.draw_circle(o, z.r * tt, fill); c.draw_arc(o, z.r, 0, TAU, 48, edge, 2.5)
		"donut":
			_ring(c, o, z.r0, z.r, faint); _ring(c, o, z.r0, z.r0 + (z.r - z.r0) * tt, fill)
			c.draw_arc(o, z.r0, 0, TAU, 48, edge, 2.5); c.draw_arc(o, z.r, 0, TAU, 64, edge, 2.5)
		"line":
			var dv := Vector2(cos(z.ang), sin(z.ang)); var nv: Vector2 = Vector2(-dv.y, dv.x) * z.w
			var L: float = z.len
			c.draw_colored_polygon(PackedVector2Array([o + nv, o + dv * L + nv, o + dv * L - nv, o - nv]), faint)
			c.draw_colored_polygon(PackedVector2Array([o + nv, o + dv * L * tt + nv, o + dv * L * tt - nv, o - nv]), fill)
			c.draw_polyline(PackedVector2Array([o + nv, o + dv * L + nv, o + dv * L - nv, o - nv, o + nv]), edge, 2.0)
		"fan":
			var arc := PackedVector2Array([o]); var arc2 := PackedVector2Array([o])
			for k in 21:
				var aa: float = z.ang - z.half + z.half * 2 * k / 20.0
				arc.append(o + Vector2(cos(aa), sin(aa)) * z.len); arc2.append(o + Vector2(cos(aa), sin(aa)) * z.len * max(tt, .02))
			c.draw_colored_polygon(arc, faint); c.draw_colored_polygon(arc2, fill)
			arc.append(o); c.draw_polyline(arc, edge, 2.5)
		"safe":
			var pul: float = .5 + .5 * sin(game.G.time * 8)
			c.draw_rect(Rect2(game.P.x - 900, game.P.y - 700, 1800, 1400), Color(TELE_C, .06 + .1 * tt))
			for q in z.spots:
				c.draw_circle(q, z.sr, Color(.3, 1, .45, .25 + .15 * pul))
				c.draw_arc(q, z.sr, 0, TAU, 40, Color(.45, 1, .55, .95), 3.5)
				c.draw_arc(q, z.sr * (1 - tt) + 6, 0, TAU, 40, Color(.8, 1, .85, .7), 2.0)

func _ring(c: CanvasItem, o: Vector2, r0: float, r1: float, col: Color) -> void:
	if r1 - r0 < .5: return
	c.draw_arc(o, (r0 + r1) / 2.0, 0, TAU, 64, col, r1 - r0)

func _glow(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	c.draw_texture_rect(glow_tex(), Rect2(p.x - r, p.y - r, r * 2, r * 2), false, col)

func _draw_fx_add() -> void:
	var G = game.G
	if G == null or mg == null: return
	var c := fx_add; var sh: float = game.shot_h
	var M: Dictionary = Actor.meta()
	for f in G.fx:
		var a: float = f.life / f.max
		if f.has("dust") or f.has("smoke"): continue
		var h: float = f.get("h", .06)
		if f.has("rel"):
			var hh: float = sh * .78 + f.hv * (f.d / 160.0)
			if f.mist: _glow(c, _y(f.x, f.y, hh), f.size * (3.6 - a * 2.0), Color(Color(f.color), a * .22))
			else: c.draw_circle(_y(f.x, f.y, hh), f.size * .5, Color(1, 1, 1, a * .95))
		elif f.has("flame"):
			var col: Color
			if a > .65: col = Color("#fff1c4").lerp(Color("#ffb347"), (1 - a) / .35)
			elif a > .3: col = Color("#ffb347").lerp(Color("#ff5a1f"), (.65 - a) / .35)
			else: col = Color("#ff5a1f").lerp(Color("#7a1a10"), (.3 - a) / .3)
			col.a = min(1.0, a * 1.6) * (.75 if f.has("big") else .62)
			_glow(c, _y(f.x, f.y, h + (1 - a) * .25), f.size * (1.9 - a * .9), col)
		elif f.has("flash"):
			_glow(c, _y(f.x, f.y, h), f.size * (1.6 - a * .6), Color(Color(f.color), a)); _glow(c, _y(f.x, f.y, h), f.size * .45, Color(1, 1, 1, a))
		elif f.has("cone"): _glow(c, _y(f.x, f.y, .55), f.size * (4.5 - a * 2.5), Color(Color(f.color), a * .42))
		elif f.size > 2.6: _glow(c, _y(f.x, f.y, h), f.size * 2.6, Color(Color(f.color), a * .8))
		else: c.draw_circle(_y(f.x, f.y, h), f.size * .6, Color(Color(f.color), a * .9))
	for z in G.zones:
		var a: float = min(1.0, z.life / max(z.max, .001) * 3)
		if z.kind == "ember":
			var fl: float = .8 + .2 * sin(G.time * 14 + z.x)
			_glow(c, Vector2(z.x, z.y - 3), 20 * fl, Color(Color("#ff7a2a"), .7 * a))
		elif z.kind == "scorch":
			var k: float = z.life / z.max
			_glow(c, Vector2(z.x, z.y), z.r * .8, Color(1, .4, .1, .3 * k * k))
	# 탄
	for s in G.shots:
		var p := _y(s.x, s.y, sh)
		c.draw_set_transform(Vector2(s.x, s.y), 0, Vector2(1, .4)); c.draw_texture_rect(glow_tex(), Rect2(-10, -10, 20, 20), false, Color(0, 0, 0, 0)); c.draw_set_transform(Vector2.ZERO)
		if s.els.has("fire"):
			var fl: float = .9 + .1 * sin(G.time * 40 + s.x)
			_glow(c, p, s.r * 5.2 * fl, Color(1, .45, .12, .55)); _glow(c, p, s.r * 3.3 * fl, Color(1, .75, .3, .95)); c.draw_circle(p, s.r * 1.25, Color(1, .97, .85))
		else:
			_glow(c, p, s.r * 4, Color(Color(s.color), .5))
			var sn: String = "fx_icicle" if s.els.has("frost") else ("fx_spark_blue" if s.els.has("storm") else "fx_plasma")
			_fxspr(c, M, sn, p, (s.r * 5 if sn != "fx_icicle" else s.r * 9), atan2(s.vy, s.vx) + PI if sn == "fx_icicle" else 0.0, int(G.time * 12 + s.x))
	for s in G.eshots:
		if s.kind == "arrow": continue
		var col := Color({ice = "#9fd0ff", poison = "#8fd14f", fire = "#ff6a2a", skull = "#b77bff", spit = "#d98a9a", spike = "#ffdca0"}.get(s.kind, "#ffffff"))
		var p := _y(s.x, s.y, .9)
		_glow(c, p, s.r * 2.2, Color(col, .45))
		var sn: String = {ice = "fx_spark_blue", poison = "fx_spark_green", skull = "fx_spark_red", fire = "fx_fireball", spit = "fx_spark_green"}.get(s.kind, "")
		if sn != "": _fxspr(c, M, sn, p, s.r * 8 if sn == "fx_fireball" else s.r * 4.5, atan2(s.vy, s.vx) + PI if sn == "fx_fireball" else 0.0, int(G.time * 12 + s.x))
	# 번개·광선
	for b in G.bolts:
		var col := Color(b.color)
		var pts := PackedVector2Array()
		for q in b.pts: pts.append(_y(q.x, q.y, sh))
		if (b.get("from_p", 0) or b.has("beam")) and game.P.tip != null: pts[0] = Vector2(game.P.tip.x, game.P.tip.y)
		if pts.size() < 2: continue
		if b.has("beam"):
			c.draw_polyline(pts, Color(col, .25), 24); c.draw_polyline(pts, Color(col, .6), 11); c.draw_polyline(pts, Color(1, 1, 1, .9), 4)
		elif b.has("elec"):
			var fl: float = randf_range(.65, 1.0)
			var zz := _zig(pts[0], pts[-1], 7.0)
			c.draw_polyline(zz, Color(col, .1 * fl), 11); c.draw_polyline(zz, Color(col, .35 * fl), 3.2); c.draw_polyline(zz, Color(.92, .98, 1, .8 * fl), 1.2)
			c.draw_polyline(_zig(pts[0], pts[-1], 4.5), Color(col.lightened(.35), .4 * fl), 1.0)
			_glow(c, pts[-1], randf_range(9, 13), Color(col, .35))
		else:
			c.draw_polyline(pts, Color(col, .3), 9); c.draw_polyline(pts, Color(col, .85), 3); c.draw_polyline(pts, Color.WHITE, 1.4)
	for r in G.rings:
		var tt: float = 1 - r.life / r.max; var rr: float = r.r0 + (r.r1 - r.r0) * tt; var col := Color(r.color)
		c.draw_arc(Vector2(r.x, r.y), rr, 0, TAU, 48, Color(col, (1 - tt) * .9), 4 * (1 - tt) + 1)
		c.draw_arc(Vector2(r.x, r.y), rr, 0, TAU, 48, Color(col, (1 - tt) * .25), 10 * (1 - tt) + 2)
	# 그림 효과(fx_ 시트)
	for an in G.anims:
		if not M.has(an.name): continue
		var m: Dictionary = M[an.name]; var A: Dictionary = m.anims.idle
		var fr: int = min(A.frames - 1, int(an.t / an.life * A.frames))
		var al: float = max(0.0, 1 - (an.t - an.life * .7) / (an.life * .3)) if an.t > an.life * .7 else 1.0
		_fxspr(c, M, an.name, _y(an.x, an.y, an.get("h", 0.0)), an.size, an.rot, fr, al)
	# 계단 금빛 고리
	if mg.stairs != null and G.floor > 0 and not mg.stairs.get("alcove", false) and mg.is_seen(mg.stairs.x, mg.stairs.y):
		var st = mg.stairs
		c.draw_set_transform(Vector2(st.x, st.y + 4), 0, Vector2(1, .5))
		c.draw_arc(Vector2.ZERO, 40, G.time * .8, G.time * .8 + TAU * .8, 32, Color(.89, .69, .29, .45 + .25 * sin(G.time * 3)), 3)
		c.draw_set_transform(Vector2.ZERO)
	# 스태프 끝 빛(시전 중)
	var P = game.P
	if P.firing and P.active != null and G.floor > 0 and G.state == "play" and P.tip != null:
		var pul: float = .8 + .2 * sin(G.time * 18.0)
		_glow(c, Vector2(P.tip.x, P.tip.y), 14 * pul, Color(Color(game.act_color()), .8)); c.draw_circle(Vector2(P.tip.x, P.tip.y), 2.5, Color(1, 1, 1, .9))
	# 보호막
	if P.ward > 0:
		var cen := Vector2(P.x, P.y - 22)
		c.draw_set_transform(cen, 0, Vector2(1, 1.35)); c.draw_arc(Vector2.ZERO, 24, 0, TAU, 40, Color(.5, .75, 1, .55), 2.0)
		_glow(c, Vector2.ZERO, 26, Color(.4, .65, 1, .12)); c.draw_set_transform(Vector2.ZERO)

func _zig(a: Vector2, b: Vector2, amp: float) -> PackedVector2Array:
	var L := a.distance_to(b); var n: int = max(3, int(L / 16))
	var side := (b - a).orthogonal().normalized()
	var out := PackedVector2Array([a])
	for i in range(1, n): out.append(a.lerp(b, float(i) / n) + side * randf_range(-amp, amp))
	out.append(b); return out

func _fxspr(c: CanvasItem, M: Dictionary, name: String, p: Vector2, size: float, rot: float, fr: int, al := 1.0) -> void:
	if not M.has(name): return
	var m: Dictionary = M[name]; var A: Dictionary = m.anims.idle
	var tex := tx("res://assets/sprites/%s.png" % name)
	if tex == null: return
	var f: int = posmod(fr, int(A.frames))
	var k: float = size / max(m.cw, m.ch)
	c.draw_set_transform(p, rot, Vector2(k, k))
	c.draw_texture_rect_region(tex, Rect2(-m.anchor[0], -m.anchor[1], m.cw, m.ch), Rect2(f * m.cw, int(A.row) * m.ch, m.cw, m.ch), Color(1, 1, 1, al))
	c.draw_set_transform(Vector2.ZERO)

# ---------------- 8방향 캐릭터 ----------------
class Actor2D extends Node2D:
	var sname := ""
	var m: Dictionary
	var pages: Array = []
	var anim := "stance"
	var at := 0.0
	var face := PI / 2
	var hpx := 46.0
	var tint := Color.WHITE
	var shadow := true
	func setup(n: String, h: float) -> void:
		sname = n; hpx = h
		m = Actor.meta().get(n, {})
		for i in int(m.get("pages", 1)):
			pages.append(View2D.tx("res://assets/sprites/%s%s.png" % [n, ("_%d" % i) if i > 0 else ""]))
	func set_anim(a: String) -> void:
		if a != anim:
			anim = a; at = 0.0
	func _draw() -> void:
		if shadow:
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, .42)); draw_texture_rect(View2D.glow_tex(), Rect2(-hpx * .32, -hpx * .32, hpx * .64, hpx * .64), false, Color(0, 0, 0, .5)); draw_set_transform(Vector2.ZERO)
		if m.is_empty() or pages.is_empty() or pages[0] == null: return
		var A: Dictionary = m.anims.get(anim, m.anims.get("stance", m.anims.values()[0]))
		var dir: int = Actor.fdir(face) if int(m.dirs) == 8 else 0
		var n: int = int(A.frames); var fr := 0
		if n > 1:
			var p: float = at * 1000.0 / max(1.0, float(A.dur))
			if A.type == "play_once": fr = min(n - 1, int(p * n))
			elif A.type == "back_forth":
				var mm := 2 * n - 2; var q: int = int(p * mm) % mm
				fr = q if q < n else mm - q
			else: fr = int(p * n) % n
		var k: float = hpx / float(m.get("hgt", m.ch))
		if m.has("fr"):
			var f = m.fr[(int(A.row) + dir) * int(m.nf) + fr]
			if f == null: return
			var tex: Texture2D = pages[int(f[0])]
			draw_texture_rect_region(tex, Rect2((f[5] - m.anchor[0]) * k, (f[6] - m.anchor[1]) * k, f[3] * k, f[4] * k), Rect2(f[1], f[2], f[3], f[4]), tint)
		else:
			draw_texture_rect_region(pages[0], Rect2(-m.anchor[0] * k, -m.anchor[1] * k, m.cw * k, m.ch * k), Rect2(fr * m.cw, (int(A.row) + dir) * m.ch, m.cw, m.ch), tint)
