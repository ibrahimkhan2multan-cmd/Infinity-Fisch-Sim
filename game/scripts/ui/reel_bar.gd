class_name ReelBar
extends Control
## Draws the reeling minigame: fish marker, your bar (hold to move right,
## release to fall left) and the catch progress.

var minigame: ReelMinigame = null


func _init() -> void:
	custom_minimum_size = Vector2(700, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if minigame == null:
		return
	var w := size.x
	var track := Rect2(0, 6, w, 44)
	draw_rect(track, Color(0, 0, 0, 0.55))
	draw_rect(track, Color(1, 1, 1, 0.5), false, 3.0)
	# player bar
	var bw := minigame.bar_size * w
	var bx := minigame.bar_pos * w - bw * 0.5
	var zone := minigame.in_zone()
	var col := Color(0.25, 0.85, 0.4, 0.85) if zone else Color(0.9, 0.35, 0.3, 0.8)
	draw_rect(Rect2(bx, track.position.y + 3, bw, track.size.y - 6), col)
	# fish marker
	var fx := minigame.fish_pos * w
	var fc := Vector2(fx, track.position.y + track.size.y * 0.5)
	draw_circle(fc, 18.0, Color(1.0, 0.9, 0.3))
	draw_circle(fc, 18.0, Color(0, 0, 0, 0.6), false, 3.0)
	draw_circle(fc + Vector2(6, -4), 3.5, Color.BLACK)
	# progress
	var pr := Rect2(0, 62, w, 22)
	draw_rect(pr, Color(0, 0, 0, 0.55))
	var pcol := Color(0.3, 0.8, 0.95).lerp(Color(0.3, 1.0, 0.4), minigame.progress)
	draw_rect(Rect2(pr.position, Vector2(pr.size.x * minigame.progress, pr.size.y)), pcol)
	draw_rect(pr, Color(1, 1, 1, 0.5), false, 2.0)
