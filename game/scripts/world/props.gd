class_name Props
extends RefCounted
## Procedural low-poly props: trees, rocks, buildings, fish, boats.
## Meshes are cached because many instances share them.

static var _cache: Dictionary = {}


static func _col(hex: String, jitter := 0.0, seed_value := 0) -> Color:
	var c := Color(hex)
	if jitter > 0.0:
		var r := Util.hash01(seed_value * 7 + 3) - 0.5
		c = c.lightened(r * jitter) if r > 0.0 else c.darkened(-r * jitter)
	return c


static func _g(hex: String) -> Color:
	return Color(hex)


## Foliage blob cluster helper: several lumpy ellipsoids with a light-top/dark-bottom gradient.
static func _canopy(b: MeshBuilder, blobs: Array, top: Color, bot: Color, seed_value: int, sway := 1.0) -> void:
	var i := 0
	for bl in blobs:
		var c: Vector3 = bl[0]
		var r: Vector3 = bl[1]
		var tint := (Util.hash01(seed_value * 31 + i) - 0.5) * 0.12
		var t2 := top.lightened(tint) if tint > 0.0 else top.darkened(-tint)
		var b2 := bot.lightened(tint) if tint > 0.0 else bot.darkened(-tint)
		b.ellipsoid(c, r, t2, b2, 9, 6, Basis.IDENTITY, 0.16, seed_value + i * 3, sway)
		i += 1


