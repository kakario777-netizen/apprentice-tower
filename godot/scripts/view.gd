# 움직이는 것들 그리기: 캐릭터·적·시체·상자·떨어진 물건·계단·귀환문·탑 문·탄·효과
# 게임 상태(game.gd, 픽셀 좌표)를 매 프레임 읽어 3D 로 옮긴다.
class_name View
extends Node3D

const S := 1.0 / 32.0
const UP := World.STAND / 32.0     # 세운 그림에서 웹 px 높이 → 3D 높이

var game: Game
var world: World
var player: Actor
var npcs := {}          # id → Actor
var enemies := {}       # id → Actor
var corpses := {}       # id → Actor
var chests := {}        # id → Sprite3D
var drops := {}         # id → Node3D
var stairs_node: Node3D
var stairs_key := ""
var portal_node: Node3D
var gate_node: Node3D
var ward_q: MeshInstance3D
var harden_q: MeshInstance3D

# 효과 묶음
var mm_add_glow: MultiMeshInstance3D
var mm_add_dot: MultiMeshInstance3D
var mm_mix_dot: MultiMeshInstance3D
var lines_add := ImmediateMesh.new()
var lines_mix := ImmediateMesh.new()
var batches := {}       # fx 그림 이름 → MultiMeshInstance3D
var shot_lights: Array = []
var tips := {}
var tip_glow: MeshInstance3D
var tip_core: MeshInstance3D
var tip_light: OmniLight3D
var tip_a := 0.0
var tip3 := Vector3()
var shot_h := 1.3          # 내 탄이 나는 높이 = 스태프 끝 높이

static var _dot_tex: Texture2D
static func dot_tex() -> Texture2D:
	if _dot_tex == null:
		var g = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(.8, Color(1, 1, 1, 1))
		var t = GradientTexture2D.new(); t.gradient = g; t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(.5, .5); t.fill_to = Vector2(1, .5); t.width = 64; t.height = 64
		_dot_tex = t
	return _dot_tex

static func w3(x: float, y: float, h := 0.0) -> Vector3: return Vector3(x * S, h, y * S)

func _ready() -> void:
	player = Actor.new(); add_child(player); player.setup("player", 46)
	mm_add_glow = _mm(World.glow_tex(), true)
	mm_add_dot = _mm(dot_tex(), true)
	mm_mix_dot = _mm(dot_tex(), false)
	for im in [[lines_add, true], [lines_mix, false]]:
		var mi = MeshInstance3D.new(); mi.mesh = im[0]
		var m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if im[1] else BaseMaterial3D.BLEND_MODE_MIX
		m.no_depth_test = true; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.render_priority = 2 if im[1] else 1
		mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.custom_aabb = AABB(Vector3(-10, -10, -10), Vector3(200, 50, 200))
		add_child(mi)
	ward_q = _anim_quad("fx_shield"); harden_q = _anim_quad("")
	var f = FileAccess.open("res://ui/staff_tips.json", FileAccess.READ)
	if f: tips = JSON.parse_string(f.get_as_text())
	tip_glow = world.glow_quad(Color(1, 1, 1, 0), .9); add_child(tip_glow)
	tip_core = world.glow_quad(Color(1, 1, 1, 0), .28); add_child(tip_core)
	for q in [tip_glow, tip_core]:
		var mm: StandardMaterial3D = q.material_override; mm.no_depth_test = true; mm.render_priority = 4
	tip_light = OmniLight3D.new(); tip_light.omni_range = 3.0; tip_light.light_energy = 0.0; add_child(tip_light)
	for i in 4:
		var L = OmniLight3D.new(); L.omni_range = 4.0; L.light_energy = 0.0; L.visible = false
		add_child(L); shot_lights.append(L)

func _mm(tex: Texture2D, add: bool) -> MultiMeshInstance3D:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q = QuadMesh.new(); q.size = Vector2(1, 1); q.orientation = PlaneMesh.FACE_Y
	mm.mesh = q
	var mi = MultiMeshInstance3D.new(); mi.multimesh = mm
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_texture = tex; m.no_depth_test = true; m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 3 if add else 1
	mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-10, -10, -10), Vector3(200, 50, 200))
	add_child(mi)
	return mi

# 그림 프레임을 도는 평면 효과(불덩이·폭발 등)
static var FX_SHADER: Shader
func _batch(name: String) -> MultiMeshInstance3D:
	if batches.has(name): return batches[name]
	if FX_SHADER == null:
		FX_SHADER = Shader.new()
		FX_SHADER.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap;
