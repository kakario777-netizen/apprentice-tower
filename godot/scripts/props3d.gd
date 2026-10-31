# 입체 소품: 통·나무 상자·보물상자·나무·덤불·바위·석상·화로·독서대·분수·노점·묘비·그루터기
# 세워 둔 그림(종이 느낌) 대신 간단한 3D 도형에 질감을 입혀 만든다. 단위: 1 = 타일 한 칸.
class_name Props3D
extends RefCounted

static var MATS := {}

static func m(name: String, col := Color.WHITE, rough := 1.0, emis := Color(0, 0, 0)) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [name, col.to_html(), emis.to_html()]
	if MATS.has(key): return MATS[key]
	var mt := StandardMaterial3D.new()
	if name != "":
		mt.albedo_texture = load("res://ui/tex_%s.png" % name)
		# 요철(노멀맵)로 나뭇결·돌결이 빛을 받아 도드라지게
		if ResourceLoader.exists("res://ui/tex_%s_n.png" % name):
			mt.normal_enabled = true; mt.normal_texture = load("res://ui/tex_%s_n.png" % name); mt.normal_scale = 1.4
	mt.albedo_color = col; mt.roughness = rough
	mt.rim_enabled = true; mt.rim = .12 if name == "leaf" else .22; mt.rim_tint = .7       # 가장자리 빛(윤곽이 살아 보이게)
	mt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if emis.r + emis.g + emis.b > 0:
		mt.emission_enabled = true; mt.emission = emis
	MATS[key] = mt
	return mt

static var cast := true      # 그림자를 드리울지(바닥 아이템 등은 끔)
static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3(), scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat
	mi.position = pos; mi.rotation = rot; mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi); return mi

static func cyl(r0: float, r1: float, h: float, seg := 14) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = r0; c.bottom_radius = r1; c.height = h; c.radial_segments = seg; c.rings = 1
	return c
static func box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new(); b.size = Vector3(x, y, z); return b
static func ball(r: float, seg := 10) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2; s.radial_segments = seg; s.rings = seg / 2 + 1; return s

static func shadow(parent: Node3D, w: float, d: float, a := .5) -> void:
	var q := QuadMesh.new(); q.size = Vector2(w, d); q.orientation = PlaneMesh.FACE_Y
	var sm := StandardMaterial3D.new(); sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; sm.albedo_texture = World.glow_tex(); sm.albedo_color = Color(0, 0, 0, a)
	var c0 := cast; cast = false
	_mesh(parent, q, sm, Vector3(0, .02, 0)); cast = c0

const NAMES := ["barrel", "dcrate", "crate", "chest", "statue", "brazier", "lectern", "oak", "birch", "pine", "deadtree", "shrub", "rock", "stump", "grave", "cross", "fountain", "stall", "wood", "anvil", "campfire"]

static func supports(n: String) -> bool:
	if _model_spec(n).size(): return true
	for k in NAMES:
		if n.begins_with(k): return true
	return false