static func tree_mesh(kind: String) -> ArrayMesh:
	var key := "tree_" + kind
	if _cache.has(key):
		return _cache[key]
	var b := MeshBuilder.new()
	match kind:
		"pine", "frost_pine":
			var frost := kind == "frost_pine"
			var bark := _g("5a4a3a") if frost else _g("5e4128")
			b.tube([Vector3(0, -0.1, 0), Vector3(0.03, 1.2, 0), Vector3(0, 3.0, 0.02)], [0.34, 0.24, 0.12], bark, bark.darkened(0.15), 7, false, true)
			for i in 6:
				var y0 := 1.0 + i * 0.85
				var r := 1.85 - i * 0.28
				var dark := _g("2b6e3a") if not frost else _g("3d6a66")
				var light := _g("4fae5c") if not frost else _g("8fb9b2")
				if frost and i >= 4:
					light = _g("f3f9fc")
					dark = _g("c9dde6")
				var tilt := (Util.hash01(i * 7 + (1 if frost else 0)) - 0.5) * 0.06
				b.tube([Vector3(0, y0, 0), Vector3(tilt, y0 + 0.45, 0), Vector3(tilt, y0 + 1.5, 0)],
					[r, r * 0.55, 0.03], dark, light, 10, true, false, 0.9)
		"round":
			b.tube([Vector3(0, -0.1, 0), Vector3(0.05, 1.0, 0), Vector3(-0.05, 2.1, 0.05)], [0.42, 0.3, 0.2], _g("7a5530"), _g("5e4126"), 8, false, true)
			b.tube([Vector3(0, 1.7, 0), Vector3(0.7, 2.5, 0.2)], [0.12, 0.06], _g("6a4a2c"), _g("5e4126"), 5, false, true)
			b.tube([Vector3(0, 1.9, 0), Vector3(-0.7, 2.7, -0.3)], [0.12, 0.06], _g("6a4a2c"), _g("5e4126"), 5, false, true)
			_canopy(b, [[Vector3(0, 3.2, 0), Vector3(1.8, 1.45, 1.75)], [Vector3(1.0, 2.7, 0.5), Vector3(1.15, 0.95, 1.1)],
				[Vector3(-0.95, 2.8, -0.5), Vector3(1.1, 0.95, 1.05)], [Vector3(0.2, 3.9, -0.3), Vector3(1.2, 0.85, 1.2)],
				[Vector3(-0.5, 2.5, 0.9), Vector3(0.9, 0.7, 0.9)]], _g("7ccc5c"), _g("2f7a38"), 11)
		"palm":
			var pts: Array = []
			var rads: Array = []
			for i in 8:
				var t := i / 7.0
				pts.append(Vector3(-0.9 * t * t, t * 4.4, 0.1 * sin(t * 3.0)))
				rads.append(lerpf(0.26, 0.15, t))
			b.tube(pts, rads, _g("b5946a"), _g("8f704a"), 8, false, true)
			var top: Vector3 = pts[7]
			for i in 9:
				var yaw := TAU * i / 9.0 + 0.2
				var len := 2.4 + 0.3 * Util.hash01(i + 40)
				var arc: Array = []
				for k in 6:
					var f := k / 5.0
					arc.append(top + Basis(Vector3.UP, yaw) * Vector3(f * len, 0.35 * sin(f * 2.1) - f * f * 1.2, 0))
				# frond leaf: spine along the arc, widening then tapering
				var poly: Array = [top]
				var cols: Array = [_g("4aa84e")]
				for k in range(1, 6):
					var f := k / 5.0
					var wdt := 0.34 * sin(f * PI * 0.9 + 0.2)
					poly.append((arc[k] as Vector3) + Basis(Vector3.UP, yaw) * Vector3(0, 0, wdt))
					cols.append(_g("3a9a44").lerp(_g("7acb5a"), f))
				for k in range(4, 0, -1):
					var f := k / 5.0
					var wdt2 := 0.34 * sin(f * PI * 0.9 + 0.2)
					poly.append((arc[k] as Vector3) + Basis(Vector3.UP, yaw) * Vector3(0, 0, -wdt2))
					cols.append(_g("3a9a44").lerp(_g("7acb5a"), f))
				# sway weight on frond colours
				for ci in cols.size():
					var cc: Color = cols[ci]
					cc.a = 0.0 if ci > 0 else 0.5
					cols[ci] = cc
				b.fin(poly, cols)
			for i in 3:
				b.ellipsoid(top + Vector3(0.12 * cos(i * 2.1), -0.35, 0.12 * sin(i * 2.1)), Vector3(0.17, 0.2, 0.17), _g("6b4a26"), _g("4a3219"), 7, 4)
		"mangrove":
			for i in 7:
				var a := TAU * i / 7.0 + 0.3
				var out := Vector3(cos(a), 0, sin(a))
				b.tube([out * 1.5 + Vector3(0, -0.2, 0), out * 1.1 + Vector3(0, 0.8, 0), out * 0.45 + Vector3(0, 1.7, 0)],
					[0.07, 0.1, 0.16], _g("4a3a28"), _g("5f4a32"), 5, false, true)
			b.tube([Vector3(0, 1.4, 0), Vector3(0.05, 2.3, 0)], [0.32, 0.24], _g("5f4a32"), _g("5f4a32"), 7, false, true)
			_canopy(b, [[Vector3(0, 3.1, 0), Vector3(1.9, 1.0, 1.9)], [Vector3(0.9, 2.8, 0.6), Vector3(1.0, 0.7, 1.0)],
				[Vector3(-0.9, 2.9, -0.4), Vector3(1.0, 0.7, 1.0)]], _g("5f9448"), _g("2a4f2d"), 21)
		"dead":
			b.tube([Vector3(0, -0.1, 0), Vector3(0.12, 1.3, 0), Vector3(-0.05, 2.6, 0.1), Vector3(0.1, 3.3, 0)], [0.34, 0.24, 0.14, 0.04], _g("5a4b3f"), _g("7a6a5a"), 6, false, true)
			b.tube([Vector3(0.05, 1.7, 0), Vector3(0.9, 2.4, 0.2), Vector3(1.4, 2.7, 0.1)], [0.1, 0.06, 0.02], _g("5a4b3f"), _g("7a6a5a"), 5, false, true)
			b.tube([Vector3(0, 2.2, 0.05), Vector3(-0.8, 2.9, -0.3)], [0.08, 0.02], _g("5a4b3f"), _g("7a6a5a"), 5, false, true)
		"bush":
			_canopy(b, [[Vector3(0, 0.5, 0), Vector3(0.95, 0.65, 0.8)], [Vector3(0.6, 0.4, 0.3), Vector3(0.55, 0.45, 0.5)],
				[Vector3(-0.55, 0.42, -0.2), Vector3(0.6, 0.45, 0.55)]], _g("5cb34f"), _g("2d7a34"), 31)
			for i in 5:
				var a2 := i * 1.9
				b.ellipsoid(Vector3(cos(a2) * 0.55, 0.62 + 0.15 * sin(a2 * 2.0), sin(a2) * 0.45 + 0.1), Vector3(0.06, 0.06, 0.06),
					_g("f4e9ff") if i % 2 == 0 else _g("ff9db8"), Color(0, 0, 0, 0), 5, 3)
		"reed":
			for i in 7:
				var a := TAU * i / 7.0
				var lean := 0.15 + 0.1 * (i % 3)
				var base := Vector3(cos(a) * 0.18, 0, sin(a) * 0.18)
				var h := 1.3 + 0.3 * (i % 3)
				b.tube([base, base + Vector3(cos(a) * lean * 0.5, h * 0.6, sin(a) * lean * 0.5), base + Vector3(cos(a) * lean, h, sin(a) * lean)],
					[0.035, 0.028, 0.012], _g("6d8f35"), _g("a3b552"), 4, false, true, 0.9)
			b.ellipsoid(Vector3(0.1, 1.5, 0.05), Vector3(0.05, 0.2, 0.05), _g("7a5530"), _g("5a3b20"), 5, 3, Basis.IDENTITY, 0.0, 0, 0.7)
		"grass":
			for i in 7:
				var a3 := TAU * i / 7.0 + Util.hash01(i + 5)
				var h3 := 0.38 + 0.3 * Util.hash01(i + 90)
				var dirv := Vector3(cos(a3), 0, sin(a3))
				var perp := Vector3(-dirv.z, 0, dirv.x)
				var base3 := dirv * 0.08
				var tip := base3 + dirv * (0.18 + 0.12 * Util.hash01(i)) + Vector3(0, h3, 0)
				var cl := _g("3f8f38")
				var ct := _g("9bd05a")
				b.fin([base3 - perp * 0.045, base3 + perp * 0.045, tip], [Color(cl.r, cl.g, cl.b, 1.0), Color(cl.r, cl.g, cl.b, 1.0), Color(ct.r, ct.g, ct.b, 0.1)])
		"flowers":
			for i in 6:
				var a4 := TAU * i / 6.0 + 0.4
				var h4 := 0.32 + 0.18 * Util.hash01(i + 120)
				var base4 := Vector3(cos(a4) * 0.2, 0, sin(a4) * 0.2)
				b.tube([base4, base4 + Vector3(0, h4, 0)], [0.012, 0.01], _g("4a9a3a"), _g("4a9a3a"), 3, false, true, 0.7)
				var pc: Color = [_g("ff6f91"), _g("ffd23f"), _g("ffffff"), _g("b28dff"), _g("ff9f45"), _g("7fd1ff")][i % 6]
				b.ellipsoid(base4 + Vector3(0, h4 + 0.02, 0), Vector3(0.07, 0.035, 0.07), pc, pc.darkened(0.15), 6, 3, Basis.IDENTITY, 0.0, 0, 0.7)
				b.ellipsoid(base4 + Vector3(0, h4 + 0.05, 0), Vector3(0.025, 0.02, 0.025), _g("f5c518"), _g("f5c518"), 5, 3)
	var m := b.build()
	_cache[key] = m
	return m


