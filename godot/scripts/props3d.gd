# 입체 소품: 통·나무 상자·보물상자·나무·덤불·바위·석상·화로·독서대·분수·노점·묘비·그루터기
# 세워 둔 그림(종이 느낌) 대신 간단한 3D 도형에 질감을 입혀 만든다. 단위: 1 = 타일 한 칸.
class_name Props3D
extends RefCounted

static var MATS := {}

static func m(name: String, col := Color.WHITE, rough := 1.0, emis := Color(0, 0, 0)) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [name, col.to_html(), emis.to_html()]
	if MATS.has(key): return MATS[key]
	var mt := StandardMaterial3D.new()
	if name != "": mt.albedo_texture = load("res://ui/tex_%s.png" % name)
	mt.albedo_color = col; mt.roughness = rough
	mt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if emis.r + emis.g + emis.b > 0:
		mt.emission_enabled = true; mt.emission = emis
	MATS[key] = mt
	return mt

static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3(), scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = mesh; mi.material_override = mat
	mi.position = pos; mi.rotation = rot; mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	_mesh(parent, q, sm, Vector3(0, .02, 0))

const NAMES := ["barrel", "dcrate", "crate", "chest", "statue", "brazier", "lectern", "oak", "birch", "pine", "deadtree", "shrub", "rock", "stump", "grave", "cross", "fountain", "stall", "wood", "anvil", "campfire"]

static func supports(n: String) -> bool:
	for k in NAMES:
		if n.begins_with(k): return true
	return false

static func make(n: String, sc: float, h: int) -> Node3D:
	var root := Node3D.new()
	var R := RandomNumberGenerator.new(); R.seed = h * 7919 + 13
	root.rotation.y = R.randf_range(-.35, .35)
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
	_mesh(r, ball(rad, 9), m("leaf", col), pos, Vector3(), Vector3(1, .85, 1))

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

static func _fountain(r: Node3D) -> void:
	var st := m("stone", Color(.85, .85, .92))
	shadow(r, 3.4, 2.4, .35)
	_mesh(r, cyl(1.35, 1.45, .45, 24), st, Vector3(0, .22, 0))
	var water := StandardMaterial3D.new(); water.albedo_color = Color(.25, .45, .7, .85); water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = .1; water.metallic_specular = 1.0; water.emission_enabled = true; water.emission = Color(.05, .12, .25)
	_mesh(r, cyl(1.2, 1.2, .05, 24), water, Vector3(0, .42, 0))
	_mesh(r, cyl(.2, .28, 1.2, 12), st, Vector3(0, .9, 0))
	_mesh(r, cyl(.55, .25, .2, 16), st, Vector3(0, 1.5, 0))
	_mesh(r, cyl(.45, .45, .03, 16), water, Vector3(0, 1.6, 0))
	_mesh(r, ball(.14, 8), st, Vector3(0, 1.75, 0))

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
