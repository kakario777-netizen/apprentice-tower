# 게임 화면 위 UI — 웹 drawHud + #hudbtns/#belt/#bagbtn/#pausebtn/#talkBtn/#toast
# 화면 크기는 웹의 CSS 픽셀과 같게(가로 832 × 세로 384 기준) 맞춰 수치를 그대로 쓴다.
class_name Hud
extends CanvasLayer

const STICKR := 54.0

var main            # main.gd
var game: Game
var cam: Camera3D
var draw := HudDraw.new()
var mini := TextureRect.new()
var mini_img: Image
var mini_tex: ImageTexture
var toast_l := Label.new()
var toast_t := 0.0
var fader := ColorRect.new()

# 버튼(터치를 직접 나눠 주므로 그림 역할만)
var pause_b := Control.new()
var bag_b := TextureRect.new()
var bag_dot := ColorRect.new()
var belt := VBoxContainer.new()
var skills := VBoxContainer.new()
var talk_b := Button.new()
var hot: Array = []      # [Control, Callable]

# 터치 스틱
var move_id := -1
var aim_id := -1
var mo := Vector2(); var mc := Vector2(); var ao := Vector2(); var ac := Vector2()
var mouse_aim = null
var mouse_down := false
var touch_ui := true
var pad_on := false

func _ready() -> void:
	layer = 1
	var root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	draw.hud = self; draw.set_anchors_preset(Control.PRESET_FULL_RECT); draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(draw)
	mini.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; mini.stretch_mode = TextureRect.STRETCH_SCALE; mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini.modulate.a = .85
	root.add_child(mini)
	mini_img = Image.create(MapGen.MW, MapGen.MH, false, Image.FORMAT_RGBA8); mini_tex = ImageTexture.create_from_image(mini_img); mini.texture = mini_tex
	# 일시정지 버튼(두 줄)
	pause_b.custom_minimum_size = Vector2(34, 34); pause_b.size = Vector2(34, 34); pause_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_b.draw.connect(func():
		var c = Color("#e8e4f0"); var o = Vector2(9, 9)
		pause_b.draw_rect(Rect2(o + Vector2(1, 1), Vector2(5, 16)), Color(0, 0, 0, .6)); pause_b.draw_rect(Rect2(o + Vector2(12, 1), Vector2(5, 16)), Color(0, 0, 0, .6))
		pause_b.draw_rect(Rect2(o, Vector2(5, 16)), c); pause_b.draw_rect(Rect2(o + Vector2(11, 0), Vector2(5, 16)), c))
	root.add_child(pause_b)
	bag_b.texture = load("res://ui/bag.png"); bag_b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; bag_b.size = Vector2(38, 38); bag_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bag_b)
	bag_dot.color = Color("#ff6a5a"); bag_dot.size = Vector2(10, 10); bag_dot.position = Vector2(29, 1); bag_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag_b.add_child(bag_dot)
	belt.add_theme_constant_override("separation", 2); belt.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(belt)
	skills.add_theme_constant_override("separation", 6); skills.alignment = BoxContainer.ALIGNMENT_BEGIN; skills.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(skills)
	talk_b.add_theme_stylebox_override("normal", Ui.sb(Color("#e8b552"), 28, Color("#4a2e0c"), 2, Vector4(18, 8, 18, 8))); talk_b.add_theme_color_override("font_color", Color("#1b1206"))
	talk_b.add_theme_font_size_override("font_size", 17); talk_b.add_theme_font_override("font", Ui.bold); talk_b.mouse_filter = Control.MOUSE_FILTER_IGNORE; talk_b.visible = false
	root.add_child(talk_b)
	toast_l.add_theme_stylebox_override("normal", Ui.sb(Color(.086, .07, .125, .9), 14, Color("#33293f"), 1, Vector4(14, 6, 14, 6)))
	toast_l.add_theme_font_size_override("font_size", 13); toast_l.modulate.a = 0; toast_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_l)
	fader.color = Color(0, 0, 0, 1); fader.set_anchors_preset(Control.PRESET_FULL_RECT); fader.mouse_filter = Control.MOUSE_FILTER_IGNORE; fader.modulate.a = 0
	root.add_child(fader)
	touch_ui = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

