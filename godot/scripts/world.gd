# 3D 세계 만들기: 바닥·벽(덩어리로 나눠 묶음), 소품, 횃불 빛.
class_name World
extends Node3D

const CHUNK := 8
const WALLZ := 50.0 / 32.0       # 벽 높이(타일 단위)
const LOWZ := WALLZ * .3         # 방 아래쪽 테두리 벽(캐릭터를 가리지 않게 낮게)
const PF := .35                  # 소품 그림 배율(웹 버전과 같음)
const STAND := 1.305             # 세워 놓은 그림이 비스듬한 카메라에서 납작해 보이는 만큼 보정(1/cos40°)

static var TEX := {}
static var PROPM := {}

static func tex(path: String) -> Texture2D:
	if not TEX.has(path): TEX[path] = load(path)
	return TEX[path]

static func props_meta() -> Dictionary:
	if PROPM.is_empty():
		var f = FileAccess.open("res://assets/props/props.json", FileAccess.READ)
		if f: PROPM = JSON.parse_string(f.get_as_text())
	return PROPM

static var FOG_SHADER: Shader
static var fog_tex: ImageTexture
static var TINT := Color.WHITE        # 20층마다 바뀌는 분위기 색
static var TORCH := Color(1, .6, .3)
static var FLOOR_TEX := "floor2"
static func mat(t: Texture2D, _vcol := true) -> ShaderMaterial:
	if FOG_SHADER == null:
		FOG_SHADER = Shader.new()
		FOG_SHADER.code = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D fog : filter_linear;
