# 소리: 배경음(장면마다 바뀌고 부드럽게 넘어감) + 효과음(동시에 여러 개)
# 모든 소리는 OpenGameArt 의 CC0(자유 이용) 작품 — sound/CREDITS.txt
class_name Snd
extends Node

var music_vol := 0.7      # 0~1 (설정에서 바꿈)
var sfx_vol := 0.9
var cur_music := ""
var mA := AudioStreamPlayer.new()
var mB := AudioStreamPlayer.new()
var front: AudioStreamPlayer
var pool: Array = []
var last := {}            # 같은 소리가 너무 겹치지 않게
var loop_p := AudioStreamPlayer.new()
var loop_name := ""
var cache := {}

func _ready() -> void:
	for p in [mA, mB, loop_p]: add_child(p)
	mA.volume_db = -80; mB.volume_db = -80; front = mA
	for i in 14:
		var p = AudioStreamPlayer.new(); add_child(p); pool.append(p)

func _stream(path: String, loop := false) -> AudioStream:
	var key := path + ("|L" if loop else "")
	if cache.has(key): return cache[key]
	if not ResourceLoader.exists(path): return null
	var s = load(path)
	if s is AudioStreamOggVorbis:
		s = s.duplicate(); s.loop = loop
	cache[key] = s
	return s

static func db(v: float) -> float: return linear_to_db(max(v, .0001))

# ---------------- 배경음 ----------------
func music(id: String) -> void:
	if id == cur_music: return
	cur_music = id
	var back: AudioStreamPlayer = mB if front == mA else mA
	var s := _stream("res://sound/bgm/%s.ogg" % id, not (id in ["defeat", "victory"]))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(front, "volume_db", -60.0, 1.2)
	if s != null:
		back.stream = s; back.volume_db = -60.0; back.play()
		tw.tween_property(back, "volume_db", db(music_vol * .8), 1.4)
	front = back

func set_music_vol(v: float) -> void:
	music_vol = v
	if front.playing: front.volume_db = db(music_vol * .8)

# ---------------- 효과음 ----------------
const GAIN := {hit = .5, coin = .55, coin2 = .55, click = .6, step = .4, hurt = .6, die = .7, arrow = .6, eorb = .55, pickup = .7, item = .8, boom = .8, arcane = .55, fire = .7}
func play(name: String, vol := 1.0, pitch_var := .08) -> void:
	if sfx_vol <= .01: return
	var now := Time.get_ticks_msec()
	if last.get(name, -1000) > now - 45: return
	last[name] = now
	var s := _stream("res://sound/sfx/%s.ogg" % name)
	if s == null: return
	var p: AudioStreamPlayer = null
	for q in pool:
		if not q.playing:
			p = q; break
	if p == null: p = pool[randi() % pool.size()]
	p.stream = s; p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = db(sfx_vol * vol * GAIN.get(name, 1.0)); p.play()

# 누르고 있는 동안 계속 나는 소리(번개·냉기 숨결)
func loop(name: String) -> void:
	if name == loop_name: return
	loop_name = name
	if name == "":
		var tw := create_tween(); tw.tween_property(loop_p, "volume_db", -60.0, .15); tw.tween_callback(_loop_off); return
	loop_p.stream = _stream("res://sound/sfx/%s.ogg" % name, true)
	loop_p.volume_db = db(sfx_vol * .5); loop_p.play()

func _loop_off() -> void:
	if loop_name == "": loop_p.stop()
