class_name Player
extends CharacterBody3D
## The angler: third-person movement, orbit camera and interaction sensor.

signal nearest_changed(interactable: Interactable)

const WALK_SPEED := 5.0
const RUN_SPEED := 8.5
const JUMP_SPEED := 7.2
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


func _ready() -> void:
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.6
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
	var speed_norm := Vector2(velocity.x, velocity.z).length() / RUN_SPEED
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
	var speed := RUN_SPEED if (run_toggle or Input.is_action_pressed("run")) else WALK_SPEED
	if fishing.state != FishingController.State.IDLE:
		speed = 0.0
	var target_vel := dir * speed * minf(1.0, _move_input.length())
	var accel := 40.0 if is_on_floor() else 12.0
	velocity.x = move_toward(velocity.x, target_vel.x, accel * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, accel * delta)
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	elif Input.is_action_just_pressed("jump") and movement_enabled and not fishing.locks_movement():
		velocity.y = JUMP_SPEED
	# keep the player out of deep water
	var next := global_position + Vector3(velocity.x, 0, velocity.z) * delta
	if not Terrain.walkable(next.x, next.z):
		var try_x := Terrain.walkable(next.x, global_position.z)
		var try_z := Terrain.walkable(global_position.x, next.z)
		velocity.x = velocity.x if try_x else 0.0
		velocity.z = velocity.z if try_z else 0.0
	move_and_slide()
	if dir.length() > 0.1 and fishing.state == FishingController.State.IDLE and model.pose == "idle":
		_facing_yaw = lerp_angle(_facing_yaw, atan2(-dir.x, -dir.z), minf(1.0, delta * 12.0))
	# footsteps
	if is_on_floor() and Vector2(velocity.x, velocity.z).length() > 2.0:
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
