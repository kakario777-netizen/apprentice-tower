# 메뉴 화면들 — 웹의 .ov 오버레이(타이틀·난이도·첫 마법·레벨업·일시정지·샌드박스·가방·대화·끝)
class_name Ui
extends CanvasLayer

static var body: Font
static var display: Font
static var bold: Font
static var theme: Theme

const INK := Color("#efe4cf")
const MUTED := Color("#a395b3")
const GOLD := Color("#e3b04b")
const PANEL := Color("#161220")
const LINE := Color("#33293f")

static func init_fonts() -> void:
	if body != null: return
	body = load("res://fonts/GowunDodum-Regular.ttf")
	display = load("res://fonts/GowunBatang-Bold.ttf")
	var b = FontVariation.new(); b.base_font = body; b.variation_embolden = .7; bold = b
	theme = Theme.new()
	theme.default_font = body; theme.default_font_size = 14
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", Color("#1b1206"))
	theme.set_color("font_hover_color", "Button", Color("#1b1206"))
	theme.set_color("font_pressed_color", "Button", Color("#1b1206"))
	theme.set_color("font_focus_color", "Button", Color("#1b1206"))
	theme.set_color("font_disabled_color", "Button", Color(.1, .07, .02, .6))
	theme.set_font("font", "Button", bold)
	theme.set_font_size("font_size", "Button", 15)
	theme.set_stylebox("normal", "Button", btn_sb(false))
	theme.set_stylebox("hover", "Button", btn_sb(false, .06))
	theme.set_stylebox("pressed", "Button", btn_sb(false, -.08))
	theme.set_stylebox("disabled", "Button", btn_sb(false, -.3))
	theme.set_stylebox("focus", "Button", focus_sb())
	theme.set_stylebox("panel", "PanelContainer", sb(PANEL, 8, LINE, 1, Vector4(12, 12, 12, 12)))
	var vs = StyleBoxFlat.new(); vs.bg_color = Color(1, 1, 1, .12); vs.set_corner_radius_all(3)
	theme.set_stylebox("grabber", "VScrollBar", vs); theme.set_stylebox("grabber_highlight", "VScrollBar", vs)
	theme.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())

static func sb(bg: Color, rad := 6, border := Color(0, 0, 0, 0), bw := 0, pad := Vector4(0, 0, 0, 0)) -> StyleBoxFlat:
	var s = StyleBoxFlat.new(); s.bg_color = bg; s.set_corner_radius_all(rad)
	if bw > 0:
		s.border_color = border; s.set_border_width_all(bw)
	s.content_margin_left = pad.x; s.content_margin_top = pad.y; s.content_margin_right = pad.z; s.content_margin_bottom = pad.w
	return s

static func btn_sb(ghost: bool, light := 0.0) -> StyleBoxFlat:
	var s: StyleBoxFlat
	if ghost:
		s = sb(Color(.12, .09, .16, .9).lightened(max(light, 0)).darkened(max(-light, 0)), 6, Color("#6a5640"), 1, Vector4(22, 11, 22, 11))
	else:
		s = sb(Color("#e8b552").lightened(max(light, 0)).darkened(max(-light, 0)), 6, Color("#4a2e0c"), 0, Vector4(22, 11, 22, 11))
		s.border_width_bottom = 2; s.border_color = Color("#4a2e0c")
		s.shadow_color = Color(0, 0, 0, .4); s.shadow_size = 4; s.shadow_offset = Vector2(0, 2)
	return s

static func focus_sb() -> StyleBoxFlat:
	var s = StyleBoxFlat.new(); s.draw_center = false; s.set_border_width_all(3); s.border_color = GOLD; s.set_corner_radius_all(8)
	s.expand_margin_left = 3; s.expand_margin_right = 3; s.expand_margin_top = 3; s.expand_margin_bottom = 3
	return s

static func icon_path(spec: Dictionary, plain := false) -> String:
	var p = "_p" if plain else ""
	match spec.t:
		"el": return "res://ui/el_%s%s.png" % [spec.el, p]
		"fusion": return "res://ui/fus_%s_%s%s.png" % [spec.a, spec.b, p]
		"sub": return "res://ui/sub_%s%s.png" % [spec.id, p]
		"sec": return "res://ui/sec_%s%s.png" % [spec.id, p]
		"pass": return "res://ui/pass_%s%s.png" % [spec.id, p]
		"diff": return "res://ui/diff_%s%s.png" % [spec.id, p]
	return ""

static func gear_path(it) -> String: return "res://ui/gear_%s_%s.png" % [it.base, it.rar]

# ---------------- 카드(누르는 큰 선택지) ----------------
class Card extends PanelContainer:
	signal pressed
	var color = Color("#e3b04b")
	var normal: StyleBoxFlat
	var focused: StyleBoxFlat
	var _down = false
	func _init(opt: Dictionary) -> void:
		color = Color(opt.color)
		focus_mode = Control.FOCUS_ALL; mouse_filter = Control.MOUSE_FILTER_STOP
		var big: bool = opt.get("big", false)
		var bgc: Color = Ui.PANEL.lerp(color, .14)
		if big: bgc.a = .8
		normal = Ui.sb(bgc, 10 if big else 8, Ui.LINE, 1, Vector4(18, 16, 18, 16) if big else Vector4(14, 12, 14, 12)); normal.border_color = Ui.LINE.lerp(color, .55); normal.border_width_top = 1
		focused = normal.duplicate(); focused.border_color = Ui.GOLD; focused.set_border_width_all(2)
		add_theme_stylebox_override("panel", normal)
		var h = HBoxContainer.new(); h.add_theme_constant_override("separation", 12); h.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(h)
		if opt.has("icon") and opt.icon != null:
			var t = TextureRect.new(); t.texture = load(Ui.icon_path(opt.icon)); t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.custom_minimum_size = Vector2(66, 66) if big else Vector2(54, 54); t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN; t.mouse_filter = Control.MOUSE_FILTER_IGNORE; h.add_child(t)
		var v = VBoxContainer.new(); v.add_theme_constant_override("separation", 4); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.mouse_filter = Control.MOUSE_FILTER_IGNORE; h.add_child(v)
		v.add_child(Ui.label(opt.tag, 13 if big else 11, Ui.MUTED))
		var tt = Ui.label(opt.title, 22 if big else 18, Ui.INK, Ui.display); tt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(tt)
		var ds = Ui.label(opt.desc, 15 if big else 13, Ui.MUTED.lightened(.15) if big else Ui.MUTED); ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(ds)
		focus_entered.connect(func(): add_theme_stylebox_override("panel", focused))
		focus_exited.connect(func(): add_theme_stylebox_override("panel", normal))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed: _down = true
			elif _down:
				_down = false
				if get_global_rect().has_point(get_global_mouse_position()): pressed.emit()
			accept_event()
		elif ev.is_action_pressed("ui_accept"):
			pressed.emit(); accept_event()

