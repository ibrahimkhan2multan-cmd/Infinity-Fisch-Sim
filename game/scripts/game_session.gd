class_name GameSession
extends Node
## One play session: builds the world, the HUD / touch controls / panels, wires
## world interactions to panels, and owns rest, ferry travel and pause.

signal quit_to_menu

var world: GameWorld
var hud: Hud
var touch: TouchControls
var panels: Dictionary = {}          ## name -> PanelBase

var _ui_layer: CanvasLayer
var _panel_layer: CanvasLayer
var _fade_layer: CanvasLayer
var _fade: ColorRect
var _open: PanelBase = null
var _busy := false                   ## true during fades (rest / ferry)
var _resume_clock := true


## Builds everything. `progress` receives (fraction, text) for the loading screen.
func start(progress: Callable = Callable()) -> void:
	world = GameWorld.new()
	world.name = "World"
	add_child(world)
	if progress.is_valid():
		world.build_progress.connect(progress)
	await world.build_async()
	_build_ui()
	Game.in_game = true
	Clock.running = true
	Save.autosave_enabled = true
	Settings.apply()
	var info := Save.save_info()
	var away := Util.now() - float(info.get("saved_at", Util.now()))
	if info.size() > 0 and away > 90.0:
		hud.toast("Welcome back! Your facilities kept working for %s." % Util.duration(minf(away, 43200.0)), "good")
	elif Game.play_time < 5.0:
		hud.toast("Welcome to Driftwood Village! Walk to the water's edge and hold CAST.", "info")


func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 5
	add_child(_ui_layer)
	hud = Hud.new()
	_ui_layer.add_child(hud)
	touch = TouchControls.new()
	touch.theme = UI.theme()
	_ui_layer.add_child(touch)
	touch.bind(world.player)
	hud.bind(world.player, touch)
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 10
	add_child(_panel_layer)
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 30
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)

	panels["inventory"] = PanelInventory.new()
	panels["collection"] = PanelCollection.new()
	panels["tackle"] = PanelShop.new().setup("tackle")
	panels["general"] = PanelShop.new().setup("general")
	panels["market"] = PanelMarket.new()
	panels["hatchery"] = PanelHatchery.new()
	panels["kitchen"] = PanelKitchen.new()
	panels["factory"] = PanelFactory.new()
	panels["guild"] = PanelGuild.new()
	var ferry := PanelFerry.new()
	ferry.destinations = world.destinations
	ferry.travel_requested.connect(_travel)
	panels["ferry"] = ferry
	panels["settings"] = PanelSettings.new()
	var pause := PanelPause.new()
	pause.settings_requested.connect(func(): open_panel("settings"))
	pause.menu_requested.connect(_quit_to_menu)
	panels["pause"] = pause
	for k in panels:
		var p: PanelBase = panels[k]
		_panel_layer.add_child(p)
		p.closed.connect(_on_panel_closed.bind(p))

	world.interacted.connect(_on_interacted)
	touch.use_pressed.connect(func(): world.interact(world.player.nearest))
	touch.pause_pressed.connect(func(): open_panel("pause"))
	touch.bag_pressed.connect(func(): open_panel("inventory"))
	touch.dex_pressed.connect(func(): open_panel("collection"))
	get_tree().root.go_back_requested.connect(_on_back)
	Game.level_up.connect(func(_l): Settings.vibrate(150))


func _on_back() -> void:
	if _open != null:
		_open.close_panel()
	else:
		open_panel("pause")


func _unhandled_input(event: InputEvent) -> void:
	if world == null or hud == null:
		return
	if event.is_action_pressed("pause"):
		_on_back()
	elif event.is_action_pressed("inventory") and _open == null:
		open_panel("inventory")


# ---- panels --------------------------------------------------------------------

func open_panel(name: String, tab := 0) -> void:
	if _busy or not panels.has(name):
		return
	if _open != null and _open != panels[name]:
		_open.close_panel()
	var p: PanelBase = panels[name]
	var player := world.player
	if player.fishing.state != FishingController.State.IDLE:
		player.fishing.cancel()
	_open = p
	touch.enabled = false
	player.movement_enabled = false
	player.look_locked = true
	if name == "pause":
		_resume_clock = Clock.running
		Clock.running = false
		Save.save_game(true)
	p.open_panel(tab)


func _on_panel_closed(p: PanelBase) -> void:
	if _open != p:
		return
	_open = null
	if p == panels["pause"]:
		Clock.running = _resume_clock
	touch.enabled = true
	world.player.movement_enabled = true
	world.player.look_locked = false


func is_panel_open() -> bool:
	return _open != null


# ---- world interactions -----------------------------------------------------------

func _on_interacted(action: String, data: Dictionary) -> void:
	match action:
		"shop_tackle": open_panel("tackle")
		"shop_general": open_panel("general")
		"guild": open_panel("guild")
		"market": open_panel("market")
		"kitchen": open_panel("kitchen")
		"hatchery": open_panel("hatchery")
		"factory": open_panel("factory")
		"crate": open_panel("guild", 2)
		"ferry": open_panel("ferry")
		"rest": _rest()
		_:
			push_warning("Unhandled interaction: " + action)


func _fade_to(alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, duration)
	await tw.finished


func _rest() -> void:
	if _busy:
		return
	_busy = true
	touch.enabled = false
	world.player.movement_enabled = false
	await _fade_to(1.0, 0.6)
	Clock.skip_to_morning()
	Save.save_game(true)
	await get_tree().create_timer(0.5).timeout
	await _fade_to(0.0, 0.6)
	hud.toast("You slept until morning. Game saved.", "good")
	touch.enabled = true
	world.player.movement_enabled = true
	_busy = false


func _travel(dest_id: String) -> void:
	if _busy:
		return
	var d: Dictionary = world.destinations.get(dest_id, {})
	if d.is_empty():
		return
	var permit: String = d.get("permit", "")
	var fare := int(d.get("fare", 0))
	if permit != "" and not Game.has_permit(permit):
		hud.toast("You need that island's fishing permit first (Fishing Guild).", "bad")
		return
	if fare > 0 and not Game.spend(fare):
		return
	_busy = true
	touch.enabled = false
	world.player.movement_enabled = false
	Sfx.play("ferry")
	await _fade_to(1.0, 0.7)
	world.travel_to(dest_id)
	await get_tree().create_timer(0.6).timeout
	await _fade_to(0.0, 0.7)
	hud.toast("Welcome to %s." % String(d["name"]), "info")
	Save.save_game(true)
	touch.enabled = true
	world.player.movement_enabled = true
	_busy = false


func _quit_to_menu() -> void:
	Save.save_game(true)
	Game.in_game = false
	Clock.running = false
	Save.autosave_enabled = false
	touch.release_all()
	quit_to_menu.emit()
