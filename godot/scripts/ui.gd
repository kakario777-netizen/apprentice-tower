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
	# 디아블로 한글판처럼 날카로운 명조(본고딕 명조 KR, OFL)
	body = load("res://font_d/DSerif-Medium.ttf")
	display = load("res://font_d/DSerif-Bold.ttf")
	bold = display
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
static func iname(it) -> String: return String(it.name) + (" +%d" % int(it.enh) if int(it.get("enh", 0)) > 0 else "")

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
		var tg = Ui.label(opt.tag, 13 if big else 11, Ui.MUTED); tg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(tg)
		var tt = Ui.label(opt.title, 22 if big else 18, Ui.INK, Ui.display); tt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(tt)
		var ds = Ui.label(opt.desc, 15 if big else 13, Ui.MUTED.lightened(.15) if big else Ui.MUTED); ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(ds)
		focus_entered.connect(func(): add_theme_stylebox_override("panel", focused))
		focus_exited.connect(func(): add_theme_stylebox_override("panel", normal))
	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed: _down = true
			elif _down:
				_down = false
				if Rect2(Vector2.ZERO, size).has_point(ev.position): pressed.emit()     # 뗀 자리가 카드 안이면 선택
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
	for c in box.get_children():
		box.remove_child(c); c.queue_free()      # 바로 떼어내야 같은 이름의 새 창과 엉키지 않는다
	var bc = root.get_node_or_null("bagclose")
	if bc and id != "bag": bc.queue_free()
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
	b.pressed.connect(func(): main.snd.play("click"))
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
		c.set_meta("opt", o)
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
	var li := Game.latest_slot()
	var sv = Game.read_slot(li) if li >= 0 else null
	var items: Array = []
	if sv != null: items.append(btn("이어하기", func(): main.continue_game(li)))
	var newf = func():
		var fs := Game.free_slot()
		if fs >= 0: open_new(fs)
		else: open_slots(true)
	items.append(btn("새로 시작", newf))
	if sv != null: items.append(btn("캐릭터 선택", func(): open_slots(false), true))
	items.append(btn("샌드박스 (테스트용)", func(): main.sand_start(), true))
	v.add_child(row(items, false))
	if sv != null:
		v.add_child(label("이어하기: %s" % _slot_line(sv), 12, MUTED))
	v.add_child(label("왼쪽을 끌어 이동 · 오른쪽을 눌러 조준·발사 · 컨트롤러도 연결하면 바로 쓸 수 있어요", 12, MUTED))
	var cr = label("캐릭터·몬스터·아이템·마법 그림: Flare (Clint Bellanger 외, CC-BY-SA 3.0)를 가공해 사용 · 고도 엔진으로 제작", 11, MUTED); cr.modulate.a = .7
	v.add_child(cr)
	return v

func _no_title_grad() -> void:
	var g = root.get_node_or_null("tgrad")
	if g: g.visible = false
	var vv = root.get_node_or_null("ver")
	if vv: vv.queue_free()

func _slot_line(sv: Dictionary) -> String:
	var dn = ""
	for d in D.DIFFICULTIES:
		if d.id == sv.diff: dn = d.name
	var fl := int(sv.get("floor", 0))
	var wh: String = ("%d층" % fl if fl < D.ROOF else "옥상") if fl > 0 else "마을 (다음 %d층)" % int(sv.resume)
	return "%s · %s · Lv %d · %s · 금화 %d" % [String(sv.P.get("name", "견습생")), dn, int(sv.P.lv), wh, int(sv.gold)]

# ================= 단계 고르기(이어하기) =================
func open_tier_pick(si: int, sv: Dictionary) -> void:
	_no_title_grad(); _begin("tier")
	box.add_child(h2("어느 단계로 들어갈까요?"))
	box.add_child(lead("단계마다 오른 층과 웨이포인트는 따로 기억돼요. 캐릭터·장비·금화는 함께 써요."))
	var tm := int(sv.get("tierMax", 0)); var cur := int(sv.get("tier", 0)); var tiers: Dictionary = sv.get("tiers", {})
	var col = VBoxContainer.new(); col.add_theme_constant_override("separation", 10); _center(col, 560)
	for t in range(0, tm + 1):
		var snap = tiers.get(str(t), {})
		var fl := int(sv.get("floor", 0)) if t == cur else int(snap.get("floor", 0))
		var done := bool(snap.get("done", false))
		var res := int(sv.get("resume", 1)) if t == cur else int(snap.get("resume", 1))
		var where := "마을" if (fl <= 0 or fl == D.COW or done) else ("옥상" if fl == D.ROOF else "%d층" % fl)
		var sub := ("완료 · " if done else "") + ("%s에서 · 다음 %d층" % [where, res] if where == "마을" else "%s에서 이어서" % where)
		var p = PanelContainer.new(); p.add_theme_stylebox_override("panel", sb(Color(.13, .105, .18, .97), 12, Color(D.TIERS[t].color), 2, Vector4(16, 10, 16, 10)))
		var h = HBoxContainer.new(); h.add_theme_constant_override("separation", 12); p.add_child(h)
		var v = VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(v)
		v.add_child(label(D.TIERS[t].name, 21, Color(D.TIERS[t].color), display))
		v.add_child(label(sub + ("  · 몬스터 레벨 +%d" % (100 * t) if t > 0 else ""), 13, MUTED))
		var tt: int = t
		h.add_child(_sbtn("들어가기", func(): main.continue_game(si, tt), false, 16))
		col.add_child(p)
	box.add_child(col)
	box.add_child(row([btn("돌아가기", func(): open_title(), true)]))
	_focus_first()

# ================= 세이브 슬롯 =================
var del_ask := -1
func _sbtn(t: String, fn: Callable, ghost: bool, fs := 14) -> Button:
	var b = btn(t, fn, ghost); b.add_theme_font_size_override("font_size", fs)
	for st in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(st, _small(btn_sb(ghost)))
	return b

func open_slots(for_new: bool) -> void:
	_no_title_grad(); _begin("slots")
	box.add_child(h2("캐릭터 선택" if not for_new else "어느 칸에 새로 시작할까요?"))
	box.add_child(lead("캐릭터마다 따로 저장돼요. 화면을 끄거나 층을 오르거나 포탈을 타면 자동으로 저장됩니다."))
	var col = VBoxContainer.new(); col.add_theme_constant_override("separation", 8); _center(col, 640)
	for i in Game.SLOT_N:
		var sv = Game.read_slot(i)
		var p = PanelContainer.new(); p.add_theme_stylebox_override("panel", _pnl(Vector4(14, 10, 14, 10)))
		var h = HBoxContainer.new(); h.add_theme_constant_override("separation", 10); p.add_child(h)
		var nv = VBoxContainer.new(); nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nv.add_theme_constant_override("separation", 2); h.add_child(nv)
		var si: int = i
		if sv == null:
			nv.add_child(label("%d번 칸 · 비어 있음" % (i + 1), 16, MUTED, display))
			h.add_child(_sbtn("새 캐릭터", func(): open_new(si), false))
		else:
			nv.add_child(label("%d번 · %s" % [i + 1, String(sv.P.get("name", "견습생"))], 17, GOLD, display))
			nv.add_child(label(_slot_line(sv), 12, MUTED))
			var t := int(sv.get("at", 0))
			if t > 0: nv.add_child(label("마지막 저장 %s" % Time.get_datetime_string_from_unix_time(t + 9 * 3600, true).substr(0, 16), 11, MUTED))
			if for_new:
				var owf = func():
					if del_ask == si:
						del_ask = -1; Game.delete_slot(si); open_new(si)
					else:
						del_ask = si; open_slots(true)
				h.add_child(_sbtn("덮어쓰고 새로" if del_ask == i else "이 칸에", owf, true))
			else:
				h.add_child(_sbtn("이어하기", func(): main.continue_game(si), false))
				var delf = func():
					if del_ask == si:
						del_ask = -1; Game.delete_slot(si); open_slots(false)
					else:
						del_ask = si; open_slots(false)
				h.add_child(_sbtn("정말 지울까요?" if del_ask == i else "지우기", delf, true, 13))
		col.add_child(p)
	box.add_child(col)
	var backf = func():
		del_ask = -1; open_title()
	box.add_child(row([btn("돌아가기", backf, true)]))
	_focus_first()

var new_slot := 0
func open_new(slot_i := -1) -> void:
	if slot_i >= 0: new_slot = slot_i
	_no_title_grad(); _begin("new")
	box.add_child(h2("난이도"))
	box.add_child(lead("어느 정도의 시험을 치를까요? (%d번 칸에 저장돼요)" % (new_slot + 1)))
	var opts: Array = []
	for d in D.DIFFICULTIES: opts.append({icon = {t = "diff", id = d.id}, tag = "난이도", title = d.name, desc = d.desc, color = d.color, id = d.id})
	box.add_child(cards(opts, func(o): main.new_game(o.id, new_slot)))
	box.add_child(row([btn("돌아가기", func(): open_title(), true)]))
	_focus_first()

