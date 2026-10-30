# 화면 위 UI(1단계): 층 이름, FPS, 가상 조이스틱, 화면 전환 페이드
class_name Hud
extends CanvasLayer

var stick := Vector2()
var root := Control.new()
var info := Label.new()
var big := Label.new()
var fader := ColorRect.new()
var pad := StickPad.new()

func _ready() -> void:
	root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	pad.set_anchors_preset(Control.PRESET_FULL_RECT); pad.hud = self
	root.add_child(pad)
	info.position = Vector2(24, 16)
	info.add_theme_font_size_override("font_size", 22)
	info.add_theme_color_override("font_color", Color(1, .93, .78))
	info.add_theme_color_override("font_outline_color", Color(0, 0, 0, .9))
	info.add_theme_constant_override("outline_size", 6)
	root.add_child(info)
	big.set_anchors_preset(Control.PRESET_CENTER_TOP); big.position.y = 70
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_size_override("font_size", 46)
	big.add_theme_color_override("font_color", Color(1, .86, .5))
	big.add_theme_color_override("font_outline_color", Color(.1, .05, 0, .95))
	big.add_theme_constant_override("outline_size", 10)
	big.grow_horizontal = Control.GROW_DIRECTION_BOTH
	big.modulate.a = 0
	root.add_child(big)
	fader.color = Color(0, 0, 0, 1); fader.set_anchors_preset(Control.PRESET_FULL_RECT)
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE; fader.modulate.a = 0
	root.add_child(fader)

func set_info(where: String, fps: float) -> void:
	info.text = "%s   ·   %d FPS" % [where, int(fps)]

func banner(t: String) -> void:
	big.text = t
	var tw := create_tween()
	tw.tween_property(big, "modulate:a", 1.0, .35)
	tw.tween_interval(1.6)
	tw.tween_property(big, "modulate:a", 0.0, .6)

func fade(to: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(fader, "modulate:a", to, dur)
	await tw.finished
