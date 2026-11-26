class_name FishingController
extends Node3D
## Full fishing loop for the player:
##   IDLE -> CHARGING (hold) -> CASTING -> WAITING -> BITE -> REELING -> RESULT -> IDLE
## Handles the rod/line/bobber visuals, water & permit checks, the fish roll and
## the reel minigame, and reports to the HUD through signals.

enum State { IDLE, CHARGING, CASTING, WAITING, BITE, REELING, RESULT }

signal state_changed(state: int)
signal power_changed(power: float)
signal bite_started
signal message(text: String, kind: String)
signal reel_started(fish: Dictionary)
signal catch_finished(success: bool, fish: Dictionary, is_new: bool)

const ROD_LEN := 2.4
const BITE_WINDOW := 1.5
const CAST_TIME := 0.7

var state: State = State.IDLE
var power := 0.0
var water_type := ""
var target := Vector3.ZERO
var minigame: ReelMinigame = null
var current_fish: Dictionary = {}
var reel_holding := false
var cast_stats: Dictionary = {}

var _player: Player
var _rod_holder: Node3D
var _rod_mesh: MeshInstance3D
var _bobber: MeshInstance3D
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh
var _aim: MeshInstance3D
var _held_fish: MeshInstance3D
var _splash: CPUParticles3D
var _sparkle: CPUParticles3D
var _power_dir := 1.0
var _cast_t := 0.0
var _cast_from := Vector3.ZERO
var _wait_left := 0.0
var _bite_left := 0.0
var _result_left := 0.0
var _rod_angle := 2.9
var _rod_tip_local := Vector3(0, -ROD_LEN, 0)
var _ripple: MeshInstance3D
var _ripple_mat: ShaderMaterial
var _t := 0.0
var _reel_tick := 0.0


func setup(p: Player) -> void:
	_player = p
	_rod_holder = Node3D.new()
	_player.model.rod_mount.add_child(_rod_holder)
	_rod_mesh = MeshInstance3D.new()
	_rod_holder.add_child(_rod_mesh)
	_rebuild_rod()
	Game.equipment_changed.connect(_rebuild_rod)
	# world-space helpers
	_bobber = MeshInstance3D.new()
	_bobber.top_level = true
	_bobber.visible = false
	var bb := MeshBuilder.new()
	bb.ellipsoid(Vector3(0, 0.06, 0), Vector3(0.14, 0.16, 0.14), Color("f4f1ea"), Color("e6e0d2"), 10, 7)
	bb.ellipsoid(Vector3(0, -0.07, 0), Vector3(0.138, 0.13, 0.138), Color("d9302a"), Color("a82220"), 10, 6)
	bb.tube([Vector3(0, 0.2, 0), Vector3(0, 0.4, 0)], [0.018, 0.012], Color("e8e3d6"), Color("d9302a"), 6, false, true)
	bb.tube([Vector3(0, -0.2, 0), Vector3(0, -0.28, 0)], [0.012, 0.012], Color("3a3a3e"), Color("3a3a3e"), 5, false, true)
	_bobber.mesh = bb.build()
	add_child(_bobber)
	_ripple = MeshInstance3D.new()
	var rp := PlaneMesh.new()
	rp.size = Vector2(2.4, 2.4)
	_ripple.mesh = rp
	_ripple_mat = ShaderMaterial.new()
	_ripple_mat.shader = preload("res://shaders/ripple.gdshader")
	_ripple.material_override = _ripple_mat
	_ripple.top_level = true
	_ripple.visible = false
	_ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ripple)
	_line = MeshInstance3D.new()
	_line.top_level = true
	_line_mesh = ImmediateMesh.new()
	_line.mesh = _line_mesh
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.95, 0.95, 0.9, 0.95)
	_line.material_override = lm
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)
	_aim = MeshInstance3D.new()
	_aim.top_level = true
	_aim.visible = false
	var cm := CylinderMesh.new()
	cm.top_radius = 0.7
	cm.bottom_radius = 0.7
	cm.height = 0.03
	cm.radial_segments = 20
	var am := StandardMaterial3D.new()
	am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	am.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	am.albedo_color = Color(0.4, 0.95, 1.0, 0.55)
	cm.material = am
	_aim.mesh = cm
	_aim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aim)
	_held_fish = MeshInstance3D.new()
	_held_fish.visible = false
	_player.model.body_root.add_child(_held_fish)
	_held_fish.position = Vector3(0, 2.55, 0)
	_splash = _make_particles(Color(0.8, 0.92, 1.0), 26, 0.6, 3.5, 5.5, 55.0)
	_splash.top_level = true
	add_child(_splash)
	_sparkle = _make_particles(Color.WHITE, 40, 1.0, 1.5, 3.5, 180.0)
	_player.model.body_root.add_child(_sparkle)
	_sparkle.position = Vector3(0, 2.3, 0)


