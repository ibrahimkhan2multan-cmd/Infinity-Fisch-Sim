class_name TerrainBuilder
extends RefCounted
## Builds flat-shaded, vertex-coloured terrain chunks (mesh + trimesh collision)
## from the analytic Terrain functions.

const CELL := 5.0
const CHUNK_CELLS := 20
const CHUNK_SIZE := CELL * CHUNK_CELLS  # 100 m
const DEEP_SKIP := -14.0                # chunks entirely below this have no mesh
const COLLIDE_ABOVE := -3.0             # chunks entirely below this have no collision

static var _material: ShaderMaterial = null
static var _height_tex: ImageTexture = null

const HEIGHT_TEX_SIZE := 256
const H_MIN := -8.0
const H_MAX := 4.0


static func chunks_per_side() -> int:
	return int(ceil(Terrain.WORLD_HALF * 2.0 / CHUNK_SIZE))


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/terrain.gdshader")
	return _material


static func set_quality(q: int) -> void:
	material().set_shader_parameter("quality", 1.0 if q > 0 else 0.0)


## Low-res terrain height map (R8, clamped to [H_MIN, H_MAX]) for the water
## shader: it gives depth-based colour and shoreline foam without needing the
## depth texture (which is slow / unreliable on many phones).
static func height_texture() -> ImageTexture:
	if _height_tex == null:
		var img := Image.create(HEIGHT_TEX_SIZE, HEIGHT_TEX_SIZE, false, Image.FORMAT_R8)
		var step := Terrain.WORLD_HALF * 2.0 / HEIGHT_TEX_SIZE
		for j in HEIGHT_TEX_SIZE:
			for i in HEIGHT_TEX_SIZE:
				var h := Terrain.height_at(-Terrain.WORLD_HALF + (i + 0.5) * step, -Terrain.WORLD_HALF + (j + 0.5) * step)
				var v := clampf((h - H_MIN) / (H_MAX - H_MIN), 0.0, 1.0)
				img.set_pixel(i, j, Color(v, v, v, 1.0))
		_height_tex = ImageTexture.create_from_image(img)
	return _height_tex


## Returns a Node3D (or null for open-sea chunks that need no ground).
static func build_chunk(ix: int, iz: int) -> Node3D:
	var x0 := -Terrain.WORLD_HALF + ix * CHUNK_SIZE
	var z0 := -Terrain.WORLD_HALF + iz * CHUNK_SIZE
	var n := CHUNK_CELLS + 1
	var pn := n + 2  # padded by one ring so edge normals match across chunks
	var hp := PackedFloat32Array()
	hp.resize(pn * pn)
	var hmax := -1e9
	for j in pn:
		for i in pn:
			var h := Terrain.height_at(x0 + (i - 1) * CELL, z0 + (j - 1) * CELL)
			hp[j * pn + i] = h
			if i >= 1 and i <= n and j >= 1 and j <= n:
				hmax = maxf(hmax, h)
	if hmax < DEEP_SKIP:
		return null
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(n * n)
	norms.resize(n * n)
	cols.resize(n * n)
	for j in n:
		for i in n:
			var h := hp[(j + 1) * pn + i + 1]
			var x := x0 + i * CELL
			var z := z0 + j * CELL
			verts[j * n + i] = Vector3(x, h, z)
			var dx := hp[(j + 1) * pn + i] - hp[(j + 1) * pn + i + 2]
			var dz := hp[j * pn + i + 1] - hp[(j + 2) * pn + i + 1]
			norms[j * n + i] = Vector3(dx, 2.0 * CELL, dz).normalized()
			cols[j * n + i] = Terrain.biome_color(x, z, h)
	var idx := PackedInt32Array()
	var faces := PackedVector3Array()  # for collision
	var collide := hmax > COLLIDE_ABOVE
	for j in CHUNK_CELLS:
		for i in CHUNK_CELLS:
			var ia := j * n + i
			var ib := ia + 1
			var ic := ia + n
			var id := ic + 1
			# split the quad along its flatter diagonal for nicer shapes
			if absf(verts[ia].y - verts[id].y) < absf(verts[ib].y - verts[ic].y):
				_add_tri(ia, ib, id, verts, idx, faces, collide)
				_add_tri(ia, id, ic, verts, idx, faces, collide)
			else:
				_add_tri(ia, ib, ic, verts, idx, faces, collide)
				_add_tri(ib, id, ic, verts, idx, faces, collide)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
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


static func _add_tri(ia: int, ib: int, ic: int, verts: PackedVector3Array, idx: PackedInt32Array,
		faces: PackedVector3Array, collide: bool) -> void:
	var a := verts[ia]
	var b := verts[ib]
	var c := verts[ic]
	var nrm := (c - a).cross(b - a)
	if nrm.y < 0.0:
		var t := ib
		ib = ic
		ic = t
		t = 0
		var tv := b
		b = c
		c = tv
	idx.append(ia); idx.append(ib); idx.append(ic)
	if collide:
		faces.append(a); faces.append(b); faces.append(c)