# ---------------- 진짜 3D 모델(Quaternius, CC0) ----------------
# 소품 이름 → [모델 후보들, 크기 배율, 색 보정 종류]
const MODEL_MAP := [
	["fpine", ["Pine_5", "Pine_4"], .4, "leaf"],
	["foak", ["CommonTree_5", "CommonTree_3"], .44, "leaf"],
	["oak", ["CommonTree_1", "CommonTree_2", "CommonTree_5"], .44, "leaf"],
	["birch", ["CommonTree_3", "CommonTree_4"], .36, "leaf"],
	["pine", ["Pine_1", "Pine_2", "Pine_3", "Pine_5"], .42, "leaf"],
	["deadtree", ["DeadTree_1", "DeadTree_2", "DeadTree_3"], .28, "dead"],
	["shrub", ["Bush_Common", "Bush_Common_Flowers"], .42, "leaf"],
	["rock", ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"], .3, "stone"],
	["flower", ["Flower_3_Group", "Flower_4_Group"], .2, "leaf"],
	["fern", ["Fern_1"], .3, "leaf"],
	["grass", ["Grass_Common_Short", "Grass_Wispy_Short"], .32, "leaf"],
	["leaf", ["Clover_1", "Plant_1"], .32, "leaf"],
	["barrel", ["Barrel", "Barrel", "Barrel_Apples"], .85, "prop"],
	["dcrate", ["Crate_Wooden", "Crate_Metal"], .78, "prop"],
	["crate", ["Crate_Wooden", "Crate_Wooden", "Crate_Metal"], .78, "prop"],
	["chest", ["Chest_Wood"], .72, "prop"],
	["lectern", ["BookStand"], .78, "prop"],
	["anvil", ["Anvil"], 1.0, "prop"],
	["stall", ["Stall_Empty"], 1.15, "prop"],
]
const GRADE := {leaf = Color(.42, .5, .42), dead = Color(.6, .58, .64), stone = Color(.7, .7, .76), prop = Color(.85, .8, .76)}   # 밤이라 잎은 어둡게(빛에 비칠 때만 살짝 보이게)
static var GRADED := {}

static func _model_spec(n: String) -> Array:
	for m in MODEL_MAP:
		if n.begins_with(m[0]): return m
	return []

static func _graded(mat: Material, kind: String) -> Material:
	if not (mat is BaseMaterial3D): return mat
	var key := "%d|%s" % [mat.get_instance_id(), kind]
	if GRADED.has(key): return GRADED[key]
	var g: BaseMaterial3D = mat.duplicate()
	g.albedo_color = g.albedo_color * GRADE[kind]
	g.rim_enabled = true; g.rim = .15 if kind == "leaf" else .25; g.rim_tint = .6
	if kind == "leaf":
		g.roughness = 1.0; g.metallic_specular = .15; g.rim = .05
	# 잎 그림의 투명 부분은 '잘라내기'로(반투명 섞기보다 훨씬 가볍다)
	if g.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; g.alpha_scissor_threshold = .5
	GRADED[key] = g
	return g

static func model(name: String, kind := "prop", sc := 1.0) -> Node3D:
	var ps: PackedScene = load("res://models/%s.gltf" % name)
	var n: Node3D = ps.instantiate()
	n.scale = Vector3.ONE * sc
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m3: MeshInstance3D = mi
		m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in m3.mesh.get_surface_count():
			var mt = m3.get_active_material(i)
			if mt != null: m3.set_surface_override_material(i, _graded(mt, kind))
	return n

static func make(n: String, sc: float, h: int) -> Node3D:
	var root := Node3D.new()
	var R := RandomNumberGenerator.new(); R.seed = h * 7919 + 13
	root.rotation.y = R.randf_range(-.35, .35)
	var spec := _model_spec(n)
	if spec.size():
		var nm: String = spec[1][R.randi() % spec[1].size()]
		var kind: String = spec[3]
		if kind in ["leaf", "dead", "stone"]: root.rotation.y = R.randf() * TAU
		if n.begins_with("stall") or n.begins_with("chest"): root.rotation.y = 0
		var md := model(nm, kind, spec[2] * (sc if kind != "prop" else 1.0) * R.randf_range(.92, 1.08))
		root.add_child(md)
		if n.begins_with("chest"):
			var ap: AnimationPlayer = md.find_child("AnimationPlayer", true, false)
			if ap and n.contains("_o") and ap.has_animation("Chest_Opened"): ap.play("Chest_Opened")
		if kind == "prop" or kind == "stone": shadow(root, .9 * spec[2], .55 * spec[2], .4)
		return root
	if n.begins_with("barrel"): _barrel(root, sc)
	elif n.begins_with("dcrate") or n.begins_with("crate"): _crate(root, sc, R)
	elif n.begins_with("chest"): _chest(root, n.contains("_o"))
	elif n.begins_with("statue"): _statue(root, sc)
	elif n.begins_with("brazier"): _brazier(root)
	elif n.begins_with("lectern"): _lectern(root)
	elif n.begins_with("pine"): _pine(root, sc, R)
	elif n.begins_with("oak") or n.begins_with("birch"): _tree(root, sc, R, n.begins_with("birch"))
	elif n.begins_with("deadtree"): _dead(root, sc, R)
	elif n.begins_with("shrub"): _shrub(root, sc, R)
	elif n.begins_with("rock"): _rock(root, sc, R)
	elif n.begins_with("stump") or n.begins_with("wood"): _stump(root, sc)
	elif n.begins_with("grave") or n.begins_with("cross"): _grave(root, n.begins_with("cross"))
	elif n.begins_with("fountain"): root.rotation.y = 0; _fountain(root)
	elif n.begins_with("stall"): root.rotation.y = 0; _stall(root)
	elif n.begins_with("anvil"): _anvil(root)
	elif n.begins_with("campfire"): _stump(root, .6)
	return root

static func _barrel(r: Node3D, sc: float) -> void:
	var s := sc * 1.15
	shadow(r, .9 * s, .55 * s)
	var w := m("wood", Color(.95, .85, .75)); var iron := m("", Color(.22, .2, .22), .5)
	_mesh(r, cyl(.33 * s, .28 * s, .35 * s), w, Vector3(0, .175 * s, 0))
	_mesh(r, cyl(.28 * s, .33 * s, .35 * s), w, Vector3(0, .525 * s, 0))
	_mesh(r, cyl(.27 * s, .27 * s, .02), m("wood", Color(.7, .55, .45)), Vector3(0, .71 * s, 0))
	for y in [.12, .35, .58]:
		_mesh(r, cyl(.338 * s if y == .35 else .31 * s, .338 * s if y == .35 else .31 * s, .045 * s), iron, Vector3(0, y * s, 0))

static func _crate(r: Node3D, sc: float, R: RandomNumberGenerator) -> void:
	var s := sc * 1.1
	shadow(r, 1.0 * s, .7 * s)
	var w := m("wood", Color(.9, .8, .68)); var frame := m("wood", Color(.55, .42, .32))
	var e := .74 * s
	_mesh(r, box(e, e, e), w, Vector3(0, e / 2, 0))
	for x in [-1, 1]:
		for z in [-1, 1]:
			_mesh(r, box(.07 * s, e + .01, .07 * s), frame, Vector3(x * (e / 2 - .03 * s), e / 2, z * (e / 2 - .03 * s)))
	for y in [0.04, e - .04]:
		_mesh(r, box(e + .01, .07 * s, .07 * s), frame, Vector3(0, y, e / 2 - .03 * s))
		_mesh(r, box(e + .01, .07 * s, .07 * s), frame, Vector3(0, y, -e / 2 + .03 * s))
	_mesh(r, box(e * 1.3, .06 * s, .07 * s), frame, Vector3(0, e / 2, e / 2 + .005), Vector3(0, 0, .78))

# 보물상자: 금테·자물쇠·은은한 금빛 — 장애물(통·나무 상자)과 확실히 다르게
static func _chest(r: Node3D, open: bool) -> void:
	shadow(r, 1.1, .7, .55)
	var w := m("wood", Color(.62, .34, .2)); var gold := m("", Color(1, .78, .3), .35, Color(.35, .22, .02))
	_mesh(r, box(.82, .42, .5), w, Vector3(0, .21, 0))
	for x in [-.38, 0.0, .38]: _mesh(r, box(.06, .44, .52), gold, Vector3(x, .21, 0))
	var lid := Node3D.new(); lid.position = Vector3(0, .42, -.25); r.add_child(lid)
	if open: lid.rotation.x = -1.9
	_mesh(lid, cyl(.25, .25, .82, 12), w, Vector3(0, 0, .25), Vector3(0, 0, PI / 2), Vector3(1, 1, 1))
	for x in [-.38, .38]: _mesh(lid, cyl(.265, .265, .06, 12), gold, Vector3(x, 0, .25), Vector3(0, 0, PI / 2))
	if not open:
		_mesh(r, box(.14, .16, .04), gold, Vector3(0, .36, .27))
	else:
		_mesh(r, box(.7, .05, .4), m("", Color(1, .85, .35), .3, Color(1, .7, .2)), Vector3(0, .4, 0))

static func _statue(r: Node3D, sc: float) -> void:
	var st := m("stone", Color(.85, .85, .9))
	shadow(r, 1.2, .8)
	_mesh(r, box(.9, .3, .9), st, Vector3(0, .15, 0))
	_mesh(r, box(.7, .2, .7), st, Vector3(0, .4, 0))
	_mesh(r, cyl(.12, .3, 2.0 * sc, 4), st, Vector3(0, .5 + sc, 0), Vector3(0, PI / 4, 0))
	_mesh(r, cyl(0, .16, .35, 4), st, Vector3(0, .5 + 2 * sc + .17, 0), Vector3(0, PI / 4, 0))
	_mesh(r, box(.08, .25, .02), m("", Color(.6, .8, 1), .5, Color(.3, .5, 1)), Vector3(0, 1.0 + sc * .6, .21))

static func _brazier(r: Node3D) -> void:
	var iron := m("", Color(.25, .22, .22), .45)
	shadow(r, .8, .55)
	_mesh(r, cyl(.18, .26, .12), iron, Vector3(0, .06, 0))
	_mesh(r, cyl(.06, .06, .7), iron, Vector3(0, .45, 0))
	_mesh(r, cyl(.36, .16, .22, 12), iron, Vector3(0, .9, 0))
	_mesh(r, cyl(.3, .3, .03, 12), m("", Color(1, .5, .15), 1, Color(1, .45, .1)), Vector3(0, 1.0, 0))

static func _lectern(r: Node3D) -> void:
	var w := m("wood", Color(.7, .55, .45))
	shadow(r, .8, .5)
	_mesh(r, box(.5, .08, .4), w, Vector3(0, .04, 0))
	_mesh(r, box(.12, .8, .12), w, Vector3(0, .45, 0))
	_mesh(r, box(.6, .06, .45), w, Vector3(0, .88, 0), Vector3(-.5, 0, 0))
	_mesh(r, box(.5, .03, .36), m("", Color(.9, .85, .7)), Vector3(0, .93, .02), Vector3(-.5, 0, 0))

static func _foliage(r: Node3D, pos: Vector3, rad: float, col: Color) -> void:
	_mesh(r, ball(rad, 9), m("leaf", col * Color(.78, .8, .74)), pos, Vector3(), Vector3(1, .85, 1))   # 잎은 덜 쨍하게

static func _tree(r: Node3D, sc: float, R: RandomNumberGenerator, birch: bool) -> void:
	var s := sc * 1.25
	shadow(r, 2.6 * s, 1.5 * s, .45)
	var trunk := m("bark", Color(.95, .93, .9) if birch else Color(.85, .75, .65))
	_mesh(r, cyl(.1 * s, .2 * s, 1.6 * s, 8), trunk, Vector3(0, .8 * s, 0))
	var col := Color(.85, 1, .7) if birch else Color(.9, 1, .85)
	for k in 6:
		var a := k / 6.0 * TAU + R.randf() * .6
		var d := (.45 + R.randf() * .3) * s
		_foliage(r, Vector3(cos(a) * d, (1.8 + R.randf() * .7) * s, sin(a) * d * .8), (.55 + R.randf() * .25) * s, col)
	_foliage(r, Vector3(0, 2.5 * s, 0), .75 * s, col)

static func _pine(r: Node3D, sc: float, R: RandomNumberGenerator) -> void:
	var s := sc * 1.3
	shadow(r, 2.0 * s, 1.2 * s, .45)
	_mesh(r, cyl(.08 * s, .15 * s, 1.0 * s, 8), m("bark", Color(.8, .7, .6)), Vector3(0, .5 * s, 0))
	var g := m("leaf", Color(.6, .85, .7))
	for k in 4:
		var y := (.8 + k * .62) * s; var rr := (1.0 - k * .2) * s
		_mesh(r, cyl(0, rr, .95 * s, 10), g, Vector3(0, y + .4 * s, 0), Vector3(0, R.randf() * TAU, 0))

static func _dead(r: Node3D, sc: float, R: RandomNumberGenerator) -> void:
	var s := sc * 1.2
	shadow(r, 1.4 * s, .8 * s, .4)
	var b := m("bark", Color(.6, .55, .5))
	_mesh(r, cyl(.07 * s, .17 * s, 1.8 * s, 7), b, Vector3(0, .9 * s, 0))
	for k in 4:
		var a := k / 4.0 * TAU + R.randf()
		_mesh(r, cyl(.02 * s, .06 * s, .9 * s, 5), b, Vector3(cos(a) * .3 * s, (1.3 + k * .15) * s, sin(a) * .3 * s), Vector3(sin(a) * .9, 0, -cos(a) * .9))

static func _shrub(r: Node3D, sc: float, R: RandomNumberGenerator) -> void:
	var s := sc * .9
	shadow(r, 1.1 * s, .7 * s, .35)
	for k in 3:
		_foliage(r, Vector3(R.randf_range(-.25, .25) * s, (.28 + R.randf() * .12) * s, R.randf_range(-.15, .15) * s), (.32 + R.randf() * .12) * s, Color(.8, .95, .75))

static func _rock(r: Node3D, sc: float, R: RandomNumberGenerator) -> void:
	var s := sc
	shadow(r, 1.0 * s, .6 * s, .4)
	_mesh(r, ball(.35 * s, 7), m("stone", Color(.75, .73, .78)), Vector3(0, .15 * s, 0), Vector3(R.randf(), R.randf() * TAU, 0), Vector3(1.2, .6, .9))
	_mesh(r, ball(.2 * s, 6), m("stone", Color(.7, .68, .72)), Vector3(.3 * s, .08 * s, .1 * s), Vector3(0, R.randf(), 0), Vector3(1, .7, 1))

static func _stump(r: Node3D, sc: float) -> void:
	shadow(r, .8 * sc, .5 * sc, .4)
	_mesh(r, cyl(.26 * sc, .32 * sc, .35 * sc, 10), m("bark", Color(.8, .7, .6)), Vector3(0, .175 * sc, 0))
	_mesh(r, cyl(.25 * sc, .25 * sc, .01, 10), m("wood", Color(.95, .8, .6)), Vector3(0, .355 * sc, 0))

static func _grave(r: Node3D, cross: bool) -> void:
	var st := m("stone", Color(.7, .7, .75))
	shadow(r, .8, .5, .4)
	if cross:
		_mesh(r, box(.12, .9, .12), st, Vector3(0, .45, 0)); _mesh(r, box(.5, .12, .12), st, Vector3(0, .65, 0))
	else:
		_mesh(r, box(.55, .6, .14), st, Vector3(0, .3, 0)); _mesh(r, cyl(.275, .275, .14, 12), st, Vector3(0, .6, 0), Vector3(PI / 2, 0, 0))

static func _anvil(r: Node3D) -> void:
	var iron := m("", Color(.3, .3, .33), .4)
	shadow(r, .9, .5)
	_mesh(r, box(.3, .4, .3), m("wood", Color(.6, .5, .4)), Vector3(0, .2, 0))
	_mesh(r, box(.6, .18, .26), iron, Vector3(0, .49, 0))

# 유럽 마을 광장의 작은 분수: 팔각 돌 수반 + 두 단 접시 + 꼭대기 장식, 흘러내리는 물줄기와 잔물결
static var WATER_SH: Shader
static func water_mat(deep := Color(.06, .2, .3), shallow := Color(.25, .55, .65)) -> ShaderMaterial:
	if WATER_SH == null:
		WATER_SH = Shader.new(); WATER_SH.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
uniform vec3 deep : source_color = vec3(.06, .2, .3);
uniform vec3 shallow : source_color = vec3(.25, .55, .65);
uniform sampler2D noise : hint_normal, repeat_enable, filter_linear_mipmap;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wp.xz * .9;
	vec3 n1 = texture(noise, uv + vec2(TIME * .05, TIME * .03)).rgb;
	vec3 n2 = texture(noise, uv * 1.7 - vec2(TIME * .04, -TIME * .06)).rgb;
	NORMAL_MAP = normalize(n1 + n2 - 1.0);
	NORMAL_MAP_DEPTH = 1.2;
	float r = length(UV - .5) * 2.0;
	ALBEDO = mix(deep, shallow, smoothstep(.0, 1.0, r));
	ROUGHNESS = .06; METALLIC = .0; SPECULAR = .9;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = shallow * .12 + vec3(.5, .7, .8) * fres * .25;
	ALPHA = .86;
}
"""
	var mt := ShaderMaterial.new(); mt.shader = WATER_SH
	var nt := NoiseTexture2D.new(); nt.seamless = true; nt.as_normal_map = true; nt.bump_strength = 6.0; nt.width = 256; nt.height = 256
	var fn := FastNoiseLite.new(); fn.frequency = .03; nt.noise = fn
	mt.set_shader_parameter("noise", nt); mt.set_shader_parameter("deep", deep); mt.set_shader_parameter("shallow", shallow)
	return mt

static func _water_drop(r: Node3D, pos: Vector3, ring: float, amount: int, fall: float) -> void:
	# 접시 가장자리에서 아래로 떨어지는 물줄기(작은 물방울 입자)
	var pt := CPUParticles3D.new(); var q := QuadMesh.new(); q.size = Vector2(.05, .14)
	var pm := StandardMaterial3D.new(); pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; pm.albedo_texture = World.glow_tex(); pm.albedo_color = Color(.75, .9, 1, .55); pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = pm; pt.mesh = q; pt.amount = amount; pt.lifetime = sqrt(2 * fall / 9.8) + .05; pt.preprocess = 1.0
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING; pt.emission_ring_axis = Vector3.UP; pt.emission_ring_radius = ring; pt.emission_ring_inner_radius = ring * .96; pt.emission_ring_height = .01
	pt.direction = Vector3(0, -1, 0); pt.spread = 4.0; pt.initial_velocity_min = .1; pt.initial_velocity_max = .3; pt.gravity = Vector3(0, -9.8, 0)
	pt.position = pos; r.add_child(pt)

static func _fountain(r: Node3D) -> void:
	var st: Material = World.pbr("large_sandstone_blocks", .9)
	var st2: Material = m("stone", Color(.62, .6, .66), .9)
	shadow(r, 3.6, 2.6, .35)
	# 팔각 수반: 바깥 벽 + 테두리 돌
	_mesh(r, cyl(1.4, 1.5, .5, 8), st, Vector3(0, .25, 0))
	_mesh(r, cyl(1.5, 1.5, .08, 8), st2, Vector3(0, .52, 0))
	var wm := water_mat()
	var pool := MeshInstance3D.new(); var pd := CylinderMesh.new(); pd.top_radius = 1.3; pd.bottom_radius = 1.3; pd.height = .02; pd.radial_segments = 32; pool.mesh = pd
	pool.material_override = wm; pool.position = Vector3(0, .47, 0); r.add_child(pool)
	# 가운데 기둥 → 아래 접시 → 위 작은 접시 → 꼭대기 장식
	_mesh(r, cyl(.16, .24, 1.1, 10), st2, Vector3(0, 1.0, 0))
	_mesh(r, cyl(.7, .2, .22, 16), st2, Vector3(0, 1.5, 0))
	var b1 := MeshInstance3D.new(); var d1 := CylinderMesh.new(); d1.top_radius = .62; d1.bottom_radius = .62; d1.height = .02; d1.radial_segments = 24; b1.mesh = d1; b1.material_override = wm; b1.position = Vector3(0, 1.6, 0); r.add_child(b1)
	_mesh(r, cyl(.08, .12, .5, 8), st2, Vector3(0, 1.85, 0))
	_mesh(r, cyl(.32, .1, .12, 12), st2, Vector3(0, 2.1, 0))
	var b2 := MeshInstance3D.new(); var d2 := CylinderMesh.new(); d2.top_radius = .27; d2.bottom_radius = .27; d2.height = .02; d2.radial_segments = 16; b2.mesh = d2; b2.material_override = wm; b2.position = Vector3(0, 2.16, 0); r.add_child(b2)
	_mesh(r, ball(.1, 10), st2, Vector3(0, 2.3, 0))
	# 꼭대기에서 솟는 물 + 접시 가장자리에서 떨어지는 물줄기 + 수면 물보라
	var up := CPUParticles3D.new(); var uq := QuadMesh.new(); uq.size = Vector2(.06, .06)
	var um := StandardMaterial3D.new(); um.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; um.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; um.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	um.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; um.albedo_texture = World.glow_tex(); um.albedo_color = Color(.8, .95, 1, .6); uq.material = um
	up.mesh = uq; up.amount = 40; up.lifetime = .8; up.preprocess = 1.0; up.direction = Vector3(0, 1, 0); up.spread = 14.0
	up.initial_velocity_min = 1.4; up.initial_velocity_max = 1.8; up.gravity = Vector3(0, -6.0, 0); up.position = Vector3(0, 2.4, 0); r.add_child(up)
	_water_drop(r, Vector3(0, 2.15, 0), .3, 30, .5)
	_water_drop(r, Vector3(0, 1.58, 0), .66, 70, 1.1)
	var sp := CPUParticles3D.new(); var sq := QuadMesh.new(); sq.size = Vector2(.08, .08); sq.material = um
	sp.mesh = sq; sp.amount = 36; sp.lifetime = .5; sp.preprocess = .5
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING; sp.emission_ring_axis = Vector3.UP; sp.emission_ring_radius = .7; sp.emission_ring_inner_radius = .6; sp.emission_ring_height = .01
	sp.direction = Vector3(0, 1, 0); sp.spread = 50.0; sp.initial_velocity_min = .3; sp.initial_velocity_max = .7; sp.gravity = Vector3(0, -4, 0); sp.position = Vector3(0, .5, 0); r.add_child(sp)
	var L := OmniLight3D.new(); L.light_color = Color(.55, .8, 1); L.light_energy = .7; L.omni_range = 3.0; L.position = Vector3(0, .9, .9); r.add_child(L)

static func _stall(r: Node3D) -> void:
	var w := m("wood", Color(.85, .7, .55))
	shadow(r, 2.6, 1.6, .45)
	_mesh(r, box(2.0, .1, .9), w, Vector3(0, .8, 0))
	_mesh(r, box(1.9, .7, .8), m("wood", Color(.6, .45, .35)), Vector3(0, .4, 0))
	for x in [-.95, .95]:
		for z in [-.4, .4]: _mesh(r, box(.08, 2.0, .08), w, Vector3(x, 1.0, z))
	_mesh(r, box(2.3, .06, 1.3), m("cloth"), Vector3(0, 2.05, .1), Vector3(.25, 0, 0))
	# 진열품
	_mesh(r, cyl(.08, .1, .25), m("", Color(.85, .2, .25), .3, Color(.3, 0, 0)), Vector3(-.5, .98, 0))
	_mesh(r, cyl(.08, .1, .25), m("", Color(.25, .35, .9), .3, Color(0, 0, .3)), Vector3(-.25, .98, .05))
	_mesh(r, box(.4, .08, .3), m("", Color(.9, .85, .7)), Vector3(.4, .9, 0))


# ================= 바닥에 떨어진 것들(동전·물약·주문서·강화석·장비) =================
static func metal(col: Color, rough := .3, emis := .0) -> StandardMaterial3D:
	var key := "metal|%s|%s|%s" % [col.to_html(), rough, emis]
	if MATS.has(key): return MATS[key]
	var mt := StandardMaterial3D.new(); mt.albedo_color = col; mt.metallic = .75; mt.roughness = rough; mt.metallic_specular = 1.0
	mt.rim_enabled = true; mt.rim = .5; mt.rim_tint = .3
	if emis > 0:
		mt.emission_enabled = true; mt.emission = col; mt.emission_energy_multiplier = emis
	MATS[key] = mt; return mt

static func glass(col: Color, glow := .6) -> StandardMaterial3D:
	var key := "glass|%s|%s" % [col.to_html(), glow]
	if MATS.has(key): return MATS[key]
	var mt := StandardMaterial3D.new(); mt.albedo_color = Color(col, .82); mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.roughness = .05; mt.metallic_specular = 1.0; mt.rim_enabled = true; mt.rim = .8; mt.rim_tint = .2
	mt.emission_enabled = true; mt.emission = col; mt.emission_energy_multiplier = glow
	MATS[key] = mt; return mt

static func torus(r_in: float, r_out: float, seg := 18) -> TorusMesh:
	var t := TorusMesh.new(); t.inner_radius = r_in; t.outer_radius = r_out; t.rings = seg; t.ring_segments = 8; return t

const GOLD_C := Color(1.0, .76, .28)
static func loot(kind: String, it = null) -> Node3D:
	var r := Node3D.new()
	var c0 := cast; cast = false
	match kind:
		"gold":
			var g := metal(GOLD_C, .22, .25)
			var coin := cyl(.1, .1, .028, 18)
			for i in 4: _mesh(r, coin, g, Vector3(randf_range(-.02, .02), .015 + i * .03, randf_range(-.02, .02)))
			_mesh(r, coin, g, Vector3(.15, .06, .04), Vector3(0, 0, 1.0))
			_mesh(r, coin, g, Vector3(-.12, .02, .1), Vector3(.2, 0, .15))
		"pothp", "potmp":
			var col := Color(1, .18, .22) if kind == "pothp" else Color(.25, .45, 1)
			_mesh(r, ball(.13, 14), glass(col, .9), Vector3(0, .14, 0))
			_mesh(r, cyl(.045, .05, .1, 10), glass(col.lerp(Color.WHITE, .5), .3), Vector3(0, .3, 0))
			_mesh(r, cyl(.05, .04, .05, 8), m("wood", Color(.7, .5, .35)), Vector3(0, .37, 0))
			_mesh(r, ball(.05, 8), m("", Color(1, 1, 1), .1, Color(.9, .9, .9)), Vector3(.05, .19, .08))   # 반짝임
		"scroll":
			var sc_ := model("Scroll_1", "prop", 2.0); sc_.position.y = .02; r.add_child(sc_)
		"scroll_old":
			_mesh(r, cyl(.07, .07, .36, 14), m("cloth", Color(.95, .85, .62)), Vector3(0, .08, 0), Vector3(0, 0, PI / 2))
			_mesh(r, cyl(.075, .075, .06, 14), m("", Color(.75, .15, .15), .5), Vector3(0, .08, 0), Vector3(0, 0, PI / 2))
			for sx in [-.2, .2]: _mesh(r, cyl(.03, .03, .05, 8), m("wood", Color(.55, .38, .25)), Vector3(sx, .08, 0), Vector3(0, 0, PI / 2))
		"stone":
			var gem := SphereMesh.new(); gem.radius = .12; gem.height = .36; gem.radial_segments = 6; gem.rings = 3
			_mesh(r, gem, glass(Color(.45, .8, 1.0), 1.4), Vector3(0, .2, 0))
			_mesh(r, gem, glass(Color(.7, .95, 1.0), 1.0), Vector3(.12, .1, .05), Vector3(0, .5, .6), Vector3(.5, .5, .5))
		"item":
			_gear(r, it)
	cast = c0
	return r

static func _gear(r: Node3D, it) -> void:
	var rc := Color(D.RAR[it.rar].color)
	var gem := glass(rc, 1.3)
	var wood := m("wood", Color(.75, .55, .4))
	var leather := m("cloth", Color(.45, .3, .2))
	var silver := metal(Color(.85, .87, .92), .25, .05); var gold := metal(GOLD_C, .25, .1)
	var band := gold if it.rar in ["rare", "unique", "set"] else silver
	match String(it.base):
		"staff":
			_mesh(r, cyl(.025, .035, .9, 8), wood, Vector3(0, .06, 0), Vector3(0, 0, PI / 2))
			_mesh(r, torus(.05, .075), band, Vector3(.42, .06, 0), Vector3(0, 0, PI / 2))
			_mesh(r, ball(.07, 10), gem, Vector3(.5, .08, 0))
		"wand":
			_mesh(r, cyl(.018, .025, .5, 8), wood, Vector3(0, .05, 0), Vector3(0, 0, PI / 2))
			_mesh(r, ball(.045, 8), gem, Vector3(.27, .06, 0))
		"sceptre":
			_mesh(r, cyl(.025, .03, .6, 8), band, Vector3(0, .05, 0), Vector3(0, 0, PI / 2))
			_mesh(r, ball(.08, 10), band, Vector3(.32, .07, 0))
			_mesh(r, ball(.05, 8), gem, Vector3(.38, .1, 0))
		"ring":
			_mesh(r, torus(.06, .085), band, Vector3(0, .1, 0), Vector3(PI / 2 * .6, 0, 0))
			_mesh(r, ball(.035, 8), gem, Vector3(0, .19, -.03))
		"amulet":
			_mesh(r, torus(.13, .145, 22), band, Vector3(0, .02, 0))
			_mesh(r, ball(.06, 10), gem, Vector3(0, .05, .14), Vector3(), Vector3(1, .6, 1.3))
		"cloak", "robe":
			var cl := m("cloth", rc.lerp(Color(.35, .3, .4), .55))
			_mesh(r, box(.42, .06, .32), cl, Vector3(0, .03, 0))
			_mesh(r, box(.38, .05, .2), cl, Vector3(0, .08, -.04), Vector3(.2, 0, 0))
			_mesh(r, ball(.03, 6), band, Vector3(0, .11, .06))
		"gloves":
			for sx in [-.1, .1]:
				_mesh(r, box(.12, .06, .2), leather, Vector3(sx, .03, 0), Vector3(0, sx, 0))
				_mesh(r, cyl(.06, .065, .06, 10), band, Vector3(sx, .04, .12), Vector3(PI / 2, 0, 0))
		"belt":
			_mesh(r, torus(.15, .19, 22), leather, Vector3(0, .02, 0), Vector3(), Vector3(1, .5, 1))
			_mesh(r, box(.08, .05, .06), band, Vector3(0, .04, .17))
		"boots":
			for sx in [-.09, .09]:
				_mesh(r, box(.1, .22, .12), leather, Vector3(sx, .11, 0))
				_mesh(r, box(.1, .07, .2), leather, Vector3(sx, .035, .06))
				_mesh(r, box(.11, .03, .13), band, Vector3(sx, .2, 0))
		_:
			_mesh(r, box(.2, .1, .2), m("cloth", rc), Vector3(0, .05, 0))
