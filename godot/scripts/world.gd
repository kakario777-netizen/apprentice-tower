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

# 사진 질감(Poly Haven): 색·요철(노멀)·거칠기. 타일과 상관없이 월드 좌표로 이어 붙인다.
static var PBR_SHADER: Shader
static var PBR := {}
static func pbr(name: String, scale := .4) -> ShaderMaterial:
	var key := "%s|%s|%s" % [name, scale, TINT.to_html()]
	if PBR.has(key): return PBR[key]
	if PBR_SHADER == null:
		PBR_SHADER = Shader.new()
		PBR_SHADER.code = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_t : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_t : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_t : filter_linear_mipmap, repeat_enable;
uniform sampler2D fog : filter_linear;
uniform vec3 tint = vec3(1.0);
uniform float scale = .4;
uniform float nstr = 1.3;
uniform float bright = 1.0;
varying vec3 wp;
varying vec3 wn;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	vec2 uv = abs(wn.y) > .5 ? wp.xz : (abs(wn.x) > .5 ? vec2(wp.z, -wp.y) : vec2(wp.x, -wp.y));
	uv *= scale;
	vec3 c = texture(albedo_t, uv).rgb;
	float f = texture(fog, wp.xz / vec2(82.0, 62.0)).r;
	// 노멀맵: 화면 미분으로 접선 공간을 만들어 적용
	vec3 tn = texture(normal_t, uv).rgb * 2.0 - 1.0; tn.xy *= nstr;
	vec3 N = NORMAL;
	vec3 dp1 = dFdx(VERTEX); vec3 dp2 = dFdy(VERTEX); vec2 du1 = dFdx(uv); vec2 du2 = dFdy(uv);
	vec3 dp2p = cross(dp2, N); vec3 dp1p = cross(N, dp1);
	vec3 T = dp2p * du1.x + dp1p * du2.x; vec3 B = dp2p * du1.y + dp1p * du2.y;
	float im = inversesqrt(max(max(dot(T, T), dot(B, B)), 1e-12));
	NORMAL = normalize(mat3(T * im, -B * im, N) * normalize(tn));
	c = mix(vec3(dot(c, vec3(.3, .59, .11))), c, .85) * .82 * bright;   // 사진 질감은 살짝 차분하게
	ALBEDO = c * COLOR.rgb * tint * f;
	ROUGHNESS = clamp(texture(rough_t, uv).r * 1.05, .3, 1.0);
	SPECULAR = .4 * f;
}
"""
	var m := ShaderMaterial.new(); m.shader = PBR_SHADER
	m.set_shader_parameter("albedo_t", tex("res://tex/%s_d.jpg" % name))
	m.set_shader_parameter("normal_t", tex("res://tex/%s_n.jpg" % name))
	m.set_shader_parameter("rough_t", tex("res://tex/%s_r.jpg" % name))
	m.set_shader_parameter("fog", fog_tex); m.set_shader_parameter("scale", scale)
	m.set_shader_parameter("bright", {mossy_cobblestone = .55, embedded_rock_floor = .9, stone_tiles_02 = .8, forrest_ground_01 = .85}.get(name, 1.0))
	m.set_shader_parameter("tint", Vector3(TINT.r, TINT.g, TINT.b))
	PBR[key] = m
	return m

static var FLOOR_PBR := ""   # 층 분위기마다 바닥·벽 사진 질감
static var WALL_PBR := ""

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
	# 사진 질감으로
	if town != null:
		mf = pbr("forrest_ground_01", .35); mp = pbr("cobblestone_floor_001", .5)
	elif mg.terrace: mf = pbr("stone_tiles", .4)
	elif FLOOR_PBR != "": mf = pbr(FLOOR_PBR, .26 if FLOOR_PBR == "mossy_cobblestone" else .4)
	for cy in range(0, MapGen.MH, CHUNK):
		for cx in range(0, MapGen.MW, CHUNK):
			var sf = SurfaceTool.new(); sf.begin(Mesh.PRIMITIVE_TRIANGLES)
			var sp = SurfaceTool.new(); sp.begin(Mesh.PRIMITIVE_TRIANGLES)
			var sp2 = SurfaceTool.new(); sp2.begin(Mesh.PRIMITIVE_TRIANGLES)
			var nf = 0; var np = 0; var nf2 = 0
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
						_quad_floor(sp2, i, j, _uv(h % 16, 16), [.62, .62, .62, .62]); nf2 += 1
			if nf: _add_mesh(sf, mf)
			if np: _add_mesh(sp, mp)
			if nf2: _add_mesh(sp2, pbr("brown_mud_leaves_01", .35))

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
	var wn: String = "stone_wall_04" if mg.terrace else WALL_PBR
	if wn != "":
		mw = pbr(wn, .55); mt = pbr(wn, .55)
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
	const FOREST := ["fpine", "fpine", "foak", "fpine", "foak"]
	const PL := ["shrub1", "shrub2", "shrub3", "grass1", "grass2", "grass3"]
	var t = mg.town
	for j in range(t.y0 - 7, t.y0 + t.h + 4):
		for i in range(t.x0 - 7, t.x0 + t.w + 7):
			if mg.at(i, j) != 1: continue
			if mg.gate != null and absf((i + .5) * 32 - mg.gate.x) < 230 and j * 32 - mg.gate.y > -110 and j * 32 - mg.gate.y < 140: continue
			var h = MapGen.hash2(i, j); var edge = mg.wall_bits(i, j) >= 0
			# 진짜 나무 모델은 크고 무거우니 둘레에 듬성듬성(가장자리는 한 칸 걸러, 안쪽은 더 드물게)
			if edge and (i + j) % 2 == 1: continue
			if not edge and not (i % 3 == 0 and j % 2 == 0 and h % 2 == 0): continue
			var p = Vector2((i + .5) * 32 + ((h >> 3) % 9 - 4) * 2, (j + .85) * 32)
			var south := false   # 마을보다 아래(카메라 쪽)면 키 큰 나무가 캐릭터를 가리므로 덤불만
			for k in range(1, 8):
				if mg.at(i, j - k) == 0: south = true
			if south:
				if (edge and h % 3 != 0) or (not edge and h % 7 == 0): add_prop(PL[h % PL.size()], p, 1.0 if edge else .9)
			else:
				Props3D.cast = false     # 둘레 숲 나무는 그림자 없이(가볍게)
				add_prop(FOREST[h % FOREST.size()], p, .8 + (h % 5) * .08)
				Props3D.cast = true

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
		if (a.kind == "stairs" or a.kind == "down") and i >= a.tx and i < a.tx + 2 and j >= a.ty0 and j < a.ty0 + a.depth: return true
	return false

# 벽을 판 자리: 계단(위로 올라가는 돌계단) / 테라스 문(바깥 빛)
func _build_alcoves() -> void:
	for a in mg.alcoves:
		var x0: float = a.tx; var zf: float = a.ty0 + a.depth; var zb: float = a.ty0
		if a.kind == "stairs" or a.kind == "down":
			# 돌계단: 올라가는 계단은 벽 속으로 오르고, 내려가는 계단은 바닥 밑 어둠으로 내려간다
			var up: bool = a.kind == "stairs"
			var st = SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var sr = SurfaceTool.new(); sr.begin(Mesh.PRIMITIVE_TRIANGLES)
			var n := 8; var d: float = (zf - zb) / n; var hs: float = WALLZ * .95 / n
			for k in n:
				var z1: float = zf - k * d; var z0: float = z1 - d
				var y: float = (k + 1) * hs if up else -(k + 1) * hs
				var sh: float = (1.0 - .09 * k) if up else (.85 - .1 * k)
				var p := [Vector3(x0, y, z0), Vector3(x0 + 2, y, z0), Vector3(x0 + 2, y, z1), Vector3(x0, y, z1)]
				for q in [0, 1, 2, 0, 2, 3]:
					st.set_color(Color(sh, sh, sh)); st.set_uv(Vector2(p[q].x, p[q].z)); st.set_normal(Vector3.UP); st.add_vertex(p[q])
				var ytop: float = y if up else y + hs
				var rp := [Vector3(x0, ytop, z1), Vector3(x0 + 2, ytop, z1), Vector3(x0 + 2, ytop - hs, z1), Vector3(x0, ytop - hs, z1)]
				for q in [0, 1, 2, 0, 2, 3]:
					sr.set_color(Color(sh * .65, sh * .65, sh * .65)); sr.set_uv(Vector2(rp[q].x, rp[q].y)); sr.set_normal(Vector3.BACK); sr.add_vertex(rp[q])
			if not up:
				# 내려가는 구덩이의 양옆·안쪽 벽
				var D2: float = -WALLZ * 1.1
				for wq in [[Vector3(x0, 0, zf), Vector3(x0, 0, zb), Vector3.RIGHT], [Vector3(x0 + 2, 0, zb), Vector3(x0 + 2, 0, zf), Vector3.LEFT], [Vector3(x0, 0, zb), Vector3(x0 + 2, 0, zb), Vector3.BACK]]:
					var A: Vector3 = wq[0]; var B: Vector3 = wq[1]
					var qp := [A, B, B + Vector3(0, D2, 0), A + Vector3(0, D2, 0)]
					for q in [0, 1, 2, 0, 2, 3]:
						sr.set_color(Color(.35, .35, .4) if q < 2 else Color(.05, .05, .07)); sr.set_uv(Vector2(qp[q].x + qp[q].z, qp[q].y)); sr.set_normal(wq[2]); sr.add_vertex(qp[q])
			var fm: Material = pbr(FLOOR_PBR, .6) if FLOOR_PBR != "" else mat(tex("res://assets/tiles/floor2.png"))
			var wm: Material = pbr(WALL_PBR, .6) if WALL_PBR != "" else mat(tex("res://assets/tiles/wall2.png"))
			_add_mesh(st, fm); _add_mesh(sr, wm)
			_entrance_glow(x0, zb, zf, Color(1, .82, .5) if up else Color(.55, .75, 1), up)
		else:
			var col := Color(.55, .72, 1) if a.kind == "door" else Color(1, .8, .5)
			_entrance_glow(x0, zb, zf, col, true, .75)

# 디아블로3 던전 입구처럼: 입구에서 빛이 새어 나오고(빛줄기·번짐) 작은 빛 알갱이가 떠오른다
func _entrance_glow(x0: float, zb: float, zf: float, col: Color, up: bool, k := 1.0) -> void:
	var cx: float = x0 + 1
	var nodes: Array = []
	var g = glow_quad(Color(col, .55 * k), 2.6); g.position = Vector3(cx, (WALLZ * .9 if up else .2), zb + .3); add_child(g); nodes.append(g)
	var g2 = glow_quad(Color(col, .35 * k), 4.2); g2.position = Vector3(cx, .6, zf + .2); add_child(g2); nodes.append(g2)
	# 빛줄기(입구에서 바닥으로 쏟아지는 세로 판 두 장)
	var gr := Gradient.new(); gr.set_color(0, Color(col, .0)); gr.add_point(.35, Color(col, .32 * k)); gr.set_color(gr.get_point_count() - 1, Color(col, 0))
	var gt := GradientTexture2D.new(); gt.gradient = gr; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(1, 0); gt.width = 64; gt.height = 4
	var sm := StandardMaterial3D.new(); sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; sm.albedo_texture = gt; sm.cull_mode = BaseMaterial3D.CULL_DISABLED; sm.no_depth_test = false
	for side in [-.35, .35]:
		var q := QuadMesh.new(); q.size = Vector2(2.6, 1.9)
		var mi := MeshInstance3D.new(); mi.mesh = q; mi.material_override = sm
		mi.position = Vector3(cx + side, .95, zf + .9); mi.rotation = Vector3(-.5, side * .6, 0); add_child(mi); nodes.append(mi)
	# 떠오르는 빛 알갱이
	var pt := CPUParticles3D.new(); var pq := QuadMesh.new(); pq.size = Vector2(.06, .06)
	var pm := StandardMaterial3D.new(); pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; pm.albedo_texture = glow_tex(); pm.albedo_color = Color(col, .9); pm.vertex_color_use_as_albedo = true
	pq.material = pm; pt.mesh = pq; pt.amount = 24; pt.lifetime = 2.2; pt.preprocess = 2.0
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; pt.emission_box_extents = Vector3(.9, .1, .5)
	pt.direction = Vector3(0, 1, .3); pt.spread = 25.0; pt.initial_velocity_min = .2; pt.initial_velocity_max = .5; pt.gravity = Vector3.ZERO
	var cg := Gradient.new(); cg.set_color(0, Color(1, 1, 1, 0)); cg.add_point(.3, Color(1, 1, 1, 1)); cg.set_color(cg.get_point_count() - 1, Color(1, 1, 1, 0)); pt.color_ramp = cg
	pt.position = Vector3(cx, .15, zf - .3); add_child(pt); nodes.append(pt)
	var L = add_light(Vector3(cx, 1.3, zf + .4), col, 5.5, 1.6 * k); nodes.append(L)
	if mg.town == null and not mg.terrace:
		for nd in nodes: fog_nodes.append([nd, cx * 32, zf * 32])

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