static func rock_mesh() -> ArrayMesh:
	if _cache.has("rock"):
		return _cache["rock"]
	var b := MeshBuilder.new()
	b.ellipsoid(Vector3(0, 0.38, 0), Vector3(1.0, 0.62, 0.85), _g("a3a7ad"), _g("62666d"), 9, 6, Basis(Vector3.UP, 0.4), 0.2, 5)
	b.ellipsoid(Vector3(0.75, 0.2, 0.3), Vector3(0.55, 0.38, 0.5), _g("9599a0"), _g("5a5e65"), 8, 5, Basis.IDENTITY, 0.22, 9)
	b.ellipsoid(Vector3(-0.6, 0.15, -0.5), Vector3(0.4, 0.28, 0.4), _g("8d9198"), _g("575b62"), 7, 4, Basis.IDENTITY, 0.25, 14)
	b.ellipsoid(Vector3(-0.1, 0.78, 0.0), Vector3(0.55, 0.16, 0.5), _g("6aa84a"), _g("5a8f40"), 8, 3, Basis.IDENTITY, 0.18, 2)  # moss cap
	var m := b.build()
	_cache["rock"] = m
	return m


## One fish ring section helper.
static func _fish_profile(t: float) -> float:
	# t: 0 = tail tip, 1 = nose. Peduncle -> belly -> head -> rounded nose.
	var prof := [0.10, 0.20, 0.42, 0.72, 0.93, 1.0, 0.95, 0.80, 0.55, 0.0]
	var f := clampf(t, 0.0, 1.0) * 9.0
	var i := mini(int(f), 8)
	return lerpf(prof[i], prof[i + 1], f - i)


