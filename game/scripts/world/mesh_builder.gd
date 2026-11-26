class_name MeshBuilder
extends RefCounted
## Tiny flat-shaded, vertex-coloured mesh builder. Everything in the game that
## is not terrain (trees, buildings, fish, characters, boats) is baked from
## primitives with this, so no external art assets are needed and each object is
## a single draw call.
##
## Solids are "oriented outward" automatically: every triangle is flipped, if
## needed, so its normal points away from the solid's centre.

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()


func is_empty() -> bool:
	return _v.is_empty()


func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color, center: Vector3) -> void:
	var n := (c - a).cross(b - a)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	var centroid := (a + b + c) / 3.0
	if n.dot(centroid - center) < 0.0:
		var tmp := b
		b = c
		c = tmp
		n = -n
	_v.append(a); _v.append(b); _v.append(c)
	_n.append(n); _n.append(n); _n.append(n)
	_c.append(col); _c.append(col); _c.append(col)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, center: Vector3) -> void:
	_tri(a, b, c, col, center)
	_tri(a, c, d, col, center)


func box(center: Vector3, size: Vector3, col: Color, basis := Basis.IDENTITY) -> void:
	var h := size * 0.5
	var p: Array[Vector3] = []
	for i in 8:
		var s := Vector3(-1 if (i & 1) == 0 else 1, -1 if (i & 2) == 0 else 1, -1 if (i & 4) == 0 else 1)
		p.append(center + basis * (h * s))
	# corner index bits: x=1, y=2, z=4
	var faces := [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]
	for f in faces:
		_quad(p[f[0]], p[f[1]], p[f[2]], p[f[3]], col, center)


## Frustum / cylinder / cone standing on `base` (centre of the bottom disc).
func cylinder(base: Vector3, r_bottom: float, r_top: float, height: float, segs: int,
		col: Color, col_top: Color = Color(0, 0, 0, 0), basis := Basis.IDENTITY) -> void:
	var up := basis * Vector3.UP * height
	var center := base + up * 0.5
	var top := base + up
	var ring_b: Array[Vector3] = []
	var ring_t: Array[Vector3] = []
	for i in segs:
		var a := TAU * i / segs
		var dir := basis * Vector3(cos(a), 0.0, sin(a))
		ring_b.append(base + dir * r_bottom)
		ring_t.append(top + dir * r_top)
	for i in segs:
		var j := (i + 1) % segs
		var c := col
		if col_top.a > 0.0:
			c = col.lerp(col_top, 0.5)
		if r_top <= 0.0001:
			_tri(ring_b[i], ring_b[j], top, c, center)
		else:
			_quad(ring_b[i], ring_b[j], ring_t[j], ring_t[i], c, center)
		if r_bottom > 0.0001:
			_tri(base, ring_b[j], ring_b[i], col, center)
		if r_top > 0.0001:
			_tri(top, ring_t[i], ring_t[j], col_top if col_top.a > 0.0 else col, center)


func cone(base: Vector3, radius: float, height: float, segs: int, col: Color, basis := Basis.IDENTITY) -> void:
	cylinder(base, radius, 0.0, height, segs, col, Color(0, 0, 0, 0), basis)


func sphere(center: Vector3, radius: float, col: Color, segs := 8, rings := 5,
		scale := Vector3.ONE, basis := Basis.IDENTITY) -> void:
	var pts: Array = []
	for r in rings + 1:
		var phi := PI * r / rings
		var row: Array[Vector3] = []
		for s in segs:
			var th := TAU * s / segs
			var local := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th)) * radius * scale
			row.append(center + basis * local)
		pts.append(row)
	for r in rings:
		for s in segs:
			var s2 := (s + 1) % segs
			var a: Vector3 = pts[r][s]
			var b: Vector3 = pts[r][s2]
			var c: Vector3 = pts[r + 1][s2]
			var d: Vector3 = pts[r + 1][s]
			_tri(a, b, c, col, center)
			_tri(a, c, d, col, center)


## Gable roof: ridge runs along local X. `base` is the centre of the bottom rectangle.
func gable_roof(base: Vector3, width_x: float, depth_z: float, height: float, col: Color,
		col_side: Color = Color(0, 0, 0, 0), overhang := 0.0) -> void:
	var hx := width_x * 0.5 + overhang
	var hz := depth_z * 0.5 + overhang
	var b0 := base + Vector3(-hx, 0, -hz)
	var b1 := base + Vector3(hx, 0, -hz)
	var b2 := base + Vector3(hx, 0, hz)
	var b3 := base + Vector3(-hx, 0, hz)
	var r0 := base + Vector3(-hx, height, 0)
	var r1 := base + Vector3(hx, height, 0)
	var center := base + Vector3(0, height * 0.4, 0)
	_quad(b0, b1, r1, r0, col, center)
	_quad(b3, b2, r1, r0, col, center)
	var sc := col_side if col_side.a > 0.0 else col.darkened(0.15)
	_tri(b0, b3, r0, sc, center)
	_tri(b1, b2, r1, sc, center)
	_quad(b0, b1, b2, b3, col.darkened(0.3), center)


func pyramid(base: Vector3, width: float, depth: float, height: float, col: Color) -> void:
	var hx := width * 0.5
	var hz := depth * 0.5
	var p := [base + Vector3(-hx, 0, -hz), base + Vector3(hx, 0, -hz),
		base + Vector3(hx, 0, hz), base + Vector3(-hx, 0, hz)]
	var apex := base + Vector3(0, height, 0)
	var center := base + Vector3(0, height * 0.3, 0)
	for i in 4:
		_tri(p[i], p[(i + 1) % 4], apex, col, center)
	_quad(p[0], p[1], p[2], p[3], col.darkened(0.3), center)


## Appends another builder's geometry transformed by `xf`.
func append(other: MeshBuilder, xf: Transform3D) -> void:
	var nb := xf.basis.inverse().transposed()
	for i in other._v.size():
		_v.append(xf * other._v[i])
		_n.append((nb * other._n[i]).normalized())
		_c.append(other._c[i])


func build(material: Material = null) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _v.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material if material else MeshBuilder.vertex_color_material())
	return mesh


static var _vc_mat: StandardMaterial3D = null

static func vertex_color_material() -> StandardMaterial3D:
	if _vc_mat == null:
		_vc_mat = StandardMaterial3D.new()
		_vc_mat.vertex_color_use_as_albedo = true
		_vc_mat.vertex_color_is_srgb = true  # palette colors are authored as sRGB hex
		_vc_mat.roughness = 0.9
		_vc_mat.metallic = 0.0
		_vc_mat.metallic_specular = 0.2
	return _vc_mat
