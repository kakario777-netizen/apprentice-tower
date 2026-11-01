# 견습마법사의 탑 — 고도판 진입점: 카메라·입력·컨트롤러·화면 전환을 묶는다
extends Node3D

const CAM_ELEV := 40.0     # 바닥을 내려다보는 각도(웹 CTH=50° 와 같은 기울기)
const CAM_DIST := 16.25    # 웹 RC=520px
const CAM_FOV := 37.0
const SETTINGS := "user://settings.cfg"

var game := Game.new()
var world: World
var view: View
var cam := Camera3D.new()
var env := WorldEnvironment.new()
var moon := DirectionalLight3D.new()
var plight: OmniLight3D
var hud: Hud
var ui: Ui
var title_t := 0.0
var pad_swap := false
var quality := 1.0
var show_fps := false
var snd := Snd.new()
var autosave_min := 5          # 자동 저장 간격(분): 5 · 10 · 15 · 30
var autosave_t := 0.0
var pad_prev := {}
var pad_was := false
var last_town := false

# 시험용(스크린샷·성능 측정)
var shot_path := ""
var shot_frames := 0
var shot_mode := ""
var bench := false
var bench_t := 0.0
var bench_n := 0
var test_floor := 0
var test_inp = null
var samples_dir := ""
var lvtest := false
var fxtest := false
var tiertest := false
var roomtest := false
var terrtest := false

func _ready() -> void:
	Ui.init_fonts()
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		pad_swap = cfg.get_value("pad", "swap", false)
		quality = cfg.get_value("gfx", "quality", 1.0); show_fps = cfg.get_value("gfx", "fps", false)
		autosave_min = cfg.get_value("game", "autosave", 5)
		snd.music_vol = cfg.get_value("sound", "music", .7); snd.sfx_vol = cfg.get_value("sound", "sfx", .9)
	Game.migrate_old()
	if OS.has_feature("mobile"): Input.emulate_touch_from_mouse = false     # 폰: 터치→마우스→터치로 한 번 더 들어오는 가짜 터치 막기
	get_viewport().scaling_3d_scale = quality
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): shot_path = a.substr(7)
		elif a.begins_with("--floor="): test_floor = int(a.substr(8))
		elif a.begins_with("--mode="): shot_mode = a.substr(7)
		elif a == "--bench": bench = true
		elif a.begins_with("--samples="): samples_dir = a.substr(10)
		elif a == "--lvtest": lvtest = true
		elif a == "--fxtest": fxtest = true
		elif a == "--tiertest": tiertest = true
		elif a == "--roomtest": roomtest = true
		elif a == "--terrtest": terrtest = true
		elif a.begins_with("--seed="): seed(int(a.substr(7)))
	add_child(game)
	World.set_fog(PackedByteArray())
	world = World.new(); add_child(world)
	view = View.new(); view.game = game; view.world = world; add_child(view)
	cam.fov = CAM_FOV; cam.near = .5; cam.far = 90.0; add_child(cam)
	env.environment = Environment.new(); add_child(env)
	moon.rotation_degrees = Vector3(-55, 30, 0); add_child(moon)
	plight = OmniLight3D.new(); plight.omni_range = 10.0; plight.light_energy = 1.1; plight.light_color = Color(1, .92, .85); add_child(plight)
	_make_dust(); _make_vignette(); _apply_shadows()
	hud = Hud.new(); hud.main = self; hud.game = game; hud.cam = cam; add_child(hud)
	ui = Ui.new(); ui.main = self; ui.game = game; add_child(ui)
	game.toast.connect(hud.show_toast)
	game.saved.connect(hud.show_saving)
	add_child(snd); game.sfx.connect(snd.play)
	game.ui.connect(_on_ui)
	game.rumble.connect(_rumble)
	# 타이틀: 마을 장면을 배경으로
	_title_scene()
	ui.open_title()
	if test_floor > 0 or shot_mode != "": _test_setup()
	if samples_dir != "" and not fxtest and not tiertest and not roomtest and not terrtest: _run_samples()
	if lvtest: _run_lvtest()
	if fxtest: _run_fxtest()
	if tiertest: _run_tiertest()
	if roomtest: _run_roomtest()
	if terrtest: _run_terrtest()