func _make_particles(col: Color, amount: int, life: float, vmin: float, vmax: float, spread: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3(0, -9.0, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	sm.material = m
	p.mesh = sm
	p.color = col
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _rebuild_rod() -> void:
	var built := RodModel.build(Game.rod_data(), ROD_LEN)
	_rod_mesh.mesh = built["mesh"]
	_rod_tip_local = built["tip"]


func rod_tip() -> Vector3:
	return _rod_holder.global_transform * _rod_tip_local


func state_name() -> String:
	return State.keys()[state]


func locks_movement() -> bool:
	return state != State.IDLE


func _set_state(s: State) -> void:
	state = s
	state_changed.emit(int(s))


# ---- Input API (called by the HUD / keyboard) ---------------------------------

func press_cast() -> void:
	match state:
		State.IDLE:
			if not Game.has_space():
				_say("Your backpack is full! Sell or store some fish.", "bad")
				Sfx.play("error")
				return
			power = 0.0
			_power_dir = 1.0
			_set_state(State.CHARGING)
			_player.model.pose = "charge"
		State.WAITING:
			cancel("You reel the line back in.")
		State.BITE:
			hook()


func release_cast() -> void:
	if state == State.CHARGING:
		_launch()


func hook() -> void:
	if state != State.BITE:
		return
	var luck: float = cast_stats.get("luck", 0.0)
	var f := FishLogic.roll_catch(water_type, luck, cast_stats.get("size", 0.0), Clock.hour, Clock.weather)
	if f.is_empty():
		cancel("Nothing there.")
		return
	current_fish = f
	minigame = ReelMinigame.new()
	minigame.setup(FishLogic.reel_difficulty(f), cast_stats.get("control", 0.3), cast_stats.get("resilience", 0.1))
	reel_holding = false
	_set_state(State.REELING)
	_player.model.pose = "reel"
	Sfx.play("splash", 0.7)
	Settings.vibrate(60)
	reel_started.emit(f)


func set_reel(holding: bool) -> void:
	reel_holding = holding


func cancel(msg := "") -> void:
	if state == State.IDLE:
		return
	_end_cast()
	if msg != "":
		_say(msg, "info")


func _end_cast() -> void:
	_bobber.visible = false
	_aim.visible = false
	_line_mesh.clear_surfaces()
	minigame = null
	reel_holding = false
	_player.model.pose = "idle"
	_set_state(State.IDLE)


func _say(text: String, kind := "info") -> void:
	message.emit(text, kind)
	Game.notify.emit(text, kind)


# ---- Casting ---------------------------------------------------------------------

func _origin() -> Vector3:
	return _player.global_position + Vector3(0, 1.0, 0) + _player.aim_dir() * 0.8


## Finds the water point closest to the desired distance along the aim direction.
## Returns an empty array when there is no water within range in that direction.
func find_target(origin: Vector3, dir: Vector3, desired: float, max_range: float) -> Array:
	var best: Array = []
	var best_diff := 1e9
	var d := 3.0
	while d <= max_range + 0.01:
		var p := origin + dir * d
		var wl := Terrain.water_level_at(p.x, p.z)
		if wl != -INF and Terrain.height_at(p.x, p.z) < wl - 0.3:
			var diff := absf(d - desired)
			if diff < best_diff:
				best_diff = diff
				best = [Vector3(p.x, wl, p.z), d]
		d += 1.0
	return best


func _launch() -> void:
	var range_m := Game.fishing_stat("range")
	var desired := lerpf(0.3, 1.0, power) * range_m
	var found := find_target(_origin(), _player.aim_dir(), desired, range_m)
	if found.is_empty():
		_say("No water that way - face the water and try again.", "bad")
		Sfx.play("error")
		_end_cast()
		return
	var tp: Vector3 = found[0]
	var wt := Terrain.water_type_at(tp.x, tp.z)
	if wt == "":
		wt = "shore"
	if not Game.has_water_access(wt):
		var loc: DataTypes.Location = Data.locations[WorldDB.location_for_water(wt)]
		_say("%s needs a permit (level %d, %s) - visit the Fishing Guild." % [loc.name, loc.level_req, Util.money(loc.cost)], "bad")
		Sfx.play("error")
		_end_cast()
		return
	water_type = wt
	target = tp
	# lock in the stats now (bait is used up by the cast)
	cast_stats = {
		"luck": Game.fishing_stat("luck"), "lure": Game.fishing_stat("lure"),
		"control": Game.fishing_stat("control"), "resilience": Game.fishing_stat("resilience"),
		"size": Game.fishing_stat("size"),
	}
	Game.consume_bait()
	_cast_from = rod_tip()
	_cast_t = 0.0
	_bobber.global_position = _cast_from
	_bobber.visible = true
	_aim.visible = false
	_player.model.pose = "cast"
	_set_state(State.CASTING)
	Sfx.play("cast")


# ---- Per-frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_update_rod_pose(delta)
	match state:
		State.CHARGING:
			power += _power_dir * delta * 1.15
			if power >= 1.0:
				power = 1.0
				_power_dir = -1.0
			elif power <= 0.0:
				power = 0.0
				_power_dir = 1.0
			power_changed.emit(power)
			var range_m := Game.fishing_stat("range")
			var found := find_target(_origin(), _player.aim_dir(), lerpf(0.3, 1.0, power) * range_m, range_m)
			_aim.visible = not found.is_empty()
			if not found.is_empty():
				_aim.global_position = (found[0] as Vector3) + Vector3(0, 0.05, 0)
		State.CASTING:
			_cast_t += delta / CAST_TIME
			var t := minf(_cast_t, 1.0)
			var p := _cast_from.lerp(target, t)
			p.y += sin(t * PI) * 3.5
			_bobber.global_position = p
			if _cast_t >= 1.0:
				_on_landed()
		State.WAITING:
			_bobber.global_position = target + Vector3(0, sin(_t * 2.2) * 0.04 + 0.05, 0)
			_wait_left -= delta
			if _wait_left <= 0.0:
				_start_bite()
		State.BITE:
			_bobber.global_position = target + Vector3(sin(_t * 40.0) * 0.06, -0.22, cos(_t * 33.0) * 0.06)
			_bite_left -= delta
			if _bite_left <= 0.0:
				Sfx.play("escape")
				_say("The fish got away - hook faster next time!", "bad")
				_end_cast()
		State.REELING:
			_update_reeling(delta)
		State.RESULT:
			_result_left -= delta
			if _result_left <= 0.0:
				_held_fish.visible = false
				_player.model.pose = "idle"
				_set_state(State.IDLE)
	_update_ripple()
	_update_line()


func _on_landed() -> void:
	_splash.global_position = target
	_splash.restart()
	_splash.emitting = true
	Sfx.play("splash", 0.8)
	_player.model.pose = "fish"
	_wait_left = FishLogic.bite_wait(cast_stats.get("lure", 1.0), Clock.bite_mult())
	_set_state(State.WAITING)


func _start_bite() -> void:
	_bite_left = BITE_WINDOW
	_splash.global_position = target
	_splash.restart()
	_splash.emitting = true
	Sfx.play("bite")
	Settings.vibrate(120)
	_set_state(State.BITE)
	bite_started.emit()


func _update_reeling(delta: float) -> void:
	minigame.update(delta, reel_holding)
	# the bobber is dragged toward the angler as progress grows, thrashing with the fish
	var base := _player.global_position + Vector3(0, 0.1, 0)
	var flat := Vector3(target.x - base.x, 0, target.z - base.z)
	var dist := flat.length() * (1.0 - minigame.progress * 0.75)
	var p := base + flat.normalized() * dist
	var wl := Terrain.water_level_at(p.x, p.z)
	p.y = (wl if wl != -INF else target.y) + 0.05 + sin(_t * 25.0) * 0.05
	p += Vector3(sin(_t * 9.0), 0, cos(_t * 7.0)) * 0.4 * (1.0 - minigame.progress)
	_bobber.global_position = p
	if reel_holding:
		_reel_tick -= delta
		if _reel_tick <= 0.0:
			_reel_tick = 0.14
			Sfx.play("reel", 0.5, 0.9 + minigame.progress * 0.5)
	if minigame.state == ReelMinigame.State.WON:
		_finish(true)
	elif minigame.state == ReelMinigame.State.LOST:
		_finish(false)


func _finish(success: bool) -> void:
	var f := current_fish
	_bobber.visible = false
	_line_mesh.clear_surfaces()
	minigame = null
	reel_holding = false
	if not success:
		Sfx.play("escape")
		_say("It broke free!", "bad")
		_player.model.pose = "idle"
		catch_finished.emit(false, f, false)
		_set_state(State.IDLE)
		return
	var is_new := false
	if Game.has_space():
		Game.add_fish(f)
	elif Game.crate.size() < Game.warehouse_capacity():
		Game.crate.append(f)
		_say("Backpack full - the fish went to the dock crate.", "info")
	else:
		_say("Backpack and crate are full - the fish was released.", "bad")
	is_new = Game.record_catch(f)
	var sp: DataTypes.FishSpecies = Data.fish[f["sp"]]
	var xp := Util.RARITY_XP[sp.rarity] + int(float(f["w"]) * 2.0)
	if is_new:
		xp += 20 + sp.rarity * 15
	Game.add_xp(xp)
	var rare: bool = sp.rarity >= 3 or str(f.get("mut", "")) != ""
	Sfx.play("rare" if rare else "catch")
	Settings.vibrate(200 if rare else 80)
	# show the fish above the angler's head
	_held_fish.mesh = Props.fish_mesh(sp.c1, sp.c2, sp.shape)
	var sc := clampf(0.5 + log(1.0 + float(f["w"])) * 0.18, 0.5, 1.8)
	_held_fish.scale = Vector3.ONE * sc
	_held_fish.rotation = Vector3(0, PI, 0)
	_held_fish.visible = true
	_sparkle.color = Util.rarity_color(sp.rarity)
	_sparkle.amount = 24 + sp.rarity * 14
	_sparkle.restart()
	_sparkle.emitting = true
	_player.model.pose = "hold_fish"
	_result_left = 2.0
	_set_state(State.RESULT)
	catch_finished.emit(true, f, is_new)


func _update_rod_pose(delta: float) -> void:
	var want := 2.9  # carried upright
	match state:
		State.CHARGING: want = 3.6
		State.CASTING: want = 1.55
		State.WAITING, State.BITE: want = 2.1 + (sin(_t * 30.0) * 0.12 if state == State.BITE else 0.0)
		State.REELING: want = 2.0 + sin(_t * 18.0) * 0.1
		State.RESULT: want = 2.6
	_rod_angle = lerpf(_rod_angle, want, minf(1.0, delta * 12.0))
	# rod direction is local -Y rotated about X; counter the arm so the pole angle is absolute
	_rod_holder.rotation.x = _rod_angle - _player.model.arm_r.rotation.x


func _update_ripple() -> void:
	var on_water := _bobber.visible and state in [State.WAITING, State.BITE, State.REELING]
	_ripple.visible = on_water
	if on_water:
		_ripple.global_position = Vector3(_bobber.global_position.x, target.y + 0.04, _bobber.global_position.z)
		_ripple_mat.set_shader_parameter("speed", 2.2 if state == State.BITE else 0.7)
		_ripple_mat.set_shader_parameter("strength", 1.0 if state != State.REELING else 0.7)


func _update_line() -> void:
	_line_mesh.clear_surfaces()
	if state in [State.IDLE, State.CHARGING, State.RESULT]:
		return
	var a := rod_tip()
	var b := _bobber.global_position
	var sag := 0.55
	match state:
		State.REELING: sag = 0.08
		State.CASTING: sag = 0.25
		State.BITE: sag = 0.15
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var n := 12
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(b, t)
		p.y -= sag * 4.0 * t * (1.0 - t)
		_line_mesh.surface_add_vertex(p)
	_line_mesh.surface_end()
