class_name Player
extends CharacterBody3D
## The angler: third-person movement, orbit camera and interaction sensor.

signal nearest_changed(interactable: Interactable)

const WALK_SPEED := 7.0          # was 5.0 - the island is big, so everything is quicker
const RUN_SPEED := 12.0          # was 8.5
const SWIM_SPEED := 5.5
const SWIM_RUN_SPEED := 7.5
const JUMP_SPEED := 8.6          # was 7.2
const GROUND_ACCEL := 60.0
const AIR_ACCEL := 22.0
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.12
const CAM_DISTANCES: Array[float] = [4.2, 6.5, 9.5]

var model: CharacterModel
var cam_yaw := 0.0
var cam_pitch := -0.32
var camera: Camera3D
var movement_enabled := true     ## false while a panel is open
var run_toggle := false
var nearest: Interactable = null
var fishing: FishingController

var _rig: Node3D
var _pitch: Node3D
var _arm: SpringArm3D
var _sensor: Area3D
var _last_safe := Vector3.ZERO
var _safe_timer := 0.0
var _step_timer := 0.0
var _move_input := Vector2.ZERO
var _facing_yaw := 0.0
var look_locked := false
var swimming := false
var _coyote := 0.0
var _jump_buffer := 0.0
var _swim_cooldown := 0.0
var _swim_splash := 0.0
var _ripple: MeshInstance3D
var _ripple_mat: ShaderMaterial


func _ready() -> void:
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.9
	floor_max_angle = deg_to_rad(62.0)   # climb steep banks instead of bouncing off them
	floor_stop_on_slope = false
	max_slides = 6
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)
	model = CharacterModel.new()
	model.setup(Color("e8584a"), Color("2f4a7a"), Color("e0b08a"), Color("f2c230"), "cap")
	add_child(model)
	fishing = FishingController.new()
	fishing.name = "Fishing"
	add_child(fishing)
	fishing.setup(self)
	_build_camera()
	_sensor = Area3D.new()
	_sensor.collision_layer = 0
	_sensor.collision_mask = 2
	_sensor.monitoring = true
	var ss := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 4.5
	ss.shape = sh
	ss.position = Vector3(0, 1.0, 0)
	_sensor.add_child(ss)
	add_child(_sensor)
	Settings.changed.connect(_apply_camera_settings)
	_apply_camera_settings()
	_last_safe = global_position


func _build_camera() -> void:
	_rig = Node3D.new()
	_rig.top_level = true
	add_child(_rig)
	_pitch = Node3D.new()
	_rig.add_child(_pitch)
	_arm = SpringArm3D.new()
	_arm.collision_mask = 1
	_arm.margin = 0.3
	_arm.spring_length = CAM_DISTANCES[1]
	_pitch.add_child(_arm)
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.near = 0.15
	_arm.add_child(camera)
	camera.current = true


func _apply_camera_settings() -> void:
	camera.far = Settings.view_distance_m() + 40.0
	_arm.spring_length = CAM_DISTANCES[clampi(Settings.camera_distance, 0, 2)]


func add_look(delta_px: Vector2) -> void:
	if look_locked:
		return
	var s := 0.0042 * Settings.look_sensitivity
	cam_yaw -= delta_px.x * s
	cam_pitch = clampf(cam_pitch - delta_px.y * s, -1.2, 0.55)


## Horizontal forward direction of the camera (the direction casts go in).
func aim_dir() -> Vector3:
	return Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))


func _process(delta: float) -> void:
	# smooth camera follow
	var target := global_position + Vector3(0, 1.55, 0)
	_rig.global_position = _rig.global_position.lerp(target, minf(1.0, delta * 14.0))
	_rig.rotation.y = cam_yaw
	_pitch.rotation.x = cam_pitch
	var speed_norm := minf(1.0, Vector2(velocity.x, velocity.z).length() / 8.5)
	var fishing_pose := model.pose != "idle"
	model.animate(delta, speed_norm, is_on_floor())
	if fishing_pose:
		_facing_yaw = lerp_angle(_facing_yaw, cam_yaw, minf(1.0, delta * 10.0))
	model.rotation.y = _facing_yaw