func _setup_env(town: bool) -> void:
	var mg := game.mg
	var e: Environment = env.environment
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(.02, .016, .03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true; e.glow_intensity = .7; e.glow_bloom = .06; e.glow_hdr_threshold = 1.0
	# 색 보정: 대비·채도를 살짝 올려 화면이 덜 밋밋하게
	e.adjustment_enabled = true; e.adjustment_contrast = 1.1; e.adjustment_saturation = 1.06; e.adjustment_brightness = 1.02
	var dm: StandardMaterial3D = dust.mesh.surface_get_material(0)
	dm.albedo_color = Color(.85, 1, .55, .55) if town else Color(1, .82, .55, .35)
	if town:
		e.ambient_light_color = Color(.42, .44, .58); e.ambient_light_energy = 1.0
		moon.visible = true; moon.light_color = Color(.62, .68, .95); moon.light_energy = .55; plight.visible = false
	elif mg.terrace:
		e.background_color = Color(.012, .014, .035)
		e.ambient_light_color = Color(.4, .44, .62); e.ambient_light_energy = 1.0
		moon.visible = true; moon.light_color = Color(.66, .72, 1); moon.light_energy = .7; plight.visible = true
	else:
		var th: Dictionary = D.THEMES[D.theme(game.G.floor)]
		e.ambient_light_color = th.amb; e.ambient_light_energy = 1.0
		moon.visible = false; plight.visible = true

func _on_ui(what: String) -> void:
	match what:
		"buttons": hud.build_buttons()
		"belt": hud.build_belt()
		"levelup": ui.open_level()
		"end": ui.open_end()
		"gate": ui.open_gate()
		"state":
			if game.G.state == "first": ui.open_first()
			if game.G.state != "play": hud.clear_input()

func _rebuild_level() -> void:
	game.level_changed = false
	World.set_fog(game.mg.fog_bytes())
	var th: Dictionary = D.THEMES[D.theme(max(1, game.G.floor))]
	World.TINT = th.tint if game.G.floor > 0 and not game.mg.terrace and game.mg.town == null else Color.WHITE
	World.TORCH = th.torch if game.G.floor > 0 else Color(1, .6, .3)
	World.FLOOR_TEX = th.floor
	World.FLOOR_PBR = th.fp; World.WALL_PBR = th.wp
	world.build(game.mg); view.rebuild()
	_setup_env(game.mg.town != null)
	game.mg.dirty = true
	cam.position = Vector3()   # 다음 프레임에 바로 따라붙도록

# ---------------- 메뉴에서 부르는 것 ----------------
func new_game(diff: String, slot_i := -1) -> void:
	if slot_i < 0: slot_i = max(0, Game.free_slot())
	ui.hide_all(); game.new_game(diff, slot_i); hud.build_buttons(); autosave_t = 0.0
func continue_game(slot_i := -1, tier := -1) -> void:
	if slot_i < 0: slot_i = Game.latest_slot()
	if slot_i < 0: return
	var sv = Game.read_slot(slot_i)
	if sv == null: return
	# 다음 단계가 열려 있으면(디아블로처럼) 이어하기 전에 단계를 고른다
	if tier < 0 and int(sv.get("tierMax", 0)) > 0:
		ui.open_tier_pick(slot_i, sv); return
	ui.hide_all(); game.load_game(sv, slot_i, tier); hud.build_buttons(); autosave_t = 0.0
func sand_start() -> void:
	ui.hide_all(); game.sand_start(); hud.build_buttons(); ui.open_sand()
func open_pause() -> void:
	if game.G == null or game.G.state != "play": return
	game.set_state("pause"); ui.open_pause(); game.save()
func resume() -> void:
	ui.hide_all(); game.set_state("play"); hud.build_buttons()
func to_title(do_save := true) -> void:
	if do_save: game.save()
	_title_scene(); ui.open_title()

func _title_scene() -> void:
	game.no_save = true
	game.G = game.fresh_g("easy"); game.P = game.fresh_p(); game.recalc(); game.go_town(false); game.G.banner.t = 0
	game.set_state("title")
func first_back() -> void:
	ui.hide_all(); game.set_state("play"); game.P.y += 40
func try_talk() -> void:
	var n = game.near_npc()
	if n != null and game.G.state == "play": ui.open_talk(n)
func save_settings() -> void:
	var cfg = ConfigFile.new(); cfg.set_value("pad", "swap", pad_swap)
	cfg.set_value("gfx", "quality", quality); cfg.set_value("gfx", "fps", show_fps); cfg.set_value("game", "autosave", autosave_min)
	cfg.set_value("sound", "music", snd.music_vol); cfg.set_value("sound", "sfx", snd.sfx_vol); cfg.save(SETTINGS)

func set_quality(q: float) -> void:
	quality = q; get_viewport().scaling_3d_scale = q; _apply_shadows(); save_settings()

# 선명하게: 내 주변 빛·달빛이 소품 그림자를 드리운다(보통·가볍게는 끔)
func _apply_shadows() -> void:
	var on := quality >= .99
	plight.shadow_enabled = on; plight.shadow_bias = .08; plight.shadow_normal_bias = 1.5; plight.shadow_blur = 1.5
	moon.shadow_enabled = on; moon.shadow_blur = 1.5
	moon.directional_shadow_max_distance = 30.0

# 공기 중에 떠다니는 먼지·반딧불(던전은 따뜻한 먼지, 마을은 연둣빛)
var dust := CPUParticles3D.new()
func _make_dust() -> void:
	var q := QuadMesh.new(); q.size = Vector2(.07, .07)
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; m.albedo_texture = World.glow_tex()
	m.albedo_color = Color(1, .82, .55, .35); m.vertex_color_use_as_albedo = true
	q.material = m; dust.mesh = q
	dust.amount = 70; dust.lifetime = 7.0; dust.preprocess = 7.0; dust.local_coords = false
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; dust.emission_box_extents = Vector3(10, 1.4, 8)
	dust.direction = Vector3(0, 1, 0); dust.spread = 180.0; dust.initial_velocity_min = .05; dust.initial_velocity_max = .25; dust.gravity = Vector3(0, .02, 0)
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 0)); g.add_point(.3, Color(1, 1, 1, 1)); g.add_point(.7, Color(1, 1, 1, 1)); g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	dust.color_ramp = g; dust.scale_amount_min = .6; dust.scale_amount_max = 1.6
	add_child(dust)

# 화면 가장자리를 살짝 어둡게(비네트) — 시선이 가운데로 모이고 화면이 묵직해 보인다
func _make_vignette() -> void:
	var cl := CanvasLayer.new(); cl.layer = 0; add_child(cl)
	var r := ColorRect.new(); r.set_anchors_preset(Control.PRESET_FULL_RECT); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new(); sh.code = """
shader_type canvas_item;
void fragment() {
	vec2 d = UV - .5; d.x *= 1.6;
	float v = smoothstep(.45, 1.05, length(d));
	COLOR = vec4(.01, .005, .02, v * .55);
}
"""
	var sm := ShaderMaterial.new(); sm.shader = sh; r.material = sm; cl.add_child(r)
func pad_mode(on: bool) -> void: hud.set_pad(on)

