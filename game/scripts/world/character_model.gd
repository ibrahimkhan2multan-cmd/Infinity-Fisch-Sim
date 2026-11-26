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


static var _cache: Dictionary = {}

const HAIR_COLORS := ["2e2118", "4a3222", "7a4f2a", "1c1a1a", "a8742e", "5a2e22"]


func setup(shirt: Color, pants: Color, skin: Color, hat: Color, hat_kind := "cap") -> CharacterModel:
	var seed_value := int(shirt.r8 * 7 + shirt.g8 * 13 + shirt.b8 * 29 + pants.r8 * 3 + hat.g8)
	var hair := Color(HAIR_COLORS[seed_value % HAIR_COLORS.size()])
	var style := (seed_value / 7) % 3  # 0 short, 1 side-swept, 2 long
	var key := "%s|%s|%s|%s|%s" % [shirt.to_html(false), pants.to_html(false), skin.to_html(false), hat.to_html(false), hat_kind]
	var meshes: Dictionary = _cache.get(key, {})
	if meshes.is_empty():
		meshes = {
			"torso": _build_torso(shirt, pants, skin),
			"head": _build_head(skin, hair, style, hat, hat_kind),
			"arm_l": _build_arm(-1.0, shirt, skin),
			"arm_r": _build_arm(1.0, shirt, skin),
			"leg": _build_leg(pants),
		}
		_cache[key] = meshes
	body_root = Node3D.new()
	add_child(body_root)
	_part(body_root, Vector3.ZERO, meshes["torso"])
	var head := _part(body_root, Vector3(0, 1.8, 0), meshes["head"])
	head.name = "Head"
	arm_l = _pivot(Vector3(-0.38, 1.45, 0), meshes["arm_l"], body_root)
	arm_r = _pivot(Vector3(0.38, 1.45, 0), meshes["arm_r"], body_root)
	rod_mount = Node3D.new()
	rod_mount.position = Vector3(0, -0.66, 0)
	arm_r.add_child(rod_mount)
	leg_l = _pivot(Vector3(-0.15, 0.8, 0), meshes["leg"], self)
	leg_r = _pivot(Vector3(0.15, 0.8, 0), meshes["leg"], self)
	return self


func _pivot(pos: Vector3, mesh: Mesh, parent: Node3D) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	pivot.add_child(mi)
	return pivot


