class_name VillageBuilder
extends RefCounted
## Places every building, shop counter, pier, NPC and interaction point.
## Fills world.destinations (ferry stops) and world.tank_anchors / stall anchors.

var world: Node3D
var destinations: Dictionary = {}        # id -> {"name","pos","yaw","permit","fare"}
var market_slots: Array[Vector3] = []    # where customers stand
var tank_anchors: Array[Vector3] = []    # hatchery tank display positions
var kitchen_anchor := Vector3.ZERO
var smoke_points: Array[Vector3] = []


func build(p_world: Node3D) -> void:
	world = p_world
	_village()
	_factory()
	_hamlet()
	_island(Terrain.BOG, "bog", "Stilt Village", "mangrove")
	_island(Terrain.FROST, "frost", "Frostfin Outpost", "frostfin")
	_island(Terrain.TRENCH, "trench", "Trench Platform", "abyss")


# ---- helpers -------------------------------------------------------------------

func _gy(x: float, z: float) -> float:
	return Terrain.height_at(x, z)


func _face(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return atan2(d.x, d.y)


func _building(label_text: String, pos: Vector2, yaw: float, w: float, d: float, h: float,
		wall: Color, roof: Color, opts := {}) -> Node3D:
	var root := Node3D.new()
	root.name = label_text.replace(" ", "") if label_text != "" else "House"
	root.position = Vector3(pos.x, _gy(pos.x, pos.y), pos.y)
	root.rotation.y = yaw
	var mi := MeshInstance3D.new()
	mi.mesh = Props.building(w, d, h, wall, roof, opts)
	root.add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, h + 1.0, d)
	cs.shape = box
	cs.position = Vector3(0, (h + 1.0) * 0.5, 0)
	body.add_child(cs)
	root.add_child(body)
	if label_text != "":
		var l := Props.label(label_text, 0.9, Color("ffffff"), 14)
		l.position = Vector3(0, h + h * 0.55 + 1.3, 0)
		root.add_child(l)
	world.add_child(root)
	return root


## Interactable placed `dist` metres in front of a building (local +Z).
func _door_interact(b: Node3D, d: float, dist: float, prompt: String, action: String, data := {}) -> Interactable:
	var it := Interactable.new().setup(prompt, action, 3.4, data)
	var fwd := Vector3(sin(b.rotation.y), 0, cos(b.rotation.y))
	it.position = b.position + fwd * (d * 0.5 + dist)
	it.position.y = _gy(it.position.x, it.position.z) + 1.0
	world.add_child(it)
	return it


func _interact_at(pos: Vector3, prompt: String, action: String, radius := 3.4, data := {}) -> Interactable:
	var it := Interactable.new().setup(prompt, action, radius, data)
	it.position = pos
	world.add_child(it)
	return it


func _npc(npc_name: String, title: String, pos: Vector3, yaw: float, shirt: Color, pants: Color,
		hat: Color, hat_kind := "cap") -> Npc:
	var n := Npc.new()
	n.setup(shirt, pants, Color("e0b08a") if randf() < 0.5 else Color("a8744f"), hat, hat_kind)
	n.init_npc(npc_name, title, yaw)
	n.position = pos
	world.add_child(n)
	return n


func _prop(mesh: Mesh, pos: Vector3, yaw := 0.0, collide_size := Vector3.ZERO) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = yaw
	world.add_child(mi)
	if collide_size != Vector3.ZERO:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = collide_size
		cs.shape = box
		cs.position = Vector3(0, collide_size.y * 0.5, 0)
		body.add_child(cs)
		mi.add_child(body)
	return mi


func _pier(start: Vector2, yaw: float, length: float, deck_y: float, width := 3.6) -> Vector3:
	var root := Node3D.new()
	root.position = Vector3(start.x, deck_y, start.y)
	root.rotation.y = yaw
	var mi := MeshInstance3D.new()
	mi.mesh = Props.pier(length, width)
	root.add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.3, length)
	cs.shape = box
	cs.position = Vector3(0, 0.0, length * 0.5)
	body.add_child(cs)
	root.add_child(body)
	# railings (posts + cross bar) every 6 m
	var rails := MeshBuilder.new()
	for i in int(length / 6.0):
		for sx in [-1.0, 1.0]:
			rails.cylinder(Vector3(sx * (width * 0.5 - 0.05), 0.1, 3.0 + i * 6.0), 0.07, 0.07, 1.0, 5, Color("6b4a2b"))
	root.add_child(_mesh_node(rails.build()))
	world.add_child(root)
	Terrain.add_walk_zone(start, yaw, length, width)
	var dir := Vector2(sin(yaw), cos(yaw))
	var end := start + dir * length
	return Vector3(end.x, deck_y, end.y)