func open_first() -> void:
	_no_title_grad(); _begin("first")
	box.add_child(h2("이름과 첫 마법"))
	box.add_child(lead("탑에 들어가기 전에 이름을 정하고, 시험에 가져갈 첫 마법을 고르세요. 이름은 세이브 칸에 표시돼요."))
	var nr = HBoxContainer.new(); nr.add_theme_constant_override("separation", 8); nr.alignment = BoxContainer.ALIGNMENT_CENTER
	var le = LineEdit.new(); le.text = String(game.P.get("name", "견습생")); le.max_length = 12; le.custom_minimum_size = Vector2(240, 42)
	le.placeholder_text = "이름"; le.add_theme_font_override("font", display); le.add_theme_font_size_override("font_size", 18)
	le.add_theme_stylebox_override("normal", sb(Color(.1, .08, .14), 8, GOLD, 1, Vector4(12, 6, 12, 6))); le.add_theme_stylebox_override("focus", sb(Color(.12, .1, .17), 8, Color("#ffe39a"), 2, Vector4(12, 6, 12, 6)))
	le.select_all_on_focus = true; nr.add_child(label("이름", 15, GOLD, display)); nr.add_child(le)
	var rnd_name = func():
		le.text = Game.pick(["세린", "카일", "엘라", "로웬", "미르", "하랑", "이브", "테오", "루아", "다온", "벨라", "시온"]) + Game.pick(["", " 아르", " 블랙우드", " 은빛", " 폭풍", "벨"])
	nr.add_child(_sbtn("무작위", rnd_name, true, 13)); box.add_child(nr)
	var opts: Array = []
	for id in D.PRIM_ORDER:
		var d: Dictionary = D.PRIMARIES[id]; opts.append({icon = {t = "el", el = id}, tag = "첫 마법", title = d.name, desc = d.desc, color = d.color, id = id})
	box.add_child(cards(opts, func(o):
		var nm: String = le.text
		hide_all(); game.pick_first(o.id, nm), 980.0))
	box.add_child(row([btn("조금 더 둘러볼게요", func(): main.first_back(), true)]))
	_focus_first()

# ================= 레벨업 =================
# 뒤 화면 흐리게(레벨업 동안)
static var _blur: ShaderMaterial
static func blur_mat() -> ShaderMaterial:
	if _blur == null:
		var sh := Shader.new(); sh.code = """
shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear;
uniform float amt = 0.0;
uniform float dim = .35;
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * 3.2 * amt;
	vec3 c = vec3(0.0); float w = 0.0;
	for (int x = -3; x <= 3; x++) for (int y = -3; y <= 3; y++) {
		float k = exp(-float(x * x + y * y) / 8.0);
		c += texture(scr, SCREEN_UV + vec2(float(x), float(y)) * px).rgb * k; w += k;
	}
	COLOR = vec4(mix(c / w, vec3(.03, .02, .05), dim * amt), 1.0);
}
"""
		_blur = ShaderMaterial.new(); _blur.shader = sh
	return _blur

var lv_sel = null
var lv_busy := false
var lv_grid: Control = null
func _tw() -> Tween:
	var t := create_tween(); t.set_ignore_time_scale(true); return t

func open_level() -> void:
	_no_title_grad(); _begin("level", 0.0)
	lv_sel = null; lv_busy = false
	var bm := blur_mat(); bg.material = bm; bg.color = Color.WHITE
	bm.set_shader_parameter("amt", 0.0); _tw().tween_method(func(v): bm.set_shader_parameter("amt", v), 0.0, 1.0, .45)
	var G = game.G; var P = game.P
	box.add_child(h2("레벨 업 · Lv %d" % (P.lv - G.pendingLv + 1)))
	box.add_child(lead("남은 선택 %d번. 셋 중 하나를 익히세요." % G.pendingLv if G.pendingLv > 1 else "셋 중 하나를 익히세요."))
	var opts = game.build_options()
	for o in opts: o.big = true
	var grid := cards(opts, func(o): _lv_pick(o), 820.0); grid.name = "lvgrid"; lv_grid = grid
	box.add_child(grid)
	# 원작처럼 아래에서 천천히 떠오르며 나타난다(카드는 하나씩)
	var m: MarginContainer = scroll.get_node("m")
	var top0: int = m.get_theme_constant("margin_top")
	m.add_theme_constant_override("margin_top", top0 + 140); box.modulate.a = 0.0
	var t := _tw().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v): m.add_theme_constant_override("margin_top", int(v)), float(top0 + 140), float(top0), .75)
	t.tween_property(box, "modulate:a", 1.0, .55)
	var i := 0
	for c in grid.get_children():
		c.modulate.a = 0.0
		_tw().tween_property(c, "modulate:a", 1.0, .45).set_delay(.18 + i * .12); i += 1
	_focus_first()

func _lv_pick(o: Dictionary) -> void:
	if lv_busy or lv_sel != null: return
	var grid = lv_grid
	if grid == null or not is_instance_valid(grid): return
	lv_sel = o
	main.snd.play("ok")
	var card: Control = null
	for c in grid.get_children():
		if c.get_meta("opt") == o: card = c
		else: _tw().tween_property(c, "modulate", Color(.55, .55, .6, .55), .25)
	if card == null:
		lv_sel = null; return
	# 살짝 울렁이며 커지고, 뒤로 은은한 반짝임
	card.pivot_offset = card.size / 2; card.z_index = 2
	var t := _tw().set_trans(Tween.TRANS_SINE)
	t.tween_property(card, "scale", Vector2(1.09, 1.09), .14).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "scale", Vector2(1.03, 1.03), .12)
	t.tween_property(card, "scale", Vector2(1.06, 1.06), .1)
	t.tween_property(card, "scale", Vector2(1.05, 1.05), .1)
	var ft := _tw(); ft.tween_property(card, "modulate", Color(1.5, 1.42, 1.15), .1); ft.tween_property(card, "modulate", Color.WHITE, .35)
	var fl := ColorRect.new(); fl.set_anchors_preset(Control.PRESET_FULL_RECT); fl.color = Color(1, .9, .6, 0); fl.mouse_filter = Control.MOUSE_FILTER_IGNORE; fl.name = "lvflash"
	root.add_child(fl); root.move_child(fl, 1)
	var t2 := _tw(); t2.tween_property(fl, "color:a", .1, .12); t2.tween_property(fl, "color:a", 0.0, .45); t2.tween_callback(fl.queue_free)
	# 0.5초 뒤 "선택하시겠습니까?"
	await get_tree().create_timer(.5, true, false, true).timeout
	if lv_sel != o or cur != "level": return
	var bar = VBoxContainer.new(); bar.name = "lvconfirm"; bar.add_theme_constant_override("separation", 8); bar.modulate.a = 0.0
	var q = label("「%s」 — 선택하시겠습니까?" % o.title, 18, GOLD, display); q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bar.add_child(q)
	var yes = btn("선택", func(): _lv_confirm(o)); var no = btn("다시 고르기", func(): _lv_cancel(), true)
	bar.add_child(row([yes, no])); box.add_child(bar)
	_tw().tween_property(bar, "modulate:a", 1.0, .35)
	await get_tree().process_frame
	if is_instance_valid(yes): yes.grab_focus()

func _lv_cancel() -> void:
	if lv_busy: return
	lv_sel = null
	var grid = lv_grid
	if grid and is_instance_valid(grid):
		for c in grid.get_children():
			_tw().tween_property(c, "modulate", Color.WHITE, .2); _tw().tween_property(c, "scale", Vector2.ONE, .2); c.z_index = 0
	var bar = box.get_node_or_null("lvconfirm")
	if bar: bar.queue_free()
	_focus_first()

func _lv_confirm(o: Dictionary) -> void:
	if lv_busy: return
	lv_busy = true
	main.snd.play("levelup")
	# 창 전체가 자연스럽게 사라지고, 흐림도 걷힌다
	var m: MarginContainer = scroll.get_node("m")
	var top0: int = m.get_theme_constant("margin_top")
	var bm := blur_mat()
	var t := _tw().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(box, "modulate:a", 0.0, .38)
	t.tween_method(func(v): m.add_theme_constant_override("margin_top", int(v)), float(top0), float(top0 - 50), .38)
	t.tween_method(func(v): bm.set_shader_parameter("amt", v), 1.0, 0.0, .38)
	await t.finished
	box.modulate.a = 1.0; bg.material = null; lv_busy = false; lv_sel = null
	hide_all(); main.slow_resume(); game.apply_option(o)

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
	# 크게 누르기 쉬운 "계속하기"
	var cont = btn("계속하기", func(): main.resume()); cont.custom_minimum_size = Vector2(min(420.0, get_viewport().get_visible_rect().size.x - 60), 64)
	cont.add_theme_font_override("font", display); cont.add_theme_font_size_override("font_size", 24)
	cont.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; box.add_child(cont)
	box.add_child(row([btn("가방", func(): open_bag(), true), btn("설정", func(): open_tab("settings"), true), btn("샌드박스", func(): open_sand(), true),
		btn("처음 화면으로", func(): main.to_title(), true)]))
	_focus_first()

# ================= 탑 문(웨이포인트) =================
func open_gate() -> void:
	_no_title_grad(); _begin("gate", .7)
	var G = game.G
	box.add_child(h2("어디서부터 오를까요?" if int(G.tier) == 0 else "%s · 어디서부터 오를까요?" % game.tier_name()))
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
	if int(G.cowQ) == 1 and int(G.cowF) > 0:
		# 괴생물이 나타난 층: 혼자 붉게 빛난다
		var cb = btn("%d층 · 정체 모를 기운" % int(G.cowF), go.bind(int(G.cowF)))
		var cs = btn_sb(false); cs.bg_color = Color(.55, .12, .1); cs.border_color = Color(1, .55, .4); cs.set_border_width_all(2); cs.shadow_color = Color(1, .3, .2, .7); cs.shadow_size = 14
		for k in ["normal", "hover", "pressed", "focus"]: cb.add_theme_stylebox_override(k, cs)
		cb.add_theme_color_override("font_color", Color(1, .92, .85))
		var hb = row([cb]); box.add_child(hb)
		var tw := cb.create_tween().set_loops()
		tw.tween_property(cb, "modulate", Color(1.35, 1.1, 1.0), .7); tw.tween_property(cb, "modulate", Color(1, 1, 1), .7)
	var backf = func():
		hide_all(); game.set_state("play")
	box.add_child(row([btn("돌아가기", backf, true)]))
	_focus_first()