static func label(t: String, size: int, col := INK, f: Font = null) -> Label:
	var l = Label.new(); l.text = t; l.add_theme_font_size_override("font_size", size); l.add_theme_color_override("font_color", col)
	if f: l.add_theme_font_override("font", f)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# ================= 화면 관리 =================
var main
var game: Game
var cur := ""             # 지금 열린 화면 id
var root := Control.new()
var bg := ColorRect.new()
var scroll := ScrollContainer.new()
var box := VBoxContainer.new()
var talk_npc = null
var talk_page := 0
var bag_sel = null        # {from, i|slot}
var bag_new_first := true
var pad_swap := false

func _ready() -> void:
	layer = 2
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT); bg.color = Color(.035, .027, .055, .88); root.add_child(bg)
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var center = MarginContainer.new(); center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.name = "m"; scroll.add_child(center)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER; box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	hide_all()

func hide_all() -> void:
	cur = ""; root.visible = false

func _begin(id: String, dim := .88, align := BoxContainer.ALIGNMENT_CENTER, left := false) -> void:
	cur = id; root.visible = true
	for c in box.get_children(): c.queue_free()
	bg.color = Color(.035, .027, .055, dim); bg.material = null
	box.alignment = align
	var m: MarginContainer = scroll.get_node("m")
	var ins: Dictionary = main.hud.inset()
	var vs = get_viewport().get_visible_rect().size
	m.custom_minimum_size = vs
	m.add_theme_constant_override("margin_left", int(max(16.0, ins.l) + (vs.x * .06 if left else 0.0)))
	m.add_theme_constant_override("margin_right", int(max(16.0, ins.r)))
	m.add_theme_constant_override("margin_top", int(20 + ins.t)); m.add_theme_constant_override("margin_bottom", int(20 + ins.b))
	scroll.scroll_vertical = 0

func _focus_first() -> void:
	await get_tree().process_frame
	var cand: Array = []
	_collect_focus(box, cand)
	for c in cand:
		if c is Card:
			c.grab_focus(); return
	if cand.size(): cand[0].grab_focus()

func _collect_focus(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Control and c.focus_mode == Control.FOCUS_ALL and c.visible and not (c is BaseButton and c.disabled): out.append(c)
		_collect_focus(c, out)

func _center(c: Control, maxw := 760.0) -> Control:
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var vs = get_viewport().get_visible_rect().size
	c.custom_minimum_size.x = min(maxw, vs.x - 32)
	return c

func h2(t: String) -> Label:
	var l = label(t, 24, GOLD, display); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; return l

func lead(t: String, w := 520.0) -> Label:
	var l = label(t, 14, MUTED); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_center(l, w); return l

func btn(t: String, fn: Callable, ghost := false) -> Button:
	var b = Button.new(); b.text = t; b.focus_mode = Control.FOCUS_ALL
	if ghost:
		b.add_theme_stylebox_override("normal", btn_sb(true)); b.add_theme_stylebox_override("hover", btn_sb(true, .05)); b.add_theme_stylebox_override("pressed", btn_sb(true, -.05))
		b.add_theme_color_override("font_color", INK); b.add_theme_color_override("font_hover_color", INK); b.add_theme_color_override("font_pressed_color", INK); b.add_theme_color_override("font_focus_color", INK)
		b.add_theme_font_override("font", body)
	b.pressed.connect(fn)
	return b

func row(items: Array, center := true) -> HFlowContainer:
	var r = HFlowContainer.new(); r.add_theme_constant_override("h_separation", 10); r.add_theme_constant_override("v_separation", 10)
	r.alignment = FlowContainer.ALIGNMENT_CENTER if center else FlowContainer.ALIGNMENT_BEGIN
	for i in items: r.add_child(i)
	return r

func cards(opts: Array, on_pick: Callable, maxw := 760.0) -> GridContainer:
	var vs = get_viewport().get_visible_rect().size
	var g = GridContainer.new(); var w: float = min(maxw, vs.x - 32)
	g.columns = clampi(int(w / 220), 1, max(1, opts.size()))
	g.add_theme_constant_override("h_separation", 10); g.add_theme_constant_override("v_separation", 10)
	_center(g, maxw)
	for o in opts:
		var c = Card.new(o); c.custom_minimum_size.x = (w - 10 * (g.columns - 1)) / g.columns
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.pressed.connect(func(): on_pick.call(o)); g.add_child(c)
	return g

func stats(pairs: Array) -> GridContainer:
	var g = GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 18); g.add_theme_constant_override("v_separation", 4)
	for p in pairs:
		g.add_child(label(str(p[0]), 15, MUTED)); g.add_child(label(str(p[1]), 15, INK))
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return g

# ================= 타이틀 =================
func open_title() -> void:
	_begin("start", 0.0, BoxContainer.ALIGNMENT_CENTER, true)
	bg.color = Color(0, 0, 0, 0)
	var grad = TextureRect.new(); grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	var g = Gradient.new(); g.set_color(0, Color(.02, .016, .047, .85)); g.set_color(1, Color(.02, .016, .047, 0)); g.add_point(.36 / .62, Color(.02, .016, .047, .6))
	var gt = GradientTexture2D.new(); gt.gradient = g; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(.62, 0); gt.width = 256; gt.height = 4
	grad.texture = gt; grad.stretch_mode = TextureRect.STRETCH_SCALE; grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_title_block())
	var bgnode = root.get_node_or_null("tgrad")
	if bgnode == null:
		grad.name = "tgrad"; root.add_child(grad); root.move_child(grad, 1)
	else: bgnode.visible = true
	_focus_first()