func _mesh_node(m: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	return mi


## March from `from` along `dir` until water; returns the last land point.
func _coast(from: Vector2, dir: Vector2) -> Vector2:
	var p := from
	for i in 400:
		var q := p + dir
		if Terrain.water_level_at(q.x, q.y) != -INF:
			return p
		p = q
	return p


# ---- Driftwood Village ------------------------------------------------------------

func _village() -> void:
	var V := Terrain.VILLAGE
	var plaza := V + Vector2(0, 6)
	var tackle := _building("TACKLE SHOP", Vector2(-42, 46), _face(Vector2(-42, 46), plaza), 9, 7, 4.4,
		Color("d9a066"), Color("b0452f"), {"chimney": true, "awning": true, "awning_color": Color("d9534f")})
	_door_interact(tackle, 7, 2.2, "Tackle Shop", "shop_tackle")
	_npc("Finn", "Tackle Trader", tackle.position + Vector3(-1.5, 0, 6.0).rotated(Vector3.UP, tackle.rotation.y), tackle.rotation.y, Color("c0392b"), Color("3b4a6b"), Color("3b4a6b"))

	var general := _building("GENERAL STORE", Vector2(-24, 38), _face(Vector2(-24, 38), plaza), 10, 7, 4.4,
		Color("7fb5c9"), Color("3a6ea5"), {"awning": true, "awning_color": Color("3a9a6a")})
	_door_interact(general, 7, 2.2, "General Store", "shop_general")
	_npc("Marta", "Shopkeeper", general.position + Vector3(1.5, 0, 6.0).rotated(Vector3.UP, general.rotation.y), general.rotation.y, Color("3a9a6a"), Color("5a4a3a"), Color("f5f0e0"), "straw")

	var guild := _building("FISHING GUILD", Vector2(-4, 40), _face(Vector2(-4, 40), plaza), 12, 8, 5.4,
		Color("c9b58a"), Color("6b4a8a"), {"chimney": true})
	_door_interact(guild, 8, 2.4, "Fishing Guild", "guild")
	_npc("Captain Mara", "Guild Master", guild.position + Vector3(2.5, 0, 7.0).rotated(Vector3.UP, guild.rotation.y), guild.rotation.y, Color("6b4a8a"), Color("2f3a4a"), Color("2f3a4a"))

	var home := _building("HOME", Vector2(16, 52), _face(Vector2(16, 52), plaza), 7, 6, 3.8,
		Color("e8d9b8"), Color("8a4a3a"), {"chimney": true})
	_door_interact(home, 6, 2.0, "Rest until morning & save", "rest")

	var hatch := _building("HATCHERY", Vector2(-52, 66), _face(Vector2(-52, 66), plaza), 11, 8, 4.2,
		Color("9ad0d0"), Color("2f6f8a"), {})
	_door_interact(hatch, 8, 3.0, "Hatchery (fish tanks)", "hatchery")
	_npc("Dr. Lin", "Fish Breeder", hatch.position + Vector3(3.5, 0, 6.5).rotated(Vector3.UP, hatch.rotation.y), hatch.rotation.y, Color("f5f0e0"), Color("3a5a7a"), Color("5ab0c0"), "hood")
	for i in 6:
		tank_anchors.append(Vector3(-52 + i * 4.7, _gy(-52 + i * 4.7, 79) + 0.0, 79))

	# market stalls with customer queue spots
	for i in 3:
		var sx := -40.0 + i * 12.0
		var stall_pos := Vector3(sx, _gy(sx, 62), 62)
		var colors := [Color("d9534f"), Color("3a9a6a"), Color("e0a020")]
		_prop(Props.stall(colors[i]), stall_pos, 0.0, Vector3(3.2, 1.2, 1.3))
		market_slots.append(Vector3(sx, _gy(sx, 66), 66.2))
		_npc(["Rico", "Aiko", "Dev"][i], "Fishmonger" if i == 1 else "", stall_pos + Vector3(0, 0, -1.4), 0.0,
			colors[i].darkened(0.2), Color("3a3a4a"), colors[i], "cap")
	_interact_at(Vector3(-28, _gy(-28, 66) + 1.0, 66), "Fish Market", "market", 6.0)
	var mlabel := Props.label("FISH MARKET", 1.0, Color("ffd36a"), 14)
	mlabel.position = Vector3(-28, 6.6, 62)
	world.add_child(mlabel)

	# kitchen pavilion
	var kc := Vector3(10, _gy(10, 74), 74)
	kitchen_anchor = kc
	var kb := MeshBuilder.new()
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			kb.cylinder(Vector3(sx * 6.0, 0, sz * 3.0), 0.18, 0.18, 3.4, 6, Color("7a5430"))
	kb.gable_roof(Vector3(0, 3.4, 0), 13.0, 7.0, 1.8, Color("c0603a"), Color("a84f2e"), 0.5)
	kb.box(Vector3(0, 0.5, -2.6), Vector3(12.0, 1.0, 0.9), Color("b8a58a"))
	kb.box(Vector3(-4.5, 1.15, -2.6), Vector3(1.6, 0.3, 0.8), Color("2f2f2f"))        # grill
	kb.cylinder(Vector3(-1.6, 1.0, -2.6), 0.55, 0.5, 0.5, 8, Color("8a8f96"))         # pot
	kb.box(Vector3(1.6, 1.1, -2.6), Vector3(1.5, 0.2, 0.8), Color("e8d6b0"))          # prep board
	kb.box(Vector3(4.6, 1.5, -2.6), Vector3(1.4, 1.0, 0.8), Color("5a3f3a"))          # oven
	var kitchen := _prop(kb.build(), kc, 0.0, Vector3(12.0, 1.0, 1.0))
	(kitchen.get_child(0) as StaticBody3D).position = Vector3(0, 0, -2.6)
	var klabel := Props.label("KITCHEN", 0.9, Color("ffd36a"), 14)
	klabel.position = Vector3(0, 6.0, 0)
	kitchen.add_child(klabel)
	_interact_at(kc + Vector3(0, 1.0, 1.0), "Kitchen (cook)", "kitchen", 4.5)
	_npc("Chef Bao", "Head Chef", kc + Vector3(-3.0, 0, -1.2), 0.0, Color("f5f0e0"), Color("3a3a4a"), Color("f5f0e0"), "cap")

	# lamp posts around the plaza
	for p in [Vector2(-34, 52), Vector2(-14, 52), Vector2(6, 62), Vector2(-60, 56), Vector2(10, 40)]:
		_prop(Props.lantern_post(), Vector3(p.x, _gy(p.x, p.y), p.y))

	# pier, dock crate, ferry
	var start := Vector2(-20, 112)
	var end := _pier(start, 0.0, 40.0, 1.3)
	_interact_at(Vector3(-24, _gy(-24, 106) + 1.0, 106), "Dock Crate (assistant catches)", "crate", 3.4)
	_prop(_crate_mesh(), Vector3(-24, _gy(-24, 106), 106), 0.3, Vector3(1.4, 1.2, 1.4))
	var crate_label := Props.label("DOCK CRATE", 0.6, Color("ffffff"))
	crate_label.position = Vector3(-24, _gy(-24, 106) + 2.2, 106)
	world.add_child(crate_label)
	_prop(Props.boat(), end + Vector3(7.0, -0.9, -3.0), deg_to_rad(80))
	_npc("Skipper Joe", "Ferry Captain", end + Vector3(0, 0.15, -1.0), PI, Color("2f6f8a"), Color("2f3a4a"), Color("f5f0e0"))
	_interact_at(end + Vector3(0, 1.0, -2.0), "Ferry", "ferry", 4.0)
	destinations["home"] = {"name": "Driftwood Village", "pos": Vector3(-20, _gy(-20, 108) + 1.2, 108), "yaw": 0.0,
		"permit": "cove", "fare": 0}
	# fishing hints
	var hint := Props.label("Fish from the pier!", 0.55, Color("bfeaff"))
	hint.position = end + Vector3(0, 3.0, -6.0)
	world.add_child(hint)


func _crate_mesh() -> ArrayMesh:
	var b := MeshBuilder.new()
	b.box(Vector3(0, 0.6, 0), Vector3(1.3, 1.2, 1.3), Color("a8794a"))
	b.box(Vector3(0, 1.22, 0), Vector3(1.4, 0.12, 1.4), Color("8a5f38"))
	b.box(Vector3(0, 0.6, 0.67), Vector3(1.3, 0.12, 0.05), Color("6b4a2b"))
	return b.build()


# ---- Cannery district --------------------------------------------------------------

func _factory() -> void:
	var F := Terrain.FACTORY
	var cannery := _building("FISH CANNERY", F + Vector2(0, -10), _face(F + Vector2(0, -10), F + Vector2(0, 10)), 16, 10, 7.0,
		Color("b8b8c0"), Color("5a5f6b"), {"roof_h": 2.5})
	_door_interact(cannery, 10, 2.6, "Cannery Office (factory)", "factory")
	_npc("Foreman Hale", "Factory Boss", cannery.position + Vector3(3.0, 0, 8.0), 0.0, Color("e0a020"), Color("3a4a5a"), Color("e0a020"))
	# chimneys + smoke
	for sx in [-5.0, 5.0]:
		var cp := cannery.position + Vector3(sx, 0, -2.0)
		var cb := MeshBuilder.new()
		cb.cylinder(Vector3(0, 0, 0), 0.8, 0.6, 11.0, 8, Color("8a5a4a"))
		cb.cylinder(Vector3(0, 10.2, 0), 0.85, 0.85, 0.5, 8, Color("2f2f2f"))
		_prop(cb.build(), cp)
		smoke_points.append(cp + Vector3(0, 11.2, 0))
	var wh := _building("WAREHOUSE", F + Vector2(-20, -4), _face(F + Vector2(-20, -4), F + Vector2(0, 8)), 12, 9, 5.0,
		Color("9a8a7a"), Color("5a4a3a"), {})
	_prop(Props.container_stack(), Vector3(F.x + 18, _gy(F.x + 18, F.y + 6), F.y + 6), 0.2, Vector3(5.2, 5.2, 6.0))
	_npc("Dockhand Sam", "", Vector3(F.x + 10, _gy(F.x + 10, F.y + 6), F.y + 6), -1.0, Color("3a6ea5"), Color("3a3a4a"), Color("e0a020"))
	var sign := Props.label("Wholesale buyers pay daily prices", 0.55, Color("c9e6ff"))
	sign.position = Vector3(F.x, _gy(F.x, F.y + 10) + 3.4, F.y + 10)
	world.add_child(sign)
	wh.name = "Warehouse"


# ---- Mirror Lake hamlet ---------------------------------------------------------------

func _hamlet() -> void:
	var H := Terrain.HAMLET
	var toward_lake := (Terrain.LAKE_C - H).normalized()
	var cabin := _building("LAKE CABIN", H + Vector2(-5, -3), _face(H + Vector2(-5, -3), H + Vector2(4, 4)), 8, 6, 3.6,
		Color("8a5f3a"), Color("4a6b3a"), {"chimney": true})
	_door_interact(cabin, 6, 2.0, "Rest until morning & save", "rest")
	var stall_pos := Vector3(H.x + 5, _gy(H.x + 5, H.y + 3), H.y + 3)
	var yaw := _face(Vector2(stall_pos.x, stall_pos.z), Terrain.LAKE_C)
	_prop(Props.stall(Color("3a9a6a")), stall_pos, yaw, Vector3(3.2, 1.2, 1.3))
	_interact_at(stall_pos + Vector3(sin(yaw), 1.0, cos(yaw)) * 2.2, "Angler's Stand (sell fish)", "market", 3.6)
	_npc("Old Pike", "Lake Angler", stall_pos + Vector3(-sin(yaw), 0, -cos(yaw)) * 1.4, yaw, Color("3a6ea5"), Color("5a4a3a"), Color("e8cf86"), "straw")
	_prop(Props.lantern_post(), Vector3(H.x, _gy(H.x, H.y), H.y - 6))
	var coast := _coast(H, toward_lake)
	var start := coast - toward_lake * 3.0
	var yaw_p := atan2(toward_lake.x, toward_lake.y)
	_pier(start, yaw_p, 16.0, Terrain.LAKE_LEVEL + 0.75)
	var hint := Props.label("Mirror Lake - needs a permit", 0.55, Color("bfeaff"))
	hint.position = Vector3(start.x, Terrain.LAKE_LEVEL + 3.5, start.y)
	world.add_child(hint)


# ---- Islands -------------------------------------------------------------------------

func _island(center: Vector2, id: String, title: String, permit: String) -> void:
	var home_dir := (Vector2(-20, 100) - center).normalized()
	var coast := _coast(center, home_dir)
	var start := coast - home_dir * 3.0
	var yaw := atan2(home_dir.x, home_dir.y)
	var end := _pier(start, yaw, 18.0, 1.3)
	var side := Vector2(-home_dir.y, home_dir.x)
	_npc("Skipper %s" % ["Kai", "Nora", "Tane"][["bog", "frost", "trench"].find(id)], "Ferry Captain",
		end + Vector3(0, 0.15, 0) - Vector3(home_dir.x, 0, home_dir.y) * 1.2, yaw + PI, Color("2f6f8a"), Color("2f3a4a"), Color("f5f0e0"))
	_interact_at(end + Vector3(0, 1.0, 0) - Vector3(home_dir.x, 0, home_dir.y) * 2.5, "Ferry", "ferry", 4.0)
	var land_in := start - home_dir * 1.5
	destinations[id] = {
		"name": title, "pos": Vector3(land_in.x, maxf(_gy(land_in.x, land_in.y), 0.5) + 1.5, land_in.y),
		"yaw": yaw + PI, "permit": permit, "fare": {"bog": 150, "frost": 400, "trench": 900}[id],
	}
	var title_label := Props.label(title.to_upper(), 1.1, Color("ffd36a"), 14)
	title_label.position = Vector3(center.x, ISLAND_SIGN_Y, center.y)
	world.add_child(title_label)
	var plaza := center
	match id:
		"bog":
			for i in 3:
				var a := TAU * i / 3.0 + 0.5
				var p := center + Vector2.from_angle(a) * 14.0
				_building("", p, _face(p, plaza), 6, 5, 3.0, Color("8a6a3a"), Color("55663a"), {"chimney": i == 0})
			_market_stand(center + Vector2(2, 3), "Bog Fish Stand", Color("55663a"))
		"frost":
			var ib := MeshBuilder.new()
			ib.sphere(Vector3(0, 0, 0), 4.2, Color("eef6fb"), 10, 6, Vector3(1, 0.8, 1))
			ib.box(Vector3(0, 0.9, 4.0), Vector3(1.6, 1.8, 1.4), Color("c9d8e0"))
			var ig := _prop(ib.build(), Vector3(center.x - 8, 2.6, center.y - 4), _face(center + Vector2(-8, -4), plaza), Vector3(6, 3, 6))
			ig.name = "Igloo"
			_building("", center + Vector2(10, -6), _face(center + Vector2(10, -6), plaza), 6, 5, 3.0, Color("9ab8d0"), Color("3a6ea5"), {"chimney": true})
			_market_stand(center + Vector2(2, 4), "Frostfin Fish Stand", Color("3a6ea5"))
		"trench":
			_building("", center + Vector2(-3, -3), _face(center + Vector2(-3, -3), plaza), 6, 5, 3.0, Color("6d6a66"), Color("a8386a"), {})
			_market_stand(center + Vector2(3, 3), "Trench Fish Stand", Color("a8386a"))


const ISLAND_SIGN_Y := 12.0


func _market_stand(p: Vector2, prompt: String, color: Color) -> void:
	var pos := Vector3(p.x, _gy(p.x, p.y), p.y)
	_prop(Props.stall(color), pos, 0.0, Vector3(3.2, 1.2, 1.3))
	_interact_at(pos + Vector3(0, 1.0, 2.2), prompt, "market", 3.6)