func inset() -> Dictionary:
	var vs = get_viewport().get_visible_rect().size
	var sa = DisplayServer.get_display_safe_area(); var ss = DisplayServer.screen_get_size()
	if ss.x <= 0 or OS.get_name() != "Android": return {t = 0.0, r = 0.0, b = 0.0, l = 0.0}
	var k = vs.x / ss.x
	return {t = sa.position.y * k, l = sa.position.x * k, r = (ss.x - sa.end.x) * k, b = (ss.y - sa.end.y) * k}

func show_toast(msg: String) -> void:
	toast_l.text = msg; toast_t = 1.4

func playing() -> bool: return game.G != null and game.G.state == "play"

func _process(dt: float) -> void:
	var vs = get_viewport().get_visible_rect().size; var ins = inset()
	toast_t -= dt
	if game.G != null and game.G.get("pull") != null: fader.modulate.a = clamp(game.G.pull.t / .9, 0, 1)
	else: fader.modulate.a = move_toward(fader.modulate.a, 0.0, dt * 2.4)
	toast_l.modulate.a = clamp(toast_t * 4, 0, 1) if toast_t < .25 else min(1.0, toast_l.modulate.a + dt * 4)
	toast_l.reset_size(); toast_l.position = Vector2((vs.x - toast_l.size.x) / 2, vs.y - ins.b - 28 - toast_l.size.y)
	var on = playing()
	for c in [pause_b, bag_b, belt, skills]: c.visible = on
	if not on: talk_b.visible = false
	pause_b.position = Vector2(ins.l + 14, ins.t + 10)
	bag_b.position = Vector2(ins.l + 54, ins.t + 6)
	belt.position = Vector2(ins.l + 8, ins.t + 54)
	skills.reset_size(); skills.position = Vector2(vs.x - ins.r - 16 - skills.size.x, ins.t + 112)
	if on:
		bag_dot.visible = game.G.bagNew
		var n = game.near_npc() if game.G.floor == 0 else null
		talk_b.visible = n != null
		if n != null:
			talk_b.text = "%s%s · %s" % ["A  " if pad_on else "", "거래하기" if n.id == "shop" else "말 걸기", n.name]
			talk_b.custom_minimum_size = Vector2(150, 56); talk_b.reset_size()
			var rc := pad_pos(1)
			talk_b.position = Vector2(min(vs.x - ins.r - 12 - talk_b.size.x, rc.x - talk_b.size.x / 2), rc.y - STICKR - 22 - talk_b.size.y)
		_upd_cooldowns()
	var mw: float = min(120.0, vs.x * .15)
	mini.visible = on or (game.G != null and game.G.state in ["pause", "levelup"])
	mini.position = Vector2(vs.x - ins.r - 12 - mw, ins.t + 10); mini.size = Vector2(mw, mw * MapGen.MH / MapGen.MW)
	if game.G != null and game.mg.dirty: _upd_minimap()
	draw.queue_redraw()

func _upd_minimap() -> void:
	var mg = game.mg
	for k in MapGen.MW * MapGen.MH:
		var c = Color(0, 0, 0, 0)
		if mg.seen[k]: c = Color8(78, 66, 96, 235) if mg.map[k] == 0 else Color8(30, 24, 38, 235)
		mini_img.set_pixel(k % MapGen.MW, k / MapGen.MW, c)
	mini_tex.update(mini_img)
	World.set_fog(mg.fog_bytes())
	main.world.update_fog()
	mg.dirty = false

# ---------------- 버튼 만들기 ----------------
func build_buttons() -> void:
	for c in skills.get_children(): c.queue_free()
	hot = hot.filter(func(h): return h[0].get_parent() != skills)
	if game.P == null: return
	var P = game.P
	if game.active_list().size() > 1:
		var b = Label.new(); b.text = game.act_name()
		b.add_theme_font_size_override("font_size", 11); b.add_theme_color_override("font_color", Color("#e8dcc6"))
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0)); b.add_theme_constant_override("outline_size", 4)
		b.add_theme_stylebox_override("normal", Ui.sb(Color(0, 0, 0, 0), 15, Color(game.act_color()), 2, Vector4(8, 6, 8, 6)))
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skills.add_child(b); hot.append([b, func(): game.swap_active()])
		_hint(b, "LT")
	for si in P.secOrder.size():
		var id: String = P.secOrder[si]
		var b = TextureRect.new(); b.texture = load("res://ui/sec_%s_p.png" % id); b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b.custom_minimum_size = Vector2(50, 50); b.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.set_meta("sec", id)
		var cd = Control.new(); cd.set_anchors_preset(Control.PRESET_FULL_RECT); cd.mouse_filter = Control.MOUSE_FILTER_IGNORE; cd.name = "cd"
		cd.draw.connect(func():
			var f: float = cd.get_meta("f", 0.0)
			if f > 0: cd.draw_arc(Vector2(25, 25), 9.5, -PI / 2, -PI / 2 + TAU * f, 32, Color(.016, .008, .03, .8), 19))
		b.add_child(cd)
		skills.add_child(b); hot.append([b, func(): game.cast_sec(id)])
		_hint(b, ["X", "Y", "B"][si])
	build_belt()

