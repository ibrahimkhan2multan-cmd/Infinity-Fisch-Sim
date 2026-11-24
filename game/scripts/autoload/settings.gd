extends Node
## Player settings (autoload "Settings"): graphics, audio, controls.
## Every option here has a real effect - see apply() and the nodes that
## listen to the `changed` signal (world, HUD, touch controls).

signal changed

const PATH := "user://settings.cfg"

const PRESETS := {
	"low": {"render_scale": 0.65, "msaa": 0, "shadows": 0, "view_distance": 0,
		"prop_density": 0.35, "water_quality": 0, "weather_fx": false, "fps_cap": 30},
	"medium": {"render_scale": 0.85, "msaa": 0, "shadows": 1, "view_distance": 1,
		"prop_density": 0.65, "water_quality": 1, "weather_fx": true, "fps_cap": 60},
	"high": {"render_scale": 1.0, "msaa": 1, "shadows": 2, "view_distance": 2,
		"prop_density": 1.0, "water_quality": 1, "weather_fx": true, "fps_cap": 60},
}
const VIEW_DISTANCES: Array[float] = [140.0, 240.0, 380.0]

# graphics
var preset: String = "medium"
var render_scale: float = 0.85
var msaa: int = 0                # 0 off, 1 = 2x, 2 = 4x
var shadows: int = 1             # 0 off, 1 low, 2 high
var view_distance: int = 1       # index into VIEW_DISTANCES
var prop_density: float = 0.65
var water_quality: int = 1       # 0 simple, 1 animated
var weather_fx: bool = true
var fps_cap: int = 60
var show_fps: bool = false
# audio
var master_volume: float = 0.8
var sfx_volume: float = 0.9
# controls
var haptics: bool = true
var look_sensitivity: float = 1.0
var joystick_scale: float = 1.0
var left_handed: bool = false
var camera_distance: int = 1     # 0 close, 1 normal, 2 far
var first_run: bool = true

const _KEYS := ["preset", "render_scale", "msaa", "shadows", "view_distance", "prop_density",
	"water_quality", "weather_fx", "fps_cap", "show_fps", "master_volume", "sfx_volume",
	"haptics", "look_sensitivity", "joystick_scale", "left_handed", "camera_distance", "first_run"]


func _ready() -> void:
	_register_inputs()
	load_settings()
	if first_run:
		apply_preset(recommended_preset())
		first_run = false
		save_settings()
	apply()


func recommended_preset() -> String:
	var gpu := RenderingServer.get_video_adapter_name()
	var g := gpu.to_lower()
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		return "high"
	for weak in ["mali-t", "mali-g31", "mali-g51", "mali-g52", "mali-g57", "powervr", "adreno (tm) 3", "adreno (tm) 4", "adreno (tm) 5", "adreno (tm) 610", "adreno (tm) 612", "adreno (tm) 613", "adreno (tm) 615", "adreno (tm) 616", "adreno (tm) 618", "adreno (tm) 619", "adreno (tm) 620", "adreno (tm) 630"]:
		if g.contains(weak):
			return "low"
	for strong in ["mali-g710", "mali-g715", "mali-g720", "mali-g78", "mali-g77", "adreno (tm) 7", "adreno (tm) 660", "adreno (tm) 650", "adreno (tm) 740", "immortalis"]:
		if g.contains(strong):
			return "high"
	return "medium"


func apply_preset(name: String) -> void:
	if not PRESETS.has(name):
		return
	var p: Dictionary = PRESETS[name]
	for k in p:
		set(k, p[k])
	preset = name


## Call after changing individual options by hand.
func mark_custom() -> void:
	preset = "custom"


func apply() -> void:
	var root := get_tree().root
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = clampf(render_scale, 0.4, 1.0)
	match msaa:
		0: root.msaa_3d = Viewport.MSAA_DISABLED
		1: root.msaa_3d = Viewport.MSAA_2X
		_: root.msaa_3d = Viewport.MSAA_4X
	Engine.max_fps = fps_cap
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_LOW if shadows < 2 else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	RenderingServer.directional_shadow_atlas_set_size(1024 if shadows <= 1 else 2048, false)
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(master_volume, 0.0001)))
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(maxf(sfx_volume, 0.0001)))
	changed.emit()


func view_distance_m() -> float:
	return VIEW_DISTANCES[clampi(view_distance, 0, VIEW_DISTANCES.size() - 1)]


func vibrate(ms: int = 40) -> void:
	if haptics and OS.get_name() == "Android":
		Input.vibrate_handheld(ms)


func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in _KEYS:
		cf.set_value("settings", k, get(k))
	cf.save(PATH)


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in _KEYS:
		if cf.has_section_key("settings", k):
			set(k, cf.get_value("settings", k))


func _register_inputs() -> void:
	_action("move_left", [KEY_A, KEY_LEFT])
	_action("move_right", [KEY_D, KEY_RIGHT])
	_action("move_forward", [KEY_W, KEY_UP])
	_action("move_back", [KEY_S, KEY_DOWN])
	_action("jump", [KEY_SPACE])
	_action("interact", [KEY_E])
	_action("cast", [KEY_F])
	_action("run", [KEY_SHIFT])
	_action("pause", [KEY_ESCAPE])
	_action("inventory", [KEY_I, KEY_TAB])


func _action(name: String, keys: Array) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name, 0.2)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(name, ev)