## Fish facing +Z. Used for held fish, tank fish and effects.
static func fish_mesh(c1: Color, c2: Color, shape: int) -> ArrayMesh:
	var key := "fish_%s_%s_%d" % [c1.to_html(false), c2.to_html(false), shape]
	if _cache.has(key):
		return _cache[key]
	var b := MeshBuilder.new()
	var body := Vector3(0.4, 0.6, 1.0)
	match shape:
		1: body = Vector3(0.65, 0.75, 0.8)
		2: body = Vector3(0.3, 0.35, 1.6)
		3: body = Vector3(0.9, 0.22, 0.95)
		4: body = Vector3(0.5, 0.55, 1.5)
	var hx := 0.5 * body.x
	var hy := 0.5 * body.y
	var len := body.z
	var pat := int(Util.hash01(int(c1.r8 * 3 + c1.g8 * 5 + c1.b8 * 7) + shape) * 4.0)  # 0 plain,1 stripes,2 spots,3 lateral band
	var belly := c2.lightened(0.3)
	var segs := 14
	var stations := 18
	var rings: Array = []
	var nrms: Array = []
	var colr: Array = []
	for i in stations + 1:
		var t := float(i) / stations
		var z := lerpf(-0.5, 0.5, t) * len
		var pr := _fish_profile(t)
		var row: Array[Vector3] = []
		var nrow: Array[Vector3] = []
		var crow: Array[Color] = []
		for j in segs:
			var a := TAU * j / segs
			var up := sin(a)  # +1 dorsal, -1 ventral
			var p := Vector3(cos(a) * hx * pr, up * hy * pr * (1.0 if up > 0.0 else 0.85), z)
			row.append(p)
			var nv := Vector3(cos(a) / maxf(hx * pr, 1e-3), up / maxf(hy * pr, 1e-3), 0.0)
			var dz := (_fish_profile(minf(t + 0.05, 1.0)) - _fish_profile(maxf(t - 0.05, 0.0))) * 3.0
			nv.z = -dz * 0.0
			nrow.append(nv.normalized())
			# back -> belly gradient
			var k := smoothstep(-0.55, 0.45, up)
			var cl := belly.lerp(c1, k)
			if pat == 1 and fmod(t * 7.0, 1.0) < 0.35 and up > -0.2 and t > 0.2 and t < 0.85:
				cl = cl.lerp(c2.darkened(0.45), 0.7)
			elif pat == 2 and Util.hash01(i * 31 + j * 7 + shape) > 0.84 and up > -0.1:
				cl = cl.lerp(Color.WHITE, 0.6)
			elif pat == 3 and absf(up - 0.05) < 0.22 and t > 0.12:
				cl = cl.lerp(c2.lightened(0.35), 0.8)
			cl.a = 1.0
			crow.append(cl)
		rings.append(row)
		nrms.append(nrow)
		colr.append(crow)
	for i in stations:
		for j in segs:
			var j2 := (j + 1) % segs
			b.tri_smooth(rings[i][j], rings[i][j2], rings[i + 1][j2], nrms[i][j], nrms[i][j2], nrms[i + 1][j2], colr[i][j], colr[i][j2], colr[i + 1][j2])
			b.tri_smooth(rings[i][j], rings[i + 1][j2], rings[i + 1][j], nrms[i][j], nrms[i + 1][j2], nrms[i + 1][j], colr[i][j], colr[i + 1][j2], colr[i + 1][j])
	var tz := -0.5 * len
	var fin_a := c2
	var fin_b := c2.lerp(c1, 0.5).darkened(0.1)
	var fl := 0.42 * len + 0.06  # tail span
	var fh := maxf(hy * 1.7, 0.22)
	if shape == 3:
		fh = 0.2
	# forked tail
	b.fin([Vector3(0, 0, tz + 0.05), Vector3(0, fh * 0.5, tz - fl * 0.55), Vector3(0, fh, tz - fl), Vector3(0, fh * 0.15, tz - fl * 0.72),
		Vector3(0, -fh * 0.15, tz - fl * 0.72), Vector3(0, -fh, tz - fl), Vector3(0, -fh * 0.5, tz - fl * 0.55)],
		[fin_a, fin_a, fin_b, fin_a, fin_a, fin_b, fin_a])
	if shape != 3:
		# dorsal fin
		var dh := hy * 1.0 + 0.14 if shape != 2 else hy * 1.0 + 0.1
		b.fin([Vector3(0, hy * 0.9, len * 0.18), Vector3(0, hy + dh, len * 0.02), Vector3(0, hy + dh * 0.55, -len * 0.14), Vector3(0, hy * 0.7, -len * 0.26)],
			[fin_a, fin_b, fin_b, fin_a])
		# anal fin
		b.fin([Vector3(0, -hy * 0.75, -len * 0.08), Vector3(0, -hy - 0.12, -len * 0.18), Vector3(0, -hy * 0.7, -len * 0.28)], [fin_a, fin_b, fin_a])
	# pectoral fins
	for sx in [-1.0, 1.0]:
		var base := Vector3(sx * hx * 0.85, -hy * 0.25, len * 0.18)
		b.fin([base, base + Vector3(sx * 0.18, -0.1, -0.05), base + Vector3(sx * 0.22, -0.16, -0.2), base + Vector3(sx * 0.02, -0.02, -0.22)], [fin_a, fin_b, fin_b, fin_a])
	if shape == 3:
		# ray-like wings
		for sx in [-1.0, 1.0]:
			b.fin([Vector3(sx * hx * 0.5, 0, len * 0.3), Vector3(sx * hx * 1.5, 0, len * 0.1), Vector3(sx * hx * 1.3, 0, -len * 0.3), Vector3(sx * hx * 0.4, 0, -len * 0.35)], [c1, c1, c2, c1])
	# eyes
	var ez := len * 0.33
	var ey := hy * 0.28
	var ex := hx * 0.78
	for sx in [-1.0, 1.0]:
		b.ellipsoid(Vector3(sx * ex, ey, ez), Vector3(0.065, 0.065, 0.065), Color("f6f3e8"), Color("f6f3e8"), 7, 4)
		b.ellipsoid(Vector3(sx * (ex + 0.03), ey, ez + 0.012), Vector3(0.036, 0.04, 0.036), Color("101418"), Color("101418"), 6, 3)
	# gill line + mouth
	b.ellipsoid(Vector3(0, -hy * 0.1, len * 0.5 - 0.02), Vector3(hx * 0.3, 0.018, 0.03), c2.darkened(0.55), c2.darkened(0.55), 6, 3)
	var m := b.build()
	_cache[key] = m
	return m