func _title_block() -> Control:
	var v = VBoxContainer.new(); v.add_theme_constant_override("separation", 12); v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var e = label("마법학교 졸업 시험", 13, Color("#c9a3ff"), display); v.add_child(e)
	var ver := "개발판"
	if FileAccess.file_exists("res://version.txt"): ver = FileAccess.get_file_as_string("res://version.txt").strip_edges()
	var vl = label("버전 %s" % ver, 12, Color(1, 1, 1, .55)); vl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	vl.position = get_viewport().get_visible_rect().size - Vector2(110, 26); vl.name = "ver"
	var oldv = root.get_node_or_null("ver")
	if oldv: oldv.queue_free()
	root.add_child(vl)
	var t = label("견습마법사의 탑", 52, Color("#f6cf72"), display)
	t.add_theme_color_override("font_outline_color", Color("#2a1606")); t.add_theme_constant_override("outline_size", 6)
	t.add_theme_color_override("font_shadow_color", Color(.94, .75, .35, .35)); t.add_theme_constant_override("shadow_outline_size", 18); t.add_theme_constant_override("shadow_offset_x", 0); t.add_theme_constant_override("shadow_offset_y", 0)
	v.add_child(t)
	var ld = label("마법학교 졸업 시험은 단 하나. 흑마법사가 차지한 탑을 꼭대기까지 올라가 쓰러뜨리는 것.", 14, MUTED); ld.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; ld.custom_minimum_size.x = 540
	v.add_child(ld)
	var sv = Game.read_save()
	var items: Array = []
	if sv != null: items.append(btn("이어하기", func(): main.continue_game()))
	items.append(btn("새로 시작", func(): open_new()))
	items.append(btn("샌드박스 (테스트용)", func(): main.sand_start(), true))
	v.add_child(row(items, false))
	if sv != null:
		var dn = ""
		for d in D.DIFFICULTIES:
			if d.id == sv.diff: dn = d.name
		v.add_child(label("이어하기: %s · Lv %d · %d층부터 · 금화 %d" % [dn, int(sv.P.lv), int(sv.resume), int(sv.gold)], 12, MUTED))
	v.add_child(label("왼쪽을 끌어 이동 · 오른쪽을 눌러 조준·발사 · 컨트롤러도 연결하면 바로 쓸 수 있어요", 12, MUTED))
	var cr = label("캐릭터·몬스터·아이템·마법 그림: Flare (Clint Bellanger 외, CC-BY-SA 3.0)를 가공해 사용 · 고도 엔진으로 제작", 11, MUTED); cr.modulate.a = .7
	v.add_child(cr)
	return v

func _no_title_grad() -> void:
	var g = root.get_node_or_null("tgrad")
	if g: g.visible = false
	var vv = root.get_node_or_null("ver")
	if vv: vv.queue_free()

func open_new() -> void:
	_no_title_grad(); _begin("new")
	box.add_child(h2("난이도"))
	box.add_child(lead("어느 정도의 시험을 치를까요? 진행 중인 기록이 있다면 새 기록으로 바뀝니다."))
	var opts: Array = []
	for d in D.DIFFICULTIES: opts.append({icon = {t = "diff", id = d.id}, tag = "난이도", title = d.name, desc = d.desc, color = d.color, id = d.id})
	box.add_child(cards(opts, func(o): main.new_game(o.id)))
	box.add_child(row([btn("돌아가기", func(): open_title(), true)]))
	_focus_first()

func open_first() -> void:
	_no_title_grad(); _begin("first")
	box.add_child(h2("첫 마법"))
	box.add_child(lead("탑에 들어가기 전에, 시험에 가져갈 첫 마법을 고르세요."))
	var opts: Array = []
	for id in D.PRIM_ORDER:
		var d: Dictionary = D.PRIMARIES[id]; opts.append({icon = {t = "el", el = id}, tag = "첫 마법", title = d.name, desc = d.desc, color = d.color, id = id})
	box.add_child(cards(opts, func(o):
		hide_all(); game.pick_first(o.id)))
	box.add_child(row([btn("조금 더 둘러볼게요", func(): main.first_back(), true)]))
	_focus_first()

# ================= 레벨업 =================
func open_level() -> void:
	_no_title_grad(); _begin("level", .42)
	var G = game.G; var P = game.P
	box.add_child(h2("레벨 업 · Lv %d" % (P.lv - G.pendingLv + 1)))
	box.add_child(lead("남은 선택 %d번. 셋 중 하나를 익히세요." % G.pendingLv if G.pendingLv > 1 else "셋 중 하나를 익히세요."))
	var opts = game.build_options()
	for o in opts: o.big = true
	box.add_child(cards(opts, func(o):
		hide_all(); game.apply_option(o), 820.0))
	_focus_first()

# ================= 일시정지 =================
func open_pause() -> void:
	_no_title_grad(); _begin("pause")
	var G = game.G; var P = game.P
	game.recalc()
	box.add_child(h2("잠시 쉬는 중"))
	var r = HFlowContainer.new(); r.alignment = FlowContainer.ALIGNMENT_CENTER; r.add_theme_constant_override("h_separation", 28); _center(r)
	r.add_child(stats([["층", "%d / %d" % [G.floor, D.LAST_FLOOR] if G.floor else "마을 (다음 %d층)" % G.resume], ["난이도", game.diff_d().name], ["레벨", P.lv],
		["생명", "%d / %d" % [ceili(P.hp), P.maxhp]], ["마나", "%d / %d" % [floori(P.mp), P.maxmp]], ["처치", G.kills], ["금화", G.gold]]))
	var li = VBoxContainer.new(); li.add_theme_constant_override("separation", 4); li.custom_minimum_size.x = 280
	var bx = func(v): return " (+%s 장비)" % str(v) if v else ""
	var add = func(n: String, l: String):
		var p = PanelContainer.new(); p.add_theme_stylebox_override("panel", sb(PANEL, 4, Color(0, 0, 0, 0), 0, Vector4(10, 6, 10, 6)))
		var h = HBoxContainer.new(); p.add_child(h)
		var a = label(n, 14); a.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(a); h.add_child(label(l, 14, MUTED)); li.add_child(p)
	for id in D.PRIM_ORDER:
		if P.prim[id]: add.call(D.PRIMARIES[id].name, "%d단계%s" % [P.prim[id], bx.call(P.bonus.prim.get(id, 0))])
	if P.fusion != null: add.call(D.FUSIONS[P.fusion].name, "융합")
	for s in D.SUBS:
		if P.es.get(s.id, 0): add.call(s.name, "%d단계%s" % [P.subs.get(s.id, 0), bx.call(P.bonus.sub.get(s.id, 0))])
	for id in P.secOrder: add.call(D.sec(id).name, "%d단계%s" % [P.sec[id], bx.call(P.bonus.sec.get(id, 0))])
	for s in D.PASSIVES:
		if P["pass"].get(s.id, 0): add.call(s.name, "%d단계" % P["pass"][s.id])
	r.add_child(li)
	box.add_child(r)
	box.add_child(row([btn("계속하기", func(): main.resume()), btn("가방", func(): open_bag(), true), btn("샌드박스", func(): open_sand(), true),
		btn("처음 화면으로", func(): main.to_title(), true)]))
	var swf = func():
		main.pad_swap = not main.pad_swap; main.save_settings(); open_pause()
	var sw = btn("컨트롤러 버튼 배치: %s" % ("닌텐도식 (A·B 위치 바꿈)" if main.pad_swap else "엑스박스식"), swf, true)
	box.add_child(row([sw]))
	var pi = label("연결됨: %s · 왼스틱 이동, 오른스틱 조준·발사, RT/A 자동 조준 공격, X·Y·B 보조 마법, LB·RB 물약, LT 마법 교체, START 일시정지, SELECT 가방" % main.pad_name() if main.pad_connected() else "컨트롤러를 연결하면 바로 쓸 수 있어요 (유선·블루투스 모두 가능).", 12, MUTED)
	pi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; pi.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _center(pi, 640)
	box.add_child(pi)
	_focus_first()