func _hint(c: Control, t: String) -> void:
	var h = Label.new(); h.text = t; h.name = "hint"
	h.add_theme_font_size_override("font_size", 10); h.add_theme_color_override("font_color", Color("#1b1206"))
	h.add_theme_stylebox_override("normal", Ui.sb(Color("#efe4cf"), 10, Color(0, 0, 0, 0), 0, Vector4(4, 1, 4, 1)))
	h.position = Vector2(c.custom_minimum_size.x - 14, -4); h.mouse_filter = Control.MOUSE_FILTER_IGNORE; h.visible = pad_on
	c.add_child(h)

func set_pad(on: bool) -> void:
	pad_on = on
	for c in skills.get_children() + belt.get_children():
		var h = c.get_node_or_null("hint")
		if h: h.visible = on

func _upd_cooldowns() -> void:
	var P = game.P
	for b in skills.get_children():
		if not b.has_meta("sec"): continue
		var id: String = b.get_meta("sec"); var cdv: float = P.secCd.get(id, 0.0); var mx = game.sec_cd_max(id)
		var f: float = cdv / mx if cdv > 0 else 0.0
		var cd: Control = b.get_node("cd"); cd.set_meta("f", f); cd.queue_redraw()
		b.modulate = Color(.7, .7, .75) if f > 0 else Color.WHITE

func build_belt() -> void:
	for c in belt.get_children(): c.queue_free()
	hot = hot.filter(func(h): return h[0].get_parent() != belt)
	if game.P == null: return
	for id in ["pothp", "potmp", "scroll"]:
		var n: int = game.P.pot.get(id, 0)
		if id == "scroll" and (n == 0 or game.G.floor == 0): continue
		var b = Control.new(); b.custom_minimum_size = Vector2(60, 60); b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t = TextureRect.new(); t.texture = load("res://ui/item_%s.png" % id); t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.position = Vector2(2, 2); t.size = Vector2(56, 56); t.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(t)
		var l = Label.new(); l.text = str(n); l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0)); l.add_theme_constant_override("outline_size", 4)
		l.position = Vector2(42, 38); l.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(l)
		if n == 0: b.modulate.a = .4
		belt.add_child(b); hot.append([b, func(): game.use_pot(id)])
		_hint(b, {pothp = "LB", potmp = "RB", scroll = "R3"}[id])

# ---------------- 터치 ----------------
func pad_pos(side: int) -> Vector2:
	var vs = get_viewport().get_visible_rect().size; var ins = inset(); var m = STICKR + 22
	return Vector2(vs.x - ins.r - m, vs.y - ins.b - m) if side else Vector2(ins.l + m, vs.y - ins.b - m)

func _hit_button(p: Vector2) -> bool:
	if not playing(): return false
	var fixed = [[pause_b, func(): main.open_pause()], [bag_b, func(): main.ui.open_bag()]]
	if talk_b.visible: fixed.append([talk_b, func(): main.try_talk()])
	for h in fixed + hot:
		var c: Control = h[0]
		if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().grow(4).has_point(p):
			h[1].call(); return true
	return false

