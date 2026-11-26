class_name MainMenu
extends Control
## Title screen: Continue / New Game / Settings / Quit.

signal new_game
signal continue_game
signal settings_requested

var _confirm: Control = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()


func _ready() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.03, 0.12, 0.24))
	grad.set_color(1, Color(0.1, 0.45, 0.6))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(tr)
	_swimmers()
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -300
	box.offset_right = 300
	box.offset_top = -300
	box.offset_bottom = 300
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	var t := UI.label("INFINITY FISHING", 64, UI.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_constant_override("outline_size", 12)
	t.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.14))
	box.add_child(t)
	box.add_child(UI.label("Catch. Breed. Cook. Build your fish empire.", 24, Color(0.85, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.spacer(18))
	var info := Save.save_info()
	if not info.is_empty():
		var sub := "Level %d · %s · day %d" % [int(info["level"]), Util.money(int(info["money"])), int(info["day"])]
		box.add_child(UI.button("Continue\n" + sub, func(): continue_game.emit(), true, Vector2(0, 92), UI.C_GOOD))
	box.add_child(UI.button("New Game", _on_new, true, Vector2(0, 76)))
	box.add_child(UI.button("Settings", func(): settings_requested.emit(), true, Vector2(0, 76)))
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		box.add_child(UI.button("Quit", func(): get_tree().quit(), true, Vector2(0, 64), UI.C_BAD))
	box.add_child(UI.label("Single-player · plays fully offline", 18, Color(0.7, 0.85, 0.95, 0.8), HORIZONTAL_ALIGNMENT_CENTER))


func _on_new() -> void:
	if Save.has_save():
		_ask_confirm()
	else:
		new_game.emit()


func _ask_confirm() -> void:
	if _confirm != null:
		return
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_confirm = dim
	var pc := PanelContainer.new()
	pc.anchor_left = 0.5
	pc.anchor_right = 0.5
	pc.anchor_top = 0.5
	pc.anchor_bottom = 0.5
	pc.offset_left = -330
	pc.offset_right = 330
	pc.offset_top = -150
	pc.offset_bottom = 150
	dim.add_child(pc)
	var v := VBoxContainer.new()
	pc.add_child(v)
	var l := UI.label("Start a new game? Your current save will be replaced.", UI.FONT, UI.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	v.add_child(UI.spacer(12))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	h.add_child(UI.button("Keep my save", func():
		dim.queue_free()
		_confirm = null, true, Vector2(240, 68)))
	h.add_child(UI.button("Start over", func():
		Save.delete_save()
		new_game.emit(), true, Vector2(240, 68), UI.C_BAD))


## A few fish silhouettes drifting across the background.
func _swimmers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var ids: Array = Data.fish.keys()
	for i in 7:
		var icon := FishIcon.new()
		icon.custom_minimum_size = Vector2(160, 90)
		icon.size = Vector2(160, 90)
		icon.modulate = Color(1, 1, 1, 0.22)
		icon.scale = Vector2(-1, 1) if i % 2 == 0 else Vector2.ONE
		icon.show_fish({"sp": ids[rng.randi() % ids.size()]})
		add_child(icon)
		var y := rng.randf_range(40.0, 660.0)
		var dur := rng.randf_range(18.0, 34.0)
		var from_x := -200.0 if i % 2 == 0 else 1480.0
		var to_x := 1480.0 if i % 2 == 0 else -200.0
		icon.position = Vector2(from_x, y)
		var tw := create_tween().set_loops()
		tw.tween_property(icon, "position:x", to_x, dur).from(from_x).set_delay(rng.randf_range(0.0, 8.0))