# ================= 탑 문(웨이포인트) =================
func open_gate() -> void:
	_no_title_grad(); _begin("gate", .7)
	var G = game.G
	box.add_child(h2("어디서부터 오를까요?"))
	box.add_child(lead("열어 둔 웨이포인트 층으로 바로 갈 수 있어요."))
	var items: Array = []
	var go = func(f):
		hide_all(); game.set_state("play"); game.enter_tower(f)
	items.append(btn("이어서 · %d층" % G.resume, go.bind(G.resume)))
	var ws: Array = G.waypoints.duplicate(); ws.sort()
	for f in ws:
		if f == G.resume: continue
		items.append(btn("%d층 웨이포인트" % f, go.bind(f), true))
	box.add_child(row(items))
	var backf = func():
		hide_all(); game.set_state("play")
	box.add_child(row([btn("돌아가기", backf, true)]))
	_focus_first()

# ================= 끝 =================
func open_end() -> void:
	_no_title_grad(); _begin("end")
	var G = game.G; var P = game.P; var win: bool = game.end_win
	box.add_child(h2("졸업 시험 합격!" if win else "쓰러졌습니다"))
	box.add_child(lead("흑마법사 벨로르를 물리치고 탑을 되찾았어요." if win else "%d층에서 정신을 잃었어요. 교수님들이 마을로 데려와 주지만, 들고 있던 금화 절반(%d)은 잃어버려요." % [G.floor, G.gold / 2]))
	box.add_child(stats([["도달한 층", "%d층" % G.floor], ["레벨", P.lv], ["처치", G.kills], ["금화", G.gold]]))
	var items: Array = []
	if not win and G.sb == null: items.append(btn("마을에서 다시 일어나기", func():
		hide_all(); game.revive()))
	items.append(btn("처음 화면으로" if win else "처음부터 다시", func(): main.to_title(false), true))
	box.add_child(row(items))
	_focus_first()

# ================= 대화·상점 =================
func open_talk(n) -> void:
	_no_title_grad(); talk_npc = n; talk_page = 0; game.set_state("talk"); _render_talk()

func _render_talk() -> void:
	_begin("talk", .45, BoxContainer.ALIGNMENT_END)
	var n = talk_npc; var lines: Array = D.TALK[n.id]
	var tb = PanelContainer.new(); var st = sb(Color("#1b1526"), 10, LINE, 1, Vector4(14, 14, 14, 14)); st.border_color = Color(.89, .69, .29, .5); st.border_width_top = 1
	tb.add_theme_stylebox_override("panel", st); _center(tb)
	var h = HBoxContainer.new(); h.add_theme_constant_override("separation", 14); tb.add_child(h)
	h.add_child(_portrait(n))
	var v = VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.add_theme_constant_override("separation", 8); h.add_child(v)
	v.add_child(label(n.name, 17, GOLD, display))
	var tx = label(lines[min(talk_page, lines.size() - 1)], 15); tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(tx)
	var btns: Array = []
	if n.id == "shop":
		_render_trade(); return
	if false:
		tx.text = "%s (가진 금화 %d)" % [lines[0], game.G.gold]
		var g = GridContainer.new(); g.columns = 2 if get_viewport().get_visible_rect().size.x > 1000 else 1
		g.add_theme_constant_override("h_separation", 8); g.add_theme_constant_override("v_separation", 8)
		for it in D.SHOP:
			var p = PanelContainer.new(); p.add_theme_stylebox_override("panel", sb(PANEL, 6, LINE, 1, Vector4(10, 8, 10, 8))); p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var r = HBoxContainer.new(); r.add_theme_constant_override("separation", 10); p.add_child(r)
			var ic = TextureRect.new(); ic.texture = load("res://ui/item_%s.png" % it.id); ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.custom_minimum_size = Vector2(34, 34); r.add_child(ic)
			var nv = VBoxContainer.new(); nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nv.add_theme_constant_override("separation", 0); r.add_child(nv)
			nv.add_child(label(it.name, 14)); nv.add_child(label("%s · %d/%d개" % [it.desc, game.P.pot.get(it.id, 0), it.max], 12, MUTED))
			var b = btn("금화 %d" % it.price, func():
				game.buy(it.id); _render_talk())
			b.add_theme_font_size_override("font_size", 13); b.add_theme_stylebox_override("normal", _small(btn_sb(false)))
			b.disabled = game.G.gold < it.price or game.P.pot.get(it.id, 0) >= it.max
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.add_child(b); g.add_child(p)
		v.add_child(g)
		btns.append(btn("그만 볼게요", close_talk))
	else:
		if talk_page < lines.size() - 1:
			btns.append(btn("그만 들을게요", close_talk, true))
			btns.append(btn("다음", func():
				talk_page += 1; _render_talk()))
		else:
			game.G.talkSeen[n.id] = 1
			btns.append(btn("알겠습니다", close_talk))
	var rr = HBoxContainer.new(); rr.alignment = BoxContainer.ALIGNMENT_END; rr.add_theme_constant_override("separation", 10)
	for b in btns: rr.add_child(b)
	v.add_child(rr)
	box.add_child(tb)
	_focus_first()