# ================= 끝 =================
func open_end() -> void:
	_no_title_grad(); _begin("end")
	var G = game.G; var P = game.P; var win: bool = game.end_win
	box.add_child(h2(("%s 정복!" % game.tier_name()) if win else "쓰러졌습니다"))
	if win and int(G.tier) < 2 and int(G.tierMax) > int(G.tier):
		var nt = label("%s 단계가 열렸어요 · 몬스터 레벨이 %d층부터 다시 시작돼요" % [game.tier_name(int(G.tier) + 1), 101 + 100 * int(G.tier)], 17, Color(D.TIERS[int(G.tier) + 1].color), display)
		nt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(nt)
	box.add_child(lead("흑마법사 벨로르를 물리치고 탑을 되찾았어요." if win else "%d층에서 정신을 잃었어요. 교수님들이 마을로 데려와 주지만, 들고 있던 금화 절반(%d)은 잃어버려요." % [G.floor, G.gold / 2]))
	box.add_child(stats([["도달한 층", "%d층" % G.floor], ["레벨", P.lv], ["처치", G.kills], ["금화", G.gold]]))
	var items: Array = []
	if not win and G.sb == null: items.append(btn("마을에서 다시 일어나기", func():
		hide_all(); game.revive()))
	if win:
		var nxt: int = int(G.tier) + 1
		if nxt <= 2 and int(G.tierMax) >= nxt:
			var gonext = func():
				hide_all(); game.switch_tier(nxt); main.hud.build_buttons()
			items.append(btn("%s 시작" % game.tier_name(nxt), gonext))
		var gotown = func():
			hide_all(); game.go_town(false); main.hud.build_buttons()
		items.append(btn("마을로 돌아가기", gotown, true))
	else: items.append(btn("처음부터 다시", func(): main.to_title(false), true))
	box.add_child(row(items))
	_focus_first()

# ================= 대화·상점 =================
func open_talk(n) -> void:
	_no_title_grad(); talk_npc = n; talk_page = 0; game.set_state("talk"); _render_talk()

func _render_talk() -> void:
	_begin("talk", .45, BoxContainer.ALIGNMENT_CENTER)
	var n = talk_npc
	var ckey: String = game.cow_talk_key() if n.id == "guide" else ""
	var lines: Array = D.TALK[ckey] if ckey != "" else D.TALK[n.id]
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
	if n.id == "smith":
		_render_enhance(); return
	if false:
		tx.text = "%s (가진 금화 %d)" % [lines[0], game.G.gold]
		var g = GridContainer.new(); g.columns = 2 if get_viewport().get_visible_rect().size.x > 1000 else 1
		g.add_theme_constant_override("h_separation", 8); g.add_theme_constant_override("v_separation", 8)
		for it in D.SHOP:
			var p = PanelContainer.new(); p.add_theme_stylebox_override("panel", sb(PANEL, 6, LINE, 1, Vector4(10, 8, 10, 8))); p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var r = HBoxContainer.new(); r.add_theme_constant_override("separation", 10); p.add_child(r)
			var ic = TextureRect.new(); ic.texture = load("res://ui/item_%s.png" % it.id); ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.custom_minimum_size = Vector2(34, 34); r.add_child(ic)
			var nv = VBoxContainer.new(); nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nv.add_theme_constant_override("separation", 0); r.add_child(nv)
			nv.add_child(label(it.name, 14)); nv.add_child(label("%s · %d/%d개" % [it.desc, game.P.pot.get(it.id, 0), game.pot_max(it.id)], 12, MUTED))
			var b = btn("금화 %d" % it.price, func():
				game.buy(it.id); _render_talk())
			b.add_theme_font_size_override("font_size", 13); b.add_theme_stylebox_override("normal", _small(btn_sb(false)))
			b.disabled = game.G.gold < it.price or game.P.pot.get(it.id, 0) >= game.pot_max(it.id)
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
			if ckey == "cow_q" or ckey == "cow_open":
				btns.append(btn("알겠습니다", func():
					game.cow_talk_done(ckey); close_talk()))
			else: btns.append(btn("알겠습니다", close_talk))
	var rr = HBoxContainer.new(); rr.alignment = BoxContainer.ALIGNMENT_END; rr.add_theme_constant_override("separation", 10)
	for b in btns: rr.add_child(b)
	v.add_child(rr)
	box.add_child(tb)
	_focus_first()

# ---------------- 거래창(상인 미라) ----------------
func _render_trade() -> void:
	_begin("talk", .72, BoxContainer.ALIGNMENT_CENTER)
	var G = game.G; var P = game.P
	var vs = get_viewport().get_visible_rect().size
	var W: float = min(880.0, vs.x - 24)
	var head = HBoxContainer.new(); _center(head, W)
	var t = label("상인 미라의 가게", 22, GOLD, display); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(t)
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
		nv.add_child(label(it.name, 15))
		var dl = label("%s · %d/%d개" % [it.desc, P.pot.get(it.id, 0), game.pot_max(it.id)], 12, MUTED); dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; nv.add_child(dl)
		var bf = func():
			game.buy(it.id); _render_trade()
		var b = btn("금화 %d" % it.price, bf); b.add_theme_font_size_override("font_size", 14)
		for st in ["normal", "hover", "pressed", "disabled"]: b.add_theme_stylebox_override(st, _small(btn_sb(false, -.3 if st == "disabled" else 0.0)))
		b.disabled = G.gold < it.price or P.pot.get(it.id, 0) >= game.pot_max(it.id); b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(b); lv.add_child(r)
	# 가방 늘리기
	lv.add_child(HSeparator.new())
	var br = HBoxContainer.new(); br.add_theme_constant_override("separation", 10)
	var bi = TextureRect.new(); bi.texture = load("res://ui/bag.png"); bi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; bi.custom_minimum_size = Vector2(46, 46); br.add_child(bi)
	var bv = VBoxContainer.new(); bv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bv.add_theme_constant_override("separation", 0); br.add_child(bv)
	bv.add_child(label("가방 칸 늘리기 (+%d칸)" % D.BAG_STEP, 15)); bv.add_child(label("지금 %d칸 · 최대 %d칸" % [P.bagMax, D.BAG_LIMIT], 12, MUTED))
	var bagf = func():
		game.buy_bag(); _render_trade()
	var bb = btn("금화 %d" % D.bag_price(P.bagMax) if P.bagMax < D.BAG_LIMIT else "최대", bagf); bb.add_theme_font_size_override("font_size", 14)
	for st in ["normal", "hover", "pressed", "disabled"]: bb.add_theme_stylebox_override(st, _small(btn_sb(false, -.3 if st == "disabled" else 0.0)))
	bb.disabled = P.bagMax >= D.BAG_LIMIT or G.gold < D.bag_price(P.bagMax); bb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	br.add_child(bb); lv.add_child(br)
	# 물약 주머니 늘리기(물약 최대 소지 수 +1, 10개까지 · 비쌈)
	var pr_ = HBoxContainer.new(); pr_.add_theme_constant_override("separation", 10)
	var pi_ = TextureRect.new(); pi_.texture = load("res://ui/item_pothp.png"); pi_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; pi_.custom_minimum_size = Vector2(46, 46); pr_.add_child(pi_)
	var pv_ = VBoxContainer.new(); pv_.size_flags_horizontal = Control.SIZE_EXPAND_FILL; pv_.add_theme_constant_override("separation", 0); pr_.add_child(pv_)
	var pmx: int = int(P.get("potMax", 5))
	pv_.add_child(label("물약 주머니 늘리기 (+1개)", 15)); pv_.add_child(label("생명·마나 물약 각각 지금 %d개 · 최대 10개" % pmx, 12, MUTED))
	var pouchf = func():
		game.buy_pouch(); _render_trade()
	var pb = btn("금화 %d" % game.pouch_price() if pmx < 10 else "최대", pouchf); pb.add_theme_font_size_override("font_size", 14)
	for st in ["normal", "hover", "pressed", "disabled"]: pb.add_theme_stylebox_override(st, _small(btn_sb(false, -.3 if st == "disabled" else 0.0)))
	pb.disabled = pmx >= 10 or G.gold < game.pouch_price(); pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr_.add_child(pb); lv.add_child(pr_)
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
		var inl = label("%s · %s %s" % [it.name, D.RAR[it.rar].name, D.slot_name(it.slot)], 14, Color(D.RAR[it.rar].color)); inl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; nv.add_child(inl)
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
	var tip = label("안 쓰는 장비는 아래 '물건 판매 (가방 열기)'로 팔 수 있어요.", 12, MUTED); tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(tip)
	var obf = func():
		talk_npc = null; open_bag(true)
	box.add_child(row([btn("물건 판매 (가방 열기)", obf), btn("닫기", close_talk)]))
	_focus_first()

# ---------------- 강화(카엘 교수 · 마법진) ----------------
var enh_sel = null      # {from, i|slot}
var enh_msg := ""
func _enh_items() -> Array:
	var P = game.P; var out: Array = []
	for k in D.SLOTS:
		if D.can_enhance(P.eq[k]): out.append({from = "eq", slot = k, i = -1, it = P.eq[k]})
	for i in P.bag.size():
		if D.can_enhance(P.bag[i]): out.append({from = "bag", slot = "", i = i, it = P.bag[i]})
	return out

