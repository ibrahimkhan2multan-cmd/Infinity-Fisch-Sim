class_name SkyController
extends Node3D
## Sun/moon, procedural sky, fog, stars, clouds, lightning. Reads Clock (time of
## day + weather) every frame and drives the Environment, the light and the
## water shaders.

const STAR_SHADER := preload("res://shaders/stars.gdshader")

var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var water: WaterBuilder = null
var follow: Node3D = null            ## camera/player: sky dome and clouds track it
var view_far := 380.0

var _stars: MeshInstance3D
var _star_mat: ShaderMaterial
var _cloud_time := 0.0
var _fog := 0.0006
var _dark := 0.0
var _wave := 0.5
var _flash := 0.0
var _next_lightning := 8.0
var _thunder_in := -1.0


func _ready() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled = true
	env.fog_sky_affect = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.04
	env.glow_intensity = 0.7
	env.glow_strength = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.light_angular_distance = 0.5
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	_build_stars()
	Settings.changed.connect(_apply_settings)
	_apply_settings()


func _build_stars() -> void:
	_star_mat = ShaderMaterial.new()
	_star_mat.shader = STAR_SHADER
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 12
	_stars = MeshInstance3D.new()
	_stars.mesh = sm
	_stars.material_override = _star_mat
	_stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_stars)


func _apply_settings() -> void:
	view_far = Settings.view_distance_m()
	var s := Settings.shadows
	env.glow_enabled = s >= 2   # bloom on lamps/windows only on the high preset
	sun.shadow_enabled = s > 0
	sun.directional_shadow_max_distance = 45.0 if s == 1 else 90.0
	var sc := view_far * 0.92
	_stars.scale = Vector3.ONE * sc
	sky_mat.set_shader_parameter("cloud_quality", 1.0 if Settings.water_quality > 0 else 0.0)
	TerrainBuilder.set_quality(Settings.water_quality)
	if water:
		water.set_quality(Settings.water_quality)


func _process(delta: float) -> void:
	if follow and is_instance_valid(follow):
		var p := follow.global_position
		_stars.global_position = p
	_cloud_time += delta
	var info := Clock.info()
	var d := Clock.daylight()
	var warm := pow(1.0 - absf(2.0 * d - 1.0), 2.0)
	var k := minf(1.0, delta * 0.8)
	_fog = lerpf(_fog, float(info["fog"]), k)
	_dark = lerpf(_dark, float(info["dark"]), k)
	_wave = lerpf(_wave, float(info["wave"]), k)

	var day_top := Color(0.22, 0.48, 0.9)
	var day_hor := Color(0.72, 0.86, 0.98)
	var night_top := Color(0.008, 0.014, 0.05)
	var night_hor := Color(0.045, 0.065, 0.14)
	var top := night_top.lerp(day_top, d).lerp(Color(0.33, 0.3, 0.6), warm * 0.5)
	var hor := night_hor.lerp(day_hor, d).lerp(Color(1.0, 0.55, 0.3), warm * 0.7)
	var gray := Color(0.5, 0.53, 0.58) * (0.12 + 0.88 * d)
	top = top.lerp(gray, _dark * 0.9)
	hor = hor.lerp(gray * 1.1, _dark * 0.9)
	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", hor)
	sky_mat.set_shader_parameter("ground_color", hor.darkened(0.35))
	sky_mat.set_shader_parameter("cloud_time", _cloud_time)

	# sun / moon
	var a := (Clock.hour - 6.0) / 12.0 * PI
	var dd := pow(d, 0.55)  # softer fall-off so dusk keeps a golden glow
	var sun_e := 0.6 * dd * (1.0 - 0.55 * _dark)
	var moon_e := 0.16 * (1.0 - d)
	if d > 0.04:
		var elev := clampf(sin(a), 0.0, 1.0)
		sun.rotation_degrees = Vector3(-lerpf(6.0, 72.0, elev), a / PI * 180.0 - 90.0, 0.0)
		sun.light_color = Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.62, 0.35), warm * 0.8)
		sun.light_energy = maxf(sun_e, moon_e)
	else:
		sun.rotation_degrees = Vector3(-48.0, 40.0, 0.0)
		sun.light_color = Color(0.62, 0.72, 1.0)
		sun.light_energy = moon_e

	# ambient + fog
	var amb := Color(0.1, 0.13, 0.26).lerp(Color(0.6, 0.66, 0.78), dd).lerp(Color(0.85, 0.6, 0.5), warm * 0.25)
	env.ambient_light_color = amb
	env.ambient_light_energy = lerpf(0.5, 0.45, dd) * (1.0 - 0.3 * _dark)
	env.fog_light_color = hor.lerp(gray, 0.3)
	env.fog_density = _fog * (380.0 / view_far)

	# stars & clouds
	_star_mat.set_shader_parameter("intensity", clampf(1.0 - d * 1.6, 0.0, 1.0) * (1.0 - _dark))
	var cc := Color(1, 1, 1).lerp(Color(1.0, 0.72, 0.58), warm * 0.55 * (1.0 - _dark))
	cc = Color(cc.r * (0.08 + 0.92 * d), cc.g * (0.08 + 0.92 * d), cc.b * (0.12 + 0.88 * d))
	sky_mat.set_shader_parameter("cloud_cover", clampf(float(info["clouds"]) * 0.9 + _dark * 0.2, 0.0, 1.0))
	sky_mat.set_shader_parameter("cloud_dark", _dark)
	sky_mat.set_shader_parameter("cloud_tint", cc)
	# sun / moon disc in the sky shader
	var sdir := sun.global_transform.basis.z.normalized()
	sky_mat.set_shader_parameter("sun_dir", sdir)
	var is_day := d > 0.04
	sky_mat.set_shader_parameter("sun_color", sun.light_color if is_day else Color(0.8, 0.88, 1.0))
	sky_mat.set_shader_parameter("sun_energy", (1.0 - 0.85 * _dark) if is_day else 0.55)
	sky_mat.set_shader_parameter("disc_size", 0.03 if is_day else 0.045)

	MeshBuilder.set_night(clampf(1.0 - smoothstep(0.02, 0.4, d) + _dark * 0.25, 0.0, 1.0))
	# water
	if water:
		water.set_sky(hor.lerp(top, 0.35))
		water.set_waves(_wave)
		water.set_dim(lerpf(0.32, 1.0, dd) * (1.0 - 0.25 * _dark))

	# lightning
	if Clock.weather == "storm":
		_next_lightning -= delta
		if _next_lightning <= 0.0:
			_flash = 1.0
			_thunder_in = randf_range(0.4, 2.2)
			_next_lightning = randf_range(5.0, 16.0)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		env.ambient_light_energy += _flash * 2.5
		sun.light_energy += _flash * 1.5
	if _thunder_in >= 0.0:
		_thunder_in -= delta
		if _thunder_in < 0.0:
			Sfx.play("thunder", 0.9)
