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
		var f := FileAccess.open("res://assets/props/props.json", FileAccess.READ)
		if f: PROPM = JSON.parse_string(f.get_as_text())
	return PROPM

static var FOG_SHADER: Shader
static var fog_tex: ImageTexture
static func mat(t: Texture2D, _vcol := true) -> ShaderMaterial:
	if FOG_SHADER == null:
		FOG_SHADER = Shader.new()
		FOG_SHADER.code = """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D fog : filter_linear;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec4 c = texture(tex, UV);
	float f = texture(fog, wp.xz / vec2(82.0, 62.0)).r;
	ALBEDO = c.rgb * COLOR.rgb * f;
	ROUGHNESS = 1.0;
}
"""
	var m := ShaderMaterial.new()
	m.shader = FOG_SHADER
	m.set_shader_parameter("tex", t)
	m.set_shader_parameter("fog", fog_tex)
	return m

static func set_fog(bytes: PackedByteArray) -> void:
	var img := Image.create_from_data(MapGen.MW, MapGen.MH, false, Image.FORMAT_L8, bytes)
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
	var W := total * tw
	return Rect2((n * tw + inset) / W, inset / tw, (tw - inset * 2) / W, (tw - inset * 2) / tw)

func _quad_floor(st: SurfaceTool, x: float, y: float, uv: Rect2, ao: Array) -> void:
	# ao: 네 모서리 밝기 [북서, 북동, 남동, 남서]
	var p := [Vector3(x, 0, y), Vector3(x + 1, 0, y), Vector3(x + 1, 0, y + 1), Vector3(x, 0, y + 1)]
	var t := [uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]
	for k in [0, 1, 2, 0, 2, 3]:
		var a: float = ao[k]
		st.set_color(Color(a, a, a)); st.set_uv(t[k]); st.set_normal(Vector3.UP); st.add_vertex(p[k])

func _ao(i: int, j: int) -> Array:
	# 벽과 닿은 모서리를 어둡게(벽 밑 그늘)
	var c := func(dx: int, dy: int) -> float:
		var n := 0
		for v in [Vector2i(dx, 0), Vector2i(0, dy), Vector2i(dx, dy)]:
			if mg.at(i + v.x, j + v.y) == 1: n += 1
		return 1.0 - .22 * n
	return [c.call(-1, -1), c.call(1, -1), c.call(1, 1), c.call(-1, 1)]

func _build_ground() -> void:
	var town = mg.town
	var tf: Texture2D; var tp: Texture2D = null
	if town != null:
		tf = tex("res://assets/tiles/grass3.png"); tp = tex("res://assets/tiles/path3.png")
	else:
		tf = tex("res://assets/tiles/floor2.png")
	var mf := mat(tf)
	var mp: ShaderMaterial = null
	if tp != null: mp = mat(tp)
	for cy in range(0, MapGen.MH, CHUNK):
		for cx in range(0, MapGen.MW, CHUNK):
			var sf := SurfaceTool.new(); sf.begin(Mesh.PRIMITIVE_TRIANGLES)
			var sp := SurfaceTool.new(); sp.begin(Mesh.PRIMITIVE_TRIANGLES)
			var nf := 0; var np := 0
			for j in range(cy, min(cy + CHUNK, MapGen.MH)):
				for i in range(cx, min(cx + CHUNK, MapGen.MW)):
					var h := MapGen.hash2(i, j)
					if mg.at(i, j) == 0:
						if town != null:
							var on_path: bool = (i >= town.pathX and i < town.pathX + town.pathW) or (j >= town.crossY and j < town.crossY + 3) or j < town.y0
							if on_path:
								_quad_floor(sp, i, j, _uv(h % 10, 16), _ao(i, j)); np += 1
							else:
								_quad_floor(sf, i, j, _uv(h % 16, 16), _ao(i, j)); nf += 1
						else:
							_quad_floor(sf, i, j, _uv(((i + j) & 1) * 8 + h % 8, 16), _ao(i, j)); nf += 1
					elif town != null:
						# 마을 바깥 숲 바닥(조금 어둡게)
						_quad_floor(sf, i, j, _uv(h % 16, 16), [.62, .62, .62, .62]); nf += 1
			if nf: _add_mesh(sf, mf)
			if np: _add_mesh(sp, mp)

func _add_mesh(st: SurfaceTool, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit(); mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi); return mi

