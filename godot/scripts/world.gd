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

# ---------------- 새 손그림 타일(godot/art) ----------------
# 월드 좌표로 이어 붙임: 바닥·벽 윗면은 위에서, 벽 앞면은 벽 밑동에서부터 그림 한 장이 벽 높이에 맞게
static var ART_SHADER: Shader
static var ARTM := {}
static var ART_TIER := 1      # 1~5: 20층마다
static func amat(name: String, scale := .25, hrep := 0.0, urep := 1.0) -> ShaderMaterial:
	var key := "%s|%s|%s|%s|%s" % [name, scale, hrep, urep, TINT.to_html()]
	if ARTM.has(key): return ARTM[key]
	if ART_SHADER == null:
		ART_SHADER = Shader.new()
		ART_SHADER.code = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fog : filter_linear;
uniform vec3 tint = vec3(1.0);
uniform float scale = .25;
uniform float hrep = 0.0;
uniform float urep = 1.0;
uniform float bump = .35;
varying vec3 wp;
varying vec3 wn;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	vec2 uv;
	if (hrep <= 0.0) uv = wp.xz * scale;
	else uv = vec2((abs(wn.z) > .5 ? wp.x : wp.z) / urep, clamp(1.0 - wp.y / hrep, .002, .998));
	vec4 c = texture(tex, uv);
	float f = texture(fog, wp.xz / vec2(82.0, 62.0)).r;
	float h = dot(c.rgb, vec3(.3, .59, .11));
	vec3 dpx = dFdx(VERTEX); vec3 dpy = dFdy(VERTEX);
	vec3 r1 = cross(dpy, NORMAL); vec3 r2 = cross(NORMAL, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad * bump);
	ALBEDO = c.rgb * COLOR.rgb * tint * f * 1.08;
	ROUGHNESS = mix(.55, .92, h);
	SPECULAR = .2 * f;
}
"""
	var m := ShaderMaterial.new(); m.shader = ART_SHADER
	m.set_shader_parameter("tex", tex("res://art/%s.png" % name))
	m.set_shader_parameter("fog", fog_tex)
	m.set_shader_parameter("scale", scale); m.set_shader_parameter("hrep", hrep); m.set_shader_parameter("urep", urep)
	var t := Color.WHITE.lerp(TINT, .25)
	m.set_shader_parameter("tint", Vector3(t.r, t.g, t.b))
	ARTM[key] = m
	return m

static func art_tile(kind: String) -> String:
	return "tile_t%d_%s" % [ART_TIER, kind]

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
	for sd in mg.sidedoors:
		# 동·서·남쪽 문: 문 너머에서 새어 나오는 빛
		var col := Color(1, .8, .5) if sd.kind == "back" else Color(.55, .72, 1)
		var px: float = sd.x / 32.0 + sd.dx * 1.0; var pz: float = sd.y / 32.0 + sd.dy * 1.0
		_entrance_sparkle(px, pz + .3, col, .9)
		var L = add_light(Vector3(px, 1.0, pz), col, 4.5, 1.4)
		if mg.town == null and not mg.terrace: fog_nodes.append([L, sd.x, sd.y])

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
	# 새 손그림 타일(1024 그림 한 장 = 4×4칸)
	var meadow: bool = town != null and town.get("meadow", false)
	if town != null:
		mf = amat("tile_meadow_grass" if meadow else "tile_town_grass"); mp = amat("tile_town_path")
	elif mg.terrace: mf = amat("tile_roof_floor" if mg.floor_no > 99 else "tile_terrace_floor")
	else: mf = amat(art_tile("floor_a"))
	var wood := {}     # 숙소 방: 나무 바닥
	for r in mg.rooms:
		if r.get("wood", false):
			for j in range(r.y, r.y + r.h):
				for i in range(r.x, r.x + r.w): wood[j * MapGen.MW + i] = true
	for cy in range(0, MapGen.MH, CHUNK):
		for cx in range(0, MapGen.MW, CHUNK):
			var sf = SurfaceTool.new(); sf.begin(Mesh.PRIMITIVE_TRIANGLES)
			var sp = SurfaceTool.new(); sp.begin(Mesh.PRIMITIVE_TRIANGLES)
			var sp2 = SurfaceTool.new(); sp2.begin(Mesh.PRIMITIVE_TRIANGLES)
			var nf = 0; var np = 0; var nf2 = 0
			var sw2 = SurfaceTool.new(); sw2.begin(Mesh.PRIMITIVE_TRIANGLES); var nw = 0
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
						elif wood.has(j * MapGen.MW + i):
							_quad_floor(sw2, i, j, _uv(h % 8, 16), _ao(i, j)); nw += 1
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
			if nf2: _add_mesh(sp2, amat("tile_town_forest"))
			if nw: _add_mesh(sw2, amat("tile_dorm_floor"))

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
	# 새 손그림: 높은 벽(512×256 → 벽 높이에 한 장), 낮은 벽(512×128), 윗면(2칸에 한 장)
	var mlow: Material
	if mg.terrace:
		mw = amat("tile_terrace_wall_low", .25, LOWZ * 1.35, LOWZ * 1.35 * 4.0); mlow = mw
		mt = amat("tile_t1_wall_top", .5)
	else:
		mw = amat(art_tile("wall_front"), .25, WALLZ, WALLZ * 2.0)
		mlow = amat(art_tile("wall_low"), .25, LOWZ, LOWZ * 4.0)
		mt = amat(art_tile("wall_top"), .5)
	for cy in range(0, MapGen.MH, CHUNK):
		for cx in range(0, MapGen.MW, CHUNK):
			var sw = SurfaceTool.new(); sw.begin(Mesh.PRIMITIVE_TRIANGLES)
			var swl = SurfaceTool.new(); swl.begin(Mesh.PRIMITIVE_TRIANGLES)
			var stt = SurfaceTool.new(); stt.begin(Mesh.PRIMITIVE_TRIANGLES)
			var n = 0; var nl = 0
			for j in range(cy, min(cy + CHUNK, MapGen.MH)):
				for i in range(cx, min(cx + CHUNK, MapGen.MW)):
					var w = mg.wall_bits(i, j)
					if w < 0: continue
					n += 1
					var h: float = LOWZ * 1.35 if mg.terrace else (LOWZ if (w & 1) else WALLZ)
					var v = MapGen.hash2(i, j) % 6
					var uvw = Rect2((v * 128 + 2) / 768.0, 0, 124 / 768.0, 1)
					var sx: SurfaceTool = sw if h >= WALLZ else swl
					if h < WALLZ: nl += 1
					if w & 4: _face(sx, Vector3(i, 0, j + 1), Vector3(i + 1, 0, j + 1), h, uvw, Vector3.BACK, 1.0)
					if w & 8: _face(sx, Vector3(i, 0, j), Vector3(i, 0, j + 1), h, uvw, Vector3.LEFT, .78)
					if w & 2: _face(sx, Vector3(i + 1, 0, j + 1), Vector3(i + 1, 0, j), h, uvw, Vector3.RIGHT, .78)
					if w & 1: _face(sx, Vector3(i + 1, 0, j), Vector3(i, 0, j), h, uvw, Vector3.FORWARD, .7)
					_top(stt, i, j, h, _uv(w & 15, 16))
			if n:
				if n > nl: _add_mesh(sw, mw)
				if nl: _add_mesh(swl, mlow)
				_add_mesh(stt, mt)

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
			if t.get("meadow", false):
				if not edge or (i + j) % 3 != 0: continue      # 토끼 동산은 넓으니 가장자리만 듬성듬성
			elif edge and (i + j) % 2 == 1: continue
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

# ---------------- 새 손그림 소품 ----------------
# 그림 크기 기준: 사람 키 380px(원본) = 웹 46px. godot/art 는 절반 크기
const ART_PS := 2.0 * 46.0 / 380.0 / 32.0 * STAND
const ART_PROP := {
	bones1 = "prop_bones_a", bones2 = "prop_bones_a", bones3 = "prop_bones_b", bones4 = "prop_bones_a", bones5 = "prop_bones_b",
	skulls = "prop_bones_b", skeleton1 = "prop_skeleton_lying", skeleton2 = "prop_skeleton_lying",
	barrel1 = "prop_barrel_a", barrel2 = "prop_barrel_b", dcrate1 = "prop_crate_a", dcrate2 = "prop_crate_b",
	lectern1 = "prop_lib_stand", chain1 = "prop_chain", brazier = "prop_brazier",
	oak1 = "nat_oak_a", oak2 = "nat_oak_b", oak3 = "nat_oak_c", oak4 = "nat_oak_a", birch1 = "nat_oak_c", birch3 = "nat_oak_b",
	pine1 = "nat_pine_a", pine2 = "nat_pine_b", fpine = ["nat_pine_a", "nat_pine_b", "nat_pine_c"], foak = ["nat_oak_a", "nat_oak_b", "nat_oak_c"],
	flower1 = "nat_flower_a", flower2 = "nat_flower_b", fern1 = "nat_bush_c", leaf1 = "nat_grass_b", grass1 = "nat_grass_a",
	grass2 = "nat_grass_b", grass3 = "nat_grass_c", rock1 = "nat_rock_a", rock2 = "nat_rock_b",
	shrub1 = "nat_bush_a", shrub2 = "nat_bush_b", shrub3 = "nat_bush_c", fountain = "bld_fountain", stall = "bld_stall"}
const ART_MODEL := {
	Barrel = "prop_barrel_a", Barrel_Apples = "prop_barrel_b", Crate_Wooden = "prop_crate_a", Crate_Metal = "prop_crate_c",
	FarmCrate_Apple = "prop_crate_b", Bucket_Wooden_1 = "prop_prison_bucket", Chain_Coil = "prop_prison_straw", Cage_Small = "prop_prison_cage",
	Cauldron = "prop_lab_cauldron", BookStand = "prop_lib_stand", CandleStick_Stand = "prop_candle_stand",
	Bed_Twin1 = "prop_dorm_bed", Bed_Twin2 = "prop_dorm_bed_messy", Nightstand_Shelf = "prop_dorm_nightstand", Stool = "prop_dorm_trunk",
	Bookcase_2 = "prop_lib_bookcase", Shelf_Arch = "prop_lib_bookcase", BookGroup_Medium_1 = "prop_lib_books", BookGroup_Medium_2 = "prop_lib_books",
	Book_Stack_1 = "prop_lib_books", Pot_1 = "prop_jar_a", Vase_2 = "prop_jar_b", Rope_1 = "prop_sack_a", Bag = "prop_sack_b",
	Barrel_Holder = "prop_store_shelf", WeaponStand = "prop_armory_rack", Shield_Wooden = "prop_armory_shield", Dummy = "prop_armory_dummy",
	Anvil = "bld_anvil", Vase_Rubble_Medium = "prop_jar_broken", Rock_Medium_1 = "prop_rubble", Rock_Medium_2 = "prop_rubble",
	Bench = "bld_bench", Workbench = "prop_lab_table", Chair_1 = "prop_meet_chair"}

static func art_model(d: Dictionary) -> String:
	var n: String = d.name; var th: String = d.get("th", "")
	var tilted: bool = d.get("tilt", Vector2.ZERO) != Vector2.ZERO
	if float(d.get("h", 0.0)) > .05 and n != "Shelf_Arch": return ""          # 탁자·선반 위 작은 물건: 탁자 그림에 이미 그려져 있음
	match n:
		"Table_Large":
			match th:
				"lab": return "prop_lab_table"
				"library": return "prop_lib_desk"
				"dining": return "prop_dining_table"
				_: return "prop_meet_table_broken" if tilted else "prop_meet_table"
		"Chair_1": return "prop_meet_chair_broken" if tilted else ("prop_dining_bench" if th == "dining" else "prop_meet_chair")
		"Cabinet": return "prop_lab_shelf" if th == "lab" else "prop_dorm_wardrobe"
		"Bookcase_2": return "prop_lib_bookcase_b" if tilted or th == "ruin" else "prop_lib_bookcase"
		"Book_5", "Scroll_2": return "" if th == "meeting" else "prop_lib_books"
	return ART_MODEL.get(n, "")

func art_sprite(id: String, p: Vector2, sc := 1.0, flip := false, z_off := 0.0) -> Sprite3D:
	var A: Dictionary = Actor.art()
	if not A.has(id): return null
	var m: Dictionary = A[id]
	var s := Sprite3D.new()
	s.texture = tex("res://art/%s.png" % id)
	s.pixel_size = ART_PS * sc
	s.centered = true; s.flip_h = flip
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.shaded = true
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var foot: float = float(m.b[0][3])         # 그림이 바닥에 닿는 줄
	s.position = Vector3(p.x / 32.0, (foot - m.h / 2.0) * s.pixel_size, p.y / 32.0 + z_off)
	if mg != null and mg.town == null: fog_nodes.append([s, p.x, p.y])
	add_child(s); return s

# ---------------- 소품 ----------------
func add_prop(n: String, p: Vector2, sc := 1.0) -> Node3D:
	if ART_PROP.has(n):
		var id = ART_PROP[n]
		var h := MapGen.hash2(int(p.x), int(p.y))
		if id is Array: id = id[h % id.size()]
		if mg != null and mg.town != null and mg.town.get("meadow", false) and String(id).begins_with("nat_flower"): id = "nat_flower_c"
		var k: float = clampf(sc / (.8 if not n in ["fpine", "foak", "fountain", "stall", "brazier"] else 1.0), .7, 1.3)
		if n == "brazier": k = 1.0
		var o := art_sprite(id, p, k, h % 2 == 0 and not n in ["fountain", "stall"])
		if o != null: return o
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
			add_prop("stall", d.pos, 1.0)
		elif d.kind == "model" and art_model(d) != "":
			var k: float = clampf(float(d.s) / .74, .7, 1.3) if mg.town == null else 1.0
			art_sprite(art_model(d), d.pos, k, false)
		elif d.kind == "model" and mg.town == null and d.name in ["Bottle_1", "Potion_1", "Potion_2", "Potion_4", "Book_5", "Scroll_2", "Candle_1", "SmallBottles_1", "Shelf_Small_Bottles", "Table_Plate", "Mug", "Chalice", "Table_Spoon"]:
			pass
		elif d.kind == "model":
			var md := Props3D.model(d.name, "prop", d.s); md.position = Vector3(d.pos.x / 32.0, d.get("h", 0.0), d.pos.y / 32.0)
			var tl: Vector2 = d.get("tilt", Vector2.ZERO)
			md.rotation = Vector3(tl.x, d.rot, tl.y); add_child(md)
			if mg.town == null: fog_nodes.append([md, d.pos.x, d.pos.y])
		elif d.kind == "circle": _magic_circle(d.pos, d.get("red", false))
		elif d.kind == "glowpt":
			var g = glow_quad(Color(d.col, .6), 1.2); g.position = Vector3(d.pos.x / 32.0, d.h, d.pos.y / 32.0 + .05); add_child(g)
			var L = add_light(Vector3(d.pos.x / 32.0, d.h + .6, d.pos.y / 32.0 + .3), d.col, 3.5, 1.2)
			fog_nodes.append([g, d.pos.x, d.pos.y]); fog_nodes.append([L, d.pos.x, d.pos.y])
		elif d.kind == "bars": _bars(d.a, d.b)
		elif d.kind == "doorframe": _doorframe(d)

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

static var _iron: StandardMaterial3D
static func iron_mat() -> StandardMaterial3D:
	if _iron == null:
		_iron = StandardMaterial3D.new(); _iron.albedo_color = Color(.22, .21, .23); _iron.metallic = .8; _iron.roughness = .45
	return _iron

# 쇠창살(감옥): a→b 를 따라 세로 막대 + 위아래 가로대
func _bars(a: Vector2, b: Vector2) -> void:
	var A := Vector3(a.x / 32.0, 0, a.y / 32.0); var B := Vector3(b.x / 32.0, 0, b.y / 32.0)
	var L := A.distance_to(B); var n: int = max(1, int(L / .22))
	var root := Node3D.new(); add_child(root)
	var cm := CylinderMesh.new(); cm.top_radius = .028; cm.bottom_radius = .028; cm.height = 1.25; cm.radial_segments = 6
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = cm; mm.instance_count = n + 1
	for i in n + 1:
		mm.set_instance_transform(i, Transform3D(Basis(), A.lerp(B, float(i) / n) + Vector3(0, .625, 0)))
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = iron_mat(); root.add_child(mi)
	for y in [.12, 1.18]:
		var bm := BoxMesh.new(); bm.size = Vector3(L + .06, .05, .05)
		var rail := MeshInstance3D.new(); rail.mesh = bm; rail.material_override = iron_mat()
		rail.position = (A + B) / 2.0 + Vector3(0, y, 0); rail.rotation.y = -atan2(B.z - A.z, B.x - A.x); root.add_child(rail)
	fog_nodes.append([root, (a.x + b.x) / 2.0, (a.y + b.y) / 2.0])

# 방 입구: 벽 높이에 맞춘 나무 문틀 + 상인방, 양쪽 문짝은 방 안쪽 벽에 착 붙도록 활짝 열림(통로를 막지 않음)
func _doorframe(d: Dictionary) -> void:
	var root := Node3D.new(); add_child(root)
	var wm = pbr("old_planks_02", .5)
	var W: float = d.wd / 32.0; var H := WALLZ * .92
	root.position = Vector3(d.pos.x / 32.0, 0, d.pos.y / 32.0)
	# 북쪽 문: 벽은 x 방향으로 놓이고 방은 +z 쪽. 동쪽 문: 방은 -x 쪽, 서쪽 문: 방은 +x 쪽
	if d.side == "e": root.rotation.y = -PI / 2
	elif d.side == "w": root.rotation.y = PI / 2
	var into := .1          # 방 쪽으로 살짝(벽 안쪽 면)
	for sx in [-1, 1]:
		var post := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(.14, H, .22); post.mesh = bm; post.material_override = wm
		post.position = Vector3(sx * (W / 2.0 + .03), H / 2.0, into); root.add_child(post)
	var lin := MeshInstance3D.new(); var lb := BoxMesh.new(); lb.size = Vector3(W + .32, .2, .26); lin.mesh = lb; lin.material_override = wm
	lin.position = Vector3(0, H, into); root.add_child(lin)
	var sill := MeshInstance3D.new(); var sb := BoxMesh.new(); sb.size = Vector3(W, .04, .3); sill.mesh = sb; sill.material_override = wm
	sill.position = Vector3(0, .02, into); root.add_child(sill)
	if d.get("leaf", false):
		for sx in [-1, 1]:
			if randf() < .25: continue          # 한 짝은 떨어져 나가고 없기도
			var leaf := MeshInstance3D.new(); var lfb := BoxMesh.new(); lfb.size = Vector3(W * .5, H * .9, .05); leaf.mesh = lfb; leaf.material_override = wm
			leaf.position = Vector3(sx * (W / 2.0 + .1 + W * .25), H * .45, into + .1)     # 문틀 바깥쪽 벽면에 붙어 열린 문짝
			root.add_child(leaf)
	fog_nodes.append([root, d.pos.x, d.pos.y])

func _magic_circle(p: Vector2, red := false) -> void:
	var q = QuadMesh.new(); q.size = Vector2(3.4, 3.4); q.orientation = PlaneMesh.FACE_Y
	var m = StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = circle_tex(); m.albedo_color = Color(1.6, .25, .2, .9) if red else Color(.45, .75, 1.6, .95)
	var mi = MeshInstance3D.new(); mi.mesh = q; mi.material_override = m; mi.position = Vector3(p.x / 32.0, .03, p.y / 32.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mi)
	var tw = mi.create_tween().set_loops(); tw.tween_property(mi, "rotation:y", TAU, 24.0).from(0.0)
	var g = glow_quad(Color(1, .3, .25, .3) if red else Color(.4, .7, 1, .35), 3.6); g.position = Vector3(p.x / 32.0, .5, p.y / 32.0); add_child(g)
	var L = add_light(Vector3(p.x / 32.0, 1.2, p.y / 32.0), Color(1, .35, .3) if red else Color(.5, .75, 1), 5.0, 1.6)
	if mg.town == null:
		for nd in [mi, g, L]: fog_nodes.append([nd, p.x, p.y])

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

static var _shaft_tex: ImageTexture
static func shaft_tex() -> ImageTexture:
	if _shaft_tex == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for j in 64:
			for i in 64:
				var u := (i + .5) / 64.0; var v := (j + .5) / 64.0
				var a: float = pow(sin(PI * u), 1.6) * smoothstep(0.0, .35, v) * (1.0 - smoothstep(.6, 1.0, v))
				img.set_pixel(i, j, Color(1, 1, 1, a))
		_shaft_tex = ImageTexture.create_from_image(img)
	return _shaft_tex

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
			var fm: Material = amat(art_tile("floor_a"))
			var wm: Material = amat(art_tile("wall_front"), .25, WALLZ, WALLZ * 2.0)
			_add_mesh(st, fm); _add_mesh(sr, wm)
			_entrance_glow(x0, zb, zf, Color(1, .82, .5) if up else Color(.55, .75, 1), up)
		else:
			var col := Color(.55, .72, 1) if a.kind == "door" else Color(1, .8, .5)
			_entrance_glow(x0, zb, zf, col, true, .75)

# 디아블로3 던전 입구처럼: 입구에서 빛이 새어 나오고(빛줄기·번짐) 작은 빛 알갱이가 떠오른다
func _entrance_glow(x0: float, zb: float, zf: float, col: Color, up: bool, k := 1.0) -> void:
	var cx: float = x0 + 1
	var nodes: Array = []
	# 테라스는 벽이 낮아서 빛도 낮고 작게(그대로 두면 벽 위로 네모난 빛판이 드러남)
	var hz: float = (LOWZ * 1.35 / WALLZ) if mg.terrace else 1.0
	if mg.terrace: k *= .55
	if mg.terrace:
		# 테라스(야외)는 빛판을 쓰지 않음 — 폰에서 벽에 걸려 네모나게 하얗게 뜨는 문제. 빛 알갱이와 은은한 조명만
		_entrance_sparkle(cx, zf, col, k); return
	var g = glow_quad(Color(col, .55 * k), 2.6 * (.7 if mg.terrace else 1.0)); g.position = Vector3(cx, (WALLZ * .9 * hz if up else .2), zb + .3); add_child(g); nodes.append(g)
	var g2 = glow_quad(Color(col, .35 * k), 4.2 * (.7 if mg.terrace else 1.0)); g2.position = Vector3(cx, .6 * hz, zf + .2); add_child(g2); nodes.append(g2)
	# 빛줄기(입구에서 바닥으로 쏟아지는 세로 판 두 장) — 가장자리가 사방으로 부드럽게 사라지게
	var sm := StandardMaterial3D.new(); sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; sm.albedo_texture = shaft_tex(); sm.albedo_color = Color(col, .32 * k); sm.cull_mode = BaseMaterial3D.CULL_DISABLED; sm.no_depth_test = false
	for side in [-.35, .35]:
		var q := QuadMesh.new(); q.size = Vector2(2.6, 1.9 * hz)
		var mi := MeshInstance3D.new(); mi.mesh = q; mi.material_override = sm
		mi.position = Vector3(cx + side, .95 * hz, zf + .9); mi.rotation = Vector3(-.5, side * .6, 0); add_child(mi); nodes.append(mi)
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

func _entrance_sparkle(cx: float, zf: float, col: Color, k: float) -> void:
	var pt := CPUParticles3D.new(); var pq := QuadMesh.new(); pq.size = Vector2(.06, .06)
	var pm := StandardMaterial3D.new(); pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; pm.albedo_texture = glow_tex(); pm.albedo_color = Color(col, .8); pm.vertex_color_use_as_albedo = true
	pq.material = pm; pt.mesh = pq; pt.amount = 16; pt.lifetime = 2.0; pt.preprocess = 2.0
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; pt.emission_box_extents = Vector3(.8, .1, .4)
	pt.direction = Vector3(0, 1, .2); pt.spread = 25.0; pt.initial_velocity_min = .2; pt.initial_velocity_max = .4; pt.gravity = Vector3.ZERO
	var cg := Gradient.new(); cg.set_color(0, Color(1, 1, 1, 0)); cg.add_point(.3, Color(1, 1, 1, 1)); cg.set_color(cg.get_point_count() - 1, Color(1, 1, 1, 0)); pt.color_ramp = cg
	pt.position = Vector3(cx, .15, zf - .3); add_child(pt)
	add_light(Vector3(cx, .9, zf + .3), col, 4.0, .9 * k)

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

