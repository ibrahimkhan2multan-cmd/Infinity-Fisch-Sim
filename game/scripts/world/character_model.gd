class_name CharacterModel
extends Node3D
## Low-poly person built from primitives, with procedural walk/fishing poses.
## Faces -Z (Godot forward). Used for the player and every NPC.

var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var body_root: Node3D
var rod_mount: Node3D   ## attached to the right hand
var pose := "idle"      ## idle | fish | charge | cast | reel | hold_fish
var _phase := 0.0
var _arm_r_target := 0.0
var _arm_l_target := 0.0
var _shake := 0.0


func setup(shirt: Color, pants: Color, skin: Color, hat: Color, hat_kind := "cap") -> CharacterModel:
	body_root = Node3D.new()
	add_child(body_root)
	_part(body_root, Vector3(0, 1.15, 0), _box_mesh(Vector3(0.55, 0.7, 0.32), shirt))
	_part(body_root, Vector3(0, 0.82, 0), _box_mesh(Vector3(0.57, 0.12, 0.34), pants.darkened(0.15)))
	# head
	var hb := MeshBuilder.new()
	hb.sphere(Vector3.ZERO, 0.26, skin, 8, 6)
	hb.sphere(Vector3(0, 0.04, 0.0), 0.275, Color("3a2a1c"), 8, 4, Vector3(1.0, 0.6, 1.0), Basis(Vector3.RIGHT, 0.45))
	for sx in [-1.0, 1.0]:
		hb.sphere(Vector3(sx * 0.1, 0.0, -0.22), 0.035, Color.BLACK, 4, 3)
	match hat_kind:
		"cap":
			hb.cylinder(Vector3(0, 0.18, 0), 0.28, 0.26, 0.14, 8, hat)
			hb.box(Vector3(0, 0.2, -0.3), Vector3(0.36, 0.04, 0.26), hat.darkened(0.2))
		"straw":
			hb.cylinder(Vector3(0, 0.17, 0), 0.2, 0.18, 0.16, 8, Color("e8cf86"))
			hb.cylinder(Vector3(0, 0.16, 0), 0.5, 0.5, 0.03, 10, Color("d9bd6a"))
		"hood":
			hb.sphere(Vector3(0, 0.02, 0.03), 0.31, hat, 8, 5, Vector3(1, 1.0, 1.05))
	var head := _part(body_root, Vector3(0, 1.8, 0), hb.build())
	head.name = "Head"
	# arms
	arm_l = _arm(-1.0, shirt, skin)
	arm_r = _arm(1.0, shirt, skin)
	rod_mount = Node3D.new()
	rod_mount.position = Vector3(0, -0.66, 0)
	arm_r.add_child(rod_mount)
	# legs
	leg_l = _leg(-1.0, pants)
	leg_r = _leg(1.0, pants)
	return self


func _box_mesh(size: Vector3, col: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	b.box(Vector3.ZERO, size, col)
	return b.build()


func _part(parent: Node3D, pos: Vector3, mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


func _arm(side: float, sleeve: Color, skin: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 0.38, 1.45, 0)
	body_root.add_child(pivot)
	var b := MeshBuilder.new()
	b.box(Vector3(0, -0.24, 0), Vector3(0.17, 0.5, 0.17), sleeve)
	b.box(Vector3(0, -0.57, 0), Vector3(0.14, 0.16, 0.14), skin)
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	pivot.add_child(mi)
	return pivot


func _leg(side: float, pants: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 0.15, 0.8, 0)
	add_child(pivot)
	var b := MeshBuilder.new()
	b.box(Vector3(0, -0.36, 0), Vector3(0.22, 0.72, 0.24), pants)
	b.box(Vector3(0, -0.76, -0.04), Vector3(0.24, 0.12, 0.34), Color("3b2a22"))
	var mi := MeshInstance3D.new()
	mi.mesh = b.build()
	pivot.add_child(mi)
	return pivot


## Call every frame. `speed` is 0..1 (fraction of run speed), `grounded` pauses the walk cycle in air.
func animate(delta: float, speed: float, grounded := true) -> void:
	if grounded:
		_phase += delta * (4.0 + speed * 9.0) * (1.0 if speed > 0.05 else 0.0)
	var swing := sin(_phase) * 0.75 * minf(speed * 1.4, 1.0)
	leg_l.rotation.x = lerpf(leg_l.rotation.x, swing, minf(1.0, delta * 18.0))
	leg_r.rotation.x = lerpf(leg_r.rotation.x, -swing, minf(1.0, delta * 18.0))
	body_root.position.y = absf(sin(_phase)) * 0.05 * speed
	match pose:
		"fish":
			_arm_r_target = 1.15
			_arm_l_target = 0.7
		"charge":
			_arm_r_target = -0.55
			_arm_l_target = 0.5
		"cast":
			_arm_r_target = 1.55
			_arm_l_target = 0.9
		"reel":
			_shake += delta * 30.0
			_arm_r_target = 1.05 + sin(_shake) * 0.12
			_arm_l_target = 0.75 + sin(_shake + 1.5) * 0.15
		"hold_fish":
			_arm_r_target = 2.7
			_arm_l_target = 2.7
		_:
			_arm_r_target = -swing * 0.7
			_arm_l_target = swing * 0.7
	var k := minf(1.0, delta * (28.0 if pose == "cast" else 12.0))
	arm_r.rotation.x = lerpf(arm_r.rotation.x, _arm_r_target, k)
	arm_l.rotation.x = lerpf(arm_l.rotation.x, _arm_l_target, k)
