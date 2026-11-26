class_name TankVisual
extends Node3D
## A glass fish tank in the hatchery yard. Shows the fish that are really in
## the tank (size by growth), swimming around; refreshed when facilities change.

var tank_index := 0
var _fish_nodes: Array[Node3D] = []
var _label: Label3D
var _t := 0.0
const W := 3.2
const D := 2.0
const H := 1.5


func setup(index: int) -> TankVisual:
	tank_index = index
	var b := MeshBuilder.new()
	b.box(Vector3(0, 0.4, 0), Vector3(W + 0.4, 0.8, D + 0.4), Color("8a8f96"))
	b.box(Vector3(0, 0.88, 0), Vector3(W + 0.5, 0.1, D + 0.5), Color("5a5f66"))
	var base := MeshInstance3D.new()
	base.mesh = b.build()
	add_child(base)
	# glass + water
	var gm := StandardMaterial3D.new()
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.45, 0.8, 0.95, 0.28)
	gm.roughness = 0.1
	var glass := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(W, H, D)
	glass.mesh = bm
	glass.material_override = gm
	glass.position = Vector3(0, 0.93 + H * 0.5, 0)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	_label = Props.label("Tank %d" % (index + 1), 0.5, Color("c9f2ff"))
	_label.position = Vector3(0, 3.1, 0)
	add_child(_label)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(W + 0.4, 2.4, D + 0.4)
	cs.shape = sh
	cs.position = Vector3(0, 1.2, 0)
	body.add_child(cs)
	add_child(body)
	Game.facilities_changed.connect(refresh)
	refresh()
	return self


func refresh() -> void:
	for n in _fish_nodes:
		n.queue_free()
	_fish_nodes.clear()
	if tank_index >= Game.tanks.size():
		return
	var tank: Dictionary = Game.tanks[tank_index]
	var feed := float(tank.get("feed", 0.0))
	var list: Array = tank["fish"]
	_label.text = "Tank %d  ·  %d fish%s" % [tank_index + 1, list.size(), "" if feed > 1.0 or list.is_empty() else "  (hungry!)"]
	var i := 0
	for f: Dictionary in list:
		var sp: DataTypes.FishSpecies = Data.fish.get(f["sp"])
		if sp == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = Props.fish_mesh(sp.c1, sp.c2, sp.shape)
		var growth := Hatchery.growth_fraction(f)
		var size := (0.35 + 0.45 * growth) * clampf(0.7 + float(f.get("g", {}).get("size", 1.0)) * 0.4, 0.6, 1.3)
		mi.scale = Vector3.ONE * size
		mi.set_meta("phase", i * 1.7 + randf() * 2.0)
		mi.set_meta("speed", randf_range(0.5, 1.0))
		mi.set_meta("lane", randf_range(-0.35, 0.35))
		mi.set_meta("height", 0.5 + (i % 3) * 0.35)
		add_child(mi)
		_fish_nodes.append(mi)
		i += 1


func _process(delta: float) -> void:
	_t += delta
	for mi in _fish_nodes:
		var ph: float = mi.get_meta("phase") + _t * float(mi.get_meta("speed"))
		var rx := (W * 0.5 - 0.5) * (1.0 + float(mi.get_meta("lane")))
		var rz := (D * 0.5 - 0.45)
		var pos := Vector3(cos(ph) * rx, 0.93 + float(mi.get_meta("height")) + sin(ph * 2.0) * 0.08, sin(ph) * rz)
		var vel := Vector3(-sin(ph) * rx, 0, cos(ph) * rz)
		mi.position = pos
		mi.rotation.y = atan2(vel.x, vel.z)
