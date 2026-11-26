extends Node
## Boot flow: main menu -> loading screen -> game session -> back to the menu.

var _menu: MainMenu
var _loading: LoadingScreen
var _session: GameSession
var _settings_panel: PanelSettings
var _overlay: CanvasLayer


func _ready() -> void:
	Settings.apply()
	_overlay = CanvasLayer.new()
	_overlay.layer = 50
	add_child(_overlay)
	_settings_panel = PanelSettings.new()
	_overlay.add_child(_settings_panel)
	_show_menu()
	if Settings.first_run:
		Settings.first_run = false
		Settings.apply_preset(Settings.recommended_preset())
		Settings.apply()
		Settings.save_settings()


func _show_menu() -> void:
	if _session != null:
		_session.queue_free()
		_session = null
	_menu = MainMenu.new()
	add_child(_menu)
	_menu.new_game.connect(func(): _begin(true))
	_menu.continue_game.connect(func(): _begin(false))
	_menu.settings_requested.connect(func(): _settings_panel.open_panel())


func _begin(is_new: bool) -> void:
	if is_new:
		Game.reset_new_game()
		Clock.reset()
	elif not Save.load_game():
		Game.reset_new_game()
		Clock.reset()
	Hatchery.ensure_tanks()
	Kitchen.ensure_slots()
	Factory.ensure_lines()
	if _menu != null:
		_menu.queue_free()
		_menu = null
	_loading = LoadingScreen.new()
	add_child(_loading)
	# let the loading screen draw before the (synchronous parts of the) build start
	await get_tree().process_frame
	await get_tree().process_frame
	_session = GameSession.new()
	_session.name = "Session"
	add_child(_session)
	_session.quit_to_menu.connect(_show_menu)
	await _session.start(_loading.update_progress)
	_loading.queue_free()
	_loading = null
	if is_new:
		Save.save_game(true)