# ---------------- 시스템 ----------------
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not _back() and what == NOTIFICATION_WM_CLOSE_REQUEST: get_tree().quit()
		elif what == NOTIFICATION_WM_GO_BACK_REQUEST and game.G != null and game.G.state == "title": get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if hud: hud.clear_input()          # 가려진 동안 뗀 손가락이 계속 눌린 걸로 남지 않게
		if game.G != null and game.G.state == "play" and shot_path == "" and not bench: open_pause()
		game.save()

func _back() -> bool:
	if game.G == null: return false
	if game.G.state == "play":
		open_pause(); return true
	return ui.back()

# ---------------- 입력 ----------------
func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch or ev is InputEventScreenDrag:
		hud.handle_input(ev)
	if ev is InputEventKey and ev.pressed and not ev.echo and game.G != null:
		var k: int = ev.keycode
		if k == KEY_ESCAPE or k == KEY_P:
			if game.G.state == "play": open_pause()
			elif ui.cur != "": ui.back()
			return
		if game.G.state != "play": return
		match k:
			KEY_Q: game.swap_active()
			KEY_I, KEY_B: ui.open_bag()
			KEY_E: try_talk()
			KEY_Z: game.use_pot("pothp")
			KEY_X: game.use_pot("potmp")
			KEY_R: game.use_pot("scroll")
			KEY_1, KEY_2, KEY_3:
				var n: int = k - KEY_1
				if n < game.P.secOrder.size(): game.cast_sec(game.P.secOrder[n])

func pad_connected() -> bool: return Input.get_connected_joypads().size() > 0
func pad_name() -> String:
	var j = Input.get_connected_joypads()
	return Input.get_joy_name(j[0]) if j.size() else ""

func _rumble(ms: int, s: float) -> void:
	if not hud.pad_on: return
	for d in Input.get_connected_joypads(): Input.start_joy_vibration(d, s * .6, s, ms / 1000.0)

func _dz(v: Vector2, d: float) -> Vector2:
	var m = v.length()
	if m < d: return Vector2()
	return v / m * min(1.0, (m - d) / (1 - d))

func _pad_state() -> Dictionary:
	var st = {on = false, l = Vector2(), r = Vector2(), b = {}}
	var js = Input.get_connected_joypads()
	if js.is_empty(): return st
	var d: int = js[0]; st.on = true
	st.l = _dz(Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), Input.get_joy_axis(d, JOY_AXIS_LEFT_Y)), .2)
	st.r = _dz(Vector2(Input.get_joy_axis(d, JOY_AXIS_RIGHT_X), Input.get_joy_axis(d, JOY_AXIS_RIGHT_Y)), .25)
	var B = {a = JOY_BUTTON_A, b = JOY_BUTTON_B, x = JOY_BUTTON_X, y = JOY_BUTTON_Y, lb = JOY_BUTTON_LEFT_SHOULDER, rb = JOY_BUTTON_RIGHT_SHOULDER,
		select = JOY_BUTTON_BACK, start = JOY_BUTTON_START, l3 = JOY_BUTTON_LEFT_STICK, r3 = JOY_BUTTON_RIGHT_STICK,
		up = JOY_BUTTON_DPAD_UP, down = JOY_BUTTON_DPAD_DOWN, left = JOY_BUTTON_DPAD_LEFT, right = JOY_BUTTON_DPAD_RIGHT}
	for k in B.keys(): st.b[k] = Input.is_joy_button_pressed(d, B[k])
	st.b.lt = Input.get_joy_axis(d, JOY_AXIS_TRIGGER_LEFT) > .4
	st.b.rt = Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) > .4
	if pad_swap:
		var t = st.b.a; st.b.a = st.b.b; st.b.b = t
		t = st.b.x; st.b.x = st.b.y; st.b.y = t
	return st

func _pad_frame() -> Dictionary:
	var st = _pad_state()
	if st.on != pad_was:
		pad_was = st.on
		hud.show_toast("컨트롤러가 연결됐어요" if st.on else "컨트롤러 연결이 끊겼어요")
		if not st.on and game.G != null and game.G.state == "play": open_pause()
	var hit = func(k: String) -> bool: return st.b.get(k, false) and not pad_prev.get(k, false)
	if st.on:
		var any: bool = st.l.length() > 0 or st.r.length() > 0
		for k in st.b.keys(): any = any or st.b[k]
		if any and not hud.pad_on:
			hud.pad_on = true; pad_mode(true)
	if hud.pad_on and game.G != null:
		if ui.cur != "":
			if hit.call("b") or (hit.call("start") and game.G.state in ["pause", "bag"]): ui.back()
			elif hit.call("select") and game.G.state == "bag": ui.close_bag()
		elif game.G.state == "play":
			if hit.call("start"): open_pause()
			elif hit.call("select"): ui.open_bag()
			elif hit.call("a") and game.G.floor == 0 and game.near_npc() != null: try_talk()
			else:
				var P = game.P
				if hit.call("x") and P.secOrder.size() > 0: game.cast_sec(P.secOrder[0])
				if hit.call("y") and P.secOrder.size() > 1: game.cast_sec(P.secOrder[1])
				if hit.call("b") and P.secOrder.size() > 2: game.cast_sec(P.secOrder[2])
				if hit.call("lb"): game.use_pot("pothp")
				if hit.call("rb"): game.use_pot("potmp")
				if hit.call("lt"): game.swap_active()
				if hit.call("r3"): game.use_pot("scroll")
	pad_prev = st.b.duplicate()
	return st