## A cute building facing +Z, origin at the centre of the ground footprint.
static func building(w: float, d: float, h: float, wall: Color, roof: Color, opts := {}) -> ArrayMesh:
	var b := MeshBuilder.new()
	var glow := MeshBuilder.new()
	var glass := MeshBuilder.new()
	var trim := Color("f2ead6")
	var wood := Color("5c3b22")
	# stone foundation + walls
	b.box(Vector3(0, 0.3, 0), Vector3(w + 0.35, 0.6, d + 0.35), Color("8d8a82"))
	b.box(Vector3(0, 0.6 + (h - 0.6) * 0.5, 0), Vector3(w, h - 0.6, d), wall)
	# horizontal board lines on the walls
	var lines := int((h - 0.6) / 0.55)
	for i in lines:
		var y := 0.95 + i * 0.55
		b.box(Vector3(0, y, d * 0.5 + 0.012), Vector3(w, 0.035, 0.03), wall.darkened(0.22))
		b.box(Vector3(0, y, -d * 0.5 - 0.012), Vector3(w, 0.035, 0.03), wall.darkened(0.22))
		b.box(Vector3(w * 0.5 + 0.012, y, 0), Vector3(0.03, 0.035, d), wall.darkened(0.22))
		b.box(Vector3(-w * 0.5 - 0.012, y, 0), Vector3(0.03, 0.035, d), wall.darkened(0.22))
	# corner posts + eaves trim
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(Vector3(sx * w * 0.5, h * 0.5 + 0.15, sz * d * 0.5), Vector3(0.22, h - 0.3, 0.22), trim.darkened(0.08))
	b.box(Vector3(0, h - 0.04, 0), Vector3(w + 0.2, 0.18, d + 0.2), trim)
	# roof: two layers for thickness + ridge cap
	var rh: float = opts.get("roof_h", h * 0.55)
	b.gable_roof(Vector3(0, h + 0.05, 0), w, d, rh, roof, roof.darkened(0.1), 0.55)
	b.gable_roof(Vector3(0, h + 0.2, 0), w - 0.2, d - 0.2, rh * 0.93, roof.lightened(0.06), roof.darkened(0.1), 0.62)
	b.box(Vector3(0, h + 0.05 + rh * 0.93 + 0.2, 0), Vector3(w + 1.3, 0.16, 0.32), roof.darkened(0.25))
	# shingle rows
	var rows := 4
	for i in rows:
		var f := (i + 0.5) / rows
		var yy := h + 0.22 + rh * 0.93 * f * 0.96
		var zz := (d * 0.5 + 0.62) * (1.0 - f * 0.97) + 0.04
		for sz in [-1.0, 1.0]:
			b.box(Vector3(0, yy, sz * zz), Vector3(w + 1.2, 0.05, 0.06), roof.darkened(0.2),
				Basis(Vector3.RIGHT, sz * -atan2(rh * 0.93, d * 0.5 + 0.6)))
	# door with frame, handle, step
	var dz := d * 0.5
	b.box(Vector3(0, 0.1, dz + 0.45), Vector3(1.7, 0.2, 0.9), Color("9a968c"))
	b.box(Vector3(0, 1.15, dz + 0.02), Vector3(1.45, 2.3, 0.14), trim)
	b.box(Vector3(0, 1.1, dz + 0.1), Vector3(1.1, 2.0, 0.12), wood)
	b.box(Vector3(0, 1.1, dz + 0.17), Vector3(0.7, 1.4, 0.04), wood.lightened(0.12))
	b.ellipsoid(Vector3(0.38, 1.05, dz + 0.2), Vector3(0.06, 0.06, 0.06), Color("d9b25a"), Color("a8812f"), 6, 4)
	# front windows (frame, glass, mullions, shutters, flower box) and side windows
	var win := Color("9fd4f0")
	var shut: Color = opts.get("shutter", roof.darkened(0.05))
	for sx: float in [-1.0, 1.0]:
		var x: float = sx * w * 0.3
		var wy := h * 0.58
		b.box(Vector3(x, wy, dz + 0.04), Vector3(1.25, 1.25, 0.1), trim)
		glass.box(Vector3(x, wy, dz + 0.09), Vector3(0.95, 0.95, 0.08), win)
		b.box(Vector3(x, wy, dz + 0.14), Vector3(0.07, 0.95, 0.05), trim)
		b.box(Vector3(x, wy, dz + 0.14), Vector3(0.95, 0.07, 0.05), trim)
		b.box(Vector3(x - 0.78, wy, dz + 0.1), Vector3(0.28, 1.15, 0.07), shut)
		b.box(Vector3(x + 0.78, wy, dz + 0.1), Vector3(0.28, 1.15, 0.07), shut)
		b.box(Vector3(x, wy - 0.78, dz + 0.22), Vector3(1.3, 0.28, 0.3), Color("7a5530"))
		for k in 4:
			var fc: Color = [Color("ff6f91"), Color("ffd23f"), Color("ffffff"), Color("ff9f45")][k]
			b.ellipsoid(Vector3(x - 0.45 + k * 0.3, wy - 0.6, dz + 0.24), Vector3(0.13, 0.12, 0.12), fc, fc.darkened(0.2), 6, 3)
			b.ellipsoid(Vector3(x - 0.45 + k * 0.3, wy - 0.68, dz + 0.24), Vector3(0.14, 0.08, 0.13), Color("3f8f38"), Color("2d7a34"), 6, 3)
	for sz2: float in [-1.0, 1.0]:
		for sx2: float in [-1.0, 1.0]:
			var zp: float = sz2 * d * 0.25
			b.box(Vector3(sx2 * (w * 0.5 + 0.03), h * 0.58, zp), Vector3(0.1, 1.1, 1.1), trim)
			glass.box(Vector3(sx2 * (w * 0.5 + 0.08), h * 0.58, zp), Vector3(0.08, 0.85, 0.85), win)
	if opts.get("chimney", false):
		b.box(Vector3(w * 0.28, h + rh * 0.62, -d * 0.12), Vector3(0.75, rh * 1.15, 0.75), Color("8a6a5a"))
		b.box(Vector3(w * 0.28, h + rh * 1.2, -d * 0.12), Vector3(0.95, 0.22, 0.95), Color("6d5446"))
	if opts.get("awning", false):
		var ac: Color = opts.get("awning_color", Color("d9534f"))
		for i in 8:
			var col: Color = ac if i % 2 == 0 else Color("f5f0e0")
			b.box(Vector3(-w * 0.4 + (i + 0.5) * w * 0.8 / 8.0, 2.75, dz + 0.9), Vector3(w * 0.8 / 8.0, 0.1, 1.9), col, Basis(Vector3.RIGHT, deg_to_rad(-10)))
			b.ellipsoid(Vector3(-w * 0.4 + (i + 0.5) * w * 0.8 / 8.0, 2.35, dz + 1.82), Vector3(w * 0.8 / 16.0, 0.16, 0.1), col, col.darkened(0.12), 6, 3)
		for sx in [-1.0, 1.0]:
			b.tube([Vector3(sx * w * 0.38, 0, dz + 1.7), Vector3(sx * w * 0.38, 2.5, dz + 1.7)], [0.08, 0.07], Color("6b4a2b"), Color("6b4a2b"), 6, false, true)
	# porch lantern (glowing)
	b.tube([Vector3(-0.95, 2.35, dz + 0.1), Vector3(-0.95, 2.55, dz + 0.3)], [0.025, 0.025], Color("2f2f33"), Color("2f2f33"), 4, false, true)
	glow.ellipsoid(Vector3(-0.95, 2.4, dz + 0.32), Vector3(0.11, 0.16, 0.11), Color("ffd98a"), Color("ffb347"), 7, 4)
	var mesh := b.build()
	glow.add_surface(mesh, MeshBuilder.glow_material(3.0))
	glass.add_surface(mesh, MeshBuilder.glow_material(1.6, 1.0))
	return mesh


