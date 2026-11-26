class_name RodModel
extends RefCounted
## Builds a distinct 3D model for every fishing rod tier (grip, reel, tapered
## and slightly bent blank, guide rings, wraps and - for the top rods - glowing
## trims). Built along local -Y from the hand; the tip position is returned so
## the fishing line can attach to the real tip.

static var _cache: Dictionary = {}


## Returns {"mesh": ArrayMesh, "tip": Vector3}.
static func build(rod: DataTypes.Rod, rod_len: float) -> Dictionary:
	var key := "%s_%.2f" % [rod.id, rod_len]
	if _cache.has(key):
		return _cache[key]
	var b := MeshBuilder.new()
	var glow := MeshBuilder.new()
	var blank: Color = rod.color
	var style := _style(rod.id)
	var grip: Color = style["grip"]
	var accent: Color = style["accent"]
	var glow_col: Color = style["glow"]
	var reel_r: float = style["reel"]
	var metal: Color = style["metal"]
	var bend: float = style["bend"]

	# --- grip + butt cap ---------------------------------------------------
	b.tube([Vector3(0, 0.3, 0), Vector3(0, 0.12, 0), Vector3(0, -0.12, 0), Vector3(0, -0.3, 0)],
		[0.036, 0.046, 0.045, 0.04], grip, grip.darkened(0.1), 9, true, true)
	b.ellipsoid(Vector3(0, 0.31, 0), Vector3(0.042, 0.03, 0.042), metal, metal.darkened(0.3), 8, 4)
	if style["rings"]:
		for i in 4:
			var y := 0.2 - i * 0.12
			b.tube([Vector3(0, y, 0), Vector3(0, y - 0.018, 0)], [0.049, 0.049], grip.darkened(0.3), grip.darkened(0.3), 9, false, false)
	# --- reel seat + reel ---------------------------------------------------
	b.tube([Vector3(0, -0.14, 0), Vector3(0, -0.34, 0)], [0.052, 0.05], metal, metal.darkened(0.2), 9, true, true)
	if reel_r > 0.0:
		var rz := -0.075  # reel hangs below the rod
		b.tube([Vector3(0, -0.2, rz * 0.3), Vector3(0, -0.2, rz)], [0.02, 0.02], metal, metal, 6, false, false)
		b.tube([Vector3(-reel_r * 0.5, -0.2, rz - reel_r * 0.75), Vector3(reel_r * 0.5, -0.2, rz - reel_r * 0.75)],
			[reel_r, reel_r], metal, metal.lightened(0.15), 14, true, true)
		b.tube([Vector3(-reel_r * 0.35, -0.2, rz - reel_r * 0.75), Vector3(reel_r * 0.35, -0.2, rz - reel_r * 0.75)],
			[reel_r * 0.86, reel_r * 0.86], Color("e7e4dc"), Color("e7e4dc"), 14, true, true)
		# handle crank
		b.tube([Vector3(reel_r * 0.5, -0.2, rz - reel_r * 0.75), Vector3(reel_r * 1.1, -0.2, rz - reel_r * 0.75)], [0.012, 0.012], metal, metal, 5, false, false)
		b.tube([Vector3(reel_r * 1.1, -0.2, rz - reel_r * 0.75), Vector3(reel_r * 1.1, -0.2 - 0.09, rz - reel_r * 0.75)], [0.01, 0.01], metal, metal, 5, false, false)
		b.ellipsoid(Vector3(reel_r * 1.1, -0.29, rz - reel_r * 0.75), Vector3(0.022, 0.022, 0.022), accent, accent.darkened(0.2), 6, 4)
		if style["gem"]:
			glow.ellipsoid(Vector3(0, -0.2, rz - reel_r * 0.75 - reel_r * 0.5), Vector3(0.025, 0.025, 0.025), glow_col, glow_col, 6, 4)
	# --- blank: slightly bent, tapered, banded -----------------------------
	var n := 10
	var pts: Array = []
	var radii: Array = []
	for i in n + 1:
		var t := float(i) / n
		pts.append(Vector3(0, -(0.3 + (rod_len - 0.3) * t), bend * t * t))
		radii.append(lerpf(0.032, 0.0075, pow(t, 0.8)))
	for i in n:
		var tt := float(i) / n
		var c := blank
		match style["pattern"]:
			"bamboo":
				c = blank.lerp(Color("8a6a2c"), 0.55 if i % 3 == 0 else 0.0)
			"carbon":
				c = blank.lightened(0.07) if i % 2 == 0 else blank
			"gradient":
				c = blank.lerp(accent, tt * 0.8)
			_:
				c = blank.lerp(blank.lightened(0.15), tt * 0.5)
		b.tube([pts[i], pts[i + 1]], [radii[i], radii[i + 1]], c, c.lerp(blank, 0.3), 7, false, i == n - 1)
	# wraps (thread bands) and bamboo nodes / glowing trim
	for i in [1, 3, 5, 7, 9]:
		var wp: Vector3 = pts[i]
		var wr: float = radii[i] + 0.006
		if glow_col.a > 0.0 and i % 2 == 1:
			glow.tube([wp, wp + Vector3(0, -0.035, 0)], [wr, wr], glow_col, glow_col, 7, false, false)
		else:
			b.tube([wp, wp + Vector3(0, -0.03, 0)], [wr, wr], accent, accent.darkened(0.15), 7, false, false)
	# guide rings (metal loops) along the blank, below it like a spinning rod
	for gi in [2, 4, 6, 8, 10]:
		var gp: Vector3 = pts[gi]
		var gr: float = radii[gi]
		var gs: float = 0.03 - gi * 0.0013
		b.tube([gp + Vector3(0, 0, -gr), gp + Vector3(0, 0, -gr - gs * 1.3)], [0.005, 0.005], metal, metal, 4, false, false)
		var ring: Array = []
		var ring_r: Array = []
		for k in 9:
			var a := TAU * k / 8.0
			ring.append(gp + Vector3(0, sin(a) * gs * 0.6, -gr - gs * 1.3 - gs * 0.6 - cos(a) * gs * 0.6))
			ring_r.append(0.0042)
		b.tube(ring, ring_r, metal.lightened(0.1), metal, 4, false, false)
	var tip: Vector3 = pts[n]
	b.ellipsoid(tip, Vector3(0.011, 0.011, 0.011), metal, metal, 6, 4)
	if style["crystal"]:
		glow.ellipsoid(tip + Vector3(0, -0.04, 0), Vector3(0.022, 0.05, 0.022), glow_col, glow_col, 6, 4)
	var mesh := b.build()
	if glow_col.a > 0.0:
		glow.add_surface(mesh, MeshBuilder.glow_material(1.7))
	var out := {"mesh": mesh, "tip": tip}
	_cache[key] = out
	return out


