class_name PanelSettings
extends PanelBase
## Graphics / audio / controls. Every control changes the real setting, applies
## it immediately (Settings.apply emits `changed` which the world listens to)
## and saves it to disk.


func _init() -> void:
	super()
	title = "Settings"
	tab_names = ["Graphics", "Audio & Controls"]


func _populate(t: int) -> void:
	if t == 0:
		_graphics()
	else:
		_controls()


func _commit(custom := true) -> void:
	if custom:
		Settings.mark_custom()
	Settings.apply()
	Settings.save_settings()


func _choice_row(label_text: String, options: Array, current: int, setter: Callable) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.style(UI.C_ROW, 12, 0, Color.TRANSPARENT, 14))
	var v := VBoxContainer.new()
	pc.add_child(v)
	v.add_child(UI.label(label_text, UI.FONT))
	var h := HBoxContainer.new()
	v.add_child(h)
	for i in options.size():
		var b := UI.button(String(options[i]), func():
			setter.call(i)
			_commit()
			refresh(), true, Vector2(130, 56))
		if i != current:
			b.add_theme_stylebox_override("normal", UI.style(Color(0.2, 0.3, 0.4), 12, 0, Color.TRANSPARENT, 14))
		h.add_child(b)
	content.add_child(pc)


func _toggle_row(label_text: String, value: bool, setter: Callable, custom := true) -> void:
	_choice_row(label_text, ["Off", "On"], 1 if value else 0, func(i): setter.call(i == 1))


func _slider_row(label_text: String, value: float, lo: float, hi: float, step: float, fmt: String, setter: Callable,
		custom := true) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.style(UI.C_ROW, 12, 0, Color.TRANSPARENT, 14))
	var v := VBoxContainer.new()
	pc.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var name_l := UI.label(label_text, UI.FONT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	var val_l := UI.label(fmt % value, UI.FONT, UI.C_GOLD)
	top.add_child(val_l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(0, 44)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(nv: float):
		val_l.text = fmt % nv
		setter.call(nv))
	# commit when the finger lifts, not on every drag step
	s.drag_ended.connect(func(_changed: bool): _commit(custom))
	v.add_child(s)
	content.add_child(pc)


func _graphics() -> void:
	add_header("Quality preset")
	var names := ["low", "medium", "high"]
	var row := HBoxContainer.new()
	content.add_child(row)
	for n in names:
		var b := UI.button(String(n).capitalize(), func():
			Settings.apply_preset(n)
			_commit(false)
			refresh(), true, Vector2(180, 60))
		if Settings.preset != n:
			b.add_theme_stylebox_override("normal", UI.style(Color(0.2, 0.3, 0.4), 12, 0, Color.TRANSPARENT, 14))
		row.add_child(b)
	add_note("Current: %s.  Use Low on older phones for a smoother frame rate; changes apply instantly." % Settings.preset.capitalize())
	add_header("Details")
	_slider_row("Render resolution", Settings.render_scale, 0.5, 1.0, 0.05, "%.2f", func(v): Settings.render_scale = v)
	_choice_row("Anti-aliasing", ["Off", "2x", "4x"], Settings.msaa, func(i): Settings.msaa = i)
	_choice_row("Shadows", ["Off", "Low", "High"], Settings.shadows, func(i): Settings.shadows = i)
	_choice_row("View distance", ["Near", "Normal", "Far"], Settings.view_distance, func(i): Settings.view_distance = i)
	_slider_row("Tree & rock density", Settings.prop_density, 0.2, 1.0, 0.05, "%.2f", func(v): Settings.prop_density = v)
	_choice_row("Water", ["Simple", "Animated"], Settings.water_quality, func(i): Settings.water_quality = i)
	_toggle_row("Rain & weather effects", Settings.weather_fx, func(b): Settings.weather_fx = b)
	_choice_row("Frame rate limit", ["30", "60"], 0 if Settings.fps_cap <= 30 else 1, func(i): Settings.fps_cap = 30 if i == 0 else 60)
	_toggle_row("Show FPS counter", Settings.show_fps, func(b): Settings.show_fps = b)


func _controls() -> void:
	add_header("Audio")
	_slider_row("Master volume", Settings.master_volume, 0.0, 1.0, 0.05, "%.2f", func(v): Settings.master_volume = v, false)
	_slider_row("Sound effects", Settings.sfx_volume, 0.0, 1.0, 0.05, "%.2f", func(v): Settings.sfx_volume = v, false)
	add_header("Controls")
	_toggle_row("Vibration", Settings.haptics, func(b): Settings.haptics = b)
	_slider_row("Camera sensitivity", Settings.look_sensitivity, 0.4, 2.5, 0.05, "%.2f", func(v): Settings.look_sensitivity = v, false)
	_slider_row("Joystick size", Settings.joystick_scale, 0.7, 1.5, 0.05, "%.2f", func(v): Settings.joystick_scale = v, false)
	_toggle_row("Left-handed layout", Settings.left_handed, func(b): Settings.left_handed = b)
	_choice_row("Camera distance", ["Close", "Normal", "Far"], Settings.camera_distance, func(i): Settings.camera_distance = i)