# ---------------- 거래창(미라 교수) ----------------
func _render_trade() -> void:
	_begin("talk", .72, BoxContainer.ALIGNMENT_CENTER)
	var G = game.G; var P = game.P
	var vs = get_viewport().get_visible_rect().size
	var W: float = min(880.0, vs.x - 24)
	var head = HBoxContainer.new(); _center(head, W)
	var t = label("미라 교수의 가게", 22, GOLD, display); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(t)
	var gl = label("가진 금화  %d" % G.gold, 17, Color("#ffd76a"), bold); head.add_child(gl)
	box.add_child(head)
	var cols = HBoxContainer.new(); cols.add_theme_constant_override("separation", 12); _center(cols, W)
	# 왼쪽: 물약·주문서
	var left = PanelContainer.new(); left.add_theme_stylebox_override("panel", sb(Color(.09, .07, .12, .92), 10, LINE, 1, Vector4(12, 12, 12, 12)))
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL; left.size_flags_stretch_ratio = 1.0
	var lv = VBoxContainer.new(); lv.add_theme_constant_override("separation", 8); left.add_child(lv)
	lv.add_child(label("물약 · 주문서", 14, MUTED))
	for it in D.SHOP:
		var r = HBoxContainer.new(); r.add_theme_constant_override("separation", 10)
		var ic = TextureRect.new(); ic.texture = load("res://ui/item_%s.png" % it.id); ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.custom_minimum_size = Vector2(46, 46); r.add_child(ic)
		var nv = VBoxContainer.new(); nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nv.add_theme_constant_override("separation", 0); r.add_child(nv)
		nv.add_child(label(it.name, 15)); nv.add_child(label("%s · %d/%d개" % [it.desc, P.pot.get(it.id, 0), it.max], 12, MUTED))
		var bf = func():
			game.buy(it.id); _render_trade()
		var b = btn("금화 %d" % it.price, bf); b.add_theme_font_size_override("font_size", 14)
		for st in ["normal", "hover", "pressed", "disabled"]: b.add_theme_stylebox_override(st, _small(btn_sb(false, -.3 if st == "disabled" else 0.0)))
		b.disabled = G.gold < it.price or P.pot.get(it.id, 0) >= it.max; b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(b); lv.add_child(r)
	# 가방 늘리기
	lv.add_child(HSeparator.new())
	var br = HBoxContainer.new(); br.add_theme_constant_override("separation", 10)
	var bi = TextureRect.new(); bi.texture = load("res://ui/bag.png"); bi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; bi.custom_minimum_size = Vector2(46, 46); br.add_child(bi)
	var bv = VBoxContainer.new(); bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bv.add_theme_constant_override("separation", 0); br.add_child(bv)
	bv.add_child(label("가방 칸 늘리기 (+4칸)", 15)); bv.add_child(label("지금 %d칸 · 최대 %d칸" % [P.bagMax, D.BAG_LIMIT], 12, MUTED))
	var bagf = func():
		game.buy_bag(); _render_trade()
	var bb = btn("금화 %d" % D.bag_price(P.bagMax) if P.bagMax < D.BAG_LIMIT else "최대", bagf); bb.add_theme_font_size_override("font_size", 14)
	for st in ["normal", "hover", "pressed", "disabled"]: bb.add_theme_stylebox_override(st, _small(btn_sb(false, -.3 if st == "disabled" else 0.0)))
	bb.disabled = P.bagMax >= D.BAG_LIMIT or G.gold < D.bag_price(P.bagMax); bb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	br.add_child(bb); lv.add_child(br)
	cols.add_child(left)
	# 오른쪽: 오늘의 장비(마을에 올 때마다 바뀜)
	var right = PanelContainer.new(); right.add_theme_stylebox_override("panel", sb(Color(.09, .07, .12, .92), 10, LINE, 1, Vector4(12, 12, 12, 12)))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; right.size_flags_stretch_ratio = 1.15
	var rv = VBoxContainer.new(); rv.add_theme_constant_override("separation", 8); right.add_child(rv)
	rv.add_child(label("오늘의 장비 · 마을에 올 때마다 바뀌어요", 14, MUTED))
	if G.shop.is_empty(): rv.add_child(label("오늘 물건은 다 팔렸어요.", 13, MUTED))
	for i in G.shop.size():
		var it = G.shop[i]
		var r = HBoxContainer.new(); r.add_theme_constant_override("separation", 10)
		var ic = TextureRect.new(); ic.texture = load(gear_path(it)); ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.custom_minimum_size = Vector2(46, 46); r.add_child(ic)
		var nv = VBoxContainer.new(); nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nv.add_theme_constant_override("separation", 0); r.add_child(nv)
		nv.add_child(label("%s · %s" % [it.name, "반지" if it.slot == "ring" else D.SLOTNAME[it.slot]], 14, Color(D.RAR[it.rar].color)))
		var ms: Array = []
		for m in it.mods: ms.append(D.mod_text(m))
		var ml = label(" · ".join(ms), 12, MUTED); ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; nv.add_child(ml)
		var bif = func():
			game.buy_item(i); _render_trade()
		var b = btn("금화 %d" % it.price, bif); b.add_theme_font_size_override("font_size", 14)
		for st in ["normal", "hover", "pressed", "disabled"]: b.add_theme_stylebox_override(st, _small(btn_sb(false, -.3 if st == "disabled" else 0.0)))
		b.disabled = G.gold < it.price; b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(b); rv.add_child(r)
	cols.add_child(right)
	box.add_child(cols)
	var tip = label("안 쓰는 장비는 마을에서 가방을 열면 팔 수 있어요.", 12, MUTED); tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(tip)
	var obf = func():
		talk_npc = null; open_bag()
	box.add_child(row([btn("가방 열기", obf, true), btn("닫기", close_talk)]))
	_focus_first()

func _small(s: StyleBoxFlat) -> StyleBoxFlat:
	var x = s.duplicate(); x.content_margin_left = 12; x.content_margin_right = 12; x.content_margin_top = 7; x.content_margin_bottom = 7; return x