## Market stall: counter + striped scalloped canopy + crates of fish.
static func stall(canopy: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	for i in 4:
		b.box(Vector3(0, 0.14 + i * 0.28, 0.0), Vector3(3.2, 0.26, 1.3), Color("8a5a32").lightened(0.04 * (i % 2)))
	b.box(Vector3(0, 1.14, 0.1), Vector3(3.5, 0.14, 1.7), Color("c79a62"))
	for sx in [-1.5, 1.5]:
		for sz in [-0.55, 0.9]:
			b.tube([Vector3(sx, 0, sz), Vector3(sx, 2.7 + (0.15 if sz < 0 else -0.1), sz)], [0.07, 0.06], Color("6b4a2b"), Color("5a3b20"), 6, false, true)
	for i in 8:
		var col := canopy if i % 2 == 0 else Color("f5f0e0")
		var x := -1.75 + (i + 0.5) * 0.4375
		b.box(Vector3(x, 2.78, 0.15), Vector3(0.4375, 0.08, 2.2), col, Basis(Vector3.RIGHT, deg_to_rad(-11)))
		b.ellipsoid(Vector3(x, 2.52, 1.22), Vector3(0.22, 0.2, 0.06), col, col.darkened(0.15), 7, 4)
	# crates with fish and a hanging scale
	b.box(Vector3(-0.9, 1.35, 0.25), Vector3(0.9, 0.3, 0.6), Color("a07a4a"))
	for i in 5:
		b.ellipsoid(Vector3(-1.2 + i * 0.15, 1.52, 0.25 + 0.1 * sin(i * 2.0)), Vector3(0.2, 0.08, 0.07), Color("c8d6e0"), Color("8aa0b4"), 7, 4, Basis(Vector3.UP, 0.5 * i))
	b.box(Vector3(0.9, 1.35, 0.25), Vector3(0.8, 0.3, 0.6), Color("a07a4a"))
	for i in 4:
		b.ellipsoid(Vector3(0.65 + i * 0.17, 1.5, 0.25), Vector3(0.17, 0.12, 0.17), Color("e0794a"), Color("b8552d"), 7, 4)
	return b.build()


static func pier(length: float, width: float) -> ArrayMesh:
	var b := MeshBuilder.new()
	var n := int(length / 0.55)
	for i in n:
		var shade := 0.09 * (Util.hash01(i * 13 + 5) - 0.5)
		var base := Color("a98258")
		var cl := base.lightened(shade) if shade > 0.0 else base.darkened(-shade)
		b.box(Vector3(0, 0.02, 0.28 + i * 0.55), Vector3(width, 0.2, 0.5), cl)
	# stringers + cross beams
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * (width * 0.5 - 0.15), -0.18, length * 0.5), Vector3(0.22, 0.3, length), Color("6d4a2a"))
	var posts := int(length / 4.0) + 1
	for i in posts:
		for sx in [-1.0, 1.0]:
			var px: float = sx * (width * 0.5 - 0.1)
			b.tube([Vector3(px, -3.0, i * 4.0 + 0.2), Vector3(px, 0.75, i * 4.0 + 0.2)], [0.15, 0.13], Color("4a3320"), Color("6b4a2e"), 7, false, true)
			b.ellipsoid(Vector3(px, 0.78, i * 4.0 + 0.2), Vector3(0.17, 0.08, 0.17), Color("5a3f26"), Color("4a3320"), 7, 3)
			# rope to the next post, with a sag
			if i < posts - 1:
				var pts: Array = []
				for k in 7:
					var f := k / 6.0
					pts.append(Vector3(px, 0.66 - 0.18 * sin(f * PI), i * 4.0 + 0.2 + f * 4.0))
				b.tube(pts, [0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03], Color("d6c79a"), Color("c3b383"), 4, false, true)
	# bumper tyres on the end
	for sx in [-1.0, 1.0]:
		b.ellipsoid(Vector3(sx * (width * 0.5 + 0.05), -0.1, length - 0.3), Vector3(0.14, 0.2, 0.2), Color("2b2b2e"), Color("1c1c1e"), 8, 4)
	# a barrel and a coil of rope near the end
	b.tube([Vector3(width * 0.3, 0.1, length - 1.2), Vector3(width * 0.3, 0.95, length - 1.2)], [0.3, 0.3], Color("7a4e2a"), Color("8a5a32"), 10, true, true)
	b.tube([Vector3(width * 0.3, 0.45, length - 1.2), Vector3(width * 0.3, 0.52, length - 1.2)], [0.315, 0.315], Color("3a3a3e"), Color("3a3a3e"), 10, false, false)
	return b.build()


