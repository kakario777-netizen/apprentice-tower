# 8방향 캐릭터 그림(웹 버전 meta.json 아틀라스 그대로 사용)
class_name Actor
extends Node3D

static var META := {}

static func meta() -> Dictionary:
	if META.is_empty():
		var f = FileAccess.open("res://assets/sprites/meta.json", FileAccess.READ)
		if f: META = JSON.parse_string(f.get_as_text())
	return META

var sname := ""
var m: Dictionary
var spr := Sprite3D.new()
var shadow: MeshInstance3D
var anim := "stance"
var at := 0.0          # 현재 동작 시간
var face := PI / 2     # 바라보는 방향(웹과 같음: x 오른쪽, y 아래=남쪽)
var height_px := 46.0  # 웹 버전 drawF 의 H
var pages: Array = []

func setup(name: String, h_px: float) -> void:
	sname = name; height_px = h_px
	m = meta().get(name, {})
	var n: int = int(m.get("pages", 1))
	for i in n:
		pages.append(load("res://assets/sprites/%s%s.png" % [name, ("_%d" % i) if i > 0 else ""]))
	spr.texture = pages[0]
	spr.region_enabled = true
	spr.centered = true
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # 발밑 그림자를 따로 그림
	spr.shaded = true
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var k: float = height_px / float(m.get("hgt", m.ch))
	spr.pixel_size = k / 32.0 * World.STAND
	add_child(spr)
	# 발밑 그림자
	var q = QuadMesh.new(); q.size = Vector2(1.1, .55) * (height_px / 46.0)
	var sm = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = World.glow_tex(); sm.albedo_color = Color(0, 0, 0, .55)
	shadow = MeshInstance3D.new(); shadow.mesh = q; shadow.material_override = sm
	shadow.rotation_degrees.x = -90; shadow.position.y = .02
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)
	_apply()

func set_anim(a: String) -> void:
	if a != anim:
		anim = a
		at = 0.0

func anim_done() -> bool:
	var A: Dictionary = m.anims.get(anim, m.anims.get("stance", m.anims.values()[0]))
	return A.type == "play_once" and at * 1000.0 >= A.dur

static func fdir(a: float) -> int:
	var d = fposmod(rad_to_deg(a), 360.0)
	return posmod(int(round((d - 180.0) / 45.0)), 8)

func _frame(A: Dictionary) -> int:
	var n: int = int(A.frames)
	if n <= 1: return 0
	var p: float = at * 1000.0 / max(1.0, float(A.dur))
	if A.type == "play_once": return min(n - 1, int(p * n))
	if A.type == "back_forth":
		var mm = 2 * n - 2; var q = int(p * mm) % mm
		return q if q < n else mm - q
	return int(p * n) % n

func cur_frame() -> Array:
	var A: Dictionary = m.anims.get(anim, m.anims.get("stance", m.anims.values()[0]))
	return [anim, fdir(face) if int(m.dirs) == 8 else 0, _frame(A)]

func tick(dt: float) -> void:
	at += dt
	_apply()

func _apply() -> void:
	if m.is_empty(): return
	var A: Dictionary = m.anims.get(anim, m.anims.get("stance", m.anims.values()[0]))
	var dir = fdir(face) if int(m.dirs) == 8 else 0
	var fr = _frame(A)
	var ps = spr.pixel_size
	if m.has("fr"):
		var f = m.fr[(int(A.row) + dir) * int(m.nf) + fr]
		if f == null: return
		spr.texture = pages[int(f[0])]
		spr.region_rect = Rect2(f[1], f[2], f[3], f[4])
		var cx: float = f[5] + f[3] / 2.0 - m.anchor[0]
		var cy: float = f[6] + f[4] / 2.0 - m.anchor[1]
		spr.position = Vector3(cx * ps, -cy * ps, 0)
	else:
		spr.region_rect = Rect2(fr * m.cw, (int(A.row) + dir) * m.ch, m.cw, m.ch)
		spr.position = Vector3((m.cw / 2.0 - m.anchor[0]) * ps, -(m.ch / 2.0 - m.anchor[1]) * ps, 0)
