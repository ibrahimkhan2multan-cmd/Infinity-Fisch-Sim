class_name Hud
extends Control
## In-game overlay: money / level / clock, toasts, cast power, bite alert,
## reel bar and the catch popup. Purely reads game state and signals.

var player: Player
var fishing: FishingController
var touch: TouchControls

var _money: Label
var _level: Label
var _xp: ProgressBar
var _gear: Label
var _clock: Label
var _place: Label
var _toasts: VBoxContainer
var _power_box: VBoxContainer
var _power: ProgressBar
var _power_hint: Label
var _bite: Label
var _reel: ReelBar
var _reel_box: VBoxContainer
var _reel_name: Label
var _popup: PanelContainer
var _popup_icon: FishIcon
var _popup_name: Label
var _popup_info: Label
var _popup_new: Label
var _popup_timer := 0.0
var _prompt: Label
var _fps: Label
var _flash: ColorRect


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UI.theme()


func _ready() -> void:
	_build()
	Game.money_changed.connect(func(_a): _refresh_stats())
	Game.xp_changed.connect(_refresh_stats)
	Game.level_up.connect(func(_l): _refresh_stats())
	Game.equipment_changed.connect(_refresh_stats)
	Game.items_changed.connect(_refresh_stats)
	Game.notify.connect(toast)
	_refresh_stats()


func bind(p: Player, t: TouchControls) -> void:
	player = p
	fishing = p.fishing
	touch = t
	fishing.reel_started.connect(func(f: Dictionary):
		_reel.minigame = fishing.minigame
		_reel_name.text = "Reeling in..."
		_reel_box.visible = true)
	fishing.catch_finished.connect(_on_catch)
	fishing.message.connect(func(text: String, kind: String): toast(text, kind))
	fishing.bite_started.connect(func(): _flash_screen(Color(1, 0.9, 0.3, 0.25)))


