# 왼쪽 화면 어디를 눌러도 생기는 이동 조이스틱(웹 버전과 같은 방식)
class_name StickPad
extends Control

var hud
var touch_id := -1
var origin := Vector2()
var cur := Vector2()
const R := 70.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.pressed and touch_id < 0 and ev.position.x < get_viewport_rect().size.x * .5:
			touch_id = ev.index; origin = ev.position; cur = ev.position
		elif not ev.pressed and ev.index == touch_id:
			touch_id = -1; hud.stick = Vector2.ZERO
		queue_redraw()
	elif ev is InputEventScreenDrag and ev.index == touch_id:
		cur = ev.position
		var d := cur - origin
		if d.length() > R: origin = cur - d.normalized() * R
		d = cur - origin
		hud.stick = d / 48.0 if d.length() > 6 else Vector2.ZERO
		if hud.stick.length() > 1: hud.stick = hud.stick.normalized()
		queue_redraw()

func _draw() -> void:
	if touch_id < 0: return
	draw_circle(origin, R, Color(1, 1, 1, .06))
	draw_arc(origin, R, 0, TAU, 48, Color(1, .9, .7, .35), 2.0, true)
	draw_circle(origin + (cur - origin).limit_length(R), 26, Color(1, .9, .7, .3))
