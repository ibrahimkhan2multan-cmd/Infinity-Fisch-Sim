class_name PanelPause
extends PanelBase
## Pause menu: resume, settings, manual save, back to the main menu.

signal settings_requested
signal menu_requested


func _init() -> void:
	super()
	title = "Paused"


func _populate(_t: int) -> void:
	var info := "Day %d · %s · Level %d · %s · play time %s" % [Clock.day, Util.clock_text(Clock.hour), Game.level,
		Util.money(Game.money), Util.duration(Game.play_time)]
	add_note(info, UI.C_TEXT)
	add_note("The game auto-saves every 45 seconds and whenever you leave the app. Facilities keep working while the game is closed.")
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	content.add_child(col)
	col.add_child(UI.button("Resume", close_panel, true, Vector2(0, 76), UI.C_GOOD))
	col.add_child(UI.button("Settings", func():
		close_panel()
		settings_requested.emit(), true, Vector2(0, 76)))
	col.add_child(UI.button("Save game now", func(): Save.save_game(), true, Vector2(0, 76)))
	col.add_child(UI.button("Save & quit to main menu", func():
		close_panel()
		menu_requested.emit(), true, Vector2(0, 76), UI.C_BAD))
