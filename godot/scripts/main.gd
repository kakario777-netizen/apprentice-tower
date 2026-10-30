# 1단계: 마을 → 탑 1~15층을 걸어 다니는 뼈대(전투는 2단계부터)
extends Node3D

const CAM_ELEV := 40.0     # 카메라가 바닥을 내려다보는 각도(웹 버전 CTH=50° 와 같은 기울기)
const CAM_DIST := 16.25    # 웹 버전 RC=520px
const CAM_FOV := 37.0
const SPEED := 138.0 / 32.0
const PR := 11.0 / 32.0

var mg := MapGen.new()
var world: World
var cam := Camera3D.new()
var env := WorldEnvironment.new()
var moon := DirectionalLight3D.new()
var player: Actor
var plight: OmniLight3D
var npcs: Array = []
var ppos := Vector2()
var pvel := Vector2()
var floor_no := 0
var hud: Hud
var banner_t := 0.0
var leaving := false

# 시험용(스크린샷·성능 측정)
var shot_path := ""
var shot_frames := 0
var bench := false
var bench_t := 0.0
var bench_n := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): shot_path = a.substr(7)
		elif a.begins_with("--floor="): floor_no = int(a.substr(8))
		elif a == "--bench": bench = true
		elif a.begins_with("--seed="): mg.rng.seed = int(a.substr(7))
	world = World.new(); add_child(world)
	cam.fov = CAM_FOV; cam.near = .5; cam.far = 80.0
	add_child(cam)
	env.environment = Environment.new()
	add_child(env)
	moon.rotation_degrees = Vector3(-55, 30, 0)
	moon.shadow_enabled = false
	add_child(moon)
	player = Actor.new(); add_child(player); player.setup("player", 46)
	plight = OmniLight3D.new(); plight.omni_range = 10.0; plight.light_energy = 1.1; plight.light_color = Color(1, .92, .85)
	add_child(plight)
	hud = Hud.new(); add_child(hud)
	if floor_no > 0: _enter_floor(floor_no)
	else: _go_town()

func _setup_env(town: bool) -> void:
	var e: Environment = env.environment
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(.02, .016, .03)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = .6; e.glow_bloom = .05; e.glow_hdr_threshold = 1.1
	if town:
		e.ambient_light_color = Color(.42, .44, .58); e.ambient_light_energy = 1.0
		moon.visible = true; moon.light_color = Color(.62, .68, .95); moon.light_energy = .55
		plight.visible = false
	else:
		e.ambient_light_color = Color(.46, .41, .56); e.ambient_light_energy = 1.0
		moon.visible = false
		plight.visible = true

func _clear_npcs() -> void:
	for n in npcs: n.queue_free()
	npcs.clear()

func _go_town() -> void:
	floor_no = 0
	mg.gen_town(); world.build(mg); _setup_env(true)
	ppos = mg.start; pvel = Vector2.ZERO
	_clear_npcs()
	var t = mg.town
	for d in [["guide", Vector2(t.x0 + 11, t.y0 + t.h - 5)], ["shop", Vector2(t.x0 + 26, t.y0 + 6)]]:
		var a := Actor.new(); add_child(a); a.setup(d[0], 46); a.face = PI / 2
		a.position = Vector3(d[1].x, 0, d[1].y); npcs.append(a)
		mg.obst.append({pos = d[1], r = 12 / 32.0})
	hud.banner("마법학교 앞마당"); _place(0)

func _enter_floor(n: int) -> void:
	floor_no = n
	mg.gen_floor(n); world.build(mg); _setup_env(false)
	_clear_npcs()
	ppos = mg.start; pvel = Vector2.ZERO
	hud.banner("%d층" % n); _place(0)

# ---------------- 입력 ----------------
func _move_input() -> Vector2:
	var v := Vector2()
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1
	for dev in Input.get_connected_joypads():
		var s := Vector2(Input.get_joy_axis(dev, JOY_AXIS_LEFT_X), Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y))
		if s.length() > .2: v += s
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_RIGHT): v.x += 1
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_LEFT): v.x -= 1
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_DOWN): v.y += 1
		if Input.is_joy_button_pressed(dev, JOY_BUTTON_DPAD_UP): v.y -= 1
	v += hud.stick
	if v.length() > 1: v = v.normalized()
	return v

# ---------------- 매 프레임 ----------------
func _process(dt: float) -> void:
	dt = min(dt, 1.0 / 20.0)
	var inp := _move_input()
	var kp := 1.0 - exp(-7.0 * dt)
	pvel += (inp * SPEED - pvel) * kp
	ppos = mg.move(ppos, pvel * dt, PR)
	if inp.length() > .2: player.face = atan2(inp.y, inp.x)
	player.set_anim("run" if pvel.length() > 22.0 / 32.0 else "stance")
	player.tick(dt)
	for n in npcs: n.tick(dt)
	_place(dt)
	# 층 이동
	if not leaving:
		if floor_no == 0 and mg.gate != null and ppos.distance_to(mg.gate + Vector2(0, .3)) < 1.0:
			_transition(_first_floor)
		elif floor_no > 0 and mg.stairs != null and ppos.distance_to(mg.stairs) < .8:
			_transition(_next_floor)
	hud.set_info("마을" if floor_no == 0 else "%d층" % floor_no, Engine.get_frames_per_second())
	_test_hooks(dt)

func _first_floor() -> void:
	_enter_floor(1)

func _next_floor() -> void:
	if floor_no >= 15: _go_town()
	else: _enter_floor(floor_no + 1)

func _transition(f: Callable) -> void:
	leaving = true
	await hud.fade(1.0, .25)
	f.call()
	await hud.fade(0.0, .3)
	leaving = false

func _place(dt: float) -> void:
	player.position = Vector3(ppos.x, 0, ppos.y)
	plight.position = Vector3(ppos.x, 1.6, ppos.y + .6)
	var e := deg_to_rad(CAM_ELEV)
	var target := Vector3(ppos.x, .4, ppos.y)
	var want := target + Vector3(0, sin(e), cos(e)) * CAM_DIST
	cam.position = want if dt == 0 else cam.position.lerp(want, 1.0 - exp(-12.0 * dt))
	cam.rotation = Vector3(-e, 0, 0)
	cam.v_offset = .65

func _test_hooks(dt: float) -> void:
	if bench:
		# 자동으로 방 사이를 걸으며 프레임 시간 기록
		bench_t += dt; bench_n += 1
		if bench_t > 8.0:
			print("BENCH avg_fps=%.1f frames=%d" % [bench_n / bench_t, bench_n]); get_tree().quit()
	if shot_path != "":
		shot_frames += 1
		if shot_frames == 3:
			# 시험 장면: 플레이어를 오른쪽 아래로 조금 걷게
			hud.stick = Vector2(.6, .2)
		if shot_frames == 50:
			var img := get_viewport().get_texture().get_image()
			img.save_png(shot_path); print("SHOT ", shot_path); get_tree().quit()