func _read_input(st: Dictionary) -> void:
	var G = game.G; var P = game.P
	var mx = 0.0; var my = 0.0
	var t = hud.read_touch(P, Vector2())
	mx = t.mx; my = t.my
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mx += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): mx -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): my += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): my -= 1
	var ml = Game.hyp(mx, my)
	if ml > 1:
		mx /= ml; my /= ml
	var firing = false; var ang: float = P.face
	if t.aim:
		firing = true
		if not t.auto: ang = t.ang
		else:
			var e = game.nearest_enemy(P.x, P.y, 420, true, null)
			if e != null: ang = atan2(e.y - P.y, e.x - P.x)
	if Input.is_key_pressed(KEY_SPACE):
		firing = true; var e = game.nearest_enemy(P.x, P.y, 420, true, null)
		if e != null: ang = atan2(e.y - P.y, e.x - P.x)
	if st.on:
		var B: Dictionary = st.b
		var p: Vector2 = st.l + Vector2((1 if B.right else 0) - (1 if B.left else 0), (1 if B.down else 0) - (1 if B.up else 0))
		if p.length() > 1: p = p.normalized()
		if p.length() > 0:
			mx = p.x; my = p.y
		if st.r.length() > .35:
			firing = true; ang = atan2(st.r.y, st.r.x)
			var best = null; var bd = .35
			for e in G.enemies:
				if e.dead: continue
				var d = Game.hyp(e.x - P.x, e.y - P.y)
				if d > 460: continue
				var ad = absf(Game.ang_diff(atan2(e.y - P.y, e.x - P.x), ang))
				if ad < bd and game.mg.los(P.x, P.y, e.x, e.y):
					bd = ad; best = e
			if best != null: ang = atan2(best.y - P.y, best.x - P.x)
		elif B.rt or (B.a and not (G.floor == 0 and game.near_npc() != null)):
			firing = true; var e = game.nearest_enemy(P.x, P.y, 420, true, null)
			if e != null: ang = atan2(e.y - P.y, e.x - P.x)
	game.inp = {mx = mx, my = my, firing = firing, ang = ang}
	if test_inp != null: game.inp = test_inp

# ---------------- 매 프레임 ----------------
# 레벨업 순간 슬로모션 → 멈춤, 고른 뒤에는 부드럽게 원래 속도로
var tscale := 1.0
func slow_resume() -> void: tscale = min(tscale, .15)

func _process(dt: float) -> void:
	dt = min(dt, .05)
	var st = _pad_frame()
	var G = game.G
	if G != null and G.state == "play":
		_read_input(st)
		if G.pendingLv > 0: tscale = move_toward(tscale, .12, dt * 2.2)
		elif tscale < 1.0: tscale = move_toward(tscale, 1.0, dt * 1.35)
		game.update(dt * tscale)
		autosave_t += dt
		if autosave_t >= autosave_min * 60.0:
			autosave_t = 0.0; game.save()
	elif G != null and G.state == "title":
		title_t += dt
	if game.level_changed: _rebuild_level()
	_sound_frame()
	if game.G != null:
		view.sync(dt)
		_place_cam(dt)
	_test_hooks(dt)

func _place_cam(dt: float) -> void:
	var P = game.P; var G = game.G
	var e = deg_to_rad(CAM_ELEV)
	var px: float = P.x / 32.0; var py: float = P.y / 32.0
	if G.state == "title":
		# 타이틀: 마을 위를 천천히 오가며 보여줌
		px += sin(title_t * .12) * 5 + 3; py -= 3 + sin(title_t * .07) * 1.5
	var sx = 0.0; var sy = 0.0
	if G.shake > 0:
		sx = Game.rnd(-3, 3) * G.shake * 6 / 32.0; sy = Game.rnd(-3, 3) * G.shake * 6 / 32.0
	var target = Vector3(px + sx, .4, py + sy)
	var want = target + Vector3(0, sin(e), cos(e)) * CAM_DIST
	var far = cam.position.distance_to(want) > 6
	cam.position = want if (far or dt == 0) else cam.position.lerp(want, 1.0 - exp(-12.0 * dt))
	cam.rotation = Vector3(-e, 0, 0)
	cam.v_offset = .65
	plight.position = Vector3(P.x / 32.0, 1.6, P.y / 32.0 + .6)
	dust.position = Vector3(P.x / 32.0, 1.2, P.y / 32.0)

# ---------------- 시험 ----------------
func _test_setup() -> void:
	hud.touch_ui = true
	if shot_mode == "title": return
	ui.hide_all()
	game.new_game("norm"); game.G.sb = {god = true, mana = true, nocd = false, still = false}
	var P = game.P
	P.prim.fire = 3; P.prim.arcane = 2; P.active = "fire"
	P.sec.ward = 1; P.secOrder.append("ward"); P.sec.nova = 1; P.secOrder.append("nova")
	P.lv = 6; P.next = Game.xp_need(6); game.recalc()
	P.bag.append(game.make_item("rare", 3)); P.bag.append(game.make_item("unique", 5)); P.bag.append(game.make_item("magic", 2))
	if test_floor > 0:
		game.G.resume = test_floor; game.enter_tower()
		var r: Dictionary = game.mg.rooms[0]
		P.x = r.cx; P.y = r.cy
		var n = 0
		for e in game.G.enemies:
			if n < 5 and not e.isBoss:
				e.x = P.x - 120 + n * 60; e.y = P.y - 70 + (n % 2) * 40; n += 1
		game.mg.reveal(P.x, P.y); game.mg.dirty = true
	hud.build_buttons()

