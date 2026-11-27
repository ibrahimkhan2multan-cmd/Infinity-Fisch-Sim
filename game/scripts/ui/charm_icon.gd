class_name CharmIcon
extends Control
## Hand-drawn 2D icon for a charm (drawn in code, no image files).

var charm_id := ""
var tint := Color("ffd23f")
var ring := Color("8899aa")


static func make(c: DataTypes.Charm, px := 56.0) -> CharmIcon:
	var i := CharmIcon.new()
	i.charm_id = c.id
	i.tint = c.color
	i.ring = Util.rarity_color(c.rarity)
	i.custom_minimum_size = Vector2(px, px)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return i


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 0.0:
		s = 56.0
	var c := Vector2(s, s) * 0.5
	var r := s * 0.5
	# plate
	draw_circle(c, r - 1.0, Color(0.1, 0.13, 0.18, 0.95))
	draw_arc(c, r - 2.0, 0.0, TAU, 40, ring, 3.0, true)
	var u := r * 0.62   # drawing unit inside the plate
	var hi := tint.lightened(0.35)
	var lo := tint.darkened(0.3)
	match charm_id:
		"clover":
			for k in 4:
				var a := PI * 0.25 + k * PI * 0.5
				var lc := c + Vector2(cos(a), sin(a)) * u * 0.42
				draw_circle(lc, u * 0.42, tint)
				draw_circle(lc + Vector2(-2, -2), u * 0.16, hi)
			draw_line(c + Vector2(0, u * 0.1), c + Vector2(u * 0.35, u * 0.95), lo, 3.0, true)
		"shell":
			var pts := PackedVector2Array([c + Vector2(0, u * 0.85)])
			for k in 11:
				var a := lerpf(PI * 1.1, PI * 1.9, k / 10.0)
				pts.append(c + Vector2(cos(a) * u * 1.0, sin(a) * u * 1.0 + u * 0.3))
			draw_colored_polygon(pts, tint)
			for k in 5:
				var a2 := lerpf(PI * 1.2, PI * 1.8, k / 4.0)
				draw_line(c + Vector2(0, u * 0.85), c + Vector2(cos(a2) * u, sin(a2) * u + u * 0.3), lo, 2.0, true)
			draw_rect(Rect2(c + Vector2(-u * 0.28, u * 0.75), Vector2(u * 0.56, u * 0.18)), lo)
		"knot":
			draw_arc(c + Vector2(-u * 0.32, 0), u * 0.55, 0.0, TAU, 28, tint, 5.0, true)
			draw_arc(c + Vector2(u * 0.32, 0), u * 0.55, 0.0, TAU, 28, hi, 5.0, true)
		"coin":
			draw_circle(c, u * 0.95, lo)
			draw_circle(c, u * 0.85, tint)
			draw_arc(c, u * 0.62, 0.0, TAU, 28, hi, 2.5, true)
			draw_string(ThemeDB.fallback_font, c + Vector2(-u * 0.22, u * 0.3), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, int(u * 1.0), lo)
		"moonstone":
			var pts2 := PackedVector2Array()
			for k in 17:
				var a3 := lerpf(-PI * 0.5, PI * 1.5, k / 16.0)
				pts2.append(c + Vector2(cos(a3), sin(a3)) * u * 0.95)
			draw_colored_polygon(pts2, tint)
			var pts3 := PackedVector2Array()
			for k in 17:
				var a4 := lerpf(-PI * 0.5, PI * 1.5, k / 16.0)
				pts3.append(c + Vector2(u * 0.4, -u * 0.05) + Vector2(cos(a4), sin(a4)) * u * 0.78)
			draw_colored_polygon(pts3, Color(0.1, 0.13, 0.18, 1.0))
			draw_circle(c + Vector2(-u * 0.35, -u * 0.3), u * 0.12, Color.WHITE)
		"horseshoe":
			draw_arc(c + Vector2(0, -u * 0.1), u * 0.62, PI * 0.12, PI * 0.88 + PI, 24, tint, u * 0.42, true)
			for k in 3:
				var ang := lerpf(PI * 1.15, PI * 1.85, k / 2.0) + PI
				draw_circle(c + Vector2(0, -u * 0.1) + Vector2(cos(ang), sin(ang)) * u * 0.62, 2.2, lo)
		"pearl":
			draw_circle(c, u * 0.8, tint)
			draw_circle(c + Vector2(-u * 0.25, -u * 0.25), u * 0.28, Color(1, 1, 1, 0.75))
			draw_arc(c, u * 0.9, 0.0, PI, 20, lo, 3.0, true)
		"starfall":
			var star := PackedVector2Array()
			for k in 10:
				var a5 := -PI * 0.5 + k * PI / 5.0
				var rr := u * (0.95 if k % 2 == 0 else 0.4)
				star.append(c + Vector2(cos(a5), sin(a5)) * rr)
			draw_colored_polygon(star, tint)
			draw_circle(c, u * 0.18, hi)
		"tooth":
			var tp := PackedVector2Array([c + Vector2(-u * 0.6, -u * 0.8), c + Vector2(u * 0.6, -u * 0.8),
				c + Vector2(u * 0.4, u * 0.1), c + Vector2(u * 0.05, u * 0.95), c + Vector2(-u * 0.25, u * 0.2)])
			draw_colored_polygon(tp, tint)
			draw_line(c + Vector2(-u * 0.3, -u * 0.6), c + Vector2(-u * 0.05, u * 0.6), hi, 3.0, true)
		"infinity":
			var pl := PackedVector2Array()
			for k in 41:
				var t := TAU * k / 40.0
				var den := 1.0 + sin(t) * sin(t)
				pl.append(c + Vector2(cos(t) / den, sin(t) * cos(t) / den) * u * 1.05)
			draw_polyline(pl, tint, 5.0, true)
			draw_polyline(pl, hi, 1.5, true)
		_:
			draw_circle(c, u * 0.6, tint)
