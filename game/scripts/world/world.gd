class_name GameWorld
extends Node3D
## Assembles the open world: terrain chunks, water, scatter, villages, sky,
## weather, the player and the living parts (customers, tanks, smoke).

signal build_progress(fraction: float, text: String)
signal built
signal interacted(action: String, data: Dictionary)

const START_POS := Vector3(-20, 4.5, 50)

var player: Player
var sky: SkyController
var water: WaterBuilder
var scatter: Scatter
var village: VillageBuilder
var weather_fx: WeatherFX
var customers: CustomerManager
var destinations: Dictionary = {}
var is_built := false


func build_async() -> void:
	Terrain.init_noise()
	Terrain.walk_zones.clear()
	build_progress.emit(0.02, "Raising the islands...")
	await get_tree().process_frame
	var terrain_root := Node3D.new()
	terrain_root.name = "Terrain"
	add_child(terrain_root)
	var n := TerrainBuilder.chunks_per_side()
	var total := n * n
	var done := 0
	for iz in n:
		for ix in n:
			var chunk := TerrainBuilder.build_chunk(ix, iz)
			if chunk:
				terrain_root.add_child(chunk)
			done += 1
		build_progress.emit(0.05 + 0.55 * float(done) / total, "Shaping the land...")
		await get_tree().process_frame
	build_progress.emit(0.62, "Filling the seas...")
	await get_tree().process_frame
	water = WaterBuilder.new()
	water.build(self)
	build_progress.emit(0.7, "Planting forests...")
	await get_tree().process_frame
	scatter = Scatter.new()
	scatter.build(self)
	scatter.apply_density(Settings.prop_density)
	Settings.changed.connect(func(): scatter.apply_density(Settings.prop_density))
	build_progress.emit(0.82, "Building villages...")
	await get_tree().process_frame
	village = VillageBuilder.new()
	village.build(self)
	destinations = village.destinations
	_spawn_smoke()
	_spawn_tanks()
	customers = CustomerManager.new()
	customers.name = "Customers"
	add_child(customers)
	customers.setup(village.market_slots)
	build_progress.emit(0.92, "Waking up the sky...")
	await get_tree().process_frame
	sky = SkyController.new()
	sky.name = "Sky"
	sky.water = water
	add_child(sky)
	weather_fx = WeatherFX.new()
	weather_fx.name = "WeatherFX"
	add_child(weather_fx)
	_spawn_player()
	sky.follow = player.camera
	weather_fx.follow = player
	if sky.water:
		sky.water.set_quality(Settings.water_quality)
	for it in get_tree().get_nodes_in_group("interactables"):
		pass
	is_built = true
	build_progress.emit(1.0, "Ready!")
	built.emit()


func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	add_child(player)
	var pos := START_POS
	if Game.player_pos.size() == 3:
		var p := Vector3(float(Game.player_pos[0]), float(Game.player_pos[1]), float(Game.player_pos[2]))
		if Terrain.walkable(p.x, p.z) and p.y > -1.0:
			pos = p + Vector3(0, 0.6, 0)
	pos.y = maxf(pos.y, Terrain.height_at(pos.x, pos.z) + 0.6)
	player.teleport(pos, 0.0)
	Save.player_provider = player.get_save_position


func interact(it: Interactable) -> void:
	if it == null:
		return
	interacted.emit(it.action, it.data)


func _spawn_smoke() -> void:
	for p in village.smoke_points:
		var sm := CPUParticles3D.new()
		sm.position = p
		sm.amount = 18
		sm.lifetime = 5.0
		sm.direction = Vector3(0.3, 1, 0)
		sm.spread = 12.0
		sm.initial_velocity_min = 1.5
		sm.initial_velocity_max = 2.5
		sm.gravity = Vector3(0.4, 0.3, 0)
		sm.scale_amount_min = 1.0
		sm.scale_amount_max = 2.2
		var mesh := SphereMesh.new()
		mesh.radius = 0.6
		mesh.height = 1.2
		mesh.radial_segments = 6
		mesh.rings = 3
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.8, 0.8, 0.82, 0.45)
		mesh.material = m
		sm.mesh = mesh
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sm)


func _spawn_tanks() -> void:
	for i in village.tank_anchors.size():
		var tv := TankVisual.new().setup(i)
		tv.position = village.tank_anchors[i]
		tv.name = "Tank%d" % (i + 1)
		add_child(tv)
		tv.visible = i < Game.tanks.size()
		Game.facilities_changed.connect(func(): tv.visible = i < Game.tanks.size())


## Teleports to a ferry destination id.
func travel_to(dest_id: String) -> bool:
	var d: Dictionary = destinations.get(dest_id, {})
	if d.is_empty():
		return false
	player.teleport(d["pos"], float(d["yaw"]))
	return true