varying float alpha;
void vertex() { UV.x = (UV.x + INSTANCE_CUSTOM.x) / INSTANCE_CUSTOM.y; alpha = INSTANCE_CUSTOM.z; }
void fragment() { vec4 c = texture(tex, UV); ALBEDO = c.rgb; ALPHA = c.a * alpha; }
"""
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_custom_data = true
	var q = QuadMesh.new(); q.size = Vector2(1, 1); q.orientation = PlaneMesh.FACE_Y
	mm.mesh = q
	var mi = MultiMeshInstance3D.new(); mi.multimesh = mm
	var m = ShaderMaterial.new(); m.shader = FX_SHADER
	m.set_shader_parameter("tex", load("res://assets/sprites/%s.png" % name))
	m.render_priority = 2
	mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-10, -10, -10), Vector3(200, 50, 200))
	add_child(mi); batches[name] = mi
	return mi

# 세워 두는 반투명 덧셈 그림(보호막 등): 재질 하나를 프레임마다 고친다
func _anim_quad(name: String) -> MeshInstance3D:
	var q = QuadMesh.new(); q.size = Vector2(1, 1)
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = load("res://assets/sprites/%s.png" % name) if name != "" else World.glow_tex()
	var mi = MeshInstance3D.new(); mi.mesh = q; mi.material_override = m; mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi); return mi

# ---------------- 맵이 바뀌었을 때 ----------------
func rebuild() -> void:
	for d in [npcs, enemies, corpses, chests, drops]:
		for k in d.keys(): d[k].queue_free()
		d.clear()
	if stairs_node: stairs_node.queue_free()
	stairs_node = null; stairs_key = ""
	if portal_node: portal_node.queue_free()
	portal_node = null
	if gate_node: gate_node.queue_free()
	gate_node = null
	if game.mg.gate != null: _build_gate(game.mg.gate)

func _sprite(tex: Texture2D) -> Sprite3D:
	var s = Sprite3D.new(); s.texture = tex; s.centered = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS; s.shaded = true
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return s

# 웹 drawProp 과 같은 크기·기준점으로 소품을 세운다(부모 노드 기준 위치)
func _prop(parent: Node3D, n: String, sc: float, off := Vector2()) -> Sprite3D:
	var M = World.props_meta()
	if not M.has(n): return null
	var m: Dictionary = M[n]
	var s = _sprite(World.tex("res://assets/props/%s.png" % n))
	s.pixel_size = World.PF * sc * UP
	s.position = Vector3(off.x * S + (m.w / 2.0 - m.ax) * s.pixel_size, (m.ay - m.h / 2.0) * s.pixel_size, off.y * S)
	parent.add_child(s); return s

func _glow(parent: Node3D, col: Color, size: float, pos: Vector3) -> MeshInstance3D:
	var g = world.glow_quad(col, size); g.position = pos; parent.add_child(g); return g

func _light(parent: Node3D, pos: Vector3, col: Color, rng: float, en: float) -> OmniLight3D:
	var L = OmniLight3D.new(); L.position = pos; L.light_color = col; L.omni_range = rng; L.light_energy = en; L.omni_attenuation = 1.2
	parent.add_child(L); return L

func _build_gate(g: Vector2) -> void:
	# 마을 북쪽 탑 입구(디아블로1 대성당 입구처럼): 돌 계단 → 큰 고딕 아치 → 반쯤 열린 나무 문 → 어둠 속 으스스한 빛
	gate_node = Node3D.new(); gate_node.position = w3(g.x, g.y); add_child(gate_node)
	var stone: Material = World.pbr("large_sandstone_blocks", .5)
	var dark_stone: Material = World.pbr("stone_brick_wall_001", .5)
	var step_m: Material = World.pbr("stone_tiles_02", .6)
	var box := func(size: Vector3, pos: Vector3, m: Material, rot := Vector3()) -> MeshInstance3D:
		var mi = MeshInstance3D.new(); var bm = BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = m
		mi.position = pos; mi.rotation = rot; gate_node.add_child(mi); return mi
	# 정면 벽(두껍게) + 위쪽 톱니 + 양옆 부벽
	box.call(Vector3(11.0, 4.4, 1.6), Vector3(0, 2.2, -1.25), stone)
	for k in 13: box.call(Vector3(.52, .5, 1.6), Vector3(-5.5 + .26 + k * .895, 4.65, -1.25), stone)
	for sx in [-1, 1]:
		box.call(Vector3(1.1, 5.2, 2.2), Vector3(sx * 2.25, 2.6, -1.0), dark_stone)       # 문 양옆 큰 기둥
		box.call(Vector3(1.3, .35, 2.4), Vector3(sx * 2.25, 5.3, -1.0), stone)
		box.call(Vector3(.9, 3.4, 1.8), Vector3(sx * 4.9, 1.7, -.95), dark_stone)         # 끝 부벽
	# 아치: 문틀 위로 돌을 겹겹이(뾰족 아치 느낌)
	for i in 7:
		var t: float = i / 6.0
		var ang: float = lerp(-1.15, 1.15, t)
		box.call(Vector3(.62, .5, 1.9), Vector3(sin(ang) * 1.45, 2.9 + cos(ang) * 1.05, -.95), stone, Vector3(0, 0, -ang))
	box.call(Vector3(.55, .7, 2.0), Vector3(0, 4.05, -.9), dark_stone)                    # 쐐기돌
	# 활짝 열린 아치: 안쪽은 막힌 벽이 아니라 보랏빛이 쏟아져 나오는 통로
	var pg := Gradient.new(); pg.set_color(0, Color(.95, .7, 1.0)); pg.add_point(.45, Color(.55, .25, .95)); pg.set_color(pg.get_point_count() - 1, Color(.12, .04, .22))
	var pt2 := GradientTexture2D.new(); pt2.gradient = pg; pt2.fill = GradientTexture2D.FILL_RADIAL; pt2.fill_from = Vector2(.5, .75); pt2.fill_to = Vector2(1.0, .2); pt2.width = 128; pt2.height = 128
	var vm := StandardMaterial3D.new(); vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; vm.albedo_texture = pt2
	vm.emission_enabled = true; vm.emission_texture = pt2; vm.emission = Color.WHITE; vm.emission_energy_multiplier = 1.6
	box.call(Vector3(2.45, 3.05, .08), Vector3(0, 1.52, -2.05), vm)                 # 빛나는 안쪽
	var side_m: Material = World.pbr("stone_brick_wall_001", .5)
	for sx in [-1, 1]: box.call(Vector3(.1, 3.1, 1.7), Vector3(sx * 1.25, 1.55, -1.25), side_m)
	for gq in [[3.6, .75, -1.6], [5.2, .45, -.4], [3.0, .5, .6]]:
		var ig = world.glow_quad(Color(.7, .4, 1.0, gq[1]), gq[0]); ig.position = Vector3(0, 1.3, gq[2]); gate_node.add_child(ig)
	_light(gate_node, Vector3(0, 1.4, -.6), Color(.7, .45, 1.0), 9.0, 2.6)
	_light(gate_node, Vector3(0, .6, 1.6), Color(.6, .4, 1.0), 6.0, 1.2)
	# 반쯤 열린 무거운 나무 문 두 짝
	var wood: Material = Props3D.m("wood", Color(.42, .3, .22), .8)
	var iron: Material = Props3D.metal(Color(.25, .24, .26), .45)
	for sx in [-1, 1]:
		var dn := Node3D.new(); dn.position = Vector3(sx * 1.2, 0, -.45); dn.rotation.y = sx * -1.5; gate_node.add_child(dn)   # 안쪽 벽에 붙도록 활짝
		var dmi = MeshInstance3D.new(); var db = BoxMesh.new(); db.size = Vector3(1.2, 3.0, .12); dmi.mesh = db; dmi.material_override = wood
		dmi.position = Vector3(-sx * .6, 1.5, 0); dn.add_child(dmi)
		for y in [.6, 1.6, 2.5]:
			var bi = MeshInstance3D.new(); var bb = BoxMesh.new(); bb.size = Vector3(1.22, .1, .14); bi.mesh = bb; bi.material_override = iron
			bi.position = Vector3(-sx * .6, y, 0); dn.add_child(bi)
	# 문 앞 돌계단 세 단
	for k in 3:
		box.call(Vector3(3.6 - k * .3, .16, .55), Vector3(0, .08 + k * .16, .05 - k * .45), step_m)
	# 양옆 화로(기둥 위 불)
	for sx in [-1, 1]:
		var br := Props3D.make("brazier", .8, 7 + sx); br.position = Vector3(sx * 3.4, 0, .6); gate_node.add_child(br)
		var fg = world.glow_quad(Color(1, .55, .2, .95), 1.0); fg.position = Vector3(sx * 3.4, 1.15, .66); gate_node.add_child(fg)
		_light(gate_node, Vector3(sx * 3.4, 1.6, .9), Color(1, .6, .3), 6.5, 1.6)
	# 입구에서 새어 나오는 빛 알갱이·안개
	var pt := CPUParticles3D.new(); var pq := QuadMesh.new(); pq.size = Vector2(.08, .08)
	var pm := StandardMaterial3D.new(); pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; pm.albedo_texture = World.glow_tex(); pm.albedo_color = Color(.8, .55, 1, .9); pm.vertex_color_use_as_albedo = true
	pq.material = pm; pt.mesh = pq; pt.amount = 46; pt.lifetime = 2.8; pt.preprocess = 2.0
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; pt.emission_box_extents = Vector3(1.0, .6, .2)
	pt.direction = Vector3(0, .6, 1); pt.spread = 30.0; pt.initial_velocity_min = .2; pt.initial_velocity_max = .5; pt.gravity = Vector3.ZERO
	var cg := Gradient.new(); cg.set_color(0, Color(1, 1, 1, 0)); cg.add_point(.3, Color(1, 1, 1, 1)); cg.set_color(cg.get_point_count() - 1, Color(1, 1, 1, 0)); pt.color_ramp = cg
	pt.position = Vector3(0, .8, -1.4); gate_node.add_child(pt)

# ---------------- 매 프레임 ----------------
func sync(dt: float) -> void:
	var G = game.G; var P = game.P; var mg = game.mg
	# 플레이어
	player.position = w3(P.x, P.y + 2)
	# 계단을 오르내리는 동안: 발이 계단 높이를 따라가고, 벽에 가려 잘리지 않게 맨 앞에 그린다
	var climbing: bool = G.pull != null and G.pull.what in ["stairs", "down"]
	if climbing:
		var fr: float = clamp((G.pull.ty + 58 - P.y) / 58.0, 0.0, 1.0)
		player.position.y = fr * World.WALLZ * .95 * (1.0 if G.pull.what == "stairs" else -1.0)
	player.spr.no_depth_test = climbing
	player.face = P.face
	player.set_anim(P.anim); player.at = P.at; player.tick(0)
	var blink: bool = P.inv > 0 and int(G.time * 30) % 2 == 1
	player.spr.modulate = Color(2.2, 2.2, 2.2) if blink else Color.WHITE
	P.tip = {x = P.x + cos(P.face) * 16, y = P.y - 30 + sin(P.face) * 6}
	_ward(P, G)
	_staff_tip(P, G, dt)
	# 마을 사람
	for n in G.npcs:
		if not npcs.has(n.id):
			var a = Actor.new(); add_child(a); a.setup(n.get("spr", n.id), 46); npcs[n.id] = a
			if n.has("tint"): a.spr.modulate = Color(n.tint).lerp(Color.WHITE, .45)
		var a: Actor = npcs[n.id]
		a.position = w3(n.x, n.y + 13); a.face = atan2(P.y - n.y, P.x - n.x); a.at = G.time + n.x; a.tick(0)
	# 적
	var live = {}
	for e in G.enemies:
		live[e.id] = true
		if not enemies.has(e.id):
			var a = Actor.new(); add_child(a); a.setup(Game.spr_name(e), Game.enemy_h(e)); enemies[e.id] = a
			if e.get("elite", false):
				# 유니크 몬스터: 몸 주위로 제 색 빛
				var ec := Color(e.tint)
				_glow(a, Color(ec, .5), 2.8, Vector3(0, .9, -.2)); _light(a, Vector3(0, 1.2, .6), ec, 4.0, 2.2)
		var a: Actor = enemies[e.id]
		var vis = mg.is_seen(e.x, e.y)
		a.visible = vis
		if not vis: continue
		a.position = w3(e.x, e.y)
		a.face = atan2(e.y - P.y, e.x - P.x) if e.fearT > 0 else atan2(P.y - e.y, P.x - e.x)
		a.set_anim(e.anim); a.at = e.at; a.tick(0)
		var alpha = 1.0
		if e.d.has("hidden"):
			var dp = Game.hyp(P.x - e.x, P.y - e.y)
			alpha = 1.0 if dp < 110 else (.35 if dp < 170 else .06)
		var c = Color(e.tint).lerp(Color.WHITE, .25) * 1.15 if e.get("elite", false) else (Color(e.d.tint) if e.d.has("tint") else Color.WHITE)
		if e.flash > 0: c = Color(2.4, 2.4, 2.4)
		elif e.frozenT > 0: c = Color(.62, .86, 1.35)
		elif e.shield > 0: c = Color(.85, .9, 1.2)
		if e.boss == "flesh" and e.split: c *= Color(1.12, .9, .9)
		c.a = alpha
		a.spr.modulate = c
		a.shadow.visible = alpha > .5
	for k in enemies.keys():
		if not live.has(k):
			enemies[k].queue_free(); enemies.erase(k)
	# 시체
	live = {}
	for c in G.corpses:
		live[c.id] = true
		if not corpses.has(c.id):
			var a = Actor.new(); add_child(a); a.setup(c.name, c.H); a.face = c.ang; a.set_anim("die"); corpses[c.id] = a
			a.position = w3(c.x, c.y)
		var a: Actor = corpses[c.id]
		a.visible = mg.is_seen(c.x, c.y)
		a.at = c.t; a.tick(0)
		var al: float = max(0.0, 1 - (c.t - 6) / 3) if c.t > 6 else 1.0
		a.spr.modulate = Color(1, 1, 1, al); a.shadow.visible = c.t < 1.0
	for k in corpses.keys():
		if not live.has(k):
			corpses[k].queue_free(); corpses.erase(k)
	# 상자
	for c in G.chests:
		if not chests.has(c.id):
			var n = Node3D.new(); n.position = w3(c.x, c.y + 4); add_child(n); chests[c.id] = n
			n.set_meta("open", -1)
		var n: Node3D = chests[c.id]
		n.visible = mg.is_seen(c.x, c.y)
		var o = 1 if c.open else 0
		if n.get_meta("open") != o:
			for ch in n.get_children(): ch.queue_free()
			var ch3 = Props3D.make("chest_o" if c.open else "chest_c", 1.0, c.id)
			ch3.rotation.y = 0; n.add_child(ch3)
			if not c.open:
				# 보물이 든 상자: 금빛 반짝임과 은은한 빛(장애물 소품과 구별)
				var g := _glow(n, Color(1, .8, .35, .55), 1.6, Vector3(0, .55, .15)); g.name = "aura"
				var L := _light(n, Vector3(0, 1.0, .5), Color(1, .8, .4), 3.0, .9); L.name = "auraL"
			n.set_meta("open", o)
		var au = n.get_node_or_null("aura")
		if au:
			var pul: float = .5 + .5 * sin(G.time * 3.0 + c.x)
			(au.material_override as StandardMaterial3D).albedo_color = Color(1, .8, .35, .3 + .35 * pul)
			if randf() < .05 and n.visible: G.fx.append({x = c.x + Game.rnd(-14, 14), y = c.y + Game.rnd(-6, 6), vx = 0.0, vy = -25.0, life = .7, max = .7, color = "#ffe08a", size = 1.6, h = .5})
	# 떨어진 물건
	_sync_drops(G, P)
	# 계단
	var sk = ""
	if mg.stairs != null and G.floor > 0 and not mg.stairs.get("alcove", false): sk = "%d,%d" % [int(mg.stairs.x), int(mg.stairs.y)]
	if sk != stairs_key:
		if stairs_node: stairs_node.queue_free()
		stairs_node = null; stairs_key = sk
		if sk != "":
			stairs_node = Node3D.new(); stairs_node.position = w3(mg.stairs.x, mg.stairs.y); add_child(stairs_node)
			_prop(stairs_node, "stairs_down", .5, Vector2(0, 18))
			_glow(stairs_node, Color(1, .8, .35, .5), 2.4, Vector3(0, .5, .5))
			_light(stairs_node, Vector3(0, 1.2, .5), Color(1, .82, .45), 5.0, 1.0)
	if stairs_node and mg.stairs != null: stairs_node.visible = mg.is_seen(mg.stairs.x, mg.stairs.y)
	# 귀환문
	if G.portal != null and portal_node == null:
		portal_node = Node3D.new(); add_child(portal_node)
		_prop(portal_node, "waystone_on", .7, Vector2(0, 22))
		_glow(portal_node, Color(.44, .61, 1, .7), 2.5, Vector3(0, .9, .3))
		_light(portal_node, Vector3(0, 1.2, .6), Color(.5, .66, 1), 5.0, 1.4)
	elif G.portal == null and portal_node != null:
		portal_node.queue_free(); portal_node = null
	if portal_node:
		portal_node.position = w3(G.portal.x, G.portal.y)
		if randf() < .3: G.fx.append({x = G.portal.x + Game.rnd(-12, 12), y = G.portal.y + Game.rnd(-18, 18), vx = 0.0, vy = -30.0, life = .6, max = .6, color = "#9fd0ff", size = 1.6})
	_sync_fx(G, P)

# 스태프 끝: 시전하는 동안 스킬 색으로 반짝임
func _staff_tip(P, G, dt: float) -> void:
	var casting: bool = P.firing and P.active != null and G.floor > 0 and G.state == "play"
	tip_a = move_toward(tip_a, 1.0 if casting else 0.0, dt * (10.0 if casting else 5.0))
	tip3 = player.position + Vector3(0, .9, 0)
	var vis := tip_a > .01 and tips.size() > 0
	tip_glow.visible = vis; tip_core.visible = vis; tip_light.visible = vis
	if tips.is_empty(): return
	var cf: Array = player.cur_frame()
	var an: String = "run" if cf[0] == "run" else "stance"
	var row: Array = tips[an][cf[1]]
	var t = row[min(cf[2], row.size() - 1)]
	if t == null: t = row[0]
	if t == null: return
	var ps: float = player.spr.pixel_size
	var pos := player.position + Vector3(t[0] * ps, -t[1] * ps, .08)
	tip3 = pos
	shot_h = clamp(pos.y + .1, 1.3, 1.9); game.shot_h = shot_h
	if not vis: return
	var col := Color(game.act_color())
	var pulse := .8 + .2 * sin(G.time * 18.0) + .1 * sin(G.time * 31.0)
	var gm: StandardMaterial3D = tip_glow.material_override; gm.albedo_color = Color(col, .75 * tip_a * pulse)
	var cm: StandardMaterial3D = tip_core.material_override; cm.albedo_color = Color(1, 1, 1, .9 * tip_a)
	(tip_glow.mesh as QuadMesh).size = Vector2.ONE * (.75 + .2 * pulse)
	tip_glow.position = pos; tip_core.position = pos + Vector3(0, 0, .01)
	tip_light.position = pos + Vector3(0, 0, .3); tip_light.light_color = col; tip_light.light_energy = 1.4 * tip_a * pulse

func _ward(P, G) -> void:
	var M = Actor.meta()
	if P.ward > 0 and M.has("fx_shield"):
		var m: Dictionary = M.fx_shield; var A: Dictionary = m.anims.idle
		var fr = int(G.time * 1000 / A.dur * A.frames) % int(A.frames)
		var k: float = 40.0 / m.get("hgt", m.ch) * UP
		var mat: StandardMaterial3D = ward_q.material_override
		mat.uv1_scale = Vector3(1.0 / A.frames, 1, 1); mat.uv1_offset = Vector3(float(fr) / A.frames, 0, 0)
		mat.albedo_color = Color(1, 1, 1, .75)
		(ward_q.mesh as QuadMesh).size = Vector2(m.cw * k, m.ch * k)
		ward_q.position = w3(P.x, P.y + 4, (m.anchor[1] - m.ch / 2.0) * k) + Vector3((m.cw / 2.0 - m.anchor[0]) * k, 0, .05)
		ward_q.visible = true
	else: ward_q.visible = false
	if P.hardenT > 0:
		(harden_q.mesh as QuadMesh).size = Vector2(1.3, 1.9)
		(harden_q.material_override as StandardMaterial3D).albedo_color = Color(.8, .95, 1, .5)
		harden_q.position = w3(P.x, P.y + 2, .95) + Vector3(0, 0, .06); harden_q.visible = true
	else: harden_q.visible = false

const LOOT := {gold = "loot_coins", pothp = "loot_hp", potmp = "loot_mp", scroll = "loot_scroll", stone = "loot_gem", hp = "", mp = ""}
const GEAR := {staff = "loot_staff", wand = "loot_wand", sceptre = "loot_staff", ring = "loot_ring", amulet = "loot_ring", cloak = "loot_cloak", robe = "loot_cloak", gloves = "loot_cloak", belt = "loot_ring", boots = "loot_cloak"}
static func _lname(d) -> String: return GEAR.get(d.it.base, "loot_cloak") if d.kind == "item" else LOOT.get(d.kind, "")

func _sync_drops(G, P) -> void:
	var live = {}
	var M = Actor.meta()
	var bd = 140.0; G.nearItem = null
	for d in G.drops:
		if d.kind == "item":
			var q = Game.hyp(P.x - d.x, P.y - d.y)
			if q < bd:
				bd = q; G.nearItem = d
	for d in G.drops:
		live[d.id] = true
		if not drops.has(d.id):
			var n = Node3D.new(); add_child(n); drops[d.id] = n
			# 입체 모형(동전 더미·유리 물약·두루마리·수정·장비)
			if d.kind in ["gold", "pothp", "potmp", "scroll", "stone", "item"]:
				var lo := Props3D.loot(d.kind, d.get("it")); lo.name = "spr"; lo.scale = Vector3.ONE * (1.75 if d.kind == "item" else 1.5); n.add_child(lo)
				Props3D.shadow(n, .5, .32, .45)
			if d.kind == "item" and d.it.rar in ["normal", "magic"]:
				_glow(n, Color(Color(D.RAR[d.it.rar].color), .3), 30 * S * 1.4, Vector3(0, .12, 0))
			elif d.kind == "item":
				var col = Color(D.RAR[d.it.rar].color)
				var beam = MeshInstance3D.new(); var bq = QuadMesh.new(); bq.size = Vector2((14.0 if d.it.rar in ["unique", "set"] else 10.0) * S, 90 * UP); beam.mesh = bq
				var g = Gradient.new(); g.set_color(0, Color(col, .4)); g.set_color(1, Color(col, 0))
				var gt = GradientTexture2D.new(); gt.gradient = g; gt.fill_from = Vector2(0, 1); gt.fill_to = Vector2(0, 0); gt.width = 8; gt.height = 64
				var bm = StandardMaterial3D.new(); bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; bm.albedo_texture = gt; beam.material_override = bm; beam.position = Vector3(0, 45 * UP, 0); n.add_child(beam)
				_glow(n, Color(col, .5), 44 * S * 1.4, Vector3(0, .15, 0))
			elif d.kind == "stone":
				_glow(n, Color(.6, .85, 1, .7), 30 * S * 1.4, Vector3(0, .2, 0))
			elif d.kind == "hp" or d.kind == "mp":
				var col = Color("#ff4a5a") if d.kind == "hp" else Color("#5a8cff")
				_glow(n, Color(col, .7), 32 * S * 1.4, Vector3(0, .3, 0))
				var orb = MeshInstance3D.new(); var sp = SphereMesh.new(); sp.radius = 5 * S; sp.height = 10 * S; orb.mesh = sp
				var om = StandardMaterial3D.new(); om.albedo_color = col; om.emission_enabled = true; om.emission = col; om.emission_energy_multiplier = .8; orb.material_override = om
				orb.position = Vector3(0, .3, 0); orb.name = "spr"; n.add_child(orb)
		var n: Node3D = drops[d.id]
		n.visible = game.mg.is_seen(d.x, d.y)
		var b = sin(G.time * 5 + d.x) * 2
		n.position = w3(d.x, d.y)
		var sp = n.get_node_or_null("spr")
		if sp:
			sp.position.y = _drop_base(d, M) + (d.get("h", 0.0)) * UP + (0.0 if d.kind == "gold" else b * .4 * UP)
			if d.kind != "gold" and sp is Node3D and not (sp is MeshInstance3D): sp.rotation.y = G.time * 1.4 + d.x * .01
	for k in drops.keys():
		if not live.has(k):
			drops[k].queue_free(); drops.erase(k)

func _drop_base(d, M) -> float:
	if d.kind == "hp" or d.kind == "mp": return .3
	if d.kind in ["gold", "pothp", "potmp", "scroll", "stone", "item"]: return .03
	var ln: String = _lname(d)
	if not M.has(ln): return .3
	var m: Dictionary = M[ln]
	var tw: float = 14.0 if d.kind == "gold" else (((12.0 if d.it.base == "ring" else 22.0)) if d.kind == "item" else 14.0)
	var k: float = tw / max(m.cw, m.ch)
	return (m.ch * .8 - m.ch / 2.0) * k * UP + 2 * UP

# ---------------- 효과 ----------------
func _put(mm: MultiMesh, i: int, x: float, y: float, r: float, c: Color, h := .06) -> void:
	var t = Transform3D(Basis().scaled(Vector3(r * 2 * S, 1, r * 2 * S)), w3(x, y, h))
	mm.set_instance_transform(i, t); mm.set_instance_color(i, c)

func _sync_fx(G, P) -> void:
	var glow: Array = []; var dot: Array = []; var mix: Array = []
	# 먼지·연기·잔해(일반 섞기)
	for f in G.fx:
		var a: float = f.life / f.max
		if f.has("dust") or f.has("smoke"):
			var c = Color(f.color); c.a = a * (.38 if f.has("smoke") else .6)
			mix.append([f.x, f.y, f.size * ((2.2 - a * 1.2) if f.has("smoke") else 1.0), c])
		elif f.has("cone"):
			var c = Color(f.color); c.a = a * .42; glow.append([f.x, f.y, f.size * (4.5 - a * 2.5), c, .55])
		elif f.size > 2.6:
			var c = Color(f.color); c.a = a * .8; glow.append([f.x, f.y, f.size * 2.6, c, f.get("h", .06)])
		else:
			var c = Color(f.color); c.a = a * .9; dot.append([f.x, f.y, f.size, c, f.get("h", .06)])
	for d in G.debris:
		if not game.mg.is_seen(d.x, d.y): continue
		var c = Color(d.color); c.a = min(1.0, d.life)
		var r: float = 2.5 if d.shape == "bone" else (4.0 if d.shape == "skull" else d.s)
		mix.append([d.x, d.y - d.h, r, c])
	# 구역의 빛
	for z in G.zones:
		var a: float = min(1.0, z.life / max(z.max, .001) * 3)
		if z.kind == "ember":
			var fl = .8 + .2 * sin(G.time * 14 + z.x)
			glow.append([z.x, z.y - 3, 20 * fl, Color(Color("#ff7a2a"), .7 * a)]); dot.append([z.x, z.y - 2, 2.4 * fl, Color(1, .86, .55, .8 * a)])
		elif z.kind == "acid": glow.append([z.x, z.y - 34, z.r * .9, Color(Color("#5a7a4a"), .35 * a)])
		elif z.kind == "stasis": glow.append([z.x, z.y, z.r * .9, Color(Color("#9a70ff"), .18 * a)])
	# 탄 빛
	for s in G.shots: glow.append([s.x, s.y, s.r * 4, Color(Color(s.color), .5), shot_h])
	for s in G.eshots:
		if s.kind == "arrow": continue
		var col = Color({ice = "#9fd0ff", poison = "#8fd14f", fire = "#ff6a2a", skull = "#b77bff", spit = "#d98a9a"}.get(s.kind, "#ffffff"))
		glow.append([s.x, s.y, s.r * 1.8, Color(col, .3), .9])
	for pair in [[mm_add_glow, glow], [mm_add_dot, dot], [mm_mix_dot, mix]]:
		var mm: MultiMesh = pair[0].multimesh; var L: Array = pair[1]
		if mm.instance_count < L.size(): mm.instance_count = max(64, L.size() + 64)
		mm.visible_instance_count = L.size()
		for i in L.size(): _put(mm, i, L[i][0], L[i][1], L[i][2], L[i][3], L[i][4] if L[i].size() > 4 else .06)
	_sync_sprite_fx(G)
	_sync_lines(G, P)
	# 탄에 빛 몇 개
	var li = 0
	for s in G.shots:
		if li >= shot_lights.size(): break
		var L: OmniLight3D = shot_lights[li]; L.visible = true; L.light_color = Color(s.color); L.light_energy = 1.2; L.position = w3(s.x, s.y, shot_h); li += 1
	while li < shot_lights.size():
		shot_lights[li].visible = false; li += 1

func _sync_sprite_fx(G) -> void:
	var M = Actor.meta()
	var lists = {}
	var addf = func(name: String, x: float, y: float, w: float, h: float, rot: float, fr: float, frames: float, alpha: float, ox: float, oy: float):
		if not lists.has(name): lists[name] = []
		lists[name].append([x, y, w, h, rot, fr, frames, alpha, ox, oy])
	for a in G.anims:
		if not M.has(a.name): continue
		var m: Dictionary = M[a.name]; var A: Dictionary = m.anims.idle
		var fr: int = min(A.frames - 1, int(a.t / a.life * A.frames)); var k: float = a.size / max(m.cw, m.ch)
		var al: float = max(0.0, 1 - (a.t - a.life * .7) / (a.life * .3)) if a.t > a.life * .7 else 1.0
		addf.call(a.name, a.x, a.y, m.cw * k, m.ch * k, a.rot, fr, A.frames, al, (m.cw / 2.0 - m.anchor[0]) * k, (m.ch / 2.0 - m.anchor[1]) * k)
		if a.has("h"): lists[a.name][-1].append(a.h)
	for z in G.zones:
		if z.kind == "stasis" and M.has("fx_runes"):
			var m: Dictionary = M.fx_runes; var A: Dictionary = m.anims.idle
			var fr = int(G.time * 1000 / A.dur * A.frames) % int(A.frames); var k: float = z.r * 2.1 / m.ch
			addf.call("fx_runes", z.x, z.y + z.r * .4, m.cw * k, m.ch * k, 0, fr, A.frames, min(1.0, z.life) * .8, (m.cw / 2.0 - m.anchor[0]) * k, (m.ch / 2.0 - m.anchor[1]) * k)
	for s in G.shots:
		var sn = "fx_fireball" if s.els.has("fire") else ("fx_icicle" if s.els.has("frost") else ("fx_spark_blue" if s.els.has("storm") else "fx_plasma"))
		if not M.has(sn): continue
		var m: Dictionary = M[sn]; var A: Dictionary = m.anims.idle
		var fr = int(G.time * 12 + s.x) % int(A.frames)
		var k: float = (s.r * 5 if (sn == "fx_plasma" or sn == "fx_spark_blue") else s.r * 9) / max(m.cw, m.ch)
		var rot_ = (sn == "fx_fireball" or sn == "fx_icicle")
		var ang: float = atan2(s.vy, s.vx) + PI if rot_ else 0.0
		addf.call(sn, s.x, s.y, m.cw * k, m.ch * k, ang, fr, A.frames, 1.0, m.cw * k * (.25 if rot_ else 0.0), 0.0)
		lists[sn][-1].append(shot_h)
	for s in G.eshots:
		var sn: String = {ice = "fx_spark_blue", poison = "fx_spark_green", skull = "fx_spark_red", fire = "fx_fireball", spit = "fx_spark_green"}.get(s.kind, "")
		if sn == "" or not M.has(sn): continue
		var m: Dictionary = M[sn]; var A: Dictionary = m.anims.idle
		var fr = int(G.time * 12 + s.x) % int(A.frames)
		var k: float = (s.r * 8 if sn == "fx_fireball" else s.r * 4.5) / max(m.cw, m.ch)
		var ang: float = atan2(s.vy, s.vx) + PI if sn == "fx_fireball" else 0.0
		addf.call(sn, s.x, s.y, m.cw * k, m.ch * k, ang, fr, A.frames, 1.0, m.cw * k * (.25 if sn == "fx_fireball" else 0.0), 0.0)
		lists[sn][-1].append(.9)
	for name in batches.keys():
		if not lists.has(name): batches[name].multimesh.visible_instance_count = 0
	for name in lists.keys():
		var mm: MultiMesh = _batch(name).multimesh; var L: Array = lists[name]
		if mm.instance_count < L.size(): mm.instance_count = L.size() + 16
		mm.visible_instance_count = L.size()
		for i in L.size():
			var e: Array = L[i]
			var b = Basis(Vector3.UP, -e[4]) * Basis.from_scale(Vector3(e[2] * S, 1, e[3] * S))
			var off = Vector2(e[8], e[9]).rotated(e[4])
			mm.set_instance_transform(i, Transform3D(b, w3(e[0] + off.x, e[1] + off.y, e[10] if e.size() > 10 else .08)))
			mm.set_instance_custom_data(i, Color(e[5], e[6], e[7], 0))

# 선(번개·고리·구역·화살)
func _zigzag(a: Vector3, b: Vector3, amp_px: float, n := 0) -> Array:
	var L := a.distance_to(b)
	if n <= 0: n = max(3, int(L * 32 / 16))
	var side := Vector3(-(b - a).z, 0, (b - a).x).normalized()
	var out: Array = [a]
	for i in range(1, n):
		var t := float(i) / n
		out.append(a.lerp(b, t) + side * randf_range(-amp_px, amp_px) * S + Vector3(0, randf_range(-amp_px, amp_px) * S * .5, 0))
	out.append(b)
	return out

# 3D 점들을 따라 카메라를 향한 띠(폭은 웹 px)
func _line3(im: ImmediateMesh, pts: Array, w: float, c: Color) -> void:
	if pts.size() < 2: return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pts.size():
		var p: Vector3 = pts[i]
		var dv: Vector3 = pts[min(i + 1, pts.size() - 1)] - pts[max(i - 1, 0)]
		var nrm := Vector3(-dv.z, 0, dv.x)
		if nrm.length() < .0001: nrm = Vector3(0, 1, 0)
		nrm = nrm.normalized() * w * .5 * S
		im.surface_set_color(c); im.surface_add_vertex(p + nrm)
		im.surface_set_color(c); im.surface_add_vertex(p - nrm)
	im.surface_end()

func _line(im: ImmediateMesh, pts: Array, w: float, c: Color, h := .07) -> void:
	if pts.size() < 2: return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in pts.size():
		var p: Vector2 = pts[i]
		var dv: Vector2 = (pts[min(i + 1, pts.size() - 1)] - pts[max(i - 1, 0)])
		var nrm = Vector2(-dv.y, dv.x).normalized() * w * .5
		im.surface_set_color(c); im.surface_add_vertex(w3(p.x + nrm.x, p.y + nrm.y, h))
		im.surface_set_color(c); im.surface_add_vertex(w3(p.x - nrm.x, p.y - nrm.y, h))
	im.surface_end()

func _circle_pts(x: float, y: float, r: float, a0 := 0.0, a1 := TAU, n := 40) -> Array:
	var out: Array = []
	for i in n + 1:
		var a: float = a0 + (a1 - a0) * i / n
		out.append(Vector2(x + cos(a) * r, y + sin(a) * r))
	return out

func _disc(im: ImmediateMesh, x: float, y: float, r: float, c: Color, h := .05) -> void:
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 40
	for i in n:
		var a0 = TAU * i / n; var a1 = TAU * (i + 1) / n
		for p in [Vector2(x, y), Vector2(x + cos(a0) * r, y + sin(a0) * r), Vector2(x + cos(a1) * r, y + sin(a1) * r)]:
			im.surface_set_color(c); im.surface_add_vertex(w3(p.x, p.y, h))
	im.surface_end()

func _sync_lines(G, P) -> void:
	lines_add.clear_surfaces(); lines_mix.clear_surfaces()
	for b in G.bolts:
		var c = Color(b.color)
		var p3: Array = []
		for p in b.pts: p3.append(w3(p.x, p.y, shot_h))
		if b.get("from_p", 0) or b.has("beam"): p3[0] = tip3
		if b.has("beam"):
			_line3(lines_add, p3, 24, Color(c, .25)); _line3(lines_add, p3, 11, Color(c, .6)); _line3(lines_add, p3, 4, Color(1, 1, 1, .9))
		elif b.has("elec"):
			# 전기: 매 프레임 새로 꺾이는 두 가닥 + 잔가지 + 넓은 푸른 번짐
			var a3: Vector3 = p3[0]; var b3: Vector3 = p3[-1]
			for strand in 2:
				var z := _zigzag(a3, b3, 9.0 if strand == 0 else 6.0)
				if strand == 0:
					_line3(lines_add, z, 16, Color(c, .18)); _line3(lines_add, z, 5, Color(c, .75)); _line3(lines_add, z, 1.8, Color(1, 1, 1, 1))
				else:
					_line3(lines_add, z, 2.2, Color(c.lightened(.3), .55))
				for f in 2:
					var k: int = randi_range(1, z.size() - 2)
					var dir: Vector3 = (b3 - a3).normalized().rotated(Vector3.UP, randf_range(-1.1, 1.1)) * randf_range(.5, 1.2)
					_line3(lines_add, _zigzag(z[k], z[k] + dir, 4.0, 4), 1.6, Color(c.lightened(.4), .7))
		else:
			_line3(lines_add, p3, 9, Color(c, .3)); _line3(lines_add, p3, 3, Color(c, .85)); _line3(lines_add, p3, 1.4, Color(1, 1, 1, 1))
	for r in G.rings:
		var t: float = 1 - r.life / r.max; var rr: float = r.r0 + (r.r1 - r.r0) * t; var c = Color(r.color)
		var pts = _circle_pts(r.x, r.y, rr)
		_line(lines_add, pts, 4 * (1 - t) + 1, Color(c, (1 - t) * .9)); _line(lines_add, pts, 10 * (1 - t) + 2, Color(c, (1 - t) * .25))
	for z in G.zones:
		var a: float = min(1.0, z.life / max(z.max, .001) * 3)
		if z.kind == "stasis":
			_disc(lines_mix, z.x, z.y, z.r, Color(.63, .47, 1, .1 * a))
			_line(lines_mix, _circle_pts(z.x, z.y, z.r), 2.5, Color(.78, .67, 1, .6 * a))
			for k in 10:
				var a0: float = G.time * .6 + k * TAU / 10
				_line(lines_mix, _circle_pts(z.x, z.y, z.r * .8, a0, a0 + TAU / 10 * .55, 6), 2.5, Color(.78, .67, 1, .6 * a))
		elif z.kind == "acid": _disc(lines_mix, z.x, z.y, z.r, Color(.47, .75, .24, .18 * a))
		elif z.kind == "warn":
			var t: float = 1 - z.life / z.max
			_line(lines_mix, _circle_pts(z.x, z.y, z.r), 2.5, Color(.9, .35, .27, .85)); _disc(lines_mix, z.x, z.y, z.r * t, Color(.9, .35, .27, .22))
	for s in G.eshots:
		if s.kind == "arrow":
			var a = atan2(s.vy, s.vx)
			_line(lines_mix, [Vector2(s.x - cos(a) * 10, s.y - sin(a) * 10), Vector2(s.x, s.y)], 2, Color("#e8dcc0"), .9)
	# 계단·문 앞의 회색 반원: 여기 들어서면 빨려 들어간다
	for st in [game.mg.stairs, game.mg.door, game.mg.down]:
		if st == null or G.floor == 0 or not st.get("alcove", false) or not game.mg.is_seen(st.x, st.y + 8): continue
		var pul: float = .5 + .5 * sin(G.time * 2.4)
		var pts: Array = [Vector2(st.x, st.y)]
		for k in 25: pts.append(Vector2(st.x + cos(PI * k / 24) * 44, st.y + sin(PI * k / 24) * 44))
		lines_mix.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for k in range(1, pts.size() - 1):
			for q in [pts[0], pts[k], pts[k + 1]]:
				lines_mix.surface_set_color(Color(.75, .75, .8, .16 + .06 * pul)); lines_mix.surface_add_vertex(w3(q.x, q.y, .04))
		lines_mix.surface_end()
		_line(lines_mix, pts.slice(1), 2.0, Color(.85, .85, .9, .35 + .15 * pul), .05)
	# 계단 금빛 고리
	if game.mg.stairs != null and G.floor > 0 and not game.mg.stairs.get("alcove", false) and game.mg.is_seen(game.mg.stairs.x, game.mg.stairs.y):
		var st = game.mg.stairs; var t: float = G.time
		_line(lines_add, _circle_pts(st.x, st.y + 4, 40, t * .8, t * .8 + TAU * .8), 2, Color(.89, .69, .29, .45 + .25 * sin(t * 3)))