func _portrait(n) -> Control:
	var c = Control.new(); c.custom_minimum_size = Vector2(84, 84); c.clip_contents = true
	var bgp = ColorRect.new(); bgp.color = Color("#0e0b14"); bgp.size = Vector2(84, 84); c.add_child(bgp)
	var m: Dictionary = Actor.meta().get(n.id, {})
	if m.has("fr"):
		var row_: int = int(m.anims.stance.row) + 6
		var f = m.fr[row_ * int(m.nf)]
		if f != null:
			var at = AtlasTexture.new(); at.atlas = load("res://assets/sprites/%s.png" % n.id); at.region = Rect2(f[1], f[2], f[3], f[4])
			var hh: float = m.hgt * .6; var sc = 84.0 / hh
			var t = TextureRect.new(); t.texture = at; t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			# 머리 부분이 보이게(웹 drawPortrait 와 같은 자리)
			var sx: float = m.anchor[0] - hh * .5; var sy: float = m.anchor[1] - m.hgt * 1.03
			t.position = Vector2((f[5] - sx) * sc, (f[6] - sy) * sc); t.size = Vector2(f[3] * sc, f[4] * sc)
			c.add_child(t)
	return c

func close_talk() -> void:
	talk_npc = null; hide_all(); game.set_state("play"); game.save()

# ================= 가방 =================
func open_bag() -> void:
	if game.G == null: return
	_no_title_grad()
	game.set_state("bag"); game.G.bagNew = false; bag_sel = null; _render_bag()

func _sel_item():
	if bag_sel == null: return null
	return game.P.bag[bag_sel.i] if bag_sel.from == "bag" else game.P.eq[bag_sel.slot]

func _slot(it, lb: String, sel: bool, sz: float, fn: Callable) -> Button:
	var b = Button.new(); b.custom_minimum_size = Vector2(sz, sz); b.focus_mode = Control.FOCUS_ALL
	var s = sb(PANEL, 7, Color(D.RAR[it.rar].color) if it != null else LINE, 2)
	if sel:
		s.border_color = INK
	b.add_theme_stylebox_override("normal", s); b.add_theme_stylebox_override("hover", s); b.add_theme_stylebox_override("pressed", s)
	if it != null:
		var t = TextureRect.new(); t.texture = load(gear_path(it)); t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.position = Vector2(sz * .08, sz * .06); t.size = Vector2(sz * .84, sz * .84); t.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(t)
	if lb != "":
		var l = label(lb, 10, MUTED); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.position = Vector2(0, sz - 15); l.size = Vector2(sz, 14); b.add_child(l)
	b.pressed.connect(fn)
	return b