static func _style(id: String) -> Dictionary:
	var d := {"grip": Color("2f2a26"), "accent": Color("d9d3c3"), "glow": Color(0, 0, 0, 0), "reel": 0.06,
		"metal": Color("a9aeb5"), "bend": 0.12, "pattern": "plain", "rings": false, "gem": false, "crystal": false}
	match id:
		"twig_rod":
			d.merge({"grip": Color("6a4524"), "accent": Color("a58a5a"), "reel": 0.0, "metal": Color("8a7a60"), "bend": 0.28, "pattern": "gradient"}, true)
		"bamboo_rod":
			d.merge({"grip": Color("c9a46a"), "accent": Color("5a3b1f"), "reel": 0.05, "metal": Color("b9a37a"), "bend": 0.2, "pattern": "bamboo", "rings": true}, true)
		"fiberglass_rod":
			d.merge({"grip": Color("1f2326"), "accent": Color("f0f4f4"), "reel": 0.06, "metal": Color("a9b1b8"), "bend": 0.16, "rings": true}, true)
		"carbon_rod":
			d.merge({"grip": Color("2b2f36"), "accent": Color("e04a3a"), "reel": 0.07, "metal": Color("c9ced4"), "bend": 0.12, "pattern": "carbon", "rings": true}, true)
		"reef_rod":
			d.merge({"grip": Color("e8e2d2"), "accent": Color("ffffff"), "reel": 0.075, "metal": Color("d9a05b"), "bend": 0.13, "pattern": "gradient", "rings": true}, true)
		"frost_rod":
			d.merge({"grip": Color("d6eefc"), "accent": Color("c9ecff"), "glow": Color("8fe6ff"), "reel": 0.075, "metal": Color("cfe9f6"), "bend": 0.1, "pattern": "gradient", "crystal": true, "gem": true}, true)
		"abyss_rod":
			d.merge({"grip": Color("241a38"), "accent": Color("7a45c9"), "glow": Color("b57bff"), "reel": 0.08, "metal": Color("4d3a70"), "bend": 0.1, "pattern": "gradient", "crystal": true, "gem": true, "rings": true}, true)
		"infinity_rod":
			d.merge({"grip": Color("7a4a14"), "accent": Color("fff0b0"), "glow": Color("ffd34a"), "reel": 0.09, "metal": Color("f0c24a"), "bend": 0.09, "pattern": "gradient", "crystal": true, "gem": true, "rings": true}, true)
	return d
