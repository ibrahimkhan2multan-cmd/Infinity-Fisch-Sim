class_name SkyController
extends Node3D
## Sun/moon, procedural sky, fog, stars, clouds, lightning. Reads Clock (time of
## day + weather) every frame and drives the Environment, the light and the
## water shaders.

const STAR_SHADER := preload("res://shaders/stars.gdshader")

var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var water: WaterBuilder = null
var follow: Node3D = null            ## camera/player: sky dome and clouds track it
var view_far := 380.0

var _stars: MeshInstance3D
var _star_mat: ShaderMaterial
var _clouds_root: Node3D
var _cloud_inst: MultiMeshInstance3D
var _cloud_mat: StandardMaterial3D
var _cloud_count := 0
var _fog := 0.0006
var _dark := 0.0
var _wave := 0.5
var _flash := 0.0
var _next_lightning := 8.0
var _thunder_in := -1.0


func _ready() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.15
	sky_mat.sky_curve = 0.25
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
	_build_clouds()
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


func _build_clouds() -> void:
	_clouds_root = Node3D.new()
	add_child(_clouds_root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cb := MeshBuilder.new()
	cb.sphere(Vector3.ZERO, 1.0, Color.WHITE, 7, 4, Vector3(1.6, 0.6, 1.0))
	cb.sphere(Vector3(1.4, -0.1, 0.3), 0.8, Color.WHITE, 7, 4, Vector3(1.5, 0.6, 1.0))
	cb.sphere(Vector3(-1.5, -0.15, -0.2), 0.75, Color.WHITE, 7, 4, Vector3(1.4, 0.55, 1.0))
	mm.mesh = cb.build()
	_cloud_count = 28
	mm.instance_count = _cloud_count
	for i in _cloud_count:
		var a := rng.randf() * TAU
		var r := rng.randf_range(90.0, 300.0)
		var s := rng.randf_range(14.0, 30.0)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.8, s)),
			Vector3(cos(a) * r, rng.randf_range(130.0, 190.0), sin(a) * r))
		mm.set_instance_transform(i, xf)
	_cloud_mat = StandardMaterial3D.new()
	_cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cloud_mat.vertex_color_use_as_albedo = true
	_cloud_mat.albedo_color = Color(1, 1, 1, 1)
	_cloud_mat.disable_fog = true
	_cloud_inst = MultiMeshInstance3D.new()
	_cloud_inst.multimesh = mm
	_cloud_inst.material_override = _cloud_mat
	_cloud_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_clouds_root.add_child(_cloud_inst)


func _apply_settings() -> void:
	view_far = Settings.view_distance_m()
	var s := Settings.shadows
	sun.shadow_enabled = s > 0
	sun.directional_shadow_max_distance = 45.0 if s == 1 else 90.0
	var sc := view_far * 0.92
	_stars.scale = Vector3.ONE * sc
	_clouds_root.scale = Vector3.ONE * (view_far / 380.0)
	if water:
		water.set_quality(Settings.water_quality)


func _process(delta: float) -> void:
	if follow and is_instance_valid(follow):
		var p := follow.global_position
		_stars.global_position = p
		_clouds_root.global_position = Vector3(p.x, 0.0, p.z)
	_clouds_root.rotation.y += delta * 0.004
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
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = hor
	sky_mat.ground_horizon_color = hor.darkened(0.25)
	sky_mat.ground_bottom_color = hor.darkened(0.6)

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
	var cloud_vis := float(info["clouds"])
	_cloud_inst.multimesh.visible_instance_count = int(round(_cloud_count * cloud_vis))
	var cc := Color(1, 1, 1).lerp(Color(0.42, 0.45, 0.5), _dark * 1.1)
	cc = cc.lerp(Color(1.0, 0.7, 0.55), warm * 0.4 * (1.0 - _dark))
	cc = Color(cc.r * (0.1 + 0.9 * d), cc.g * (0.1 + 0.9 * d), cc.b * (0.13 + 0.87 * d)) * 0.92
	_cloud_mat.albedo_color = cc

	# water
	if water:
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
