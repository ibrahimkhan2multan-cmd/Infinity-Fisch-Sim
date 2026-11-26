class_name WeatherFX
extends Node3D
## Rain / storm particles that follow the player. Respects the "weather effects"
## graphics setting (off = no particles; fog and sky changes still apply).

var follow: Node3D = null
var _rain: CPUParticles3D
var _current_amount := -1


func _ready() -> void:
	_rain = CPUParticles3D.new()
	_rain.emitting = false
	_rain.lifetime = 0.9
	_rain.local_coords = false
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(22, 0.5, 22)
	_rain.direction = Vector3(0.12, -1, 0.05)
	_rain.spread = 3.0
	_rain.initial_velocity_min = 24.0
	_rain.initial_velocity_max = 30.0
	_rain.gravity = Vector3(0, -6, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.018, 0.55, 0.018)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.78, 0.86, 1.0, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = mat
	_rain.mesh = bm
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain)
	Clock.weather_changed.connect(func(_w): _refresh())
	Settings.changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	if follow and is_instance_valid(follow):
		global_position = follow.global_position + Vector3(0, 17.0, 0)


func _refresh() -> void:
	var intensity := float(Clock.info()["rain"])
	var on := intensity > 0.0 and Settings.weather_fx
	var amount := 0
	if on:
		amount = int(420.0 * intensity) if Settings.preset != "low" else int(220.0 * intensity)
	if amount != _current_amount:
		_current_amount = amount
		if amount > 0:
			_rain.amount = amount
	_rain.emitting = on


func is_raining() -> bool:
	return _rain.emitting