func _test_hooks(dt: float) -> void:
	if bench:
		bench_t += dt; bench_n += 1
		if bench_t > 8.0:
			print("BENCH avg_fps=%.1f frames=%d" % [bench_n / bench_t, bench_n]); get_tree().quit()
	if shot_path != "":
		shot_frames += 1
		var G = game.G
		if shot_frames == 5 and G.state == "play" and test_floor > 0:
			# 싸우는 장면: 오른쪽 조준 버튼을 누르고 있는 것처럼
			game.cast_sec("ward")
		if shot_frames > 5 and shot_frames < 60 and G.state == "play" and test_floor > 0:
			test_inp = {mx = .3, my = 0.0, firing = true, ang = 0.0}
			var e = game.nearest_enemy(game.P.x, game.P.y, 420, true, null)
			if e != null: test_inp.ang = atan2(e.y - game.P.y, e.x - game.P.x)
		if shot_frames == 40:
			match shot_mode:
				"levelup":
					G.pendingLv = 1; game.set_state("levelup"); ui.open_level()
				"bag":
					ui.open_bag(); ui.bag_sel = {from = "bag", i = 0}; ui._render_bag()
				"pause": open_pause()
				"talk":
					game.go_town(false)
				"sand": ui.open_sand()
		if shot_frames == 46 and shot_mode == "talk":
			game.P.x = game.G.npcs[1].x; game.P.y = game.G.npcs[1].y + 30; ui.open_talk(game.G.npcs[1])
		if shot_frames == 70:
			var img = get_viewport().get_texture().get_image()
			img.save_png(shot_path); print("SHOT ", shot_path); get_tree().quit()

# ---------------- 한 번 실행으로 주요 화면 여러 장 캡처 ----------------
func _frames(n: int) -> void:
	for i in n: await get_tree().process_frame

func _snap(name: String) -> void:
	await _frames(2)
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [samples_dir, name]); print("SAMPLE ", name)

func _fight(n: int) -> void:
	for i in n:
		var e = game.nearest_enemy(game.P.x, game.P.y, 420, true, null)
		test_inp = {mx = 0.0, my = 0.0, firing = true, ang = atan2(e.y - game.P.y, e.x - game.P.x) if e != null else 0.0}
		await get_tree().process_frame
	test_inp = null