func _part(parent: Node3D, pos: Vector3, mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _shade(c: Color, amount: float) -> Color:
	return c.lightened(amount) if amount > 0.0 else c.darkened(-amount)


static func _build_torso(shirt: Color, pants: Color, skin: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	var belt := Color("4a3220")
	# hips + trousers top
	b.tube([Vector3(0, 0.74, 0), Vector3(0, 0.9, 0), Vector3(0, 1.0, 0)], [0.2, 0.215, 0.21], pants, pants.lightened(0.05), 12, true, false, 0.0, Vector2(1.08, 0.8))
	# torso: waist -> chest -> shoulders
	b.tube([Vector3(0, 0.98, 0), Vector3(0, 1.2, 0), Vector3(0, 1.4, 0), Vector3(0, 1.52, 0)],
		[0.2, 0.225, 0.255, 0.17], shirt.darkened(0.08), shirt.lightened(0.04), 12, false, false, 0.0, Vector2(1.12, 0.74))
	# shoulders
	for sx in [-1.0, 1.0]:
		b.ellipsoid(Vector3(sx * 0.3, 1.44, 0), Vector3(0.105, 0.1, 0.105), shirt, shirt.darkened(0.06), 9, 6)
	# belt + buckle
	b.tube([Vector3(0, 0.94, 0), Vector3(0, 1.0, 0)], [0.218, 0.218], belt, belt, 12, false, false, 0.0, Vector2(1.1, 0.78))
	b.box(Vector3(0, 0.97, -0.17), Vector3(0.09, 0.07, 0.03), Color("d4b25a"))
	# collar + neck
	b.tube([Vector3(0, 1.5, 0), Vector3(0, 1.66, 0)], [0.085, 0.075], skin, _shade(skin, -0.06), 8, false, false)
	b.tube([Vector3(0, 1.49, 0), Vector3(0, 1.55, 0)], [0.15, 0.115], shirt.lightened(0.18), shirt.lightened(0.18), 10, false, false, 0.0, Vector2(1.0, 0.85))
	# chest pockets and a zip line for some visual interest
	b.box(Vector3(0.1, 1.3, -0.205), Vector3(0.13, 0.12, 0.02), shirt.darkened(0.2))
	b.box(Vector3(-0.1, 1.3, -0.205), Vector3(0.13, 0.12, 0.02), shirt.darkened(0.2))
	b.box(Vector3(0, 1.18, -0.2), Vector3(0.018, 0.5, 0.02), shirt.darkened(0.25))
	return b.build()


static func _build_head(skin: Color, hair: Color, style: int, hat: Color, hat_kind: String) -> ArrayMesh:
	var b := MeshBuilder.new()
	var skin_d := _shade(skin, -0.1)
	b.ellipsoid(Vector3.ZERO, Vector3(0.235, 0.265, 0.245), _shade(skin, 0.05), skin_d, 14, 10)
	# jaw/chin softness
	b.ellipsoid(Vector3(0, -0.12, -0.03), Vector3(0.19, 0.15, 0.19), skin, skin_d, 10, 6)
	# ears
	for sx in [-1.0, 1.0]:
		b.ellipsoid(Vector3(sx * 0.235, -0.01, 0.0), Vector3(0.04, 0.07, 0.05), skin, skin_d, 7, 5)
	# nose, cheeks
	b.ellipsoid(Vector3(0, -0.04, -0.245), Vector3(0.04, 0.045, 0.045), _shade(skin, -0.04), skin_d, 7, 5)
	for sx in [-1.0, 1.0]:
		var blush := skin.lerp(Color("e0707a"), 0.35)
		b.ellipsoid(Vector3(sx * 0.12, -0.08, -0.205), Vector3(0.05, 0.035, 0.02), blush, blush, 7, 4)
	# eyes: white, iris, pupil, glint, brows
	for sx in [-1.0, 1.0]:
		var ex: float = sx * 0.088
		b.ellipsoid(Vector3(ex, 0.03, -0.205), Vector3(0.047, 0.05, 0.03), Color("fbfaf6"), Color("e6e3da"), 9, 6)
		b.ellipsoid(Vector3(ex, 0.03, -0.232), Vector3(0.03, 0.034, 0.014), Color("4a6b8a"), Color("2f4a63"), 8, 5)
		b.ellipsoid(Vector3(ex, 0.03, -0.243), Vector3(0.016, 0.018, 0.008), Color("0c0f14"), Color("0c0f14"), 6, 4)
		b.ellipsoid(Vector3(ex + 0.012, 0.045, -0.247), Vector3(0.007, 0.007, 0.004), Color.WHITE, Color.WHITE, 5, 3)
		b.box(Vector3(ex, 0.095, -0.215), Vector3(0.07, 0.016, 0.02), _shade(hair, -0.05), Basis(Vector3(0, 0, 1), sx * 0.12))
	# mouth (small smile)
	b.box(Vector3(0, -0.125, -0.228), Vector3(0.07, 0.014, 0.014), Color("8a3b36"))
	b.box(Vector3(-0.037, -0.115, -0.226), Vector3(0.016, 0.014, 0.012), Color("8a3b36"), Basis(Vector3(0, 0, 1), -0.6))
	b.box(Vector3(0.037, -0.115, -0.226), Vector3(0.016, 0.014, 0.012), Color("8a3b36"), Basis(Vector3(0, 0, 1), 0.6))
	# hair
	var hl := _shade(hair, 0.1)
	if hat_kind != "hood":
		b.ellipsoid(Vector3(0, 0.07, 0.03), Vector3(0.255, 0.23, 0.265), hl, hair, 12, 8, Basis(Vector3.RIGHT, 0.2))
		match style:
			1:
				b.ellipsoid(Vector3(-0.1, 0.17, -0.17), Vector3(0.17, 0.07, 0.1), hl, hair, 9, 5, Basis(Vector3(0, 0, 1), 0.3))
			2:
				b.ellipsoid(Vector3(0, -0.12, 0.17), Vector3(0.23, 0.3, 0.1), hl, hair, 10, 7)
			_:
				b.ellipsoid(Vector3(0, 0.15, -0.18), Vector3(0.2, 0.06, 0.09), hl, hair, 9, 5)
	match hat_kind:
		"cap":
			b.ellipsoid(Vector3(0, 0.12, 0.0), Vector3(0.275, 0.2, 0.285), hat.lightened(0.08), hat, 14, 7)
			b.ellipsoid(Vector3(0, 0.15, -0.3), Vector3(0.2, 0.025, 0.2), hat.darkened(0.15), hat.darkened(0.3), 12, 3)
			b.ellipsoid(Vector3(0, 0.27, 0), Vector3(0.03, 0.03, 0.03), hat.darkened(0.25), hat.darkened(0.25), 5, 3)
		"straw":
			var straw := Color("e6cb7e")
			b.ellipsoid(Vector3(0, 0.15, 0), Vector3(0.22, 0.2, 0.22), straw.lightened(0.05), straw, 12, 6)
			b.ellipsoid(Vector3(0, 0.12, 0), Vector3(0.52, 0.03, 0.52), straw.lightened(0.02), straw.darkened(0.12), 16, 3)
			b.tube([Vector3(0, 0.11, 0), Vector3(0, 0.18, 0)], [0.225, 0.22], hat, hat, 14, false, false)
		"hood":
			b.ellipsoid(Vector3(0, 0.02, 0.04), Vector3(0.32, 0.31, 0.33), hat.lightened(0.05), hat.darkened(0.1), 12, 8)
			b.ellipsoid(Vector3(0, -0.02, -0.2), Vector3(0.2, 0.2, 0.08), skin, skin_d, 10, 6)
	return b.build()


static func _build_arm(side: float, shirt: Color, skin: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	# sleeve (upper arm) then rolled cuff, forearm, hand
	b.tube([Vector3(0, -0.02, 0), Vector3(0, -0.2, 0), Vector3(0, -0.36, 0)], [0.1, 0.085, 0.08], shirt, shirt.darkened(0.05), 9, false, false)
	b.tube([Vector3(0, -0.34, 0), Vector3(0, -0.4, 0)], [0.092, 0.092], shirt.lightened(0.15), shirt.lightened(0.15), 9, false, true)
	b.tube([Vector3(0, -0.4, 0), Vector3(0, -0.55, 0)], [0.066, 0.052], skin, _shade(skin, -0.05), 8, false, false)
	b.ellipsoid(Vector3(0, -0.62, 0), Vector3(0.062, 0.075, 0.06), skin, _shade(skin, -0.06), 8, 6)
	b.ellipsoid(Vector3(-side * 0.0, -0.6, -0.055), Vector3(0.025, 0.04, 0.03), skin, skin, 6, 4)  # thumb
	return b.build()


static func _build_leg(pants: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	var boot := Color("4a3328")
	b.tube([Vector3(0, -0.02, 0), Vector3(0, -0.36, 0), Vector3(0, -0.66, 0)], [0.12, 0.1, 0.085], pants, pants.darkened(0.08), 9, false, false)
	b.tube([Vector3(0, -0.6, 0), Vector3(0, -0.74, 0)], [0.095, 0.09], boot, boot.lightened(0.05), 9, false, true)
	b.ellipsoid(Vector3(0, -0.76, -0.05), Vector3(0.1, 0.07, 0.17), boot.lightened(0.08), boot.darkened(0.2), 9, 5)
	b.ellipsoid(Vector3(0, -0.81, -0.04), Vector3(0.1, 0.02, 0.18), Color("2a1f1a"), Color("2a1f1a"), 8, 3)  # sole
	return b.build()


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