func _render_enhance() -> void:
	_begin("talk", .72, BoxContainer.ALIGNMENT_CENTER)
	var P = game.P
	var vs = get_viewport().get_visible_rect().size
	var W: float = min(880.0, vs.x - 24)
	var head = HBoxContainer.new(); _center(head, W)
	var t = label("카엘 교수의 강화 마법진", 22, Color("#9fc8ff"), display); t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(t)
	head.add_child(label("강화석  %d" % int(P.get("stones", 0)), 17, Color("#bfe6ff"), bold))
	box.add_child(head)
	var cols = HBoxContainer.new(); cols.add_theme_constant_override("separation", 12); _center(cols, W)
	var left = PanelContainer.new(); left.add_theme_stylebox_override("panel", _pnl(Vector4(12, 10, 12, 10))); left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lv = VBoxContainer.new(); lv.add_theme_constant_override("separation", 6); left.add_child(lv)
	lv.add_child(label("강화할 수 있는 장비 (유니크 · 세트)", 14, MUTED))
	var list := _enh_items()
	if list.is_empty(): lv.add_child(label("아직 유니크나 세트 장비가 없어요.", 13, MUTED))
	var sel_it = null
	for e in list:
		var issel: bool = enh_sel != null and enh_sel.from == e.from and enh_sel.slot == e.slot and enh_sel.i == e.i
		if issel: sel_it = e.it
		var r = HBoxContainer.new(); r.add_theme_constant_override("separation", 8)
		var ee = e
		var pickf = func():
			enh_sel = ee; enh_msg = ""; _render_enhance()
		r.add_child(_slot(e.it, "", issel, 44, pickf))
		var nv = VBoxContainer.new(); nv.add_theme_constant_override("separation", 0); nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nv.add_child(label(iname(e.it), 14, Color(D.RAR[e.it.rar].color), bold))
		nv.add_child(label("%s · %s" % ["착용 중" if e.from == "eq" else "가방", D.slot_name(e.it.slot)], 11, MUTED))
		r.add_child(nv); lv.add_child(r)
	cols.add_child(left)
	var right = PanelContainer.new(); right.add_theme_stylebox_override("panel", _pnl(Vector4(14, 12, 14, 12))); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rv = VBoxContainer.new(); rv.add_theme_constant_override("separation", 6); right.add_child(rv)
	if sel_it == null:
		rv.add_child(label("왼쪽에서 장비를 고르세요.", 14, MUTED))
		var tb = "성공률: " + " · ".join(D.ENH_RATE.map(func(x): return "%d%%" % x))
		var tl = label(tb, 12, MUTED); tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; rv.add_child(tl)
		var t2 = label("한 번 성공할 때마다 옵션 +20%, 스킬 +1. 실패하면 강화석만 사라져요.", 12, MUTED); t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; rv.add_child(t2)
	else:
		var e: int = int(sel_it.get("enh", 0))
		rv.add_child(label(iname(sel_it), 17, Color(D.RAR[sel_it.rar].color), display))
		rv.add_child(label("지금 +%d  →  +%d" % [e, e + 1] if e < D.ENH_MAX else "최대 강화(+%d)" % D.ENH_MAX, 15, INK, bold))
		var now: Array = D.eff_mods(sel_it)
		var nxt_it = sel_it.duplicate(true); nxt_it.enh = e + 1
		var nxt: Array = D.eff_mods(nxt_it)
		for i in now.size():
			var hh = HBoxContainer.new(); hh.add_theme_constant_override("separation", 8)
			hh.add_child(label("• " + D.mod_text(now[i]), 13))
			if e < D.ENH_MAX and str(nxt[i].v) != str(now[i].v): hh.add_child(label("→ " + D.mod_text(nxt[i]), 13, GREEN))
			rv.add_child(hh)
		if e < D.ENH_MAX:
			rv.add_child(label("성공률 %d%% · 강화석 1개" % D.enh_rate(e), 15, Color("#bfe6ff"), bold))
			var go = func():
				var r: String = game.enhance(sel_it)
				match r:
					"ok":
						enh_msg = "성공! +%d가 되었다" % int(sel_it.enh); main.hud.show_toast("강화 성공 · %s" % iname(sel_it))
						game.ring(game.P.x, game.P.y, 6, 80, .6, "#9fc8ff"); game.burst(game.P.x, game.P.y, "#bfe6ff", 40, 200, .7, 3); game.rumble.emit(160, .6)
					"fail":
						enh_msg = "실패… 강화석이 부서졌다"; main.hud.show_toast("강화 실패"); game.rumble.emit(90, .4)
					"nostone": enh_msg = "강화석이 없어요"
				_render_enhance()
			var gb = btn("강화하기", go); gb.disabled = int(P.get("stones", 0)) <= 0
			rv.add_child(row([gb], false))
		if enh_msg != "": rv.add_child(label(enh_msg, 15, GREEN if enh_msg.begins_with("성공") else Color("#ff9a8a"), display))
	cols.add_child(right)
	box.add_child(cols)
	var tip = label("강화석은 보스와 이름 붙은 유니크 몬스터가 낮은 확률로 떨어뜨려요.", 12, MUTED); tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(tip)
	var closef = func():
		enh_sel = null; enh_msg = ""; close_talk()
	box.add_child(row([btn("닫기", closef)]))
	_focus_first()

func _small(s: StyleBoxFlat) -> StyleBoxFlat:
	var x = s.duplicate(); x.content_margin_left = 12; x.content_margin_right = 12; x.content_margin_top = 7; x.content_margin_bottom = 7; return x

func _portrait(n) -> Control:
	var c = Control.new(); c.custom_minimum_size = Vector2(84, 84); c.clip_contents = true
	var bgp = ColorRect.new(); bgp.color = Color("#0e0b14"); bgp.size = Vector2(84, 84); c.add_child(bgp)
	var sp: String = n.get("spr", n.id)
	var m: Dictionary = Actor.meta().get(sp, {})
	if m.has("fr"):
		var row_: int = int(m.anims.stance.row) + 6
		var f = m.fr[row_ * int(m.nf)]
		if f != null:
			var at = AtlasTexture.new(); at.atlas = load("res://assets/sprites/%s.png" % sp); at.region = Rect2(f[1], f[2], f[3], f[4])
			var hh: float = m.hgt * .6; var sc = 84.0 / hh
			var t = TextureRect.new(); t.texture = at; t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			# 머리 부분이 보이게(웹 drawPortrait 와 같은 자리)
			var sx: float = m.anchor[0] - hh * .5; var sy: float = m.anchor[1] - m.hgt * 1.03
			t.position = Vector2((f[5] - sx) * sc, (f[6] - sy) * sc); t.size = Vector2(f[3] * sc, f[4] * sc)
			if n.has("tint"): t.modulate = Color(n.tint).lerp(Color.WHITE, .45)
			c.add_child(t)
	return c

func close_talk() -> void:
	talk_npc = null; hide_all(); game.set_state("play"); game.save()

# ================= 가방 =================
var trade_bag := false     # 상인 미라와 거래 중에 연 가방이면 팔기 가능
func open_bag(trading := false) -> void:
	if game.G == null: return
	trade_bag = trading
	bag_sel = null; open_tab("bag")

func _sel_item():
	if bag_sel == null: return null
	return game.P.bag[bag_sel.i] if bag_sel.from == "bag" else game.P.eq[bag_sel.slot]

func _slot(it, lb: String, sel: bool, sz: float, fn: Callable) -> Button:
	var b = Button.new(); b.custom_minimum_size = Vector2(sz, sz); b.focus_mode = Control.FOCUS_ALL
	var s = sb(Color(.17, .14, .23), 7, Color(D.RAR[it.rar].color) if it != null else Color(.42, .36, .5), 2)
	if sel:
		s.border_color = INK
	b.add_theme_stylebox_override("normal", s); b.add_theme_stylebox_override("hover", s); b.add_theme_stylebox_override("pressed", s)
	if it != null:
		var t = TextureRect.new(); t.texture = load(gear_path(it)); t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.position = Vector2(sz * .08, sz * .06); t.size = Vector2(sz * .84, sz * .84); t.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(t)
	if lb != "":
		var l = label(lb, 10, MUTED); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.position = Vector2(0, sz - 15); l.size = Vector2(sz, 14); b.add_child(l)
	b.pressed.connect(func(): main.snd.play("click"))
	b.pressed.connect(fn)
	return b