func _run_samples() -> void:
	DirAccess.make_dir_recursive_absolute(samples_dir)
	hud.touch_ui = true
	await _frames(20); await _snap("1_title")
	ui.hide_all(); game.new_game("norm"); game.G.sb = {god = true, mana = true, nocd = true, still = false}
	var P = game.P
	P.prim.fire = 3; P.prim.arcane = 2; P.active = "fire"
	P.sec.ward = 1; P.secOrder.append("ward"); P.sec.nova = 1; P.secOrder.append("nova")
	P.lv = 6; P.next = Game.xp_need(6); game.recalc()
	for r in ["rare", "unique", "set", "magic", "normal"]: P.bag.append(game.make_item(r, 3))
	game.G.gold = 26000; P.stones = 6
	P.eq.amulet = game.make_item("set", 4, "amulet"); P.eq.boots = game.make_item("set", 4, "boots"); P.eq.weapon = game.make_item("unique", 4, "staff"); P.eq.weapon.enh = 3
	P.eq.gloves = game.make_item("rare", 4, "gloves"); game.recalc()
	hud.build_buttons()
	await _frames(10)
	P.x = game.G.npcs[0].x + 40; P.y = game.G.npcs[0].y + 30
	await _frames(12); await _snap("2_town")
	var fo = game.mg.town.fountain
	var kp := Vector2(P.x, P.y); P.x = fo.x; P.y = fo.y + 120; await _frames(8); await _snap("2c_fountain"); P.x = kp.x; P.y = kp.y
	var gx = game.mg.gate
	if gx != null:
		var keep_p := Vector2(P.x, P.y); P.x = gx.x; P.y = gx.y + 170; await _frames(10); await _snap("2b_gate"); P.x = keep_p.x; P.y = keep_p.y
	ui.open_talk(game.G.npcs[1]); await _frames(4); await _snap("3_shop"); ui.close_talk()
	P.x = game.G.npcs[2].x + 30; P.y = game.G.npcs[2].y + 40; await _frames(10); await _snap("3a_smith")
	ui.open_talk(game.G.npcs[2]); ui.enh_sel = ui._enh_items()[0]; ui._render_enhance(); await _frames(4); await _snap("3b_enhance"); ui.close_talk()
	ui.open_slots(false); await _frames(4); await _snap("3c_slots"); ui.hide_all(); game.set_state("play")
	var keep = P.prim.duplicate()
	for k in P.prim.keys(): P.prim[k] = 0
	game.set_state("first"); await _frames(4); await _snap("3d_first"); ui.hide_all(); P.prim = keep; P.active = "fire"; game.set_state("play")
	game.G.resume = 1; game.enter_tower(); await _frames(3)
	var r0: Dictionary = game.mg.rooms[0]; P.x = r0.cx; P.y = r0.cy
	var n := 0
	for e in game.G.enemies:
		if n < 6:
			e.x = P.x - 150 + n * 60; e.y = P.y - 80 + (n % 2) * 50; e.aggro = true; n += 1
	game.mg.reveal(P.x, P.y); game.mg.dirty = true
	await _frames(4); game.cast_sec("ward"); await _fight(26); await _snap("4_fight")
	var el = game.spawn_elite("skel_knight", P.x + 90, P.y - 40); el.aggro = true; await _frames(6); await _snap("4b_elite")
	# 바닥 아이템 모형
	game.G.enemies = []; game.G.drops = []
	var kinds := ["gold", "gold", "pothp", "potmp", "scroll", "stone"]
	for i in kinds.size(): game.G.drops.append({id = game.nid(), x = P.x - 100 + i * 40, y = P.y + 50, kind = kinds[i], v = 10, t = 0.0, noPick = 1})
	var bases := ["staff", "wand", "sceptre", "ring", "amulet", "cloak", "gloves", "belt", "boots"]
	for i in bases.size(): game.G.drops.append({id = game.nid(), x = P.x - 160 + i * 40, y = P.y + 110, kind = "item", it = game.make_item(D.RAR_ORDER[i % 5], 5, bases[i]), t = 0.0, noPick = 1})
	await _frames(8); await _snap("4c_loot"); game.G.drops = []
	game.cast_sec("nova"); await _frames(6); await _snap("5_nova")
	game.levelup_blast(); await _frames(5); await _snap("5b_blast")
	game.G.pendingLv = 1; game.set_state("levelup"); ui.open_level(); await _frames(40); await _snap("6_levelup")
	var g0 = ui.box.get_node_or_null("lvgrid")
	if g0 and g0.get_child_count(): ui._lv_pick(g0.get_child(0).get_meta("opt"))
	await _frames(45); await _snap("6b_pick")
	# 두 번째 레벨업: 실제 터치(마우스 누름·뗌)로 카드를 골라 확인
	if g0 and g0.get_child_count(): ui._lv_confirm(g0.get_child(0).get_meta("opt"))
	await _frames(30)
	game.G.pendingLv = 1; game.set_state("levelup"); ui.open_level(); await _frames(40)
	var g1 = ui.lv_grid
	if g1 and g1.get_child_count() > 1:
		var c1: Control = g1.get_child(1); var cp: Vector2 = c1.get_viewport().get_screen_transform() * c1.get_global_rect().get_center()
		for pr in [true, false]:
			var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = pr; ev.position = cp; ev.global_position = cp
			Input.parse_input_event(ev); await _frames(2)
	await _frames(40); await _snap("6c_second_pick")
	print("LVTEST sel=", ui.lv_sel != null)
	ui.hide_all(); ui.bg.material = null; game.G.pendingLv = 0; game.set_state("play")
	ui.open_bag(); ui.bag_sel = {from = "bag", i = 2}; ui._render_bag(); await _frames(4); await _snap("7_bag"); ui.close_bag()
	ui.open_bag(); ui.bag_sel = {from = "eq", slot = "weapon"}; ui._render_bag(); await _frames(4); await _snap("7a_bag_unique"); ui.close_bag()
	# 포탈: 그 자리에 열고 → 마을 → 마을 포탈로 다시 그 자리
	game.G.enemies = []; game.use_pot("scroll"); await _frames(3); await _snap("8a0_portal_open")
	await _frames(14); await _snap("8a_portal")
	P.x = game.G.portal.x; P.y = game.G.portal.y + 30
	for k in 80:
		if game.G.floor == 0: break
		await _frames(1)
	await _frames(14); await _snap("8b_town_portal")
	P.x = game.G.portal.x; P.y = game.G.portal.y + 30
	for k in 80:
		if game.G.floor > 0: break
		await _frames(1)
	await _frames(3); await _snap("8c_back")
	game.G.killsBy = {skel = 12, zombie = 5, archer = 3}
	ui.open_tab("stats"); await _frames(4); await _snap("7b_stats")
	ui.open_tab("record"); await _frames(4); await _snap("7c_record")
	ui.open_tab("settings"); await _frames(4); await _snap("7d_settings"); ui.close_bag()
	ui.open_map(); await _frames(4); await _snap("7e_map"); ui.close_map()
	# 계단(벽을 판 자리)
	var st = game.mg.stairs
	if st != null:
		P.x = st.x + 20; P.y = st.y + 110; game.G.enemies = []
		for k in 3: game.mg.reveal(P.x, P.y - k * 60)
		game.mg.dirty = true; await _frames(8); await _snap("8_stairs")
		P.x = st.x; P.y = st.y + 40; await _frames(14); await _snap("8d_climb")
		while game.G.pull != null: await _frames(2)
		await _frames(10); await _snap("8e_arrive")
	# 테라스
	for f in range(2, 12):
		game.sand_goto(f); await _frames(2)
		if game.mg.door != null: break
	if game.mg.door != null:
		game.enter_terrace(); await _frames(10); await _snap("9_terrace")
	game.sand_goto(5); await _frames(3)
	P.y -= 120; await _fight(20); await _snap("10_boss")
	open_pause(); await _frames(4); await _snap("11_pause"); resume()
	for f in [25, 45, 65]:
		game.sand_goto(f); game.G.enemies = []; await _frames(3)
		hud.move_id = 0; hud.mo = hud.pad_pos(0) + Vector2(30, -20); hud.mc = hud.mo + Vector2(40, -10)
		await _frames(6); await _snap("12_theme_%d" % f)
	hud.move_id = -1
	get_tree().quit()

# ---------------- 소리: 장면에 맞는 배경음 · 누르는 동안 나는 소리 ----------------
func _sound_frame() -> void:
	var G = game.G
	if G == null: return
	var id := ""
	match G.state:
		"title": id = "title"
		"dead": id = "defeat"
		"win": id = "victory"
		_:
			if G.floor == 0: id = "town"
			elif (game.mg.terrace and G.floor != D.ROOF) or G.floor == D.COW: id = "terrace"
			else:
				var boss := false
				for e in G.enemies:
					if e.isBoss and not e.dead: boss = true
				if boss: id = "final" if G.floor == D.ROOF else "boss"
				else: id = "d%d" % (D.theme(G.floor) + 1)
	snd.music(id)
	var lp := ""
	if G.state == "play" and game.inp.firing and game.P.active != null and G.floor > 0 and game.P.mp > 1:
		var k: String = game.attack_of(game.P.active).kind
		if k == "chain" or k == "beam": lp = "storm"
		elif k == "cone": lp = "frost"
	snd.loop(lp)

# 레벨업 선택 시험(개발용): 레벨업 세 번 연속, 실제 터치로 카드 고르고 "선택"
func _tap(c: Control) -> void:
	var cp: Vector2 = c.get_viewport().get_screen_transform() * c.get_global_rect().get_center()
	for pr in [true, false]:
		var ev := InputEventMouseButton.new(); ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = pr; ev.position = cp; ev.global_position = cp
		Input.parse_input_event(ev); await _frames(2)

