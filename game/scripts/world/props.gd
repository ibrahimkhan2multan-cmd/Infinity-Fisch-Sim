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


static func tree_mesh(kind: String) -> ArrayMesh:
	var key := "tree_" + kind
	if _cache.has(key):
		return _cache[key]
	var b := MeshBuilder.new()
	match kind:
		"pine":
			b.cylinder(Vector3.ZERO, 0.28, 0.2, 1.6, 6, Color("6b4a2b"))
			b.cone(Vector3(0, 1.0, 0), 1.6, 2.2, 7, Color("2f7a3c"))
			b.cone(Vector3(0, 2.3, 0), 1.25, 2.0, 7, Color("3a8f48"))
			b.cone(Vector3(0, 3.5, 0), 0.85, 1.8, 7, Color("48a458"))
		"frost_pine":
			b.cylinder(Vector3.ZERO, 0.28, 0.2, 1.6, 6, Color("5a4a3a"))
			b.cone(Vector3(0, 1.0, 0), 1.6, 2.2, 7, Color("3f6f6a"))
			b.cone(Vector3(0, 2.3, 0), 1.25, 2.0, 7, Color("7aa6a0"))
			b.cone(Vector3(0, 3.5, 0), 0.85, 1.8, 7, Color("eef6fb"))
		"round":
			b.cylinder(Vector3.ZERO, 0.32, 0.24, 2.2, 6, Color("7a5430"))
			b.sphere(Vector3(0, 3.1, 0), 1.7, Color("4fa84a"), 8, 5, Vector3(1, 0.85, 1))
			b.sphere(Vector3(0.9, 2.6, 0.4), 1.1, Color("5bb853"), 7, 4)
			b.sphere(Vector3(-0.8, 2.7, -0.5), 1.0, Color("459a42"), 7, 4)
		"palm":
			var lean := Basis(Vector3(0, 0, 1), deg_to_rad(-8))
			b.cylinder(Vector3.ZERO, 0.25, 0.18, 2.4, 6, Color("a8845a"), Color(0, 0, 0, 0), lean)
			b.cylinder(Vector3(-0.33, 2.38, 0), 0.18, 0.13, 2.0, 6, Color("9a7850"), Color(0, 0, 0, 0), Basis(Vector3(0, 0, 1), deg_to_rad(-16)))
			var top := Vector3(-0.9, 4.3, 0)
			for i in 7:
				var yaw := TAU * i / 7.0
				var fb := Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), deg_to_rad(-62))
				b.box(top + fb * Vector3(0.0, 0.0, 0.0) + Basis(Vector3.UP, yaw) * Vector3(0.9, -0.35, 0), Vector3(2.2, 0.08, 0.55), Color("3f9a4a") if i % 2 == 0 else Color("4fb05a"), Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), deg_to_rad(-22)))
			b.sphere(top + Vector3(0, -0.2, 0), 0.28, Color("6b4a2b"), 6, 4)
		"mangrove":
			for i in 6:
				var a := TAU * i / 6.0
				var tilt := Basis(Vector3.UP, a) * Basis(Vector3(0, 0, 1), deg_to_rad(-28))
				b.cylinder(Vector3.ZERO, 0.1, 0.05, 1.8, 4, Color("5a4630"), Color(0, 0, 0, 0), tilt)
			b.cylinder(Vector3(0, 1.0, 0), 0.3, 0.22, 1.8, 6, Color("5a4630"))
			b.sphere(Vector3(0, 3.1, 0), 1.6, Color("3d6b3a"), 7, 4, Vector3(1.1, 0.7, 1.1))
			b.sphere(Vector3(0.8, 2.8, 0.5), 1.0, Color("4a7d45"), 6, 4)
		"dead":
			b.cylinder(Vector3.ZERO, 0.3, 0.12, 3.0, 5, Color("4d4036"))
			b.cylinder(Vector3(0, 1.8, 0), 0.1, 0.04, 1.4, 4, Color("4d4036"), Color(0, 0, 0, 0), Basis(Vector3(0, 0, 1), deg_to_rad(-50)))
		"bush":
			b.sphere(Vector3(0, 0.5, 0), 0.8, Color("3f9140"), 7, 4, Vector3(1.2, 0.8, 1.0))
			b.sphere(Vector3(0.6, 0.4, 0.3), 0.5, Color("55a84d"), 6, 3)
		"reed":
			for i in 5:
				var a := TAU * i / 5.0
				var lean2 := Basis(Vector3.UP, a) * Basis(Vector3(0, 0, 1), deg_to_rad(-10 - 6 * (i % 3)))
				b.cylinder(Vector3(cos(a) * 0.15, 0, sin(a) * 0.15), 0.04, 0.02, 1.4 + 0.2 * (i % 3), 4, Color("7a9a3a"), Color(0, 0, 0, 0), lean2)
	var m := b.build()
	_cache[key] = m
	return m