# ---------------- 벽 ----------------
func _face(st: SurfaceTool, a: Vector3, b: Vector3, h: float, uv: Rect2, n: Vector3, shade: float) -> void:
	# a→b 가 바닥 선, 위로 h 만큼. 낮은 벽은 그림 아래쪽만 사용
	var v0: float = uv.end.y - (uv.size.y * h / WALLZ)
	var p := [a + Vector3(0, h, 0), b + Vector3(0, h, 0), b, a]
	var t := [Vector2(uv.position.x, v0), Vector2(uv.end.x, v0), uv.end, Vector2(uv.position.x, uv.end.y)]
	var cl := [Color(shade, shade, shade), Color(shade, shade, shade), Color(shade * .62, shade * .62, shade * .62), Color(shade * .62, shade * .62, shade * .62)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_color(cl[k]); st.set_uv(t[k]); st.set_normal(n); st.add_vertex(p[k])

func _top(st: SurfaceTool, i: int, j: int, h: float, uv: Rect2) -> void:
	var p := [Vector3(i, h, j), Vector3(i + 1, h, j), Vector3(i + 1, h, j + 1), Vector3(i, h, j + 1)]
	var t := [uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_color(Color.WHITE); st.set_uv(t[k]); st.set_normal(Vector3.UP); st.add_vertex(p[k])

func _build_walls() -> void:
	var mw := mat(tex("res://assets/tiles/wall2.png")); var mt := mat(tex("res://assets/tiles/top2.png"))
	for cy in range(0, MapGen.MH, CHUNK):
		for cx in range(0, MapGen.MW, CHUNK):
			var sw := SurfaceTool.new(); sw.begin(Mesh.PRIMITIVE_TRIANGLES)
			var stt := SurfaceTool.new(); stt.begin(Mesh.PRIMITIVE_TRIANGLES)
			var n := 0
			for j in range(cy, min(cy + CHUNK, MapGen.MH)):
				for i in range(cx, min(cx + CHUNK, MapGen.MW)):
					var w := mg.wall_bits(i, j)
					if w < 0: continue
					n += 1
					var h: float = LOWZ if (w & 1) else WALLZ
					var v := MapGen.hash2(i, j) % 6
					var uvw := Rect2((v * 128 + 2) / 768.0, 0, 124 / 768.0, 1)
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
			var h := MapGen.hash2(i, j); var edge := mg.wall_bits(i, j) >= 0
			if not edge and h % 2 == 0: continue
			var p := Vector2((i + .5) * 32 + ((h >> 3) % 9 - 4) * 2, (j + .85) * 32)
			if j >= t.y0 + t.h or (edge and (mg.wall_bits(i, j) & 1)):
				# 앞쪽(카메라 쪽)은 낮은 덤불만, 그것도 가장자리 한 줄과 드문드문
				if j == t.y0 + t.h and h % 3 != 0: add_prop(PL[h % PL.size()], p, 1.0)
				elif j > t.y0 + t.h and h % 7 == 0: add_prop(PL[h % PL.size()], p, .9)
			else:
				add_prop(FOREST[h % FOREST.size()], p, .8 + (h % 5) * .08)

# ---------------- 소품 ----------------
func add_prop(n: String, p: Vector2, sc := 1.0) -> Sprite3D:
	var M := props_meta()
	if not M.has(n): return null
	var m: Dictionary = M[n]
	var s := Sprite3D.new()
	s.texture = tex("res://assets/props/%s.png" % n)
	s.pixel_size = PF * sc / 32.0 * STAND
	s.centered = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.shaded = true
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if mg.town == null: fog_nodes.append([s, p.x, p.y])
	s.position = Vector3(p.x / 32.0 + (m.w / 2.0 - m.ax) * s.pixel_size, (m.ay - m.h / 2.0) * s.pixel_size, p.y / 32.0)
	add_child(s); return s

func _build_props() -> void:
	for d in mg.decor:
		if d.kind == "prop": add_prop(d.p, d.pos, d.get("s", 1.0))
		elif d.kind == "fountain":
			add_prop("statue2", d.pos, 1.1)
		elif d.kind == "stall":
			add_prop("crate2", d.pos + Vector2(-16, 0), .9); add_prop("barrel1", d.pos + Vector2(19, 3), .9)

# ---------------- 빛 ----------------
static var _glow_tex: Texture2D
static func glow_tex() -> Texture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(.35, Color(1, 1, 1, .6))
		var t := GradientTexture2D.new()
		t.gradient = g; t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(.5, .5); t.fill_to = Vector2(1, .5); t.width = 128; t.height = 128
		_glow_tex = t
	return _glow_tex

func glow_quad(col: Color, size: float) -> MeshInstance3D:
	var q := QuadMesh.new(); q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = glow_tex(); m.albedo_color = col
	m.no_depth_test = false
	var mi := MeshInstance3D.new(); mi.mesh = q; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func add_light(pos: Vector3, col: Color, rng: float, energy: float) -> OmniLight3D:
	var L := OmniLight3D.new()
	L.position = pos; L.light_color = col; L.omni_range = rng; L.light_energy = energy
	L.omni_attenuation = 1.2
	add_child(L)
	lights.append({light = L, base = energy, ph = randf() * TAU})
	return L

func _build_torches() -> void:
	for t in mg.torches:
		var p: Vector2 = t.pos / 32.0
		if t.lamp:
			add_prop("brazier", t.pos + Vector2(0, 2), .55)
			var g := glow_quad(Color(1, .6, .25, .9), .9); g.position = Vector3(p.x, .75, p.y + .1); add_child(g)
			add_light(Vector3(p.x, 1.1, p.y + .3), Color(1, .66, .38), 6.0, 1.4)
		else:
			# 벽 횃불: 벽 남쪽 면에 붙임
			var stick := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(.08, .3, .08)
			stick.mesh = bm; var sm := StandardMaterial3D.new(); sm.albedo_color = Color(.25, .18, .14); stick.material_override = sm
			stick.position = Vector3(p.x, WALLZ * .55, p.y + .06); add_child(stick)
			var g := glow_quad(Color(1, .55, .2, 1), .7); g.position = Vector3(p.x, WALLZ * .7, p.y + .12); add_child(g)
			var g2 := glow_quad(Color(1, .9, .6, 1), .22); g2.position = Vector3(p.x, WALLZ * .68, p.y + .14); add_child(g2)
			var L := add_light(Vector3(p.x, WALLZ * .7, p.y + .6), Color(1, .6, .3), 5.5, 1.5)
			if mg.town == null:
				for n in [stick, g, g2, L]: fog_nodes.append([n, t.pos.x, t.pos.y + 14])