func _run_lvtest() -> void:
	await _frames(10)
	ui.hide_all(); game.new_game("norm"); game.G.sb = {god = true, mana = true, nocd = true, still = true}
	game.P.prim.arcane = 1; game.P.active = "arcane"; game.G.resume = 1; game.enter_tower(); hud.build_buttons(); await _frames(5)
	for round in 3:
		game.gain_xp((game.P.next - game.P.xp) / game.diff_d().reward + 1)
		for k in 200:
			if ui.cur == "level": break
			await _frames(1)
		await _frames(30)
		await _tap(ui.lv_grid.get_child(round % 3))
		for k in 100:
			if ui.box.get_node_or_null("lvconfirm") != null: break
			await _frames(1)
		var bar = ui.box.get_node_or_null("lvconfirm")
		print("LVTEST round ", round, " picked=", ui.lv_sel != null, " confirm=", bar != null)
		if bar == null: break
		var yes: Control = bar.get_child(1).get_child(0)
		await _tap(yes)
		for k in 100:
			if game.G.state == "play": break
			await _frames(1)
		print("LVTEST round ", round, " state=", game.G.state, " pending=", game.G.pendingLv)
		await _frames(20)
	get_tree().quit()

# 마법 효과·판매 창 빠른 확인(개발용): --samples=DIR --fxtest
func _run_fxtest() -> void:
	DirAccess.make_dir_recursive_absolute(samples_dir)
	hud.touch_ui = true
	await _frames(10)
	ui.hide_all(); game.new_game("norm"); game.G.sb = {god = true, mana = true, nocd = true, still = true}
	var P = game.P
	P.prim.fire = 3; P.prim.arcane = 2; P.prim.storm = 3; P.prim.frost = 3; P.active = "fire"; P.lv = 6; game.recalc()
	for r in ["rare", "unique", "set", "magic", "normal"]: P.bag.append(game.make_item(r, 3))
	game.G.resume = 1; game.enter_tower(); hud.build_buttons(); await _frames(3)
	var r0: Dictionary = game.mg.rooms[0]; P.x = r0.cx; P.y = r0.cy
	var n := 0
	for e in game.G.enemies:
		if n < 5:
			e.x = P.x + 260 + (n % 2) * 30; e.y = P.y - 60 + n * 30; n += 1
		else: e.x = -9999.0; e.y = -9999.0
	game.mg.reveal(P.x, P.y); game.mg.dirty = true; await _frames(6)
	test_inp = {mx = 0.0, my = 0.0, firing = true, ang = 0.0}
	await _frames(7); await _snap("f1_fireball")
	test_inp = null
	game.fire_explode(P.x + 90, P.y + 10); game.sfx.emit("boom"); await _frames(1); await _snap("f2_explode")
	await _frames(10); await _snap("f3_explode_late")
	P.active = "frost"; test_inp = {mx = 0.0, my = .8, firing = true, ang = 0.0}
	await _frames(24); await _snap("f4_frost_move")
	test_inp = {mx = 0.0, my = 0.0, firing = true, ang = -.5}; await _frames(14); await _snap("f4b_frost_turn")
	P.active = "storm"; test_inp = {mx = 0.0, my = 0.0, firing = true, ang = 0.0}
	await _frames(12); await _snap("f5_storm")
	test_inp = null; await _frames(4)
	P.sec.ward = 1; P.secOrder.append("ward"); game.cast_sec("ward"); await _frames(20); await _snap("f9_ward")
	if game.mg.door == null: game.mg.door = {x = P.x, y = P.y, found = true, alcove = false, kind = "door"}
	game.enter_terrace(); await _frames(4)
	if game.mg.door != null:
		P.x = game.mg.door.x; P.y = game.mg.door.y + 150
	await _frames(14); await _snap("f10_terrace")
	game.go_town(false); await _frames(6)
	ui.open_bag(true); await _frames(4); await _snap("f6_sell")
	ui.bag_sel = {from = "bag", i = 1}; ui._render_bag(); await _frames(4); await _snap("f7_sell_sel")
	ui._sell_ask(1); await _frames(16); await _snap("f8_sell_ask")
	print("FXTEST done"); get_tree().quit()