static func rock_mesh() -> ArrayMesh:
	if _cache.has("rock"):
		return _cache["rock"]
	var b := MeshBuilder.new()
	b.sphere(Vector3(0, 0.35, 0), 0.9, Color("8d9097"), 6, 4, Vector3(1.0, 0.65, 0.85))
	b.sphere(Vector3(0.7, 0.2, 0.3), 0.5, Color("7c8087"), 5, 3, Vector3(1, 0.7, 1))
	var m := b.build()
	_cache["rock"] = m
	return m


## Fish facing +Z. Used for held fish, tank fish and effects.
static func fish_mesh(c1: Color, c2: Color, shape: int) -> ArrayMesh:
	var key := "fish_%s_%s_%d" % [c1.to_html(false), c2.to_html(false), shape]
	if _cache.has(key):
		return _cache[key]
	var b := MeshBuilder.new()
	var body := Vector3(0.4, 0.6, 1.0)
	var tail_len := 0.4
	match shape:
		1: body = Vector3(0.65, 0.75, 0.8)
		2: body = Vector3(0.3, 0.35, 1.6)
		3: body = Vector3(0.9, 0.22, 0.95)
		4: body = Vector3(0.5, 0.55, 1.5); tail_len = 0.5
	b.sphere(Vector3.ZERO, 0.5, c1, 8, 5, body)
	b.sphere(Vector3(0, -0.05 * body.y, 0), 0.46, c2, 8, 5, Vector3(body.x * 0.9, body.y * 0.7, body.z * 0.98))
	var tz := -0.5 * body.z
	var rot := Basis(Vector3.RIGHT, -PI / 2.0) * Basis.from_scale(Vector3(0.25, 1.0, 1.7))
	b.cylinder(Vector3(0, 0, tz + 0.08), 0.22, 0.0, tail_len, 6, c2, Color(0, 0, 0, 0), rot)
	if shape != 3:
		b.cone(Vector3(0, 0.22 * body.y * 1.3, 0.05), 0.14, 0.26, 5, c2, Basis.from_scale(Vector3(0.25, 1, 1.5)))
	var ex := 0.17 * body.x / 0.4
	for sx in [-1.0, 1.0]:
		b.sphere(Vector3(sx * ex, 0.06 * body.y, 0.33 * body.z), 0.06, Color.WHITE, 5, 3)
		b.sphere(Vector3(sx * (ex + 0.035), 0.06 * body.y, 0.34 * body.z), 0.03, Color.BLACK, 4, 3)
	var m := b.build()
	_cache[key] = m
	return m


