# 8방향 캐릭터 그림(웹 버전 meta.json 아틀라스 그대로 사용)
class_name Actor
extends Node3D

static var META := {}
static var ART := {}

# 새 손그림 4방향 시트(godot/art): 칸마다 정면·왼쪽·오른쪽·뒷면, 발은 칸 아래에서 16px 위(절반 크기 기준)
static func art() -> Dictionary:
	if ART.is_empty():
		var f = FileAccess.open("res://art/art.json", FileAccess.READ)
		if f: ART = JSON.parse_string(f.get_as_text())
	return ART

var aid := ""            # 새 그림 이름(없으면 옛 그림)
var sheets := {}         # idle / atk / hit / down → 텍스처
var aps := 0.0           # 새 그림 한 픽셀 크기
var base := ""
var idle_h := 0.0
var casting := false     # 시전 중(주인공): 스태프 내민 그림
var sheet := "idle"
var cell := 0

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

func setup(name: String, h_px: float, art_name := "") -> void:
	sname = name; height_px = h_px
	if art_name != "" and (art().has(art_name) or art().has(art_name + "_down")):
		_setup_art(art_name); return
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

func _setup_art(a: String) -> void:
	aid = a
	var A := art()
	base = a.trim_suffix("_idle").trim_suffix("_full")
	for k in [["idle", a], ["atk", base + "_atk"], ["atk", base + "_atk1"], ["cast", base + "_cast"], ["hit", base + "_hit"], ["down", base + "_down"]]:
		if A.has(k[1]) and not sheets.has(k[0]): sheets[k[0]] = load("res://art/%s.png" % k[1])
	# 키: 정면 칸의 실제 그림 높이(무기·모자 포함)를 웹 키(height_px)에 맞춤
	var ref: String = a if A.has(a) else base + "_down"
	var b: Array = A[ref].b[0]
	var hh: float = float(b[3] - b[1]) if A.has(a) else float(b[3] - b[1]) * 2.2
	idle_h = hh if A.has(a) else 0.0
	aps = height_px / max(1.0, hh) / 32.0 * World.STAND
	spr.pixel_size = aps
	spr.centered = true
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spr.shaded = true
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	spr.region_enabled = true
	add_child(spr)
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

static func dir4(a: float) -> int:
	# 0 정면(카메라 쪽=남) · 1 왼쪽 · 2 오른쪽 · 3 뒷면
	var c := cos(a); var s := sin(a)
	if absf(c) > absf(s) * .85: return 2 if c > 0 else 1
	return 0 if s > 0 else 3

func _apply_art() -> void:
	var key := "idle"
	if anim == "die" and sheets.has("down"): key = "down"
	elif anim == "attack" and sheets.has("atk"): key = "atk"
	elif casting and anim != "hit" and sheets.has("cast"): key = "cast"
	elif anim == "hit" and sheets.has("hit"): key = "hit"
	if not sheets.has(key): key = "idle" if sheets.has("idle") else "down"
	var name: String = aid
	match key:
		"atk": name = base + "_atk" if art().has(base + "_atk") else base + "_atk1"
		"cast": name = base + "_cast"
		"hit": name = base + "_hit"
		"down": name = base + "_down"
	var M: Dictionary = art()[name]
	var n: int = int(M.n); var cw: float = float(M.w) / n; var h: float = float(M.h)
	var c: int = dir4(face) if n == 4 else 0
	sheet = key; cell = c
	spr.texture = sheets[key]
	spr.region_rect = Rect2(c * cw, 0, cw, h)
	var foot: float = h - (20.0 if key == "down" else 16.0)
	var ps := aps
	if key == "down" and idle_h > 0:
		# 쓰러진 그림은 원본이 크게 그려져 있어서, 누운 길이를 선 키의 1.15배로 맞춤
		var db: Array = M.b[0]
		ps = aps * minf(1.0, idle_h * 1.15 / max(1.0, float(db[2] - db[0])))
	spr.pixel_size = ps
	spr.position = Vector3(0, (foot - h / 2.0) * ps, 0)
	spr.flip_h = false
	spr.rotation = Vector3.ZERO
	spr.scale = Vector3.ONE
	# 걷기·맞기·공격은 그림을 흔들어 표현
	if key == "idle" or key == "cast":
		if anim == "run":
			# 걸음: 통통 튀고 좌우로 기우뚱 + 착지할 때 살짝 눌림
			var ph := at * 10.0
			var hop := absf(sin(ph))
			spr.position.y += hop * .14 * height_px / 46.0
			spr.rotation.z = sin(ph) * .13
			spr.scale = Vector3(1.0 + (1.0 - hop) * .05, 1.0 - (1.0 - hop) * .06, 1.0)
		elif anim == "hit": spr.rotation.z = .12 if c != 1 else -.12
		elif anim == "attack": spr.position.y += sin(clampf(at * 6.0, 0.0, PI)) * .08
		else: spr.position.y += sin(at * 2.4) * .012 * height_px / 46.0      # 숨쉬기

func set_anim(a: String) -> void:
	if a != anim:
		anim = a
		at = 0.0

func anim_done() -> bool:
	if aid != "": return at > .4
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
	if aid != "": _apply_art(); return
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