func _render_bag() -> void:
	var keep_focus = ""
	var fo = get_viewport().gui_get_focus_owner()
	if fo and fo.has_meta("key"): keep_focus = fo.get_meta("key")
	_begin("bag", .88, BoxContainer.ALIGNMENT_BEGIN)
	game.recalc()
	var P = game.P; var G = game.G
	var wrap = HBoxContainer.new(); wrap.add_theme_constant_override("separation", 12); _center(wrap, 1040)
	# 왼쪽: 큰 장비창 — 뒤에 마법사 윤곽을 아주 옅게, 그 위에 7칸
	var EW := 300.0; var EH := 318.0
	var ep = PanelContainer.new(); ep.add_theme_stylebox_override("panel", sb(Color(.07, .055, .1, .95), 12, LINE, 1, Vector4(0, 0, 0, 0)))
	ep.custom_minimum_size = Vector2(EW, EH)
	var lay = Control.new(); lay.custom_minimum_size = Vector2(EW, EH); ep.add_child(lay)
	lay.add_child(_silhouette(EW, EH))
	var tl = label("장비", 17, GOLD, display); tl.position = Vector2(12, 8); lay.add_child(tl)
	var POS := {amulet = Vector2(.5, .17), weapon = Vector2(.17, .42), cloak = Vector2(.83, .42), ring1 = Vector2(.17, .68), ring2 = Vector2(.83, .68), belt = Vector2(.5, .62), boots = Vector2(.5, .86)}
	for k in D.SLOTS:
		var sz := 58.0
		var b = _slot(P.eq[k], D.SLOTNAME[k], bag_sel != null and bag_sel.from == "eq" and bag_sel.slot == k, sz, func():
			bag_sel = {from = "eq", slot = k}; _render_bag())
		if P.eq[k] == null:
			var ph = TextureRect.new(); ph.texture = load("res://ui/slot_%s.png" % ("ring" if k.begins_with("ring") else k)); ph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ph.position = Vector2(sz * .12, sz * .06); ph.size = Vector2(sz * .76, sz * .76); ph.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(ph)
		b.position = Vector2(POS[k].x * EW - sz / 2, POS[k].y * EH - sz / 2); b.set_meta("key", "eq:" + k); lay.add_child(b)
	var c1 = VBoxContainer.new(); c1.add_theme_constant_override("separation", 6)
	c1.add_child(ep)
	var tot = {}
	for k in D.SLOTS:
		var it = P.eq[k]
		if it != null:
			for m in it.mods: tot[m.k] = tot.get(m.k, 0) + m.v
	var es = HFlowContainer.new(); es.add_theme_constant_override("h_separation", 10); es.custom_minimum_size.x = EW
	if tot.is_empty(): es.add_child(label("착용한 장비가 없어요.", 12, MUTED))
	for k in tot.keys(): es.add_child(label(D.mod_text({k = k, v = snappedf(tot[k], .01)}), 12, MUTED))
	c1.add_child(es)
	wrap.add_child(c1)
	# 가운데: 가방(칸은 상점에서 금화로 늘릴 수 있음)
	var c2 = VBoxContainer.new(); c2.add_theme_constant_override("separation", 8)
	c2.add_child(label("가방 %d/%d" % [P.bag.size(), P.bagMax], 17, GOLD, display))
	var gsc = ScrollContainer.new(); gsc.custom_minimum_size = Vector2(5 * 50 + 4 * 5 + 8, 6 * 55); gsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var bg_ = GridContainer.new(); bg_.columns = 5; bg_.add_theme_constant_override("h_separation", 5); bg_.add_theme_constant_override("v_separation", 5)
	for i in P.bagMax:
		var it = P.bag[i] if i < P.bag.size() else null
		var b = _slot(it, "", bag_sel != null and bag_sel.from == "bag" and bag_sel.i == i, 50, func():
			if i >= P.bag.size(): return
			bag_sel = {from = "bag", i = i}; _render_bag())
		b.set_meta("key", "bag:%d" % i); bg_.add_child(b)
	gsc.add_child(bg_); c2.add_child(gsc)
	if P.bagMax < D.BAG_LIMIT: c2.add_child(label("칸이 모자라면 미라 교수에게서 늘릴 수 있어요", 11, MUTED))
	wrap.add_child(c2)
	# 자세히
	var dt = PanelContainer.new(); dt.custom_minimum_size = Vector2(230, 90); dt.size_flags_horizontal = Control.SIZE_EXPAND_FILL; dt.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var dv = VBoxContainer.new(); dv.add_theme_constant_override("separation", 6); dt.add_child(dv)
	var it = _sel_item()
	if it == null:
		var p = label("아이템을 누르면 자세히 볼 수 있어요.", 12, MUTED); p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; dv.add_child(p)
	else:
		dv.add_child(label(it.name, 16, Color(D.RAR[it.rar].color), display))
		var bname: String = String(D.base(it.base).names[0]).split(" ")[-1]
		dv.add_child(label("%s %s · %s · %d층에서 발견" % [D.RAR[it.rar].name, bname, "반지" if it.slot == "ring" else D.SLOTNAME[it.slot], int(it.lvl)], 12, MUTED))
		for m in it.mods: dv.add_child(label("• " + D.mod_text(m), 14))
		var rr = HFlowContainer.new(); rr.add_theme_constant_override("h_separation", 10); rr.add_theme_constant_override("v_separation", 8)
		var sbtn = func(t: String, fn: Callable, ghost: bool):
			var b = btn(t, fn, ghost); b.add_theme_font_size_override("font_size", 14)
			for st in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(st, _small(btn_sb(ghost)))
			rr.add_child(b)
		if bag_sel.from == "bag":
			var targets: Array = ["ring1", "ring2"] if it.slot == "ring" else [it.slot]
			var curs: Array = targets.map(func(k): return P.eq[k]).filter(func(x): return x != null)
			if curs.size():
				var basei = curs[0]
				if it.slot == "ring" and curs.size() > 1: basei = curs[0] if Game.sum_score(curs[0]) < Game.sum_score(curs[1]) else curs[1]
				var a = Game.sum_mods(it); var b2 = Game.sum_mods(basei)
				var ks = {}
				for k in a.keys() + b2.keys(): ks[k] = true
				dv.add_child(label("착용 중인 장비와 비교 · %s" % basei.name, 12, MUTED))
				for k in ks.keys():
					var dd = snappedf(a.get(k, 0) - b2.get(k, 0), .01)
					if dd == 0: continue
					dv.add_child(label(("▲ " if dd > 0 else "▼ ") + D.mod_text({k = k, v = absf(dd)}), 12, Color("#7fd07f") if dd > 0 else Color("#ff7a6a")))
			if it.slot == "ring":
				var e1 = func(): _equip("ring1")
				var e2 = func(): _equip("ring2")
				sbtn.call("반지 1에 착용", e1, false)
				sbtn.call("반지 2에 착용", e2, false)
			else:
				var e0 = func(): _equip(it.slot)
				sbtn.call("착용", e0, false)
			var sellf = func():
				game.sell(bag_sel.i); bag_sel = null; _render_bag()
			var dropf = func():
				game.discard(bag_sel.i); bag_sel = null; _render_bag()
			if G.floor == 0: sbtn.call("팔기 · 금화 %d" % it.value, sellf, true)
			else: sbtn.call("버리기", dropf, true)
		else:
			var unf = func():
				if game.unequip(bag_sel.slot):
					bag_sel = null
				_render_bag()
			sbtn.call("벗기", unf, false)
		dv.add_child(rr)
	var c3 = VBoxContainer.new(); c3.add_theme_constant_override("separation", 8); c3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cb = btn("닫기", func(): close_bag()); cb.size_flags_horizontal = Control.SIZE_SHRINK_END
	c3.add_child(cb); c3.add_child(dt)
	wrap.add_child(c3)
	box.add_child(wrap)
	main.hud.build_buttons()
	if keep_focus != "":
		await get_tree().process_frame
		var all: Array = []; _collect_focus(box, all)
		for c in all:
			if c.has_meta("key") and c.get_meta("key") == keep_focus:
				c.grab_focus(); return
	_focus_first()

func _silhouette(w: float, h: float) -> Control:
	var c = Control.new(); c.size = Vector2(w, h); c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m: Dictionary = Actor.meta().get("player", {})
	if m.has("fr"):
		var f = m.fr[(int(m.anims.stance.row) + 6) * int(m.nf)]
		if f != null:
			var at = AtlasTexture.new(); at.atlas = load("res://assets/sprites/player.png"); at.region = Rect2(f[1], f[2], f[3], f[4])
			var sc: float = h * .92 / m.hgt
			var t = TextureRect.new(); t.texture = at; t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			t.size = Vector2(f[3], f[4]) * sc
			t.position = Vector2(w / 2 + (f[5] - m.anchor[0]) * sc, h * .96 + (f[6] - m.anchor[1]) * sc)
			t.modulate = Color(.75, .7, 1, .13)
			c.add_child(t)
	return c

func _equip(slot: String) -> void:
	game.equip(bag_sel.i, slot); bag_sel = {from = "eq", slot = slot}; _render_bag()

func close_bag() -> void:
	hide_all(); game.set_state("play"); game.save()

# ================= 샌드박스 =================
func open_sand() -> void:
	_no_title_grad()
	if game.G.sb == null: game.G.sb = {god = false, mana = false, nocd = false, still = false}
	game.set_state("sandbox"); _render_sand()

func _chip(box_: Control, t: String, fn: Callable, pressed = null) -> Button:
	var b = Button.new(); b.text = t; b.focus_mode = Control.FOCUS_ALL
	var on: bool = pressed == true
	var s = sb(GOLD if on else PANEL, 5, GOLD if on else LINE, 1, Vector4(11, 8, 11, 8))
	for st in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(st, s)
	b.add_theme_font_override("font", body); b.add_theme_font_size_override("font_size", 13)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(k, Color("#1b1206") if on else INK)
	b.pressed.connect(func():
		fn.call(); _render_sand())
	box_.add_child(b); return b

