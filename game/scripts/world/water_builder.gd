class_name WaterBuilder
extends RefCounted
## Creates all water surfaces: the sea, Mirror Lake, Silverrun River and the
## tinted overlay discs that mark swamp / arctic / abyss waters.

const SHADER := preload("res://shaders/water.gdshader")

var materials: Array[ShaderMaterial] = []


func _material(shallow: Color, deep: Color, fade := false, priority := 0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("height_tex", TerrainBuilder.height_texture())
	m.set_shader_parameter("height_origin", Vector2(-Terrain.WORLD_HALF, -Terrain.WORLD_HALF))
	m.set_shader_parameter("height_size", Terrain.WORLD_HALF * 2.0)
	m.set_shader_parameter("h_min", TerrainBuilder.H_MIN)
	m.set_shader_parameter("h_max", TerrainBuilder.H_MAX)
	m.set_shader_parameter("depth_effects", 0.0 if fade else 1.0)
	m.set_shader_parameter("shallow_color", shallow)
	m.set_shader_parameter("deep_color", deep)
	m.set_shader_parameter("edge_fade", 1.0 if fade else 0.0)
	m.render_priority = priority
	materials.append(m)
	return m


func _plane(size: float, y: float, mat: Material, pos_xz := Vector2.ZERO, subdiv := 0) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	pm.subdivide_width = subdiv
	pm.subdivide_depth = subdiv
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.position = Vector3(pos_xz.x, y, pos_xz.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func build(parent: Node3D) -> void:
	# open sea (everything below y=0)
	var sea := _plane(3600.0, 0.0, _material(Color(0.16, 0.6, 0.78, 0.86), Color(0.05, 0.3, 0.55, 0.94)))
	sea.name = "Sea"
	parent.add_child(sea)
	# Mirror Lake
	var lake_size := (Terrain.LAKE_R + 14.0) * 2.0
	var lake := _plane(lake_size, Terrain.LAKE_LEVEL, _material(Color(0.2, 0.68, 0.72, 0.82), Color(0.08, 0.4, 0.55, 0.9), false, 1), Terrain.LAKE_C)
	lake.name = "Lake"
	parent.add_child(lake)
	# zone overlays
	var swamp := _plane(240.0, 0.05, _material(Color(0.32, 0.42, 0.22, 0.78), Color(0.2, 0.3, 0.16, 0.85), true, 2), Terrain.BOG)
	swamp.name = "SwampWater"
	parent.add_child(swamp)
	var arctic := _plane(240.0, 0.05, _material(Color(0.7, 0.92, 0.98, 0.8), Color(0.42, 0.72, 0.9, 0.85), true, 2), Terrain.FROST)
	arctic.name = "ArcticWater"
	parent.add_child(arctic)
	var deep := _plane(300.0, 0.05, _material(Color(0.05, 0.1, 0.28, 0.88), Color(0.02, 0.04, 0.16, 0.95), true, 2), Terrain.TRENCH)
	deep.name = "AbyssWater"
	parent.add_child(deep)
	parent.add_child(_river())


func _river() -> MeshInstance3D:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var pts: Array = Terrain.RIVER
	# extend the last point into the sea so the river mouth is open
	var samples := 40
	var half := Terrain.RIVER_HALF + 1.6
	for i in samples + 1:
		var f := float(i) / samples * (pts.size() - 1)
		var seg := mini(int(f), pts.size() - 2)
		var u := f - seg
		var p: Vector2 = (pts[seg] as Vector2).lerp(pts[seg + 1], u)
		var dir: Vector2 = ((pts[seg + 1] as Vector2) - pts[seg]).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var t := float(i) / samples
		var y := Terrain.river_level(t) + 0.02
		var l := p + nrm * half
		var r := p - nrm * half
		verts.append(Vector3(l.x, y, l.y))
		verts.append(Vector3(r.x, y, r.y))
		uvs.append(Vector2(0.0, t))
		uvs.append(Vector2(1.0, t))
	for i in samples:
		var a := i * 2
		idx.append_array([a, a + 2, a + 1, a + 1, a + 2, a + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var normals := PackedVector3Array()
	for i in verts.size():
		normals.append(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(Color(0.25, 0.7, 0.72, 0.84), Color(0.1, 0.45, 0.6, 0.9), false, 1)
	mi.name = "River"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Settings hook: simple (flat) vs animated water.
func set_quality(q: int) -> void:
	for m in materials:
		m.set_shader_parameter("detail", 1.0 if q > 0 else 0.0)


func set_waves(amp: float) -> void:
	for m in materials:
		m.set_shader_parameter("wave_amp", amp)


func set_sky(c: Color) -> void:
	for m in materials:
		m.set_shader_parameter("sky_color", c)


func set_dim(v: float) -> void:
	for m in materials:
		m.set_shader_parameter("night_dim", v)