func _render_bag() -> void:
	var keep_focus = ""
	var fo = get_viewport().gui_get_focus_owner()
	if fo and fo.has_meta("key"): keep_focus = fo.get_meta("key")
	_begin("bag", .9, BoxContainer.ALIGNMENT_BEGIN)
	game.recalc()
	var P = game.P; var G = game.G
	box.add_child(_tradebar() if trade_bag else _tabbar("bag"))
	# 화면 크기에 맞춰: 장비창 | 가방창 을 나란히, 자세히 보기는 밑(세로 여유가 있으면) 또는 옆
	var vs = get_viewport().get_visible_rect().size; var ins: Dictionary = main.hud.inset()
	var AW: float = vs.x - 32 - ins.l - ins.r; var AH: float = vs.y - 40 - ins.t - ins.b - 48
	var EH: float = clamp(AH - 6, 250.0, 340.0); var EW: float = clamp(EH * .84, 230.0, 290.0)
	var SL: float = clamp((EH - 70) / 5.2, 40.0, 54.0)          # 가방 칸 크기
	var below: bool = AH >= EH + 200                             # 세로가 넉넉하면(폴드 펼침 등) 자세히 보기는 아래로
	var cols := 6 if below else 4
	var IW: float = cols * SL + (cols - 1) * 5 + 28
	if not below and AW - EW - IW - 20 < 210: cols = 3; IW = cols * SL + (cols - 1) * 5 + 28
	var wrap = HBoxContainer.new(); wrap.add_theme_constant_override("separation", 10); wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# 왼쪽: 큰 장비창 — 뒤에 마법사 윤곽을 아주 옅게, 그 위에 7칸
	var ep = PanelContainer.new(); ep.add_theme_stylebox_override("panel", _pnl(Vector4(0, 0, 0, 0)))
	ep.custom_minimum_size = Vector2(EW, EH)
	var lay = Control.new(); lay.custom_minimum_size = Vector2(EW, EH); ep.add_child(lay)
	lay.add_child(_silhouette(EW, EH))
	var tl = label("장비", 17, GOLD, display); tl.position = Vector2(12, 8); lay.add_child(tl)
	var POS := {amulet = Vector2(.5, .15), weapon = Vector2(.17, .38), cloak = Vector2(.83, .38), ring1 = Vector2(.17, .62), ring2 = Vector2(.83, .62), belt = Vector2(.5, .62), gloves = Vector2(.17, .86), boots = Vector2(.83, .86)}
	for k in D.SLOTS:
		var sz: float = clamp(EH / 5.6, 46.0, 58.0)
		var b = _slot(P.eq[k], D.SLOTNAME[k], bag_sel != null and bag_sel.from == "eq" and bag_sel.slot == k, sz, func():
			if _dbl("eq:" + k) and P.eq[k] != null:
				if game.unequip(k): bag_sel = null      # 두 번 누르면 벗기
				_render_bag(); return
			bag_sel = {from = "eq", slot = k}; _render_bag())
		if P.eq[k] == null:
			var ph = TextureRect.new(); ph.texture = load("res://ui/slot_%s.png" % ("ring" if k.begins_with("ring") else k)); ph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ph.position = Vector2(sz * .12, sz * .06); ph.size = Vector2(sz * .76, sz * .76); ph.mouse_filter = Control.MOUSE_FILTER_IGNORE; b.add_child(ph)
		b.position = Vector2(POS[k].x * EW - sz / 2, POS[k].y * EH - sz / 2); b.set_meta("key", "eq:" + k); lay.add_child(b)
	wrap.add_child(ep)
	# 오른쪽: 가방창(칸은 상점에서 금화로 늘릴 수 있음)
	var ip = PanelContainer.new(); ip.add_theme_stylebox_override("panel", _pnl(Vector4(12, 8, 12, 10)))
	ip.custom_minimum_size = Vector2(IW, EH)
	var c2 = VBoxContainer.new(); c2.add_theme_constant_override("separation", 6); ip.add_child(c2)
	var hh = HBoxContainer.new(); c2.add_child(hh)
	var bt = label("가방 %d/%d" % [P.bag.size(), P.bagMax], 17, GOLD, display); bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hh.add_child(bt)
	hh.add_child(label("금화 %d · 강화석 %d" % [G.gold, int(P.get("stones", 0))], 13, Color("#ffd76a")))
	var ph_ = HBoxContainer.new(); ph_.add_theme_constant_override("separation", 10); c2.add_child(ph_)
	for pid in ["pothp", "potmp", "scroll"]:
		var ic_ = TextureRect.new(); ic_.texture = load("res://ui/item_%s.png" % pid); ic_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic_.custom_minimum_size = Vector2(22, 22); ph_.add_child(ic_)
		ph_.add_child(label("%d/%d" % [P.pot.get(pid, 0), game.pot_max(pid)], 13, INK))
	var gsc = ScrollContainer.new(); gsc.custom_minimum_size = Vector2(IW - 24, EH - 78); gsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var bg_ = GridContainer.new(); bg_.columns = cols; bg_.add_theme_constant_override("h_separation", 5); bg_.add_theme_constant_override("v_separation", 5)
	for i in P.bagMax:
		var it = P.bag[i] if i < P.bag.size() else null
		var b = _slot(it, "", bag_sel != null and bag_sel.from == "bag" and bag_sel.i == i, SL, func():
			if i >= P.bag.size(): return
			if not trade_bag and _dbl("bag:%d" % i):
				# 두 번 누르면 바로 착용(반지는 빈 칸 또는 약한 쪽)
				var bi = P.bag[i]; var slot: String = bi.slot
				if slot == "ring":
					slot = "ring1" if P.eq.ring1 == null else ("ring2" if P.eq.ring2 == null else ("ring1" if Game.sum_score(P.eq.ring1) <= Game.sum_score(P.eq.ring2) else "ring2"))
				bag_sel = {from = "bag", i = i}; _equip(slot, true); return
			bag_sel = {from = "bag", i = i}; _render_bag())
		b.set_meta("key", "bag:%d" % i); bg_.add_child(b)
	gsc.add_child(bg_); c2.add_child(gsc)
	wrap.add_child(ip)
	# 자세히
	var dt = PanelContainer.new(); dt.custom_minimum_size = Vector2(230, 90); dt.size_flags_horizontal = Control.SIZE_EXPAND_FILL; dt.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var dv = VBoxContainer.new(); dv.add_theme_constant_override("separation", 6); dt.add_child(dv)
	var it = _sel_item()
	if it == null and trade_bag:
		dv.add_child(label("물건 판매", 16, GOLD, display))
		dv.add_child(label("가방에서 팔 물건을 눌러 고르세요.", 14, INK))
		dv.add_child(label("고른 뒤 [판매]를 누르면 값을 알려 드려요.", 13, MUTED))
	elif it == null:
		dv.add_child(label("착용 효과", 14, GOLD, display))
		var tot = {}
		for k in D.SLOTS:
			var e = P.eq[k]
			if e != null:
				for m in e.mods: tot[m.k] = tot.get(m.k, 0) + m.v
		var es = HFlowContainer.new(); es.add_theme_constant_override("h_separation", 12)
		if tot.is_empty(): es.add_child(label("착용한 장비가 없어요.", 12, MUTED))
		for k in tot.keys(): es.add_child(label(D.mod_text({k = k, v = snappedf(tot[k], .01)}), 13, INK))
		dv.add_child(es)
		var p = label("아이템을 누르면 자세히, 두 번 누르면 바로 착용·벗기", 12, MUTED); dv.add_child(p)
		if not trade_bag: dv.add_child(label("장비 판매는 마을의 상인 미라와 거래할 때만 돼요.", 12, MUTED))
	else:
		dv.add_child(label(iname(it), 16, Color(D.RAR[it.rar].color), display))
		var bname: String = String(it.get("bname", D.base(it.base).names[D.tier(int(it.lvl))]))
		dv.add_child(label("%s · %s · %s · %d층에서 발견" % [D.RAR[it.rar].name, bname, D.slot_name(it.slot), int(it.lvl)], 12, MUTED))
		var mcol: Color = Color("#ffe6b0") if it.rar == "unique" else (Color("#a8f0a8") if it.rar == "set" else INK)
		for m in D.eff_mods(it): dv.add_child(label("• " + D.mod_text(m), 14, mcol))
		if int(it.get("enh", 0)) > 0: dv.add_child(label("강화 +%d (옵션 +%d%%, 스킬 +%d)" % [int(it.enh), int(it.enh) * 20, int(it.enh)], 12, GREEN))
		elif D.can_enhance(it): dv.add_child(label("마을의 카엘 교수가 강화석으로 강화해 줘요.", 12, MUTED))
		if it.get("set", "") != "":
			var S: Dictionary = D.SETS[it.set]; var cnt: int = game.set_count(it.set)
			dv.add_child(label("%s (%d/%d 착용)" % [S.name, cnt, S.pieces.size()], 13, Color(D.RAR.set.color), bold))
			for pc in S.pieces:
				var have := false
				for k in D.SLOTS:
					if P.eq[k] != null and P.eq[k].name == pc.name: have = true
				dv.add_child(label("  %s" % pc.name, 12, Color(D.RAR.set.color) if have else MUTED))
			var bks: Array = S.bonus.keys(); bks.sort()
			for n in bks:
				var parts: Array = []
				for b in S.bonus[n]: parts.append(D.mod_text({k = b[0], v = b[1]}))
				dv.add_child(label("  %d개: %s" % [n, ", ".join(parts)], 12, GREEN if cnt >= int(n) else MUTED))
		var rr = HFlowContainer.new(); rr.add_theme_constant_override("h_separation", 10); rr.add_theme_constant_override("v_separation", 8)
		var sbtn = func(t: String, fn: Callable, ghost: bool):
			var b = btn(t, fn, ghost); b.add_theme_font_size_override("font_size", 14)
			for st in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(st, _small(btn_sb(ghost)))
			rr.add_child(b)
		if trade_bag:
			# 판매 모드: 착용 버튼 대신 판매만
			if bag_sel.from == "bag":
				var ask = func(): _sell_ask(bag_sel.i)
				sbtn.call("판매", ask, false)
			else:
				dv.add_child(label("착용 중인 장비는 팔 수 없어요. 벗은 뒤 팔아 주세요.", 12, MUTED))
				var unf2 = func(): _unequip_sel()
				sbtn.call("벗기", unf2, true)
		elif bag_sel.from == "bag":
			var targets: Array = ["ring1", "ring2"] if it.slot == "ring" else [it.slot]
			var curs: Array = targets.map(func(k): return P.eq[k]).filter(func(x): return x != null)
			if curs.size():
				var basei = curs[0]
				if it.slot == "ring" and curs.size() > 1: basei = curs[0] if Game.sum_score(curs[0]) < Game.sum_score(curs[1]) else curs[1]
				var a = Game.sum_mods(it); var b2 = Game.sum_mods(basei)
				var ks = {}
				for k in a.keys() + b2.keys(): ks[k] = true
				dv.add_child(label("착용 중인 장비와 비교 · %s" % basei.name, 12, MUTED))
				# 좋아지는 점은 초록 ▲, 나빠지는 점(잃는 옵션 포함)은 빨강 ▼
				var ups: Array = []; var downs: Array = []
				for k in ks.keys():
					var dd = snappedf(a.get(k, 0) - b2.get(k, 0), .01)
					if dd == 0: continue
					(ups if dd > 0 else downs).append([k, dd])
				for u in ups: dv.add_child(label("▲ " + D.mod_text({k = u[0], v = absf(u[1])}), 13, Color("#7fe07f")))
				for d_ in downs: dv.add_child(label("▼ " + D.mod_text({k = d_[0], v = absf(d_[1])}).replace("+", "-"), 13, Color("#ff6a5a")))
				if ups.is_empty() and downs.is_empty(): dv.add_child(label("옵션이 똑같아요", 12, MUTED))
			if it.slot == "ring":
				var e1 = func(): _equip("ring1")
				var e2 = func(): _equip("ring2")
				sbtn.call("반지 1에 착용", e1, false)
				sbtn.call("반지 2에 착용", e2, false)
			else:
				var e0 = func(): _equip(it.slot)
				sbtn.call("착용", e0, false)
			var dropf = func():
				game.discard(bag_sel.i); bag_sel = null; _render_bag()
			sbtn.call("버리기", dropf, true)
		else:
			var unf = func():
				if game.unequip(bag_sel.slot):
					bag_sel = null
				_render_bag()
			sbtn.call("벗기", unf, false)
		dv.add_child(rr); dv.move_child(rr, 2)   # 착용·팔기 버튼은 이름 바로 아래(스크롤 없이 보이게)
	box.add_child(wrap)
	# 자세히 보기: 한 칸 높이를 넘치면 옆 칸으로 이어서(옆으로 밀어 계속 보기)
	var DW: float = (EW + IW + 10) if below else max(220.0, min(320.0, AW - EW - IW - 20))
	var DH: float = clamp(AH - EH - 30, 110.0, 260.0) if below else EH - 26
	var colw: float = 250.0 if below else DW - 30
	var kids: Array = dv.get_children()
	for c in kids: dv.remove_child(c)
	dt.remove_child(dv); dv.queue_free()
	var hb = HBoxContainer.new(); hb.add_theme_constant_override("separation", 22); dt.add_child(hb)
	var colv: VBoxContainer = null; var used := 9999.0
	for c in kids:
		var hgt: float = 46.0 if c is HFlowContainer else float(c.get_theme_font_size("font_size") if c is Label else 14) * 1.55 + 6
		if c is Label and c.get_theme_font_size("font_size") <= 0: hgt = 28.0
		if colv == null or used + hgt > DH:
			colv = VBoxContainer.new(); colv.add_theme_constant_override("separation", 6); colv.custom_minimum_size.x = colw; hb.add_child(colv); used = 0.0
		if c is Label:
			c.autowrap_mode = TextServer.AUTOWRAP_OFF; c.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; c.custom_minimum_size.x = colw; c.clip_text = true
		colv.add_child(c); used += hgt
	var dsc = ScrollContainer.new(); dsc.custom_minimum_size = Vector2(DW, DH + 26)
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; dsc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dt.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; dt.custom_minimum_size = Vector2(0, DH + 18)
	dsc.add_child(dt)
	if hb.get_child_count() > 1:
		var hint = label("옆으로 밀면 더 있어요 ›", 11, MUTED); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var holder = VBoxContainer.new(); holder.add_theme_constant_override("separation", 2); holder.add_child(dsc); holder.add_child(hint)
		if below:
			holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; box.add_child(holder)
		else: wrap.add_child(holder)
	else:
		if below:
			dsc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; box.add_child(dsc)
		else: wrap.add_child(dsc)
	main.hud.build_buttons()
	if keep_focus != "":
		await get_tree().process_frame
		var all: Array = []; _collect_focus(box, all)
		for c in all:
			if c.has_meta("key") and c.get_meta("key") == keep_focus:
				c.grab_focus(); return
	_focus_first()