# 단계·괴생물 퀘스트·토끼 동산 확인(개발용): --samples=DIR --tiertest
func _run_tiertest() -> void:
	DirAccess.make_dir_recursive_absolute(samples_dir)
	hud.touch_ui = true
	await _frames(10)
	new_game("norm", 4); await _frames(5)
	var P = game.P; var G = game.G
	P.prim.fire = 5; P.prim.frost = 4; P.active = "fire"; P.lv = 40; P.next = Game.xp_need(40); game.recalc(); hud.build_buttons()
	G.talkSeen.guide = 1
	# 옥상 보스 처치 → 나이트메어 열림
	G.resume = 100; game.enter_tower(100); await _frames(6)
	for e in G.enemies:
		if e.isBoss: game.kill_enemy(e)
	await _frames(200); await _snap("t1_win")
	print("TIER after win: tier=", G.tier, " max=", G.tierMax, " state=", G.state)
	game.switch_tier(1); ui.hide_all(); hud.build_buttons(); await _frames(8); await _snap("t2_nm_town")
	game.enter_tower(1); await _frames(6)
	var hp0 := 0.0
	for e in G.enemies:
		hp0 = max(hp0, e.max)
	print("NM f1 enemies=", G.enemies.size(), " maxhp=", hp0, " lvf=", game.lvf())
	await _snap("t3_nm_f1")
	game.go_town(false); await _frames(4)
	ui.open_talk(G.npcs[0]); await _frames(4); await _snap("t4_quest")
	game.cow_talk_done("cow_q"); ui.close_talk(); print("cowQ=", G.cowQ, " cowF=", G.cowF)
	game.set_state("gate"); ui.open_gate(); await _frames(30); await _snap("t5_gate_glow"); ui.hide_all(); game.set_state("play")
	G.sb = {god = true, mana = true, nocd = true, still = false}
	game.enter_tower(G.cowF); await _frames(6)
	var rb = null
	for e in G.enemies:
		if e.get("cowq", false): rb = e
	print("quest rabbit: ", rb != null, " hp=", rb.max if rb else 0)
	if rb:
		P.x = rb.x; P.y = rb.y + 150; game.mg.reveal(P.x, P.y); game.mg.dirty = true; rb.aggro = true
		await _frames(30); await _snap("t6_rabbit_boss")
		game.kill_enemy(rb); await _frames(20); await _snap("t7_portal")
	G.sb = null
	game.go_town(false); await _frames(4)
	ui.open_talk(G.npcs[0]); await _frames(4); await _snap("t8_quest2")
	game.cow_talk_done("cow_open"); ui.close_talk(); await _frames(4)
	P.x = G.redPortal.x + 60; P.y = G.redPortal.y + 70; await _frames(20); await _snap("t9_red_portal")
	G.sb = {god = true, mana = true, nocd = true, still = false}
	game.enter_cow(); await _frames(10); await _snap("t10_cow_start")
	print("cow enemies=", G.enemies.size(), " herds=", G.herds.size())
	var h0 = G.herds[0]; P.x = h0.x + 220; P.y = h0.y + 120; await _frames(40); await _snap("t11_herd")
	var king = null
	for e in G.enemies:
		if e.type == "rabbit_king": king = e
	if king:
		P.x = king.x; P.y = king.y + 200; await _frames(30); await _snap("t12_king")
	P.active = "frost"; test_inp = {mx = 0.0, my = 0.0, firing = true, ang = -1.2}; await _frames(20); await _snap("t13_frost"); test_inp = null
	G.sb = null; game.save(); await _frames(2)
	to_title(false); await _frames(4)
	continue_game(4); await _frames(6); await _snap("t14_tierpick")
	continue_game(4, 0); await _frames(10); await _snap("t15_normal_town")
	print("after load normal: tier=", G.tier if game.G else -1, " floor=", game.G.floor, " resume=", game.G.resume, " cowQ=", game.G.cowQ)
	print("TIERTEST done"); get_tree().quit()

# 방 꾸미기 확인(개발용): --samples=DIR --roomtest
func _run_roomtest() -> void:
	DirAccess.make_dir_recursive_absolute(samples_dir)
	await _frames(10)
	new_game("norm", 4); await _frames(4)
	var P = game.P; var G = game.G
	P.prim.arcane = 2; P.active = "arcane"; G.sb = {god = true, mana = true, nocd = true, still = true}
	var seen := {}
	for f in [3, 7, 12, 16, 23, 27, 33, 38, 44, 48, 52, 57]:
		G.resume = f; game.enter_tower(f); await _frames(3)
		G.enemies = []
		for r in game.mg.rooms:
			var th: String = r.get("theme", "plain")
			if th == "plain" and seen.has("plain"): continue
			if seen.get(th, 0) >= 2: continue
			seen[th] = seen.get(th, 0) + 1
			P.x = r.cx; P.y = r.cy + 30; game.mg.reveal(P.x, P.y); game.mg.dirty = true
			for rr in game.mg.rooms:
				if Game.hyp(rr.cx - P.x, rr.cy - P.y) < 400: game.mg.reveal(rr.cx, rr.cy)
			await _frames(8); await _snap("r_%s_%d_f%d" % [th, seen[th], f])
		if seen.size() >= 7 and seen.values().min() >= 2: break
	print("ROOMTEST done ", seen); get_tree().quit()

# 테라스 확인(개발용): --samples=DIR --terrtest
func _run_terrtest() -> void:
	DirAccess.make_dir_recursive_absolute(samples_dir)
	await _frames(10)
	new_game("norm", 4); await _frames(4)
	var P = game.P; var G = game.G
	P.prim.arcane = 2; P.active = "arcane"; G.sb = {god = true, mana = true, nocd = true, still = false}
	# 던전 쪽 문(동·서·남쪽) 찾기
	var found := 0
	for f in range(2, 40):
		G.resume = f; game.enter_tower(f); await _frames(2)
		var d = game.mg.door
		if d != null and d.get("side", "") != "" and found < 2:
			found += 1; G.enemies = []
			P.x = d.x - d.dx * 70; P.y = d.y - d.dy * 70; game.mg.reveal(P.x, P.y); game.mg.dirty = true
			await _frames(8); await _snap("t_door_%s_f%d" % [d.side, f])
		if found >= 2: break
	var evs := ["survive", "corpse", "named", "empty", "fight", "quiet"]
	var dirs := ["n", "e", "s", "w", "e", "s"]
	for i in evs.size():
		G.resume = 5; game.enter_tower(5); await _frames(2)
		var dd: Dictionary = game.mg.door if game.mg.door != null else {}
		game.mg.door = {x = P.x, y = P.y, dir = dirs[i], dx = 0.0, dy = -1.0, kind = "door"}
		game.enter_terrace(evs[i]); await _frames(4)
		var r: Dictionary = game.mg.rooms[0]
		if evs[i] == "survive":
			await _frames(200)
		else: await _frames(20)
		await _snap("t_ter_%s_%s" % [dirs[i], evs[i]])
		print("TERR ", dirs[i], " ", evs[i], " shape=", r.get("shape", ""), " size=", r.w, "x", r.h, " door=", game.mg.door.get("side", "n"))
		game.leave_terrace(); await _frames(2)
	print("TERRTEST done"); get_tree().quit()
