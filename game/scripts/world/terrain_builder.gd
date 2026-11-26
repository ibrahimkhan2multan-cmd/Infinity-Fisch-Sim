class_name TerrainBuilder
extends RefCounted
## Builds flat-shaded, vertex-coloured terrain chunks (mesh + trimesh collision)
## from the analytic Terrain functions.

const CELL := 5.0
const CHUNK_CELLS := 20
const CHUNK_SIZE := CELL * CHUNK_CELLS  # 100 m
const DEEP_SKIP := -14.0                # chunks entirely below this have no mesh
const COLLIDE_ABOVE := -3.0             # chunks entirely below this have no collision

static var _material: StandardMaterial3D = null


static func chunks_per_side() -> int:
	return int(ceil(Terrain.WORLD_HALF * 2.0 / CHUNK_SIZE))


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 1.0
		_material.metallic_specular = 0.1
	return _material


## Returns a Node3D (or null for open-sea chunks that need no ground).
static func build_chunk(ix: int, iz: int) -> Node3D:
	var x0 := -Terrain.WORLD_HALF + ix * CHUNK_SIZE
	var z0 := -Terrain.WORLD_HALF + iz * CHUNK_SIZE
	var n := CHUNK_CELLS + 1
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	var hmax := -1e9
	for j in n:
		for i in n:
			var h := Terrain.height_at(x0 + i * CELL, z0 + j * CELL)
			hs[j * n + i] = h
			hmax = maxf(hmax, h)
	if hmax < DEEP_SKIP:
		return null
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var faces := PackedVector3Array()  # for collision
	var collide := hmax > COLLIDE_ABOVE
	for j in CHUNK_CELLS:
		for i in CHUNK_CELLS:
			var xa := x0 + i * CELL
			var za := z0 + j * CELL
			var a := Vector3(xa, hs[j * n + i], za)
			var b := Vector3(xa + CELL, hs[j * n + i + 1], za)
			var c := Vector3(xa, hs[(j + 1) * n + i], za + CELL)
			var d := Vector3(xa + CELL, hs[(j + 1) * n + i + 1], za + CELL)
			# split the quad along its flatter diagonal for nicer shapes
			if absf(a.y - d.y) < absf(b.y - c.y):
				_add_tri(a, b, d, verts, norms, cols, faces, collide)
				_add_tri(a, d, c, verts, norms, cols, faces, collide)
			else:
				_add_tri(a, b, c, verts, norms, cols, faces, collide)
				_add_tri(b, d, c, verts, norms, cols, faces, collide)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [ix, iz]
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	root.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		root.add_child(body)
	return root


static func _add_tri(a: Vector3, b: Vector3, c: Vector3, verts: PackedVector3Array,
		norms: PackedVector3Array, cols: PackedColorArray, faces: PackedVector3Array, collide: bool) -> void:
	var nrm := (c - a).cross(b - a).normalized()
	if nrm.y < 0.0:
		var t := b
		b = c
		c = t
		nrm = -nrm
	var cen := (a + b + c) / 3.0
	var col := Terrain.biome_color(cen.x, cen.z, cen.y)
	# subtle per-face variation gives the low-poly look
	var v := (Util.hash01(int(cen.x * 13.0) * 73856093 ^ int(cen.z * 13.0) * 19349663) - 0.5) * 0.08
	col = col.lightened(v) if v > 0.0 else col.darkened(-v)
	verts.append(a); verts.append(b); verts.append(c)
	norms.append(nrm); norms.append(nrm); norms.append(nrm)
	cols.append(col); cols.append(col); cols.append(col)
	if collide:
		faces.append(a); faces.append(b); faces.append(c)