# 판매 창 위쪽 띠: 무엇을 하는 화면인지 + 판매 버튼(물건을 고르면 켜짐)
func _tradebar() -> Control:
	var bar = HBoxContainer.new(); bar.add_theme_constant_override("separation", 12); _center(bar, 1040)
	var t = label("상인 미라 · 물건 판매", 19, GOLD, display); t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; bar.add_child(t)
	var can: bool = bag_sel != null and bag_sel.from == "bag" and bag_sel.i < game.P.bag.size()
	var h = label("물건을 누른 뒤 판매를 누르세요" if not can else "「%s」 판매할까요?" % iname(game.P.bag[bag_sel.i]), 14, INK if can else MUTED)
	h.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; h.clip_text = true; h.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bar.add_child(h)
	var sb_ = btn("판매", func(): _sell_sel())
	sb_.custom_minimum_size = Vector2(110, 40); sb_.disabled = not can
	if not can: sb_.modulate = Color(1, 1, 1, .4)
	sb_.set_meta("key", "trade:sell"); bar.add_child(sb_)
	bar.add_child(btn("가게로 돌아가기", func(): close_bag(), true))
	return bar

func _sell_sel() -> void:
	if bag_sel != null and bag_sel.from == "bag":
		_sell_ask(bag_sel.i)

func _unequip_sel() -> void:
	if bag_sel != null and bag_sel.from == "eq" and game.unequip(bag_sel.slot):
		bag_sel = null
	_render_bag()

