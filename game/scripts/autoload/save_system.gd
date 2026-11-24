extends Node
## Save / load (autoload "Save"). One JSON file in user://, written atomically
## (temp file + rename) so a crash while saving cannot corrupt progress.

signal saved
signal save_failed(reason: String)

const PATH := "user://infinity_fishing_save.json"
const TMP := "user://infinity_fishing_save.tmp"
const VERSION := 1
const AUTOSAVE_SECONDS := 45.0

var autosave_enabled := false
var _accum := 0.0
## Set by the player node so the world position is stored on save.
var player_provider: Callable = Callable()


func _process(delta: float) -> void:
	if not autosave_enabled:
		return
	_accum += delta
	if _accum >= AUTOSAVE_SECONDS:
		_accum = 0.0
		save_game(true)


func _notification(what: int) -> void:
	# Android: app sent to background / closed.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if autosave_enabled:
			save_game(true)


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func save_game(silent := false) -> bool:
	if player_provider.is_valid():
		Game.player_pos = player_provider.call()
	var data := {
		"version": VERSION,
		"saved_at": Util.now(),
		"game": Game.to_dict(),
		"clock": Clock.to_dict(),
	}
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		save_failed.emit("Could not open save file (error %d)." % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		save_failed.emit("Could not access storage.")
		return false
	if FileAccess.file_exists(PATH):
		dir.remove(PATH.get_file())
	var err := dir.rename(TMP.get_file(), PATH.get_file())
	if err != OK:
		save_failed.emit("Could not finalise save (error %d)." % err)
		return false
	saved.emit()
	if not silent:
		Game.notify.emit("Game saved.", "good")
	return true


## Returns true when a save was loaded into Game/Clock.
func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_warning("Save file is corrupt; ignoring it.")
		return false
	var d: Dictionary = parsed
	Game.from_dict(d.get("game", {}))
	Clock.from_dict(d.get("clock", {}))
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func save_info() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return {}
	var g: Dictionary = (parsed as Dictionary).get("game", {})
	return {
		"level": int(g.get("level", 1)), "money": int(g.get("money", 0)),
		"day": int((parsed as Dictionary).get("clock", {}).get("day", 1)),
		"saved_at": float((parsed as Dictionary).get("saved_at", 0.0)),
		"play_time": float(g.get("play_time", 0.0)),
	}