func _physics_process(delta: float) -> void:
	_move_input = Vector2.ZERO
	if movement_enabled and not fishing.locks_movement():
		_move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis_y := Basis(Vector3.UP, cam_yaw)
	var dir := basis_y * Vector3(_move_input.x, 0.0, _move_input.y)
	var running := run_toggle or Input.is_action_pressed("run")
	_update_swimming(delta)
	var speed := (SWIM_RUN_SPEED if running else SWIM_SPEED) if swimming else (RUN_SPEED if running else WALK_SPEED)
	if fishing.state != FishingController.State.IDLE:
		speed = 0.0
	var target_vel := dir * speed * minf(1.0, _move_input.length())
	var accel := 30.0 if swimming else (GROUND_ACCEL if is_on_floor() else AIR_ACCEL)
	velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)
	# jump with a short grace period (coyote time) and input buffering
	var can_act := movement_enabled and not fishing.locks_movement()
	_coyote = COYOTE_TIME if is_on_floor() else maxf(0.0, _coyote - delta)
	_jump_buffer = JUMP_BUFFER if (Input.is_action_just_pressed("jump") and can_act) else maxf(0.0, _jump_buffer - delta)
	if swimming:
		# float chest-deep; jumping out of the water works at the bank
		var level := Terrain.water_level_at(global_position.x, global_position.z)
		velocity.y = clampf((level - 1.0 - global_position.y) * 6.0, -5.0, 5.0)
		if _jump_buffer > 0.0:
			_jump_buffer = 0.0
			velocity.y = JUMP_SPEED
			_swim_cooldown = 0.5
			swimming = false
	else:
		if not is_on_floor():
			velocity.y -= 24.0 * delta
		if _jump_buffer > 0.0 and _coyote > 0.0:
			velocity.y = JUMP_SPEED
			_jump_buffer = 0.0
			_coyote = 0.0
	# keep the player out of the open sea (on foot or swimming)
	var next := global_position + Vector3(velocity.x, 0, velocity.z) * delta
	if not Terrain.passable(next.x, next.z):
		var try_x := Terrain.passable(next.x, global_position.z)
		var try_z := Terrain.passable(global_position.x, next.z)
		velocity.x = velocity.x if try_x else 0.0
		velocity.z = velocity.z if try_z else 0.0
	move_and_slide()
	if dir.length() > 0.1 and fishing.state == FishingController.State.IDLE and model.pose == "idle":
		_facing_yaw = lerp_angle(_facing_yaw, atan2(-dir.x, -dir.z), minf(1.0, delta * 12.0))
	# footsteps
	if is_on_floor() and not swimming and Vector2(velocity.x, velocity.z).length() > 2.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.42 if speed < RUN_SPEED else 0.3
			Sfx.play("step", 0.5, randf_range(0.9, 1.1))
	# safety net: never stay under the map / in deep water
	_safe_timer -= delta
	if is_on_floor() and Terrain.walkable(global_position.x, global_position.z) and _safe_timer <= 0.0:
		_safe_timer = 1.0
		_last_safe = global_position
	if global_position.y < -6.0:
		global_position = _last_safe + Vector3(0, 0.5, 0)
		velocity = Vector3.ZERO
	_update_nearest()


## Enter/leave swimming with a little hysteresis; pier decks stay walkable.
func _update_swimming(delta: float) -> void:
	_swim_cooldown = maxf(0.0, _swim_cooldown - delta)
	var p := global_position
	var level := Terrain.water_level_at(p.x, p.z)
	var was := swimming
	if level == -INF or _swim_cooldown > 0.0:
		swimming = false
	else:
		var depth := level - Terrain.height_at(p.x, p.z)
		var on_deck := Terrain.on_walk_zone(p.x, p.z) and p.y > level + 1.2
		swimming = not on_deck and depth > (0.85 if was else 1.05)
	model.swimming = swimming
	if swimming and not was:
		Sfx.play("splash", 0.6, randf_range(0.9, 1.1))
	if swimming:
		_swim_splash -= delta
		if _swim_splash <= 0.0 and Vector2(velocity.x, velocity.z).length() > 1.5:
			_swim_splash = 0.55
			Sfx.play("splash", 0.25, randf_range(1.0, 1.3))
	_update_ripple(level)


func _update_ripple(level: float) -> void:
	if _ripple == null:
		_ripple = MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(3.2, 3.2)
		_ripple.mesh = pm
		_ripple_mat = ShaderMaterial.new()
		_ripple_mat.shader = preload("res://shaders/ripple.gdshader")
		_ripple_mat.set_shader_parameter("speed", 1.1)
		_ripple.material_override = _ripple_mat
		_ripple.top_level = true
		_ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ripple)
	_ripple.visible = swimming
	if swimming:
		_ripple.global_position = Vector3(global_position.x, level + 0.04, global_position.z)


func _update_nearest() -> void:
	var best: Interactable = null
	var best_d := 1e9
	for a in _sensor.get_overlapping_areas():
		if a is Interactable:
			var d := global_position.distance_to(a.global_position)
			if d < best_d:
				best_d = d
				best = a
	if best != nearest:
		nearest = best
		nearest_changed.emit(nearest)


func teleport(pos: Vector3, yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	cam_yaw = yaw
	_facing_yaw = yaw
	_rig.global_position = pos + Vector3(0, 1.55, 0)
	_last_safe = pos


func get_save_position() -> Array:
	return [global_position.x, global_position.y, global_position.z]
