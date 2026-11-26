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


static var _vc_mat: ShaderMaterial = null

static func vertex_color_material() -> ShaderMaterial:
	if _vc_mat == null:
		_vc_mat = ShaderMaterial.new()
		_vc_mat.shader = preload("res://shaders/prop.gdshader")
	return _vc_mat


# ---------------------------------------------------------------------------
# Smooth-shaded primitives (per-vertex normals + gradients). Colour alpha is
# the wind-sway weight consumed by prop.gdshader: 1 = rigid, 0 = fully swaying.
# ---------------------------------------------------------------------------

## Adds a triangle with per-vertex normals/colours; the winding is fixed so the
## geometric normal agrees with the average vertex normal.
func tri_smooth(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		ca: Color, cb: Color, cc: Color) -> void:
	var g := (c - a).cross(b - a)
	if g.length_squared() < 1e-12:
		return
	if g.dot(na + nb + nc) < 0.0:
		var tp := b; b = c; c = tp
		tp = nb; nb = nc; nc = tp
		var tc := cb; cb = cc; cc = tc
	_v.append(a); _v.append(b); _v.append(c)
	_n.append(na); _n.append(nb); _n.append(nc)
	_c.append(ca); _c.append(cb); _c.append(cc)


## Smooth ellipsoid with a vertical colour gradient (bottom -> top), optional
## lumpiness (`bump`, for foliage/rocks) and wind sway.
func ellipsoid(center: Vector3, radii: Vector3, col_top: Color, col_bot: Color = Color(0, 0, 0, 0),
		segs := 10, rings := 7, basis := Basis.IDENTITY, bump := 0.0, seed_value := 0, sway := 0.0) -> void:
	if col_bot.a == 0.0 and col_bot == Color(0, 0, 0, 0):
		col_bot = col_top
	var pts: Array = []
	var nrm: Array = []
	var cols: Array = []
	for r in rings + 1:
		var phi := PI * r / rings
		var prow: Array[Vector3] = []
		var nrow: Array[Vector3] = []
		var crow: Array[Color] = []
		for sg in segs:
			var th := TAU * sg / segs
			var d := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var k := 1.0
			if bump > 0.0:
				var hsh := Util.hash01(seed_value * 131 + r * 17 + (sg % maxi(segs, 1)) * 7919)
				k = 1.0 + (hsh - 0.5) * 2.0 * bump
				if r == 0 or r == rings:
					k = 1.0
			var local := Vector3(d.x * radii.x, d.y * radii.y, d.z * radii.z) * k
			prow.append(center + basis * local)
			var nl := Vector3(d.x / maxf(radii.x, 1e-4), d.y / maxf(radii.y, 1e-4), d.z / maxf(radii.z, 1e-4))
			nrow.append((basis * nl).normalized())
			var t := clampf(0.5 + 0.5 * d.y, 0.0, 1.0)
			var cl := col_bot.lerp(col_top, smoothstep(0.1, 0.9, t))
			cl.a = 1.0 - sway
			crow.append(cl)
		pts.append(prow)
		nrm.append(nrow)
		cols.append(crow)
	for r in rings:
		for sg in segs:
			var s2 := (sg + 1) % segs
			tri_smooth(pts[r][sg], pts[r][s2], pts[r + 1][s2], nrm[r][sg], nrm[r][s2], nrm[r + 1][s2],
				cols[r][sg], cols[r][s2], cols[r + 1][s2])
			tri_smooth(pts[r][sg], pts[r + 1][s2], pts[r + 1][sg], nrm[r][sg], nrm[r + 1][s2], nrm[r + 1][sg],
				cols[r][sg], cols[r + 1][s2], cols[r + 1][sg])


