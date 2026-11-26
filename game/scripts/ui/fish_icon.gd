class_name FishIcon
extends Control
## 2D fish picture drawn from the species colours/shape (used in the catch popup).

var species: DataTypes.FishSpecies
var mutation := ""


func _init() -> void:
	custom_minimum_size = Vector2(260, 140)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_fish(f: Dictionary) -> void:
	species = Data.fish.get(f.get("sp", ""))
	mutation = f.get("mut", "")
	queue_redraw()


func _draw() -> void:
	if species == null:
		return
	var c := size * 0.5
	var asp := Vector2(1.0, 0.62)
	match species.shape:
		1: asp = Vector2(0.85, 0.85)
		2: asp = Vector2(1.25, 0.34)
		3: asp = Vector2(1.0, 0.4)
		4: asp = Vector2(1.15, 0.58)
	var rx := size.x * 0.32 * asp.x
	var ry := size.y * 0.5 * asp.y
	var halo := Color.TRANSPARENT
	match mutation:
		"shiny": halo = Color(0.5, 0.95, 1.0, 0.35)
		"albino": halo = Color(1, 1, 1, 0.35)
		"golden": halo = Color(1.0, 0.85, 0.3, 0.4)
		"void": halo = Color(0.6, 0.3, 0.9, 0.45)
		"giant": halo = Color(1.0, 0.5, 0.3, 0.25)
	if halo.a > 0.0:
		draw_circle(c, minf(maxf(rx, ry) * 1.2, size.y * 0.5), halo)
	var c1 := species.c1
	var c2 := species.c2
	match mutation:
		"albino": c1 = Color(0.97, 0.95, 0.9); c2 = Color(1, 0.8, 0.85)
		"golden": c1 = Color(1.0, 0.82, 0.25); c2 = Color(1.0, 0.95, 0.6)
		"void": c1 = Color(0.18, 0.08, 0.3); c2 = Color(0.5, 0.2, 0.8)
		"shiny": c1 = c1.lightened(0.35); c2 = c2.lightened(0.35)
	# tail
	var tx := c.x - rx
	draw_colored_polygon(PackedVector2Array([
		Vector2(tx + 6, c.y), Vector2(tx - rx * 0.55, c.y - ry * 0.9), Vector2(tx - rx * 0.4, c.y), Vector2(tx - rx * 0.55, c.y + ry * 0.9)]), c2)
	# dorsal fin
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - rx * 0.2, c.y - ry * 0.85), Vector2(c.x + rx * 0.1, c.y - ry * 1.5), Vector2(c.x + rx * 0.35, c.y - ry * 0.8)]), c2)
	# body (two tone)
	var pts := PackedVector2Array()
	var pts2 := PackedVector2Array()
	for i in 40:
		var a := TAU * float(i) / 40.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		if sin(a) > -0.05:
			pts2.append(c + Vector2(cos(a) * rx * 0.97, sin(a) * ry * 0.97))
	draw_colored_polygon(pts, c1)
	if pts2.size() > 2:
		draw_colored_polygon(pts2, c2)
	# eye
	var eye := c + Vector2(rx * 0.55, -ry * 0.2)
	draw_circle(eye, ry * 0.2, Color.WHITE)
	draw_circle(eye + Vector2(2, 0), ry * 0.1, Color.BLACK)