func handle_input(ev: InputEvent) -> void:
	var vs = get_viewport().get_visible_rect().size
	if ev is InputEventScreenTouch:
		var p: Vector2 = ev.position
		if ev.pressed:
			if pad_on:
				pad_on = false; main.pad_mode(false)
			if not playing(): return
			if _hit_button(p): return
			if p.x < vs.x / 2 and move_id < 0:
				move_id = ev.index; mo = p; mc = p
			elif aim_id < 0:
				aim_id = ev.index; ao = p; ac = p
		else:
			if ev.index == move_id: move_id = -1
			if ev.index == aim_id: aim_id = -1
	elif ev is InputEventScreenDrag:
		if ev.index == move_id: mc = ev.position
		elif ev.index == aim_id: ac = ev.position

func clear_input() -> void:
	move_id = -1; aim_id = -1

func read_touch(P, PSX: Vector2) -> Dictionary:
	var r = {mx = 0.0, my = 0.0, aim = false, ang = 0.0, auto = false}
	if move_id >= 0:
		var d = mc - mo; var l = d.length()
		if l > 6:
			var k: float = min(1.0, l / 48) / l; r.mx = d.x * k; r.my = d.y * k
		if l > 70: mo = mc - d / l * 70
	if aim_id >= 0:
		r.aim = true; var d = ac - ao
		if d.length() > 12: r.ang = atan2(d.y, d.x)
		else: r.auto = true
	return r