## Smooth tube along a polyline with per-point radius and colour gradient.
## Used for trunks, branches, limbs, rod blanks, necks and tails.
func tube(points: Array, radii: Array, col_a: Color, col_b: Color = Color(0, 0, 0, 0), segs := 7,
		cap_start := false, cap_end := true, sway := 0.0, squash := Vector2.ONE) -> void:
	if points.size() < 2:
		return
	if col_b == Color(0, 0, 0, 0):
		col_b = col_a
	var count: int = points.size()
	var tangent: Vector3 = ((points[1] as Vector3) - (points[0] as Vector3)).normalized()
	var ref := Vector3.RIGHT if absf(tangent.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var u := tangent.cross(ref).normalized()
	var rings: Array = []
	var norms: Array = []
	var cols: Array = []
	for i in count:
		var p: Vector3 = points[i]
		var tg: Vector3
		if i == 0:
			tg = ((points[1] as Vector3) - p).normalized()
		elif i == count - 1:
			tg = (p - (points[i - 1] as Vector3)).normalized()
		else:
			tg = ((points[i + 1] as Vector3) - (points[i - 1] as Vector3)).normalized()
		u = (u - tg * u.dot(tg)).normalized()
		var v := tg.cross(u).normalized()
		var rad: float = radii[i]
		var f := float(i) / float(count - 1)
		var cl := col_a.lerp(col_b, f)
		cl.a = 1.0 - sway * clampf(f * 1.4, 0.0, 1.0)
		var row: Array[Vector3] = []
		var nrow: Array[Vector3] = []
		for sg in segs:
			var a := TAU * sg / segs
			var dir := u * cos(a) * squash.x + v * sin(a) * squash.y
			row.append(p + dir * rad)
			nrow.append((u * cos(a) / maxf(squash.x, 1e-3) + v * sin(a) / maxf(squash.y, 1e-3)).normalized())
		rings.append(row)
		norms.append(nrow)
		cols.append(cl)
	for i in count - 1:
		for sg in segs:
			var s2 := (sg + 1) % segs
			tri_smooth(rings[i][sg], rings[i][s2], rings[i + 1][s2], norms[i][sg], norms[i][s2], norms[i + 1][s2],
				cols[i], cols[i], cols[i + 1])
			tri_smooth(rings[i][sg], rings[i + 1][s2], rings[i + 1][sg], norms[i][sg], norms[i + 1][s2], norms[i + 1][sg],
				cols[i], cols[i + 1], cols[i + 1])
	for cap in 2:
		if (cap == 0 and not cap_start) or (cap == 1 and not cap_end):
			continue
		var idx := 0 if cap == 0 else count - 1
		var c: Vector3 = points[idx]
		var tg2: Vector3 = ((points[1] as Vector3) - (points[0] as Vector3)).normalized() if cap == 0 \
			else ((points[count - 1] as Vector3) - (points[count - 2] as Vector3)).normalized()
		var nn := -tg2 if cap == 0 else tg2
		for sg in segs:
			var s2 := (sg + 1) % segs
			tri_smooth(c, rings[idx][sg], rings[idx][s2], nn, nn, nn, cols[idx], cols[idx], cols[idx])


## Straight smooth capsule-ish limb between two points (rounded ends).
func limb(a: Vector3, b: Vector3, r_a: float, r_b: float, col_a: Color, col_b: Color = Color(0, 0, 0, 0), segs := 8) -> void:
	if col_b == Color(0, 0, 0, 0):
		col_b = col_a
	tube([a, b], [r_a, r_b], col_a, col_b, segs, false, false)
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	var basis := Basis.looking_at(dir, up)
	ellipsoid(a, Vector3(r_a, r_a, r_a), col_a, col_a, segs, 4, basis)
	ellipsoid(b, Vector3(r_b, r_b, r_b), col_b, col_b, segs, 4, basis)


## Flat double-sided polygon (fan from the first point): fins, leaves, sails.
## `cols` may hold one colour per point for gradients.
func fin(points: Array, cols: Array) -> void:
	if points.size() < 3:
		return
	var n0 := (((points[1] as Vector3) - (points[0] as Vector3)).cross((points[2] as Vector3) - (points[0] as Vector3))).normalized()
	for i in range(1, points.size() - 1):
		var a: Vector3 = points[0]
		var b: Vector3 = points[i]
		var c: Vector3 = points[i + 1]
		var ca: Color = cols[0] if cols.size() > 0 else Color.WHITE
		var cb: Color = cols[mini(i, cols.size() - 1)]
		var cc: Color = cols[mini(i + 1, cols.size() - 1)]
		_v.append(a); _v.append(b); _v.append(c)
		_n.append(n0); _n.append(n0); _n.append(n0)
		_c.append(ca); _c.append(cb); _c.append(cc)
		_v.append(a); _v.append(c); _v.append(b)
		_n.append(-n0); _n.append(-n0); _n.append(-n0)
		_c.append(ca); _c.append(cc); _c.append(cb)


## Adds the geometry as an extra surface of `mesh` with its own material
## (used for emissive/glowing parts such as lamps and magical rod trims).
func add_surface(mesh: ArrayMesh, material: Material) -> void:
	if _v.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


static var _glow_mats: Array[ShaderMaterial] = []


## Emissive material for lamp glass / windows. `night_emission` is how bright it
## glows after dark; SkyController drives them all through set_night().
static func glow_material(energy := 2.0, glassy := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/glow.gdshader")
	m.set_shader_parameter("night_emission", energy)
	m.set_shader_parameter("glassy", glassy)
	_glow_mats.append(m)
	return m


static func set_night(v: float) -> void:
	for m in _glow_mats:
		m.set_shader_parameter("night", v)