static func _hull(b: MeshBuilder, scale: float, inward: bool, cols: Array) -> void:
	var stations := 13
	var prof := [0.0, 0.5, 0.82, 0.96, 1.0]
	var ys := [-0.6, -0.4, 0.0, 0.45, 0.85]
	var grid: Array = []
	for i in stations + 1:
		var t := float(i) / stations           # 0 stern -> 1 bow
		var z := lerpf(-2.9, 3.4, t)
		var wd := 1.3 * (1.0 - pow(maxf(t - 0.35, 0.0) / 0.65, 2.2) * 0.97)
		if t < 0.08:
			wd *= 0.92 + 0.08 * (t / 0.08)  # slightly narrower transom
		var lift := pow(maxf(t - 0.5, 0.0) / 0.5, 2.0) * 0.55  # bow rises
		var row: Array[Vector3] = []
		for j in 5:
			var yy: float = ys[j] * (1.0 if j < 3 else 1.0) + (lift * (float(j) / 4.0))
			if j == 0:
				yy = -0.6 + (0.35 * pow(t, 3.0))  # keel rises at the bow
			row.append(Vector3(wd * float(prof[j]) * scale, yy * scale, z * scale))
		grid.append(row)
	for side in [-1.0, 1.0]:
		for i in stations:
			for j in 4:
				var p00: Vector3 = grid[i][j]
				var p01: Vector3 = grid[i][j + 1]
				var p10: Vector3 = grid[i + 1][j]
				var p11: Vector3 = grid[i + 1][j + 1]
				p00.x *= side; p01.x *= side; p10.x *= side; p11.x *= side
				var cl: Color = cols[j]
				var ns: Array[Vector3] = []
				for p in [p00, p01, p10, p11]:
					var nrm: Vector3 = (p - Vector3(0, 0.1 * scale, p.z)).normalized()
					if inward:
						nrm = -nrm
					ns.append(nrm)
				var ca: Color = cols[j]
				var cb: Color = cols[j + 1] if not inward else cols[j]
				b.tri_smooth(p00, p10, p11, ns[0], ns[2], ns[3], ca, ca, cb)
				b.tri_smooth(p00, p11, p01, ns[0], ns[3], ns[1], ca, cb, cb)


