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

func _ready() -> void:
	Ui.init_fonts()
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		pad_swap = cfg.get_value("pad", "swap", false)
		quality = cfg.get_value("gfx", "quality", 1.0); show_fps = cfg.get_value("gfx", "fps", false)
	get_viewport().scaling_3d_scale = quality
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): shot_path = a.substr(7)
		elif a.begins_with("--floor="): test_floor = int(a.substr(8))
		elif a.begins_with("--mode="): shot_mode = a.substr(7)
		elif a == "--bench": bench = true
		elif a.begins_with("--samples="): samples_dir = a.substr(10)
		elif a.begins_with("--seed="): seed(int(a.substr(7)))
	add_child(game)
	World.set_fog(PackedByteArray())
	world = World.new(); add_child(world)
	view = View.new(); view.game = game; view.world = world; add_child(view)
	cam.fov = CAM_FOV; cam.near = .5; cam.far = 90.0; add_child(cam)
	env.environment = Environment.new(); add_child(env)
	moon.rotation_degrees = Vector3(-55, 30, 0); add_child(moon)
	plight = OmniLight3D.new(); plight.omni_range = 10.0; plight.light_energy = 1.1; plight.light_color = Color(1, .92, .85); add_child(plight)
	hud = Hud.new(); hud.main = self; hud.game = game; hud.cam = cam; add_child(hud)
	ui = Ui.new(); ui.main = self; ui.game = game; add_child(ui)
	game.toast.connect(hud.show_toast)
	game.ui.connect(_on_ui)
	game.rumble.connect(_rumble)
	# 타이틀: 마을 장면을 배경으로
	_title_scene()
	ui.open_title()
	if test_floor > 0 or shot_mode != "": _test_setup()
	if samples_dir != "": _run_samples()

func _setup_env(town: bool) -> void:
	var mg := game.mg
	var e: Environment = env.environment
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(.02, .016, .03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true; e.glow_intensity = .6; e.glow_bloom = .05; e.glow_hdr_threshold = 1.1
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
	World.TINT = th.tint if game.G.floor > 0 and not game.mg.terrace else Color.WHITE
	World.TORCH = th.torch if game.G.floor > 0 else Color(1, .6, .3)
	World.FLOOR_TEX = th.floor
	world.build(game.mg); view.rebuild()
	_setup_env(game.mg.town != null)
	game.mg.dirty = true
	cam.position = Vector3()   # 다음 프레임에 바로 따라붙도록

# ---------------- 메뉴에서 부르는 것 ----------------
func new_game(diff: String) -> void:
	ui.hide_all(); game.new_game(diff); hud.build_buttons()
func continue_game() -> void:
	var sv = Game.read_save()
	if sv != null:
		ui.hide_all(); game.load_game(sv); hud.build_buttons()
func sand_start() -> void:
	ui.hide_all(); game.sand_start(); hud.build_buttons(); ui.open_sand()
func open_pause() -> void:
	if game.G == null or game.G.state != "play": return
	game.set_state("pause"); ui.open_pause()
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
	cfg.set_value("gfx", "quality", quality); cfg.set_value("gfx", "fps", show_fps); cfg.save(SETTINGS)

func set_quality(q: float) -> void:
	quality = q; get_viewport().scaling_3d_scale = q; save_settings()
func pad_mode(on: bool) -> void: hud.set_pad(on)

# ---------------- 시스템 ----------------
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not _back() and what == NOTIFICATION_WM_CLOSE_REQUEST: get_tree().quit()
		elif what == NOTIFICATION_WM_GO_BACK_REQUEST and game.G != null and game.G.state == "title": get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
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
func _process(dt: float) -> void:
	dt = min(dt, .05)
	var st = _pad_frame()
	var G = game.G
	if G != null and G.state == "play":
		_read_input(st)
		game.update(dt)
	elif G != null and G.state == "title":
		title_t += dt
	if game.level_changed: _rebuild_level()
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
	P.bag.append(game.make_item("rare", 3)); P.bag.append(game.make_item("epic", 5)); P.bag.append(game.make_item("magic", 2))
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
	for r in ["rare", "epic", "magic", "rare", "magic"]: P.bag.append(game.make_item(r, 3))
	game.G.gold = 2600; P.eq.amulet = game.make_item("rare", 4, "amulet"); P.eq.boots = game.make_item("magic", 4, "boots"); P.eq.weapon = game.make_item("epic", 4, "staff")
	hud.build_buttons()
	await _frames(10)
	P.x = game.G.npcs[0].x + 40; P.y = game.G.npcs[0].y + 30
	await _frames(12); await _snap("2_town")
	ui.open_talk(game.G.npcs[1]); await _frames(4); await _snap("3_shop"); ui.close_talk()
	game.G.resume = 1; game.enter_tower(); await _frames(3)
	var r0: Dictionary = game.mg.rooms[0]; P.x = r0.cx; P.y = r0.cy
	var n := 0
	for e in game.G.enemies:
		if n < 6:
			e.x = P.x - 150 + n * 60; e.y = P.y - 80 + (n % 2) * 50; e.aggro = true; n += 1
	game.mg.reveal(P.x, P.y); game.mg.dirty = true
	await _frames(4); game.cast_sec("ward"); await _fight(26); await _snap("4_fight")
	game.cast_sec("nova"); await _frames(6); await _snap("5_nova")
	game.G.pendingLv = 1; game.set_state("levelup"); ui.open_level(); await _frames(4); await _snap("6_levelup"); ui.hide_all(); game.G.pendingLv = 0; game.set_state("play")
	ui.open_bag(); ui.bag_sel = {from = "bag", i = 0}; ui._render_bag(); await _frames(4); await _snap("7_bag"); ui.close_bag()
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