func _grp(parent: Control, t: String) -> VBoxContainer:
	var g = VBoxContainer.new(); g.add_theme_constant_override("separation", 6)
	g.add_child(label(t, 11, MUTED)); parent.add_child(g); return g

func _chips(g: Control) -> HFlowContainer:
	var c = HFlowContainer.new(); c.add_theme_constant_override("h_separation", 6); c.add_theme_constant_override("v_separation", 6); g.add_child(c); return c

func _lvrow(g: Control, name: String, val: int, mx: int, set_: Callable) -> void:
	var r = HBoxContainer.new(); r.add_theme_constant_override("separation", 8)
	var n = label(name, 13); n.size_flags_horizontal = Control.SIZE_EXPAND_FILL; r.add_child(n)
	_chip(r, "−", func(): set_.call(max(0, val - 1)))
	var v = label(str(val), 13, GOLD); v.custom_minimum_size.x = 30; v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; r.add_child(v)
	_chip(r, "+", func(): set_.call(min(mx, val + 1)))
	_chip(r, "최대", func(): set_.call(mx))
	g.add_child(r)

func _render_sand() -> void:
	var sv = scroll.scroll_vertical
	_begin("sand", .88, BoxContainer.ALIGNMENT_BEGIN)
	var G = game.G; var P = game.P
	box.add_child(h2("샌드박스"))
	var hp = label("테스트 전용 설정이에요. 닫으면 바로 게임으로 돌아갑니다.", 12, MUTED); hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(hp)
	var body_ = VBoxContainer.new(); body_.add_theme_constant_override("separation", 14); _center(body_, 560); box.add_child(body_)
	var c = _chips(_grp(body_, "치트"))
	for kv in [["무적", "god"], ["무한 마나", "mana"], ["보조 마법 쿨타임 없음", "nocd"], ["적 멈춤", "still"]]:
		var key: String = kv[1]
		var tog = func(): G.sb[key] = not G.sb[key]
		_chip(c, kv[0], tog, G.sb[key])
	_chip(c, "체력·마나 회복", func():
		P.hp = P.maxhp; P.mp = P.maxmp)
	c = _chips(_grp(body_, "층 이동 (지금 %d층)" % G.floor))
	for f in range(1, D.LAST_FLOOR + 1):
		var gf = func(): game.sand_goto(f)
		_chip(c, "%d★" % f if D.BOSSES.has(f) else str(f), gf, f == G.floor)
	c = _chips(_grp(body_, "레벨 (지금 Lv %d)" % P.lv))
	_chip(c, "+1 (스킬 선택)", func(): game.gain_xp((P.next - P.xp) / game.diff_d().reward + .5))
	_chip(c, "+5 즉시", func():
		P.lv += 5; P.next = Game.xp_need(P.lv); game.recalc(); P.hp = P.maxhp; P.mp = P.maxmp)
	var g = _grp(body_, "주 마법 단계")
	for id in D.PRIM_ORDER:
		_lvrow(g, D.PRIMARIES[id].name, P.prim[id], D.PRIMARY_MAX, func(v):
			P.prim[id] = v
			if not game.active_list().has(P.active): P.active = game.active_list()[0] if game.active_list().size() else id
			if v == 0 and P.fusion != null and id in String(P.fusion): P.fusion = null
			if game.active_list().is_empty():
				P.prim[id] = 1; P.active = id)
	c = _chips(_grp(body_, "융합 마법 (두 계열을 1단계 이상으로 맞춰줘요)"))
	var nof = func():
		P.fusion = null
		if not game.active_list().has(P.active): P.active = game.active_list()[0]
	_chip(c, "없음", nof, P.fusion == null)
	for key in D.FUSIONS.keys():
		var fz = func():
			for k in String(key).split("+"):
				if not P.prim[k]: P.prim[k] = 1
			P.fusion = key; P.active = key
		_chip(c, D.FUSIONS[key].name, fz, P.fusion == key)
	g = _grp(body_, "계열 강화")
	for s in D.SUBS: _lvrow(g, "%s · %s" % [s.name, D.PRIMARIES[s.of].name], P.subs.get(s.id, 0), s.max, func(v): P.subs[s.id] = v)
	g = _grp(body_, "보조 마법 (칸 제한 무시)")
	for s in D.SECONDARIES:
		_lvrow(g, s.name, P.sec.get(s.id, 0), s.max, func(v):
			P.sec[s.id] = v
			if v and not P.secOrder.has(s.id): P.secOrder.append(s.id)
			if not v:
				P.sec.erase(s.id); P.secOrder.erase(s.id))
	g = _grp(body_, "수련")
	for s in D.PASSIVES:
		_lvrow(g, s.name, P["pass"].get(s.id, 0), s.max, func(v):
			P["pass"][s.id] = v; game.recalc())
	c = _chips(_grp(body_, "장비 받기 (가방으로)"))
	for r in ["magic", "rare", "epic"]:
		_chip(c, "%s 장비" % D.RAR[r].name, func():
			if P.bag.size() < D.BAGMAX:
				P.bag.append(game.make_item(r, max(1, G.floor))); G.bagNew = true)
	c = _chips(_grp(body_, "몬스터 소환 (주변에 3마리)"))
	for id in D.MONSTERS.keys(): _chip(c, D.MONSTERS[id].name, func(): game.sand_spawn(id))
	c = _chips(_grp(body_, "보스 소환"))
	for f in D.BOSSES.keys(): _chip(c, D.BOSSES[f].name, func(): game.sand_boss(f))
	_chip(c, "적 모두 제거", func():
		G.enemies = []; G.eshots = []; G.bossMax = 0.0)
	box.add_child(row([btn("닫고 계속하기", func(): main.resume())]))
	main.hud.build_buttons()
	await get_tree().process_frame
	scroll.scroll_vertical = sv

# 뒤로(안드로이드 뒤로 버튼·패드 B)
func back() -> bool:
	match cur:
		"new": open_title(); return true
		"start": return false
		"first": main.first_back(); return true
		"talk": close_talk(); return true
		"bag": close_bag(); return true
		"sand", "pause": main.resume(); return true
		"gate":
			hide_all(); game.set_state("play"); return true
		"level", "end": return true
	return false