## A cute building facing +Z, origin at the centre of the ground footprint.
static func building(w: float, d: float, h: float, wall: Color, roof: Color, opts := {}) -> ArrayMesh:
	var b := MeshBuilder.new()
	b.box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall)
	b.box(Vector3(0, 0.12, 0), Vector3(w + 0.3, 0.24, d + 0.3), wall.darkened(0.35))
	b.gable_roof(Vector3(0, h, 0), w, d, opts.get("roof_h", h * 0.55), roof, roof.darkened(0.1), 0.45)
	# door + windows on the +Z face
	b.box(Vector3(0, 1.0, d * 0.5 + 0.03), Vector3(1.1, 2.0, 0.12), Color("5c3b22"))
	b.box(Vector3(0, 2.15, d * 0.5 + 0.05), Vector3(1.4, 0.18, 0.2), Color("4a2f1a"))
	var win := Color("a9dcff")
	var frame := Color("f0ead8")
	for sx: float in [-1.0, 1.0]:
		var x: float = sx * w * 0.3
		b.box(Vector3(x, h * 0.55, d * 0.5 + 0.04), Vector3(1.0, 1.0, 0.1), frame)
		b.box(Vector3(x, h * 0.55, d * 0.5 + 0.08), Vector3(0.8, 0.8, 0.1), win)
	if opts.get("chimney", false):
		b.box(Vector3(w * 0.28, h + h * 0.55, -d * 0.12), Vector3(0.6, 1.4, 0.6), Color("8a6a5a"))
	if opts.get("awning", false):
		b.box(Vector3(0, 2.7, d * 0.5 + 0.9), Vector3(w * 0.8, 0.12, 1.8), opts.get("awning_color", Color("d9534f")), Basis(Vector3.RIGHT, deg_to_rad(-10)))
		for sx in [-1.0, 1.0]:
			b.cylinder(Vector3(sx * w * 0.38, 0, d * 0.5 + 1.65), 0.08, 0.08, 2.6, 5, Color("6b4a2b"))
	return b.build()


## Market stall: counter + striped canopy.
static func stall(canopy: Color) -> ArrayMesh:
	var b := MeshBuilder.new()
	b.box(Vector3(0, 0.55, 0), Vector3(3.2, 1.1, 1.3), Color("8a5a32"))
	b.box(Vector3(0, 1.12, 0.1), Vector3(3.4, 0.12, 1.6), Color("c79a62"))
	for sx in [-1.5, 1.5]:
		b.cylinder(Vector3(sx, 0, -0.5), 0.07, 0.07, 2.8, 5, Color("6b4a2b"))
	for i in 6:
		var col := canopy if i % 2 == 0 else Color("f5f0e0")
		b.box(Vector3(-1.4 + i * 0.56, 2.75, -0.1), Vector3(0.56, 0.1, 2.0), col, Basis(Vector3.RIGHT, deg_to_rad(-12)))
	return b.build()


static func pier(length: float, width: float) -> ArrayMesh:
	var b := MeshBuilder.new()
	b.box(Vector3(0, 0.0, length * 0.5), Vector3(width, 0.25, length), Color("9a6b3e"))
	var n := int(length / 1.1)
	for i in n:
		b.box(Vector3(0, 0.02, 0.55 + i * 1.1), Vector3(width, 0.27, 0.9), Color("b07d4a") if i % 2 == 0 else Color("a2723f"))
	var posts := int(length / 4.0) + 1
	for i in posts:
		for sx in [-1.0, 1.0]:
			b.cylinder(Vector3(sx * (width * 0.5 - 0.1), -3.0, i * 4.0 + 0.2), 0.14, 0.14, 3.9, 6, Color("5a3f26"))
	return b.build()


static func boat() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.box(Vector3(0, 0.35, 0), Vector3(2.6, 0.7, 6.0), Color("b0452f"))
	b.box(Vector3(0, 0.75, 0), Vector3(2.2, 0.15, 5.6), Color("e8d6b0"))
	b.cone(Vector3(0, 0, 3.0), 1.3, 1.6, 4, Color("b0452f"), Basis(Vector3.RIGHT, PI / 2.0))
	b.box(Vector3(0, 1.6, -1.2), Vector3(1.6, 1.6, 1.6), Color("f5f0e0"))
	b.box(Vector3(0, 2.5, -1.2), Vector3(1.9, 0.2, 1.9), Color("3a6ea5"))
	return b.build()


static func container_stack() -> ArrayMesh:
	var b := MeshBuilder.new()
	var cols := ["c0392b", "2980b9", "27ae60", "e67e22"]
	for i in 4:
		b.box(Vector3((i % 2) * 2.6, 1.3 + (i / 2) * 2.6, 0), Vector3(2.5, 2.5, 6.0), Color(cols[i]))
	return b.build()


static func lantern_post() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.cylinder(Vector3.ZERO, 0.1, 0.07, 3.0, 5, Color("3a3a3a"))
	b.box(Vector3(0, 3.2, 0), Vector3(0.45, 0.5, 0.45), Color("ffd27a"))
	b.cone(Vector3(0, 3.45, 0), 0.4, 0.3, 4, Color("3a3a3a"))
	return b.build()


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