static func boat() -> ArrayMesh:
	var b := MeshBuilder.new()
	var navy := Color("23364f")
	var red := Color("b8412c")
	var white := Color("f0ece0")
	_hull(b, 1.0, false, [navy, navy, red, red, white])
	_hull(b, 0.93, true, [Color("b99a6a"), Color("b99a6a"), Color("c8aa78"), Color("c8aa78"), Color("c8aa78")])
	# deck planks
	for i in 14:
		var z := -2.6 + i * 0.4
		var tt := (z + 2.9) / 6.3
		var half := 1.3 * 0.68 * (1.0 - pow(maxf(tt - 0.35, 0.0) / 0.65, 2.2) * 0.97)
		if tt < 0.72 and half > 0.12:
			b.box(Vector3(0, 0.2, z), Vector3(half * 2.0, 0.06, 0.38), Color("c9a876").lightened(0.04 * (i % 2)))
	# gunwale rail
	for sx in [-1.0, 1.0]:
		var pts: Array = []
		for k in 9:
			var t := k / 8.0
			var z := lerpf(-2.85, 3.2, t)
			var wd := 1.3 * (1.0 - pow(maxf((z + 2.9) / 6.3 - 0.35, 0.0) / 0.65, 2.2) * 0.97)
			pts.append(Vector3(sx * wd * 1.0, 0.86 + pow(maxf((z + 2.9) / 6.3 - 0.5, 0.0) / 0.5, 2.0) * 0.55, z))
		var radii: Array = []
		for k in pts.size():
			radii.append(0.07)
		b.tube(pts, radii, Color("6b4a2b"), Color("7a5634"), 6, false, true)
	# cabin: walls, roof, windows
	b.box(Vector3(0, 1.45, -1.1), Vector3(1.7, 1.55, 1.7), white)
	b.box(Vector3(0, 0.75, -1.1), Vector3(1.78, 0.2, 1.78), red.darkened(0.1))
	b.ellipsoid(Vector3(0, 2.28, -1.1), Vector3(1.05, 0.2, 1.05), Color("3a6ea5"), Color("2d5584"), 10, 4)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.87, 1.7, -1.1), Vector3(0.06, 0.6, 1.0), Color("2a3a4a"))
	b.box(Vector3(0, 1.7, -0.23), Vector3(1.1, 0.6, 0.06), Color("2a3a4a"))
	b.box(Vector3(0, 1.1, -0.23), Vector3(0.6, 0.9, 0.06), Color("8a5a32"))
	# mast, antenna, flag, radar
	b.tube([Vector3(0, 2.3, -1.4), Vector3(0, 3.6, -1.4)], [0.05, 0.03], Color("8f969c"), Color("8f969c"), 6, false, true)
	b.fin([Vector3(0.03, 3.55, -1.4), Vector3(0.5, 3.45, -1.4), Vector3(0.5, 3.15, -1.4), Vector3(0.03, 3.25, -1.4)], [Color("e04a3a"), Color("e04a3a"), Color("c63a2c"), Color("c63a2c")])
	b.ellipsoid(Vector3(0, 2.55, -0.8), Vector3(0.22, 0.05, 0.22), Color("c9ced3"), Color("9aa0a6"), 8, 3)
	# lifebuoy on the cabin side
	b.tube([Vector3(0.9, 1.5, -1.5), Vector3(0.9, 1.7, -1.4), Vector3(0.9, 1.9, -1.5), Vector3(0.9, 1.7, -1.6), Vector3(0.9, 1.5, -1.5)], [0.05, 0.05, 0.05, 0.05, 0.05],
		Color("f08a24"), Color("f08a24"), 6, false, false)
	# bow cleat + bumpers + crate on the deck
	b.box(Vector3(0, 0.95, 3.0), Vector3(0.1, 0.1, 0.3), Color("8f969c"))
	for k in 3:
		b.ellipsoid(Vector3(1.28, 0.5, -1.6 + k * 1.4), Vector3(0.11, 0.2, 0.11), Color("f0ece0"), Color("c9c5b8"), 7, 4)
	b.box(Vector3(-0.5, 0.45, 1.5), Vector3(0.6, 0.45, 0.6), Color("a07a4a"))
	b.box(Vector3(0.45, 0.4, 1.6), Vector3(0.5, 0.35, 0.5), Color("8a6238"))
	return b.build()


static func container_stack() -> ArrayMesh:
	var b := MeshBuilder.new()
	var cols := ["c0392b", "2980b9", "27ae60", "e67e22"]
	for i in 4:
		var cx := (i % 2) * 2.6
		var cy := 1.3 + (i / 2) * 2.6
		var col := Color(cols[i])
		b.box(Vector3(cx, cy, 0), Vector3(2.5, 2.5, 6.0), col)
		# corrugation ribs on both long sides + door frame at the end
		for k in 14:
			var z := -2.8 + k * 0.43
			b.box(Vector3(cx + 1.255, cy, z), Vector3(0.05, 2.3, 0.14), col.darkened(0.18))
			b.box(Vector3(cx - 1.255, cy, z), Vector3(0.05, 2.3, 0.14), col.darkened(0.18))
		b.box(Vector3(cx, cy, 3.01), Vector3(2.3, 2.3, 0.05), col.darkened(0.12))
		b.box(Vector3(cx, cy, 3.04), Vector3(0.06, 2.2, 0.05), col.darkened(0.35))
	return b.build()


static func lantern_post() -> ArrayMesh:
	var b := MeshBuilder.new()
	var glow := MeshBuilder.new()
	b.tube([Vector3(0, 0, 0), Vector3(0, 3.0, 0)], [0.12, 0.07], Color("2c2c30"), Color("3a3a40"), 7, true, true)
	b.ellipsoid(Vector3(0, 0.1, 0), Vector3(0.2, 0.12, 0.2), Color("2c2c30"), Color("1e1e22"), 7, 3)
	b.box(Vector3(0, 3.18, 0), Vector3(0.5, 0.06, 0.5), Color("2c2c30"))
	b.cone(Vector3(0, 3.7, 0), 0.42, 0.3, 4, Color("2c2c30"))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(Vector3(sx * 0.2, 3.45, sz * 0.2), Vector3(0.04, 0.5, 0.04), Color("2c2c30"))
	glow.ellipsoid(Vector3(0, 3.45, 0), Vector3(0.18, 0.22, 0.18), Color("ffe3a0"), Color("ffb347"), 8, 5)
	var mesh := b.build()
	glow.add_surface(mesh, MeshBuilder.glow_material(1.8))
	return mesh


static func label(text: String, size := 0.5, color := Color.WHITE, outline := 12) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = 0.01 * size
	l.font_size = 64
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = color
	l.outline_size = outline
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.no_depth_test = false
	l.fixed_size = false
	return l
