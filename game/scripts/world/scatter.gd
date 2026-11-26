class_name Scatter
extends RefCounted
## Scatters trees, bushes, rocks and reeds with MultiMeshes, bucketed in 100 m
## cells so frustum culling works. Density is adjustable at runtime from the
## graphics settings (visible_instance_count on shuffled instances).

const CELL := 100.0

var _nodes: Array[MultiMeshInstance3D] = []
var _counts: Array[int] = []


func build(parent: Node3D) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var buckets: Dictionary = {}  # "kind|cx|cz" -> Array[Transform3D]
	var total := 0
	# continent + islands scan area
	for gz in range(-340, 340, 8):
		for gx in range(-340, 340, 8):
			var x := gx + rng.randf_range(-3.2, 3.2)
			var z := gz + rng.randf_range(-3.2, 3.2)
			var kind := _pick_kind(x, z, rng)
			if kind == "":
				continue
			var y := Terrain.height_at(x, z)
			var s := rng.randf_range(0.8, 1.35)
			if kind == "rock":
				s = rng.randf_range(0.7, 2.2)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
			var key := "%s|%d|%d" % [kind, floori(x / CELL), floori(z / CELL)]
			if not buckets.has(key):
				buckets[key] = []
			buckets[key].append(Transform3D(basis, Vector3(x, y - 0.05, z)))
			total += 1
	for key in buckets:
		var kind: String = key.split("|")[0]
		var xforms: Array = buckets[key]
		# shuffle so visible_instance_count removes a random subset, not one side
		for i in range(xforms.size() - 1, 0, -1):
			var j := rng.randi() % (i + 1)
			var tmp = xforms[i]
			xforms[i] = xforms[j]
			xforms[j] = tmp
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Props.rock_mesh() if kind == "rock" else Props.tree_mesh(kind)
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.name = "Scatter_" + key.replace("|", "_")
		if kind in ["bush", "reed", "rock"]:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
		_nodes.append(node)
		_counts.append(xforms.size())
	return total


func apply_density(d: float) -> void:
	for i in _nodes.size():
		var n := maxi(1, int(round(_counts[i] * clampf(d, 0.05, 1.0))))
		_nodes[i].multimesh.visible_instance_count = n


func _pick_kind(x: float, z: float, rng: RandomNumberGenerator) -> String:
	var h := Terrain.height_at(x, z)
	if h < 0.9:
		return ""
	var p := Vector2(x, z)
	if rng.randf() < 0.28:
		return ""
	# keep plazas, plateaus, water margins clear
	if p.distance_to(Terrain.VILLAGE) < Terrain.VILLAGE_R + 14.0: return ""
	if p.distance_to(Terrain.FACTORY) < Terrain.FACTORY_R + 8.0: return ""
	if p.distance_to(Terrain.HAMLET) < Terrain.HAMLET_R + 6.0: return ""
	if p.distance_to(Terrain.LAKE_C) < Terrain.LAKE_R + 9.0: return ""
	if Terrain.river_info(x, z)[0] < 10.0: return ""
	if p.distance_to(Terrain.BOG) < 33.0 or p.distance_to(Terrain.FROST) < 31.0 or p.distance_to(Terrain.TRENCH) < 16.0:
		return ""
	var r := rng.randf()
	if p.distance_to(Terrain.BOG) < Terrain.BOG_R + 8.0:
		return "mangrove" if r < 0.55 else ("reed" if r < 0.85 else "dead")
	if p.distance_to(Terrain.FROST) < Terrain.FROST_R + 8.0:
		return "frost_pine" if r < 0.7 else "rock"
	if p.distance_to(Terrain.TRENCH) < Terrain.TRENCH_R + 6.0:
		return "rock"
	if h < 2.3:
		return "palm" if r < 0.5 else ("reed" if r < 0.7 else "bush")
	if h > 9.0:
		return "rock" if r < 0.4 else "pine"
	if r < 0.40: return "pine"
	if r < 0.68: return "round"
	if r < 0.84: return "bush"
	return "rock"
