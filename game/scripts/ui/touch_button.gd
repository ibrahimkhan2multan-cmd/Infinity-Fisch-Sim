class_name TouchButton
extends Control
## A round on-screen button. It does not use Godot's GUI input (which only
## follows one finger); TouchControls hit-tests every finger and drives
## `set_down`, so several buttons + the joystick work at the same time.

signal pressed_down
signal released
signal tapped

var text := "" : set = _set_text
var radius := 60.0
var tint := Color(0.18, 0.62, 0.82)
var is_down := false
var pulse := false
var highlighted := false : set = _set_hl
var font_size := 24


func _init(p_text := "", p_radius := 60.0, p_tint := Color(0.18, 0.62, 0.82)) -> void:
	text = p_text
	radius = p_radius
	tint = p_tint
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = custom_minimum_size
	add_to_group("touch_button")


func _set_text(v: String) -> void:
	if v != text:
		text = v
		queue_redraw()


func _set_hl(v: bool) -> void:
	if v != highlighted:
		highlighted = v
		queue_redraw()


func center() -> Vector2:
	return global_position + size * 0.5


func contains(p: Vector2) -> bool:
	return visible and p.distance_to(center()) <= radius * 1.15


func set_down(v: bool) -> void:
	if v == is_down:
		return
	is_down = v
	queue_redraw()
	if v:
		pressed_down.emit()
	else:
		released.emit()


func _process(_delta: float) -> void:
	if pulse:
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var col := tint
	if is_down:
		col = tint.lightened(0.35)
	var a := 0.78 if not is_down else 0.95
	if pulse:
		var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.016)
		col = col.lerp(Color(1.0, 0.85, 0.2), k)
	draw_circle(c, radius, Color(0, 0, 0, 0.35))
	draw_circle(c, radius - 3.0, Color(col.r, col.g, col.b, a))
	draw_arc(c, radius - 3.0, 0.0, TAU, 48, Color(1, 1, 1, 0.8 if highlighted else 0.45), 3.0, true)
	var font := ThemeDB.fallback_font
	var lines := text.split("\n")
	var fs := font_size
	var total_h := lines.size() * (fs + 2.0)
	var y := c.y - total_h * 0.5 + fs * 0.85
	for l in lines:
		draw_string(font, Vector2(c.x - radius, y), l, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, fs, Color.WHITE)
		y += fs + 2.0