func _build() -> void:
	# --- top-left stats
	var stats := PanelContainer.new()
	stats.add_theme_stylebox_override("panel", UI.style(Color(0.05, 0.1, 0.15, 0.72), 14, 0, Color.TRANSPARENT, 12))
	stats.position = Vector2(16, 12)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 3)
	stats.add_child(sv)
	_money = UI.label("$0", 30, UI.C_GOLD)
	sv.add_child(_money)
	var lv_row := HBoxContainer.new()
	sv.add_child(lv_row)
	_level = UI.label("Lv 1", 20)
	lv_row.add_child(_level)
	_xp = UI.bar(0, 100, UI.C_ACCENT, 14)
	_xp.custom_minimum_size = Vector2(150, 14)
	_xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lv_row.add_child(_xp)
	_gear = UI.label("", 17, UI.C_DIM)
	sv.add_child(_gear)
	# --- top-center clock
	var clock_box := VBoxContainer.new()
	clock_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	clock_box.anchor_left = 0.5
	clock_box.anchor_right = 0.5
	clock_box.offset_left = -190
	clock_box.offset_right = 190
	clock_box.offset_top = 10
	clock_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clock_box)
	_clock = UI.label("", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_clock.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_clock.add_theme_constant_override("outline_size", 6)
	clock_box.add_child(_clock)
	_place = UI.label("", 19, Color(0.85, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_place.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_place.add_theme_constant_override("outline_size", 5)
	clock_box.add_child(_place)
	# --- toasts
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.anchor_left = 0.5
	_toasts.anchor_right = 0.5
	_toasts.offset_left = -320
	_toasts.offset_right = 320
	_toasts.offset_top = 84
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 6)
	add_child(_toasts)
	# --- cast power
	_power_box = VBoxContainer.new()
	_power_box.anchor_left = 0.5
	_power_box.anchor_right = 0.5
	_power_box.anchor_top = 1.0
	_power_box.anchor_bottom = 1.0
	_power_box.offset_left = -230
	_power_box.offset_right = 230
	_power_box.offset_top = -190
	_power_box.offset_bottom = -110
	_power_box.visible = false
	_power_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_power_box)
	_power_hint = UI.label("Release to cast", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_power_hint.add_theme_constant_override("outline_size", 6)
	_power_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_power_box.add_child(_power_hint)
	_power = UI.bar(0, 1.0, UI.C_GOLD, 30)
	_power_box.add_child(_power)
	# --- bite alert
	_bite = UI.label("!  FISH ON  !  tap HOOK", 46, Color(1, 0.35, 0.25), HORIZONTAL_ALIGNMENT_CENTER)
	_bite.add_theme_constant_override("outline_size", 10)
	_bite.add_theme_color_override("font_outline_color", Color.BLACK)
	_bite.set_anchors_preset(Control.PRESET_CENTER)
	_bite.anchor_left = 0.0
	_bite.anchor_right = 1.0
	_bite.anchor_top = 0.3
	_bite.anchor_bottom = 0.3
	_bite.visible = false
	add_child(_bite)
	# --- reel bar
	_reel_box = VBoxContainer.new()
	_reel_box.anchor_left = 0.5
	_reel_box.anchor_right = 0.5
	_reel_box.anchor_top = 1.0
	_reel_box.anchor_bottom = 1.0
	_reel_box.offset_left = -350
	_reel_box.offset_right = 350
	_reel_box.offset_top = -250
	_reel_box.offset_bottom = -120
	_reel_box.visible = false
	_reel_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reel_box)
	_reel_name = UI.label("Hold REEL to move right, release to fall back", 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_reel_name.add_theme_constant_override("outline_size", 6)
	_reel_name.add_theme_color_override("font_outline_color", Color.BLACK)
	_reel_box.add_child(_reel_name)
	_reel = ReelBar.new()
	_reel_box.add_child(_reel)
	# --- catch popup
	_popup = PanelContainer.new()
	_popup.add_theme_stylebox_override("panel", UI.style(Color(0.06, 0.12, 0.18, 0.95), 20, 3, UI.C_GOLD, 20))
	_popup.anchor_left = 0.5
	_popup.anchor_right = 0.5
	_popup.anchor_top = 0.5
	_popup.anchor_bottom = 0.5
	_popup.offset_left = -230
	_popup.offset_right = 230
	_popup.offset_top = -190
	_popup.offset_bottom = 120
	_popup.visible = false
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_popup)
	var pv := VBoxContainer.new()
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	_popup.add_child(pv)
	_popup_new = UI.label("NEW SPECIES!", 26, UI.C_GOOD, HORIZONTAL_ALIGNMENT_CENTER)
	pv.add_child(_popup_new)
	_popup_icon = FishIcon.new()
	pv.add_child(_popup_icon)
	_popup_name = UI.label("", 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	pv.add_child(_popup_name)
	_popup_info = UI.label("", 22, UI.C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	pv.add_child(_popup_info)
	# --- use prompt, fps, screen flash
	_prompt = UI.label("", 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.custom_minimum_size = Vector2(260, 0)
	add_child(_prompt)
	_fps = UI.label("", 18, Color.WHITE)
	_fps.position = Vector2(16, 150)
	add_child(_fps)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func _flash_screen(c: Color) -> void:
	_flash.color = c
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.35)


func _refresh_stats() -> void:
	_money.text = Util.money(Game.money)
	_level.text = "Lv %d" % Game.level
	_xp.max_value = float(Game.xp_needed(Game.level))
	_xp.value = float(Game.xp)
	var rod_name := Game.rod_data().name
	var b := Game.bait_data()
	_gear.text = "%s · %s" % [rod_name, ("%s x%d" % [b.name, int(Game.baits.get(Game.bait, 0))]) if b != null and Game.bait != "" else "no bait"]


func toast(text: String, kind := "info") -> void:
	var col := Color(0.12, 0.2, 0.28, 0.92)
	var border := Color(0.4, 0.6, 0.75)
	match kind:
		"good": col = Color(0.1, 0.3, 0.2, 0.93); border = UI.C_GOOD
		"bad": col = Color(0.35, 0.12, 0.12, 0.93); border = UI.C_BAD
		"rare": col = Color(0.3, 0.22, 0.08, 0.95); border = UI.C_GOLD
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.style(col, 12, 2, border, 14))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UI.label(text, 21, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pc.add_child(l)
	_toasts.add_child(pc)
	while _toasts.get_child_count() > 4:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))
	var tw := create_tween()
	tw.tween_interval(3.2 if kind != "rare" else 4.5)
	tw.tween_property(pc, "modulate:a", 0.0, 0.5)
	tw.tween_callback(pc.queue_free)


func _on_catch(success: bool, f: Dictionary, is_new: bool) -> void:
	_reel_box.visible = false
	_reel.minigame = null
	if not success or f.is_empty():
		return
	var sp: DataTypes.FishSpecies = Data.fish[f["sp"]]
	_popup_icon.show_fish(f)
	_popup_name.text = FishLogic.display_name(f)
	_popup_name.add_theme_color_override("font_color", Util.rarity_color(sp.rarity).lightened(0.25))
	_popup_info.text = "%s · %s · worth %s" % [Util.rarity_name(sp.rarity), Util.weight_text(float(f["w"])), Util.money(FishLogic.fish_value(f))]
	_popup_new.visible = is_new
	_popup.visible = true
	_popup_timer = 3.0


func _process(delta: float) -> void:
	_clock.text = "Day %d  ·  %s  ·  %s" % [Clock.day, Util.clock_text(Clock.hour), Clock.weather_name()]
	if player:
		_place.text = _place_name(player.global_position)
	if _popup_timer > 0.0:
		_popup_timer -= delta
		if _popup_timer <= 0.0:
			_popup.visible = false
	if fishing:
		var st := fishing.state
		_power_box.visible = st == FishingController.State.CHARGING
		if _power_box.visible:
			_power.value = fishing.power
		_bite.visible = st == FishingController.State.BITE
		if _bite.visible:
			_bite.modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.02)
		if st != FishingController.State.REELING and _reel_box.visible:
			_reel_box.visible = false
	if touch and player:
		var near := player.nearest
		_prompt.visible = near != null and touch.use_btn.visible
		if _prompt.visible:
			_prompt.text = near.prompt
			var c := touch.use_btn.center()
			_prompt.position = Vector2(c.x - 130.0, c.y - touch.use_btn.radius - 34.0)
	_fps.visible = Settings.show_fps
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()


func _place_name(p: Vector3) -> String:
	var pos := Vector2(p.x, p.z)
	var best := "Wilderness"
	var bd := 1e9
	var spots := {
		"Driftwood Village": Terrain.VILLAGE, "Cannery District": Terrain.FACTORY, "Lake Hamlet": Terrain.HAMLET,
		"Mirror Lake": Terrain.LAKE_C, "Mangrove Bog": Terrain.BOG, "Frostfin Isle": Terrain.FROST,
		"Abyss Trench Isle": Terrain.TRENCH,
	}
	for k in spots:
		var d := pos.distance_to(spots[k])
		if d < bd:
			bd = d
			best = k
	if bd > 120.0:
		best = "Open coast"
	return best