# "판매하시겠습니까?" — 판매 값은 이때(상점에서 팔기 직전)만 보여 준다
func _sell_ask(i: int) -> void:
	if i < 0 or i >= game.P.bag.size() or root.get_node_or_null("sellask"): return
	var it = game.P.bag[i]
	var dim = ColorRect.new(); dim.name = "sellask"; dim.set_anchors_preset(Control.PRESET_FULL_RECT); dim.color = Color(0, 0, 0, .55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP; root.add_child(dim)
	var cc = CenterContainer.new(); cc.set_anchors_preset(Control.PRESET_FULL_RECT); dim.add_child(cc)
	var pn = PanelContainer.new(); pn.add_theme_stylebox_override("panel", sb(Color(.13, .105, .18, .98), 14, Color(D.RAR[it.rar].color), 2, Vector4(26, 18, 26, 18)))
	cc.add_child(pn)
	var v = VBoxContainer.new(); v.add_theme_constant_override("separation", 10); pn.add_child(v)
	var top = HBoxContainer.new(); top.add_theme_constant_override("separation", 12); top.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_child(top)
	var ic = TextureRect.new(); ic.texture = load(gear_path(it)); ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.custom_minimum_size = Vector2(52, 52); top.add_child(ic)
	var nm = VBoxContainer.new(); top.add_child(nm)
	nm.add_child(label(iname(it), 17, Color(D.RAR[it.rar].color), display))
	nm.add_child(label("%s · %s" % [D.RAR[it.rar].name, D.slot_name(it.slot)], 12, MUTED))
	var q = label("판매하시겠습니까?", 20, INK, display); q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(q)
	var pr = HBoxContainer.new(); pr.alignment = BoxContainer.ALIGNMENT_CENTER; pr.add_theme_constant_override("separation", 8); v.add_child(pr)
	pr.add_child(label("판매 가격", 15, MUTED)); pr.add_child(label("금화 %d" % int(it.value), 20, Color("#ffd76a"), display))
	var close = func():
		dim.queue_free(); _focus_first()
	var yes = btn("판매", func():
		var val: int = int(game.P.bag[i].value) if i < game.P.bag.size() else 0
		game.sell(i); bag_sel = null; dim.queue_free(); main.hud.show_toast("금화 +%d" % val); _render_bag())
	var no = btn("취소", close, true)
	v.add_child(row([yes, no]))
	pn.pivot_offset = pn.size / 2; pn.scale = Vector2(.92, .92); dim.modulate.a = 0.0
	_tw().tween_property(dim, "modulate:a", 1.0, .15); _tw().tween_property(pn, "scale", Vector2.ONE, .18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().process_frame
	if is_instance_valid(yes): yes.grab_focus()

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

var tap_key := ""
var tap_t := 0
func _dbl(key: String) -> bool:
	var now := Time.get_ticks_msec()
	var yes: bool = key == tap_key and now - tap_t < 420
	tap_key = "" if yes else key; tap_t = now
	return yes

func _equip(slot: String, quick := false) -> void:
	game.equip(bag_sel.i, slot); bag_sel = {from = "eq", slot = slot}
	if quick:
		# 두 번 눌러 착용: 선택·테두리를 비워서, 그 칸으로 밀려온 다른 물건이 선택된 것처럼 보이지 않게
		bag_sel = null; tap_key = ""
		var fo = get_viewport().gui_get_focus_owner()
		if fo: fo.release_focus()
	_render_bag()

# ================= 탭 창(디아블로식): 능력치 · 가방 · 마법 · 기록 · 설정 =================
const TABS := [["stats", "능력치"], ["bag", "가방"], ["magic", "마법"], ["record", "기록"], ["settings", "설정"]]
var tab := "bag"

func _pnl(pad := Vector4(14, 12, 14, 12)) -> StyleBoxFlat:
	var st = sb(Color(.13, .105, .18, .97), 12, Color(.62, .5, .3, .7), 1, pad)
	st.border_width_top = 2
	return st

func _tabbar(active: String) -> Control:
	var vs = get_viewport().get_visible_rect().size
	var bar = HBoxContainer.new(); bar.add_theme_constant_override("separation", 4); _center(bar, 1040)
	for t in TABS:
		var on: bool = t[0] == active
		var b = Button.new(); b.text = t[1]; b.focus_mode = Control.FOCUS_ALL; b.custom_minimum_size = Vector2(min(110.0, (vs.x - 140) / 5.0), 38)
		var st = sb(Color("#e3b04b") if on else Color(.2, .16, .26), 8, Color("#e3b04b") if on else Color(.45, .38, .52), 1, Vector4(10, 6, 10, 6))
		for k in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(k, st)
		b.add_theme_font_override("font", bold); b.add_theme_font_size_override("font_size", 15)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(k, Color("#1b1206") if on else INK)
		var id: String = t[0]
		b.pressed.connect(func():
			main.snd.play("book"); open_tab(id))
		b.set_meta("key", "tab:" + id)
		bar.add_child(b)
	var sp = Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bar.add_child(sp)
	var cb = btn("닫기", func(): close_bag()); bar.add_child(cb)
	return bar

func open_tab(id: String) -> void:
	if game.G == null: return
	_no_title_grad()
	game.set_state("bag"); tab = id
	if id == "bag":
		game.G.bagNew = false; _render_bag(); return
	_begin("bag", .9, BoxContainer.ALIGNMENT_BEGIN)
	box.add_child(_tabbar(id))
	var body = PanelContainer.new(); body.add_theme_stylebox_override("panel", _pnl()); _center(body, 900)
	box.add_child(body)
	match id:
		"stats": _tab_stats(body)
		"magic": _tab_magic(body)
		"record": _tab_record(body)
		"settings": _tab_settings(body)
	await get_tree().process_frame
	var all: Array = []; _collect_focus(box, all)
	for c in all:
		if c.has_meta("key") and c.get_meta("key") == "tab:" + id:
			c.grab_focus(); return

const GREEN := Color("#7fe07f")

# 이름 | 값 (+장비 보너스는 초록)
func _statrow(g: GridContainer, name: String, val: String, bonus := "") -> void:
	g.add_child(label(name, 14, MUTED))
	var h = HBoxContainer.new(); h.add_theme_constant_override("separation", 8)
	h.add_child(label(val, 15, INK, bold))
	if bonus != "": h.add_child(label(bonus, 14, GREEN))
	g.add_child(h)

func _tab_stats(body: Control) -> void:
	var P = game.P; var G = game.G; game.recalc()
	var st: Dictionary = P.st; var pv: Dictionary = P["pass"]
	var cols = HFlowContainer.new(); cols.add_theme_constant_override("h_separation", 30); cols.add_theme_constant_override("v_separation", 10); body.add_child(cols)
	var mk = func(title: String) -> GridContainer:
		var v = VBoxContainer.new(); v.add_theme_constant_override("separation", 6); v.custom_minimum_size.x = 250; cols.add_child(v)
		v.add_child(label(title, 17, GOLD, display))
		var g = GridContainer.new(); g.columns = 2; g.add_theme_constant_override("h_separation", 16); g.add_theme_constant_override("v_separation", 5); v.add_child(g)
		return g
	var pct = func(v: float) -> String: return "+%d%%" % int(round(v * 100)) if v > 0.0001 else ""
	var g1: GridContainer = mk.call("기본")
	_statrow(g1, "레벨", str(P.lv))
	_statrow(g1, "경험치", "%d / %d" % [P.xp, P.next])
	_statrow(g1, "생명", "%d / %d" % [ceili(P.hp), P.maxhp], "+%d" % int(st.hp) if st.hp > 0 else "")
	_statrow(g1, "마나", "%d / %d" % [floori(P.mp), P.maxmp], "+%d" % int(st.mp) if st.mp > 0 else "")
	var regen: float = 8 * (1 + .25 * pv.get("calm", 0) + st.regen) + .3 * P.lv
	_statrow(g1, "마나 회복", "%.1f / 초" % regen, "(%s)" % pct.call(st.regen) if st.regen > 0 else "")
	_statrow(g1, "생명 회복", "0.4 / 초")
	_statrow(g1, "이동 속도", "%d" % int(P.speed), "(%s)" % pct.call(st.spd) if st.spd > 0 else "")
	var g2: GridContainer = mk.call("전투")
	var might: float = (1 + .12 * pv.get("might", 0)) * (1 + st.dmg)
	_statrow(g2, "레벨 보너스", "기본 피해 +%d" % int(game.lv_bonus()))
	_statrow(g2, "마법 피해", "×%.2f" % might, "(%s)" % pct.call(st.dmg) if st.dmg > 0 else "")
	_statrow(g2, "시전 속도", "×%.2f" % ((1 + .12 * pv.get("quick", 0)) * (1 + st.cast)), "(%s)" % pct.call(st.cast) if st.cast > 0 else "")
	_statrow(g2, "보조 마법 대기", "-%d%%" % int(round((1 - (1 - .12 * pv.get("focus", 0)) * (1 - st.cdr)) * 100)), "(-%d%%)" % int(round(st.cdr * 100)) if st.cdr > 0 else "")
	_statrow(g2, "받는 피해", "-%d%%" % int(round(min(.5, st.res) * 100)), "(장비)" if st.res > 0 else "")
	_statrow(g2, "금화 획득", "+%d%%" % int(round(st.gold * 100)), "(장비)" if st.gold > 0 else "")
	if P.active != null:
		var a: Dictionary = game.attack_of(P.active)
		if a.kind == "shot": _statrow(g2, a.name, "피해 %d~%d · 마나 %.1f" % [int(a.dmg[0]), int(a.dmg[1]), a.mana])
		else: _statrow(g2, a.name, "초당 %d · 마나 %.1f/초" % [int(a.dps), a.manaps])
	var g3: GridContainer = mk.call("마법 단계 (장비 포함)")
	for id in D.PRIM_ORDER:
		if P.ep.get(id, 0) > 0:
			var b: int = int(P.bonus.prim.get(id, 0))
			_statrow(g3, D.PRIMARIES[id].name, "%d단계" % P.ep[id], "+%d" % b if b > 0 else "")
	for sd in D.SUBS:
		if P.es.get(sd.id, 0):
			var b: int = int(P.bonus.sub.get(sd.id, 0))
			_statrow(g3, sd.name, "%d단계" % P.es[sd.id], "+%d" % b if b > 0 else "")
	for id in P.secOrder:
		var b: int = int(P.bonus.sec.get(id, 0))
		_statrow(g3, D.sec(id).name, "%d단계" % P.esec.get(id, P.sec[id]), "+%d" % b if b > 0 else "")
	var note = label("초록색 숫자는 장비로 늘어난 만큼이에요.", 12, GREEN); body.get_child(0).add_child(note)

func _tab_magic(body: Control) -> void:
	var P = game.P
	var v = VBoxContainer.new(); v.add_theme_constant_override("separation", 6); body.add_child(v)
	var row_ = func(icon: Dictionary, name: String, lv: String, desc: String):
		var h = HBoxContainer.new(); h.add_theme_constant_override("separation", 10)
		var t = TextureRect.new(); t.texture = load(icon_path(icon)); t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; t.custom_minimum_size = Vector2(40, 40); h.add_child(t)
		var nv = VBoxContainer.new(); nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nv.add_theme_constant_override("separation", 0); h.add_child(nv)
		var top = HBoxContainer.new(); nv.add_child(top)
		var nl = label(name, 15, INK, bold); nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(nl); top.add_child(label(lv, 14, GOLD))
		var dl = label(desc, 12, MUTED); dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; nv.add_child(dl)
		v.add_child(h)
	var any := false
	for id in D.PRIM_ORDER:
		if P.prim[id]:
			any = true; row_.call({t = "el", el = id}, D.PRIMARIES[id].name, "%d단계" % P.prim[id], D.PRIMARIES[id].desc)
	if P.fusion != null:
		var ks: PackedStringArray = String(P.fusion).split("+")
		row_.call({t = "fusion", a = ks[0], b = ks[1]}, D.FUSIONS[P.fusion].name, "융합", D.FUSIONS[P.fusion].desc)
	for sd in D.SUBS:
		if P.subs.get(sd.id, 0): row_.call({t = "sub", el = sd.of, id = sd.id}, sd.name, "%d단계" % P.subs[sd.id], sd.desc)
	for id in P.secOrder: row_.call({t = "sec", id = id}, D.sec(id).name, "%d단계" % P.sec[id], D.sec(id).desc)
	for sd in D.PASSIVES:
		if P["pass"].get(sd.id, 0): row_.call({t = "pass", id = sd.id}, sd.name, "%d단계" % P["pass"][sd.id], sd.desc)
	if not any: v.add_child(label("아직 익힌 마법이 없어요.", 14, MUTED))

func _tab_record(body: Control) -> void:
	var G = game.G; var P = game.P
	var v = VBoxContainer.new(); v.add_theme_constant_override("separation", 8); body.add_child(v)
	var g0 = GridContainer.new(); g0.columns = 2; g0.add_theme_constant_override("h_separation", 16); v.add_child(g0)
	_statrow(g0, "최고 도달", "%d층" % max(G.resume, G.floor))
	_statrow(g0, "총 처치", "%d마리" % G.kills)
	_statrow(g0, "가진 금화", "%d" % G.gold)
	_statrow(g0, "웨이포인트", ", ".join(G.waypoints.map(func(w): return "%d층" % w)))
	v.add_child(label("몬스터별 처치 수", 17, GOLD, display))
	var ks: Array = G.killsBy.keys()
	ks.sort_custom(func(a, b): return G.killsBy[a] > G.killsBy[b])
	var g = GridContainer.new(); g.columns = 4; g.add_theme_constant_override("h_separation", 18); g.add_theme_constant_override("v_separation", 4); v.add_child(g)
	if ks.is_empty(): v.add_child(label("아직 쓰러뜨린 몬스터가 없어요.", 13, MUTED))
	for k in ks:
		var nm: String = D.MONSTERS[k].name if D.MONSTERS.has(k) else String(k)
		g.add_child(label(nm, 14, Color("#ffd0c0") if not D.MONSTERS.has(k) else INK)); g.add_child(label("%d" % G.killsBy[k], 14, GOLD, bold))

func _tab_settings(body: Control) -> void:
	var v = VBoxContainer.new(); v.add_theme_constant_override("separation", 10); body.add_child(v)
	var swf = func():
		main.pad_swap = not main.pad_swap; main.save_settings(); open_tab("settings")
	v.add_child(label("컨트롤러", 17, GOLD, display))
	v.add_child(row([btn("버튼 배치: %s" % ("닌텐도식 (A·B 바꿈)" if main.pad_swap else "엑스박스식"), swf, true)], false))
	var pi = label("연결됨: %s" % main.pad_name() if main.pad_connected() else "컨트롤러를 연결하면 바로 쓸 수 있어요 (유선·블루투스).", 12, MUTED); v.add_child(pi)
	v.add_child(label("화면", 17, GOLD, display))
	var qf = func(q):
		main.set_quality(q); open_tab("settings")
	var qr: Array = []
	for q in [[1.0, "선명하게"], [.85, "보통"], [.7, "가볍게"]]:
		var b = _chip(HBoxContainer.new(), q[1], qf.bind(q[0]), absf(main.quality - q[0]) < .01)
		b.get_parent().remove_child(b); qr.append(b)
	v.add_child(row(qr, false))
	v.add_child(label("가볍게를 고르면 화면 해상도를 낮춰서 덜 뜨겁고 더 부드러워져요.", 12, MUTED))
	var fpsf = func():
		main.show_fps = not main.show_fps; main.save_settings(); open_tab("settings")
	v.add_child(row([btn("FPS 표시: %s" % ("켜짐" if main.show_fps else "꺼짐"), fpsf, true)], false))
	v.add_child(label("소리", 17, GOLD, display))
	for kind in [["배경음", "music"], ["효과음", "sfx"]]:
		var cr: Array = []
		var kk: String = kind[1]
		for lv in [[0.0, "끔"], [.35, "작게"], [.7, "보통"], [1.0, "크게"]]:
			var cur_v: float = main.snd.music_vol if kk == "music" else main.snd.sfx_vol
			var setf = func(vv):
				if kk == "music": main.snd.set_music_vol(vv)
				else: main.snd.sfx_vol = vv
				main.save_settings(); open_tab("settings")
			var b = _chip(HBoxContainer.new(), lv[1], setf.bind(lv[0]), absf(cur_v - lv[0]) < .05)
			b.get_parent().remove_child(b); cr.append(b)
		var hr = HBoxContainer.new(); hr.add_theme_constant_override("separation", 8)
		var nl = label(kind[0], 14, INK); nl.custom_minimum_size.x = 60; hr.add_child(nl)
		for b in cr: hr.add_child(b)
		v.add_child(hr)
	v.add_child(label("자동 저장", 17, GOLD, display))
	var af = func(mn):
		main.autosave_min = mn; main.autosave_t = 0.0; main.save_settings(); open_tab("settings")
	var ar: Array = []
	for mn in [5, 10, 15, 30]:
		var b = _chip(HBoxContainer.new(), "%d분마다" % mn, af.bind(mn), main.autosave_min == mn)
		b.get_parent().remove_child(b); ar.append(b)
	v.add_child(row(ar, false))
	var al = label("정해 둔 간격마다, 그리고 화면을 끄거나 층을 오르거나 포탈을 타거나 일시정지할 때 저장돼요. (%d번 칸 · %s)" % [Game.slot + 1, String(game.P.get("name", ""))], 12, MUTED)
	al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(al)
	v.add_child(label("게임", 17, GOLD, display))
	var savef = func():
		game.save(); main.hud.show_toast("저장했어요")
	v.add_child(row([btn("지금 저장", savef, true), btn("처음 화면으로", func(): main.to_title(), true)], false))
	var ver := "개발판"
	if FileAccess.file_exists("res://version.txt"): ver = FileAccess.get_file_as_string("res://version.txt").strip_edges()
	v.add_child(label("버전 %s" % ver, 12, MUTED))

# ================= 전체 지도(미니맵을 누르면) =================
class MapView extends Control:
	var ui
	func _draw() -> void:
		var game: Game = ui.game; var mg := game.mg
		var vs := get_viewport_rect().size
		draw_rect(Rect2(Vector2(), vs), Color(.02, .015, .04, .93))
		var k: float = min((vs.x - 40) / MapGen.MW, (vs.y - 70) / MapGen.MH)
		var o := Vector2((vs.x - MapGen.MW * k) / 2, 50 + (vs.y - 70 - MapGen.MH * k) / 2)
		for j in MapGen.MH:
			for i in MapGen.MW:
				var kk := j * MapGen.MW + i
				if not mg.seen[kk]: continue
				var c := Color8(96, 82, 118) if mg.map[kk] == 0 else Color8(40, 32, 52)
				draw_rect(Rect2(o + Vector2(i, j) * k, Vector2(k + .5, k + .5)), c)
		var s: float = k / 32.0
		var st = mg.stairs
		if st != null and st.found: draw_circle(o + Vector2(st.x, st.y) * s, k * .9, Color("#ffd76a"))
		if mg.door != null and mg.is_seen(mg.door.x, mg.door.y): draw_circle(o + Vector2(mg.door.x, mg.door.y) * s, k * .8, Color("#9fd0ff"))
		if game.G.portal != null: draw_circle(o + Vector2(game.G.portal.x, game.G.portal.y) * s, k * .8, Color("#7fb2ff"))
		for c in game.G.chests:
			if not c.open and mg.is_seen(c.x, c.y): draw_rect(Rect2(o + Vector2(c.x, c.y) * s - Vector2(k * .4, k * .4), Vector2(k * .8, k * .8)), Color("#e3b04b"))
		var P = game.P; var pp: Vector2 = o + Vector2(P.x, P.y) * s; var dl := Vector2(cos(P.face), sin(P.face))
		draw_colored_polygon(PackedVector2Array([pp + dl * k * 2, pp + dl.rotated(2.4) * k * 1.3, pp + dl.rotated(-2.4) * k * 1.3]), Color.WHITE)
		draw_circle(pp, k * .7, Color("#7fe0ff"))
		var f: Font = Ui.display
		var t: String = ("옥상" if game.G.floor == D.ROOF else "%d층" % game.G.floor) if game.G.floor else "마을"
		draw_string(f, Vector2(20, 34), "%s 지도 · 화면을 누르면 돌아가요" % t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#e3b04b"))
	func _gui_input(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or ev.is_action_pressed("ui_accept") or ev.is_action_pressed("ui_cancel"):
			accept_event(); ui.close_map()

func open_map() -> void:
	if game.G == null or game.G.state != "play": return
	_no_title_grad(); _begin("map", 0.0)
	game.set_state("map")
	var mv = MapView.new(); mv.ui = self; mv.set_anchors_preset(Control.PRESET_FULL_RECT); mv.name = "mapview"; mv.focus_mode = Control.FOCUS_ALL
	var old = root.get_node_or_null("mapview")
	if old: old.queue_free()
	root.add_child(mv); mv.grab_focus()

func close_map() -> void:
	var old = root.get_node_or_null("mapview")
	if old: old.queue_free()
	hide_all(); game.set_state("play")

func close_bag() -> void:
	var sa = root.get_node_or_null("sellask")
	if sa:
		sa.queue_free(); return          # 판매 확인창이 떠 있으면 그것만 닫기
	var c = root.get_node_or_null("bagclose")
	if c: c.queue_free()
	if trade_bag:
		# 거래 중 연 가방이면 다시 가게로
		trade_bag = false
		for n in game.G.npcs:
			if n.id == "shop":
				open_talk(n); return
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
		main.snd.play("click"); fn.call(); _render_sand())
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
	for f in range(1, D.ROOF + 1):
		if f > 20 and f % 5 != 0 and f % 10 != 1 and f != D.LAST_FLOOR: continue
		var gf = func(): game.sand_goto(f)
		_chip(c, "옥상" if f == D.ROOF else ("%d★" % f if D.boss_kind(f) != "" else str(f)), gf, f == G.floor)
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
	for r in D.RAR_ORDER:
		_chip(c, "%s 장비" % D.RAR[r].name, func():
			if P.bag.size() < P.bagMax:
				P.bag.append(game.make_item(r, max(1, G.floor))); G.bagNew = true)
	_chip(c, "강화석 +5", func(): P.stones = int(P.get("stones", 0)) + 5)
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
		"slots":
			del_ask = -1; open_title(); return true
		"start": return false
		"first": main.first_back(); return true
		"talk": close_talk(); return true
		"bag": close_bag(); return true
		"sand", "pause": main.resume(); return true
		"gate":
			hide_all(); game.set_state("play"); return true
		"map":
			close_map(); return true
		"level", "end": return true
	return false