uniform vec3 tint = vec3(1.0);
uniform float bump = 1.6;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec4 c = texture(tex, UV);
	float f = texture(fog, wp.xz / vec2(82.0, 62.0)).r;
	// 질감의 밝기를 높이로 보고 요철을 만든다(돌 틈·이음매가 빛을 받아 도드라짐)
	float h = dot(c.rgb, vec3(.3, .59, .11));
	vec3 dpx = dFdx(VERTEX); vec3 dpy = dFdy(VERTEX);
	vec3 r1 = cross(dpy, NORMAL); vec3 r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * bump);
	vec3 col = c.rgb * COLOR.rgb * tint;
	col = mix(vec3(dot(col, vec3(.3, .59, .11))), col, 1.12);   // 색을 조금 더 진하게
	ALBEDO = col * f;
	ROUGHNESS = mix(.42, .9, h);           // 밝은 돌은 살짝 반들반들 → 횃불에 은은한 광택
	SPECULAR = .28 * f;
}
"""
	var m = ShaderMaterial.new()
	m.shader = FOG_SHADER
	m.set_shader_parameter("tex", t)
	m.set_shader_parameter("fog", fog_tex)
	m.set_shader_parameter("tint", Vector3(TINT.r, TINT.g, TINT.b))
	return m

static func set_fog(bytes: PackedByteArray) -> void:
	var img = Image.create_from_data(MapGen.MW, MapGen.MH, false, Image.FORMAT_L8, bytes)
	if fog_tex == null: fog_tex = ImageTexture.create_from_image(img)
	else: fog_tex.update(img)

var mg: MapGen
var lights: Array = []   # {light, base, ph}
var fog_nodes: Array = [] # [node, x(px), y(px)] — 아직 못 본 곳이면 숨김
var time := 0.0

func build(m: MapGen) -> void:
	mg = m
	for c in get_children(): c.queue_free()
	lights.clear(); fog_nodes.clear()
	_build_ground()
	if mg.town == null: _build_walls()
	else: _build_forest()
	_build_props()
	_build_torches()
	_build_alcoves()

func update_fog() -> void:
	for f in fog_nodes:
		if is_instance_valid(f[0]): f[0].visible = mg.is_seen(f[1], f[2])

func _process(dt: float) -> void:
	time += dt
	for L in lights:
		var fl: float = .85 + .15 * sin(time * 11 + L.ph) + .08 * sin(time * 23 + L.ph * 2)
		L.light.light_energy = L.base * fl

# ---------------- 바닥 ----------------
func _uv(n: int, total: int, inset := 2.0, tw := 128.0) -> Rect2:
	var W = total * tw
	return Rect2((n * tw + inset) / W, inset / tw, (tw - inset * 2) / W, (tw - inset * 2) / tw)

func _quad_floor(st: SurfaceTool, x: float, y: float, uv: Rect2, ao: Array) -> void:
	# ao: 네 모서리 밝기 [북서, 북동, 남동, 남서]
	var p = [Vector3(x, 0, y), Vector3(x + 1, 0, y), Vector3(x + 1, 0, y + 1), Vector3(x, 0, y + 1)]
	var t = [uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]
	for k in [0, 1, 2, 0, 2, 3]:
		var a: float = ao[k]
		st.set_color(Color(a, a, a)); st.set_uv(t[k]); st.set_normal(Vector3.UP); st.add_vertex(p[k])

func _ao(i: int, j: int) -> Array:
	# 벽과 닿은 모서리를 어둡게(벽 밑 그늘)
	var c = func(dx: int, dy: int) -> float:
		var n = 0
		for v in [Vector2i(dx, 0), Vector2i(0, dy), Vector2i(dx, dy)]:
			if mg.at(i + v.x, j + v.y) == 1: n += 1
		return 1.0 - .22 * n
	return [c.call(-1, -1), c.call(1, -1), c.call(1, 1), c.call(-1, 1)]

func _build_ground() -> void:
	var town = mg.town
	var tf: Texture2D; var tp: Texture2D = null
	if town != null:
		tf = tex("res://assets/tiles/grass3.png"); tp = tex("res://assets/tiles/path3.png")
	elif mg.terrace:
		tf = tex("res://assets/tiles/plaza3.png")
	else:
		tf = tex("res://assets/tiles/%s.png" % FLOOR_TEX)
	var mf = mat(tf)
	var mp: ShaderMaterial = null
	if tp != null: mp = mat(tp)
	for cy in range(0, MapGen.MH, CHUNK):
		for cx in range(0, MapGen.MW, CHUNK):
			var sf = SurfaceTool.new(); sf.begin(Mesh.PRIMITIVE_TRIANGLES)
			var sp = SurfaceTool.new(); sp.begin(Mesh.PRIMITIVE_TRIANGLES)
			var nf = 0; var np = 0
			for j in range(cy, min(cy + CHUNK, MapGen.MH)):
				for i in range(cx, min(cx + CHUNK, MapGen.MW)):
					var h = MapGen.hash2(i, j)
					if mg.at(i, j) == 0:
						if town != null:
							var on_path: bool = town.path[j * MapGen.MW + i] == 1
							if on_path:
								_quad_floor(sp, i, j, _uv(h % 10, 16), _ao(i, j)); np += 1
							else:
								_quad_floor(sf, i, j, _uv(h % 16, 16), _ao(i, j)); nf += 1
						elif _stair_tile(i, j): continue
						elif mg.terrace:
							_quad_floor(sf, i, j, _uv(h % 10, 10), _ao(i, j)); nf += 1
						elif FLOOR_TEX == "floor":
							var n2: int = MapGen.hash2(i >> 1, j >> 1) % 14
							var W2 := 14 * 128.0
							var uvq := Rect2((n2 * 128 + (i & 1) * 64 + 1) / W2, ((j & 1) * 64 + 1) / 128.0, 62 / W2, 62 / 128.0)
							_quad_floor(sf, i, j, uvq, _ao(i, j)); nf += 1
						else:
							_quad_floor(sf, i, j, _uv(((i + j) & 1) * 8 + h % 8, 16), _ao(i, j)); nf += 1
					elif town != null:
						# 마을 바깥 숲 바닥(조금 어둡게)
						_quad_floor(sf, i, j, _uv(h % 16, 16), [.62, .62, .62, .62]); nf += 1
			if nf: _add_mesh(sf, mf)
			if np: _add_mesh(sp, mp)

func _add_mesh(st: SurfaceTool, m: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	mi.mesh = st.commit(); mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi); return mi

# ---------------- 벽 ----------------
func _face(st: SurfaceTool, a: Vector3, b: Vector3, h: float, uv: Rect2, n: Vector3, shade: float) -> void:
	# a→b 가 바닥 선, 위로 h 만큼. 낮은 벽은 그림 아래쪽만 사용
	var v0: float = uv.end.y - (uv.size.y * h / WALLZ)
	var p = [a + Vector3(0, h, 0), b + Vector3(0, h, 0), b, a]
	var t = [Vector2(uv.position.x, v0), Vector2(uv.end.x, v0), uv.end, Vector2(uv.position.x, uv.end.y)]
	var cl = [Color(shade, shade, shade), Color(shade, shade, shade), Color(shade * .62, shade * .62, shade * .62), Color(shade * .62, shade * .62, shade * .62)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_color(cl[k]); st.set_uv(t[k]); st.set_normal(n); st.add_vertex(p[k])

func _top(st: SurfaceTool, i: int, j: int, h: float, uv: Rect2) -> void:
	var p = [Vector3(i, h, j), Vector3(i + 1, h, j), Vector3(i + 1, h, j + 1), Vector3(i, h, j + 1)]
	var t = [uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_color(Color.WHITE); st.set_uv(t[k]); st.set_normal(Vector3.UP); st.add_vertex(p[k])

func _build_walls() -> void:
	var mw = mat(tex("res://assets/tiles/wall2.png")); var mt = mat(tex("res://assets/tiles/top2.png"))
	for cy in range(0, MapGen.MH, CHUNK):
		for cx in range(0, MapGen.MW, CHUNK):
			var sw = SurfaceTool.new(); sw.begin(Mesh.PRIMITIVE_TRIANGLES)
			var stt = SurfaceTool.new(); stt.begin(Mesh.PRIMITIVE_TRIANGLES)
			var n = 0
			for j in range(cy, min(cy + CHUNK, MapGen.MH)):
				for i in range(cx, min(cx + CHUNK, MapGen.MW)):
					var w = mg.wall_bits(i, j)
					if w < 0: continue
					n += 1
					var h: float = LOWZ * 1.35 if mg.terrace else (LOWZ if (w & 1) else WALLZ)
					var v = MapGen.hash2(i, j) % 6
					var uvw = Rect2((v * 128 + 2) / 768.0, 0, 124 / 768.0, 1)
					if w & 4: _face(sw, Vector3(i, 0, j + 1), Vector3(i + 1, 0, j + 1), h, uvw, Vector3.BACK, 1.0)
					if w & 8: _face(sw, Vector3(i, 0, j), Vector3(i, 0, j + 1), h, uvw, Vector3.LEFT, .78)
					if w & 2: _face(sw, Vector3(i + 1, 0, j + 1), Vector3(i + 1, 0, j), h, uvw, Vector3.RIGHT, .78)
					if w & 1: _face(sw, Vector3(i + 1, 0, j), Vector3(i, 0, j), h, uvw, Vector3.FORWARD, .7)
					_top(stt, i, j, h, _uv(w & 15, 16))
			if n:
				_add_mesh(sw, mw); _add_mesh(stt, mt)

# 마을: 벽 자리에 나무와 덤불
func _build_forest() -> void:
	const FOREST := ["pine1", "pine2", "pine3", "pine4", "oak1", "oak3", "pine1", "oak4", "birch2", "pine3"]
	const PL := ["shrub1", "shrub2", "shrub3", "grass1", "grass2", "grass3"]
	var t = mg.town
	for j in range(t.y0 - 7, t.y0 + t.h + 4):
		for i in range(t.x0 - 7, t.x0 + t.w + 7):
			if mg.at(i, j) != 1: continue
			if mg.gate != null and absf((i + .5) * 32 - mg.gate.x) < 170 and absf(j * 32 - mg.gate.y) < 48: continue
			var h = MapGen.hash2(i, j); var edge = mg.wall_bits(i, j) >= 0
			if not edge and h % 2 == 0: continue
			var p = Vector2((i + .5) * 32 + ((h >> 3) % 9 - 4) * 2, (j + .85) * 32)
			var south := false   # 마을보다 아래(카메라 쪽)면 키 큰 나무가 캐릭터를 가리므로 덤불만
			for k in range(1, 8):
				if mg.at(i, j - k) == 0: south = true
			if south:
				if (edge and h % 3 != 0) or (not edge and h % 7 == 0): add_prop(PL[h % PL.size()], p, 1.0 if edge else .9)
			else:
				add_prop(FOREST[h % FOREST.size()], p, .8 + (h % 5) * .08)

# ---------------- 소품 ----------------
func add_prop(n: String, p: Vector2, sc := 1.0) -> Node3D:
	if Props3D.supports(n):
		# 입체 소품
		var o := Props3D.make(n, sc, MapGen.hash2(int(p.x), int(p.y)) * 131 + int(p.x))
		o.position = Vector3(p.x / 32.0, 0, p.y / 32.0)
		if mg.town == null: fog_nodes.append([o, p.x, p.y])
		add_child(o); return o
	var M = props_meta()
	if not M.has(n): return null
	var m: Dictionary = M[n]
	var s = Sprite3D.new()
	s.texture = tex("res://assets/props/%s.png" % n)
	s.pixel_size = PF * sc / 32.0 * STAND
	s.centered = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.shaded = true
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if mg.town == null: fog_nodes.append([s, p.x, p.y])
	s.position = Vector3(p.x / 32.0 + (m.w / 2.0 - m.ax) * s.pixel_size, (m.ay - m.h / 2.0) * s.pixel_size, p.y / 32.0)
	add_child(s); return s

func _build_props() -> void:
	for d in mg.decor:
		if d.kind == "prop": add_prop(d.p, d.pos, d.get("s", 1.0))
		elif d.kind == "fountain":
			add_prop("fountain", d.pos, 1.0)
		elif d.kind == "stall":
			add_prop("stall", d.pos, 1.0); add_prop("barrel1", d.pos + Vector2(44, 10), .8); add_prop("crate2", d.pos + Vector2(-46, 8), .7)
		elif d.kind == "circle": _magic_circle(d.pos)

# 강화 교수가 서 있는 바닥 마법진(천천히 도는 푸른 룬 고리)
static var _circle_tex: ImageTexture
static func circle_tex() -> ImageTexture:
	if _circle_tex != null: return _circle_tex
	var N := 256; var img := Image.create(N, N, false, Image.FORMAT_RGBA8); img.fill(Color(0, 0, 0, 0))
	var c := Vector2(N / 2.0, N / 2.0)
	var dot := func(p: Vector2, a: float):
		var x := int(p.x); var y := int(p.y)
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				if x + ox < 0 or y + oy < 0 or x + ox >= N or y + oy >= N: continue
				var cur: Color = img.get_pixel(x + ox, y + oy)
				var k: float = a * (1.0 if ox == 0 and oy == 0 else .35)
				img.set_pixel(x + ox, y + oy, Color(1, 1, 1, min(1.0, cur.a + k)))
	for r in [122.0, 114.0, 72.0, 64.0]:
		for i in int(r * 7):
			var t: float = i / (r * 7.0) * TAU; dot.call(c + Vector2(cos(t), sin(t)) * r, .9)
	# 육망성
	for tri in 2:
		var pts: Array = []
		for k in 3: pts.append(c + Vector2.from_angle(tri * PI / 3 + k * TAU / 3 - PI / 2) * 112)
		for k in 3:
			var a: Vector2 = pts[k]; var b: Vector2 = pts[(k + 1) % 3]
			for i in 160: dot.call(a.lerp(b, i / 159.0), .8)
	# 룬 눈금
	for i in 24:
		var t := i / 24.0 * TAU
		for d in range(80, 106, 2):
			if i % 2 == 0 or d < 94: dot.call(c + Vector2(cos(t), sin(t)) * d, .5)
	_circle_tex = ImageTexture.create_from_image(img)
	return _circle_tex

func _magic_circle(p: Vector2) -> void:
	var q = QuadMesh.new(); q.size = Vector2(3.4, 3.4); q.orientation = PlaneMesh.FACE_Y
	var m = StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = circle_tex(); m.albedo_color = Color(.45, .75, 1.6, .95)
	var mi = MeshInstance3D.new(); mi.mesh = q; mi.material_override = m; mi.position = Vector3(p.x / 32.0, .03, p.y / 32.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mi)
	var tw = mi.create_tween().set_loops(); tw.tween_property(mi, "rotation:y", TAU, 24.0).from(0.0)
	var g = glow_quad(Color(.4, .7, 1, .35), 3.6); g.position = Vector3(p.x / 32.0, .5, p.y / 32.0); add_child(g)
	add_light(Vector3(p.x / 32.0, 1.2, p.y / 32.0), Color(.5, .75, 1), 5.0, 1.6)

# ---------------- 빛 ----------------
static var _glow_tex: Texture2D
static func glow_tex() -> Texture2D:
	if _glow_tex == null:
		var g = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(.35, Color(1, 1, 1, .6))
		var t = GradientTexture2D.new()
		t.gradient = g; t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(.5, .5); t.fill_to = Vector2(1, .5); t.width = 128; t.height = 128
		_glow_tex = t
	return _glow_tex

func glow_quad(col: Color, size: float) -> MeshInstance3D:
	var q = QuadMesh.new(); q.size = Vector2(size, size)
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = glow_tex(); m.albedo_color = col
	m.no_depth_test = false
	var mi = MeshInstance3D.new(); mi.mesh = q; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func add_light(pos: Vector3, col: Color, rng: float, energy: float) -> OmniLight3D:
	var L = OmniLight3D.new()
	L.position = pos; L.light_color = col; L.omni_range = rng; L.light_energy = energy
	L.omni_attenuation = 1.2
	add_child(L)
	lights.append({light = L, base = energy, ph = randf() * TAU})
	return L

func _stair_tile(i: int, j: int) -> bool:
	for a in mg.alcoves:
		if a.kind == "stairs" and i >= a.tx and i < a.tx + 2 and j >= a.ty0 and j < a.ty0 + a.depth: return true
	return false

# 벽을 판 자리: 계단(위로 올라가는 돌계단) / 테라스 문(바깥 빛)
func _build_alcoves() -> void:
	for a in mg.alcoves:
		var x0: float = a.tx; var zf: float = a.ty0 + a.depth; var zb: float = a.ty0
		if a.kind == "stairs":
			var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var sr = SurfaceTool.new(); sr.begin(Mesh.PRIMITIVE_TRIANGLES)
			var n := 7; var d: float = (zf - zb) / n; var hs: float = WALLZ * .95 / n
			for k in n:
				var z1: float = zf - k * d; var z0: float = z1 - d; var y: float = (k + 1) * hs
				var sh: float = 1.0 - .11 * k
				var uv := _uv((k * 3 + a.tx) % 16, 16)
				var p := [Vector3(x0, y, z0), Vector3(x0 + 2, y, z0), Vector3(x0 + 2, y, z1), Vector3(x0, y, z1)]
				var t := [uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]
				for q in [0, 1, 2, 0, 2, 3]:
					st.set_color(Color(sh, sh, sh)); st.set_uv(t[q]); st.set_normal(Vector3.UP); st.add_vertex(p[q])
				var uvw := Rect2(((k % 6) * 128 + 2) / 768.0, .55, 124 / 768.0, .12)
				var rp := [Vector3(x0, y, z1), Vector3(x0 + 2, y, z1), Vector3(x0 + 2, y - hs, z1), Vector3(x0, y - hs, z1)]
				var rt := [uvw.position, Vector2(uvw.end.x, uvw.position.y), uvw.end, Vector2(uvw.position.x, uvw.end.y)]
				for q in [0, 1, 2, 0, 2, 3]:
					sr.set_color(Color(sh * .7, sh * .7, sh * .7)); sr.set_uv(rt[q]); sr.set_normal(Vector3.BACK); sr.add_vertex(rp[q])
			_add_mesh(st, mat(tex("res://assets/tiles/floor2.png")))
			_add_mesh(sr, mat(tex("res://assets/tiles/wall2.png")))
			var g = glow_quad(Color(1, .85, .55, .45), 2.2); g.position = Vector3(x0 + 1, WALLZ * .95, zb + .3); add_child(g)
			var L = add_light(Vector3(x0 + 1, WALLZ * 1.1, zb + .8), Color(1, .85, .6), 4.5, 1.2)
			fog_nodes.append([g, (x0 + 1) * 32, zf * 32]); fog_nodes.append([L, (x0 + 1) * 32, zf * 32])
		else:
			var col := Color(.55, .72, 1, .6) if a.kind == "door" else Color(1, .8, .5, .55)
			var g = glow_quad(col, 2.0); g.position = Vector3(x0 + 1, .9, zb + .2); add_child(g)
			var L = add_light(Vector3(x0 + 1, 1.2, zb + .7), Color(col.r, col.g, col.b), 4.0, 1.3)
			if mg.town == null and not mg.terrace:
				fog_nodes.append([g, (x0 + 1) * 32, zf * 32]); fog_nodes.append([L, (x0 + 1) * 32, zf * 32])

func _build_torches() -> void:
	for t in mg.torches:
		var p: Vector2 = t.pos / 32.0
		if t.lamp:
			add_prop("brazier", t.pos + Vector2(0, 2), .55)
			var g = glow_quad(Color(1, .6, .25, .9), .9); g.position = Vector3(p.x, 1.12, p.y + .06); add_child(g)
			add_light(Vector3(p.x, 1.5, p.y + .3), Color(1, .66, .38), 6.0, 1.4)
		else:
			# 벽 횃불: 벽 남쪽 면에 붙임
			var stick = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = Vector3(.08, .3, .08)
			stick.mesh = bm; var sm = StandardMaterial3D.new(); sm.albedo_color = Color(.25, .18, .14); stick.material_override = sm
			stick.position = Vector3(p.x, WALLZ * .55, p.y + .06); add_child(stick)
			var g = glow_quad(Color(TORCH.r, TORCH.g * .92, TORCH.b * .7, 1), .7); g.position = Vector3(p.x, WALLZ * .7, p.y + .12); add_child(g)
			var g2 = glow_quad(Color(1, .9, .6, 1), .22); g2.position = Vector3(p.x, WALLZ * .68, p.y + .14); add_child(g2)
			var L = add_light(Vector3(p.x, WALLZ * .7, p.y + .6), TORCH, 5.5, 1.5)
			if mg.town == null:
				for n in [stick, g, g2, L]: fog_nodes.append([n, t.pos.x, t.pos.y + 14])