# ---------------- 그리기 ----------------
class HudDraw extends Control:
	var hud
	var runes: Array = []
	func _ready() -> void:
		for i in 26:
			var a: Array = []
			for k in 3:
				a.append([(MapGen.hash2(i, k * 3) % 7 - 3) / 3.0, (MapGen.hash2(i, k * 3 + 1) % 7 - 3) / 3.0, (MapGen.hash2(i, k * 3 + 2) % 7 - 3) / 3.0, (MapGen.hash2(i, k * 3 + 3) % 7 - 3) / 3.0])
			runes.append(a)

	func font() -> Font: return Ui.body
	func dfont() -> Font: return Ui.display

	func text(p: Vector2, t: String, sz: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, f: Font = null, ol := 3, olc := Color(0, 0, 0, .85)) -> void:
		var fo = f if f else font()
		var w = fo.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var x = p.x - (w / 2 if align == HORIZONTAL_ALIGNMENT_CENTER else (w if align == HORIZONTAL_ALIGNMENT_RIGHT else 0.0))
		if ol > 0: draw_string_outline(fo, Vector2(x, p.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, ol, olc)
		draw_string(fo, Vector2(x, p.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)

	func pill(x: float, y: float, w: float, h: float, v: float, mx: float, c1: Color, c2: Color, right: bool) -> void:
		var bg = StyleBoxFlat.new(); bg.bg_color = Color(0, 0, 0, .65); bg.set_corner_radius_all(int((h + 4) / 2)); bg.border_color = Color(.82, .78, .9, .55); bg.set_border_width_all(1)
		draw_style_box(bg, Rect2(x - 2, y - 2, w + 4, h + 4))
		var f: float = clamp(v / max(mx, 1.0), 0, 1); var fw = w * f
		if fw <= .5: return
		var fx = x if right else x + w - fw
		var sb = StyleBoxFlat.new(); sb.bg_color = c1.lerp(c2, .45); sb.set_corner_radius_all(int(h / 2))
		draw_style_box(sb, Rect2(fx, y, fw, h))
		var hi = StyleBoxFlat.new(); hi.bg_color = Color(1, 1, 1, .28); hi.set_corner_radius_all(int(h * .2))
		draw_style_box(hi, Rect2(fx + 1, y, max(fw - 2, 0), h * .4))

	func wp(x: float, y: float, up := 0.0) -> Vector2:
		var c: Camera3D = hud.cam
		var v = Vector3(x / 32.0, up * World.STAND / 32.0, y / 32.0)
		if c.is_position_behind(v): return Vector2(-9999, -9999)
		return c.unproject_position(v)

	func _draw() -> void:
		var game: Game = hud.game
		if game.G == null or game.P == null: return
		var G = game.G; var P = game.P
		var vs = get_viewport_rect().size; var ins: Dictionary = hud.inset()
		var showing: bool = G.state in ["play", "pause", "levelup", "talk", "first"]
		if not showing: return
		_world_labels(game, G, P)
		var Tp: float = 8 + ins.t; var cx = vs.x / 2; var bw: float = min(118.0, vs.x * .15)
		var poison: bool = P.poisonT > 0
		pill(cx - bw - 16, Tp + 2, bw, 9, P.hp, P.maxhp, Color("#a6e05a") if poison else Color("#ff4a4a"), Color("#3a7a1a") if poison else Color("#8a1018"), false)
		if P.ward > 0:
			var wf: float = min(1.0, P.ward / P.maxhp); draw_rect(Rect2(cx - 16 - bw * wf, Tp + 2, bw * wf, 3), Color(.59, .76, 1, .85))
		pill(cx + 16, Tp + 2, bw, 9, P.mp, P.maxmp, Color("#6aa0ff"), Color("#1a3a9a"), true)
		draw_circle(Vector2(cx, Tp + 6), 12, Color(0, 0, 0, .7))
		draw_arc(Vector2(cx, Tp + 6), 11, 0, TAU, 32, Color(1, 1, 1, .15), 2.5, true)
		var xf: float = clamp(float(P.xp) / P.next, 0, 1)
		if xf > 0: draw_arc(Vector2(cx, Tp + 6), 11, -PI / 2, -PI / 2 + TAU * xf, 32, Color("#ffd76a"), 2.5, true)
		text(Vector2(cx, Tp + 10.5), str(P.lv), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, dfont(), 0)
		text(Vector2(cx - bw - 22, Tp + 11), "%d/%d" % [ceili(P.hp), P.maxhp], 10, Color("#ffb0b0"), HORIZONTAL_ALIGNMENT_RIGHT)
		text(Vector2(cx + bw + 22, Tp + 11), "%d/%d" % [floori(P.mp), P.maxmp], 10, Color("#b8ccff"), HORIZONTAL_ALIGNMENT_LEFT)
		if G.goldPulse > 0: G.goldPulse -= 1.0 / 60
		var gp: float = max(0.0, G.goldPulse)
		var info = "%s · %s · 금화 %d%s" % ["%d층" % G.floor if G.floor else "마을", game.act_name(), G.gold, " · 샌드박스" if G.sb != null else ""]
		text(Vector2(cx, Tp + 34), info, 11 + int(round(gp * 5)), Color("#fff3c4") if gp > 0 else Color("#e8dcc6"))
		# 미니맵 표시
		var mm: TextureRect = hud.mini
		if mm.visible:
			draw_rect(Rect2(mm.position - Vector2(3, 3), mm.size + Vector2(6, 6)), Color(.024, .016, .04, .5))
			var k: float = mm.size.x / (MapGen.MW * 32.0)
			var st = game.mg.stairs
			if st != null and st.found: draw_rect(Rect2(mm.position + Vector2(st.x * k - 2.5, st.y * k - 2.5), Vector2(5, 5)), Color("#ffd76a"))
			if G.portal != null: draw_rect(Rect2(mm.position + Vector2(G.portal.x * k - 2, G.portal.y * k - 2), Vector2(4, 4)), Color("#7fb2ff"))
			var dp: Vector2 = mm.position + Vector2(P.x * k, P.y * k)
			var dl := Vector2(cos(P.face), sin(P.face))
			draw_colored_polygon(PackedVector2Array([dp + dl * 6, dp + dl.rotated(2.4) * 4, dp + dl.rotated(-2.4) * 4]), Color(1, 1, 1, .9))
			draw_circle(dp, 2.8, Color("#7fe0ff")); draw_arc(dp, 3.2, 0, TAU, 16, Color.WHITE, 1.0, true)
		# 보스 체력
		var bosses: Array = G.enemies.filter(func(e): return e.isBoss)
		if bosses.size():
			var tot = 0.0; var sh = 0.0; var shm = 0.0
			for e in bosses:
				tot += max(0.0, e.hp); sh += e.shield; shm += e.shieldMax
			var w: float = min(300.0, vs.x - 300); var bx = (vs.x - w) / 2; var by: float = Tp + 56
			draw_rect(Rect2(bx - 2, by - 2, w + 4, 14), Color("#0a0710")); draw_rect(Rect2(bx - 1.5, by - 1.5, w + 3, 13), Color("#6a5640"), false, 1)
			draw_rect(Rect2(bx, by, w, 10), Color("#1a1220"))
			var f: float = clamp(tot / max(1.0, G.bossMax), 0, 1)
			draw_rect(Rect2(bx, by, w * f, 10), Color("#c42a32")); draw_rect(Rect2(bx, by, w * f, 4), Color(1, 1, 1, .22))
			if shm > 0: draw_rect(Rect2(bx, by + 11, w * sh / shm, 2), Color("#c9a3ff"))
			text(Vector2(vs.x / 2, by - 6), bosses[0].name, 13, Color("#ffd0c0"), HORIZONTAL_ALIGNMENT_CENTER, dfont())
		# 계단 방향
		var st2 = game.mg.stairs
		if st2 != null and st2.found and G.floor > 0:
			var s = wp(st2.x, st2.y)
			if s.x < 0 or s.y < 0 or s.x > vs.x or s.y > vs.y:
				var a = atan2(s.y - vs.y / 2, s.x - vs.x / 2); var m = 40.0
				var px: float = clamp(vs.x / 2 + cos(a) * vs.x, m + ins.l, vs.x - m - ins.r); var py: float = clamp(vs.y / 2 + sin(a) * vs.y, m + ins.t + 40, vs.y - m - ins.b)
				draw_set_transform(Vector2(px, py), a)
				draw_circle(Vector2(), 14, Color(.89, .69, .29, .25))
				draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(-6, -8), Vector2(-2, 0), Vector2(-6, 8)]), Color("#ffd76a"))
				draw_set_transform(Vector2(), 0)
		# 배너
		if G.banner.t > 0:
			var a: float = min(1.0, G.banner.t); var by = vs.y * .42
			var tw: float = dfont().get_string_size(G.banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
			for i in 12:
				var t = i / 11.0; var aa = (1 - absf(t - .5) * 2) * .55
				draw_rect(Rect2(vs.x / 2 - tw + t * tw * 2 - tw / 11, by - 30, tw * 2 / 11 + 1, 42), Color(0, 0, 0, aa * a))
			draw_rect(Rect2(vs.x / 2 - tw * .7, by - 31, tw * 1.4, 1), Color(.79, .64, .29, .6 * a)); draw_rect(Rect2(vs.x / 2 - tw * .7, by + 11, tw * 1.4, 1), Color(.79, .64, .29, .6 * a))
			text(Vector2(vs.x / 2, by), G.banner.text, 28, Color(1, .87, .6, a), HORIZONTAL_ALIGNMENT_CENTER, dfont(), 4, Color(.12, .06, .016, .9 * a))
		# 스틱
		if not hud.pad_on and hud.touch_ui and G.state == "play":
			var L0: Vector2 = hud.pad_pos(0); var R0: Vector2 = hud.pad_pos(1)
			# 손가락을 대면 마법진이 손가락 자리로 와서 반투명 조이스틱이 되고, 떼면 제자리로
			if hud.move_id >= 0:
				rune_ring(hud.mo, Hud.STICKR, 0, true, G.time, .5); knob(hud.mo, hud.mc, Color("#8fc0ff"))
			else: rune_ring(L0, Hud.STICKR, 0, false, G.time)
			if hud.aim_id >= 0:
				rune_ring(hud.ao, Hud.STICKR, 1, true, G.time, .5); knob(hud.ao, hud.ac, Color(game.act_color()))
			else: rune_ring(R0, Hud.STICKR, 1, false, G.time)

	func knob(o: Vector2, c: Vector2, col: Color) -> void:
		var d = c - o; var l = d.length(); var k: float = Hud.STICKR * .7 / l if l > Hud.STICKR * .7 else 1.0
		var p = o + d * k
		draw_circle(p, 30, Color(col, .12)); draw_circle(p, 22, Color(col, .15)); draw_circle(p, 15, Color(.78, .88, 1, .35))

	func rune_ring(c: Vector2, r: float, kind: int, active: bool, t: float, mul := 1.0) -> void:
		var a = (.95 if active else .6) * mul; var col = Color(.59, .78, 1, a)
		draw_circle(c, r * 1.3, Color(.29, .48, .8, (.1 if active else .05) * mul))
		draw_circle(c, r, Color(.03, .05, .1, .35 * mul))
		draw_arc(c, r, 0, TAU, 64, col, 1.6, true); draw_arc(c, r * .74, 0, TAU, 64, col, 1.0, true)
		var n = runes.size()
		for i in n:
			var ang = float(i) / n * TAU + t * .05 * (-1 if kind else 1); var rr = r * .87; var s = r * .075
			var tf = Transform2D(ang + PI / 2, c + Vector2(cos(ang), sin(ang)) * rr)
			for seg in runes[i]:
				draw_line(tf * Vector2(seg[0] * s, seg[1] * s * 1.4), tf * Vector2(seg[2] * s, seg[3] * s * 1.4), col, 1.3, true)
		var lc = Color(.75, .84, 1, a * .8)
		if active: return
		if kind == 0:
			var q = r * .42
			draw_polyline(PackedVector2Array([c + Vector2(0, -q), c + Vector2(q * .87, q * .5), c + Vector2(-q * .87, q * .5), c + Vector2(0, -q)]), lc, 2, true)
		else:
			var q = r * .4
			draw_line(c + Vector2(-q, -q), c + Vector2(q, q), lc, 2, true); draw_line(c + Vector2(q, -q), c + Vector2(-q, q), lc, 2, true)
			draw_arc(c, q * .35, 0, TAU, 20, lc, 2, true)

	func _world_labels(game: Game, G, P) -> void:
		var mg = game.mg
		for n in G.npcs:
			var near: bool = Game.hyp(P.x - n.x, P.y - n.y) < 54
			text(wp(n.x, n.y + 13, 49), n.name, 11, Color("#ffd76a") if near else Color("#efe4cf"))
			if not G.talkSeen.has(n.id):
				var p = wp(n.x, n.y + 13, 63 + sin(G.time * 4) * 2)
				draw_circle(p + Vector2(0, -4), 7.5, Color("#ffd76a")); text(p, "!", 11, Color("#1b1206"), HORIZONTAL_ALIGNMENT_CENTER, null, 0)
		if mg.gate != null:
			text(wp(mg.gate.x, mg.gate.y, 132), "탑 입구 · %d층부터" % G.resume, 13, Color("#e3b04b"), HORIZONTAL_ALIGNMENT_CENTER, dfont())
		if G.portal != null: text(wp(G.portal.x, G.portal.y + 22, 52), "웨이포인트 · 마을로" if G.portal.get("way", false) else "마을로", 11, Color("#cfe6ff"))
		if mg.door != null and G.floor > 0 and mg.is_seen(mg.door.x, mg.door.y + 8):
			text(wp(mg.door.x, mg.door.y, 70), "탑 안으로" if mg.terrace else "바깥 테라스", 12, Color("#cfe6ff") if not mg.terrace else Color("#ffe0b0"))
		if G.nearItem != null:
			var d = G.nearItem
			var p = wp(d.x, d.y, 30)
			var t: String = d.it.name; var w = font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10
			var col = Color(D.RAR[d.it.rar].color)
			draw_rect(Rect2(p.x - w / 2, p.y - 11, w, 15), Color(.024, .016, .04, .78)); draw_rect(Rect2(p.x - w / 2 + .5, p.y - 10.5, w - 1, 14), Color(col, .6), false, 1)
			text(p, t, 11, col)
		for e in G.enemies:
			if e.dead or not mg.is_seen(e.x, e.y): continue
			var top = Game.enemy_h(e) * 1.05
			if e.fearT > 0: text(wp(e.x, e.y, top + 4), "!", 12, Color("#fff2c2"))
			var alpha = 1.0
			if e.d.has("hidden"):
				var dp = Game.hyp(P.x - e.x, P.y - e.y); alpha = 1.0 if dp < 110 else (.35 if dp < 170 else .06)
			if not e.isBoss and e.hp < e.max and alpha > .5:
				var p = wp(e.x, e.y, top + 6); var w: float = e.r * 2
				draw_rect(Rect2(p.x - w / 2, p.y, w, 3), Color(0, 0, 0, .65)); draw_rect(Rect2(p.x - w / 2, p.y, w * max(0.0, e.hp / e.max), 3), Color("#e0444f"))
		for t in G.texts:
			var age: float = .7 - t.life; var sc = 1 + (.12 - age) * 4 if age < .12 else 1.0
			var a: float = min(1.0, t.life * 2.5)
			text(wp(t.x, t.y), t.t, int(round(13 * sc)), Color(Color(t.color), a), HORIZONTAL_ALIGNMENT_CENTER, Ui.bold, 3, Color(.04, .016, .03, .9 * a))
