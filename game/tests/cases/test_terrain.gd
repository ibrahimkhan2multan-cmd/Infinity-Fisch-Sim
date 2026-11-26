extends RefCounted
## The terrain function must put every key location on dry land and every
## fishing water type somewhere reachable.


func run(t) -> void:
	Terrain.init_noise()
	_starter_water(t)
	for pair in [["village", Terrain.VILLAGE], ["factory", Terrain.FACTORY], ["hamlet", Terrain.HAMLET],
			["bog island", Terrain.BOG], ["frost island", Terrain.FROST], ["trench platform", Terrain.TRENCH]]:
		var p: Vector2 = pair[1]
		var h := Terrain.height_at(p.x, p.y)
		print("   %s: h=%.2f" % [pair[0], h])
		t.check(h > 1.5, "%s is on dry land (h=%.2f)" % [pair[0], h])
		t.check(Terrain.walkable(p.x, p.y), "%s is walkable" % pair[0])
	t.check(Terrain.water_type_at(Terrain.LAKE_C.x, Terrain.LAKE_C.y) == "lake", "lake centre is lake water")
	var ri: Vector2 = Terrain.RIVER[3]
	t.check(Terrain.water_type_at(ri.x, ri.y) == "river", "river polyline is river water (%s)" % Terrain.water_type_at(ri.x, ri.y))
	# column south of the village: land, then shore, then ocean
	var seen := {}
	var coast_z := -1.0
	for z in range(60, 260, 2):
		var wt := Terrain.water_type_at(-20.0, float(z))
		seen[wt] = true
		if coast_z < 0.0 and wt != "":
			coast_z = float(z)
	print("   south coast at z=%.0f, types seen: %s" % [coast_z, seen.keys()])
	t.check(seen.has("shore") and seen.has("ocean"), "shore and ocean water south of the village")
	t.check(coast_z > 95.0 and coast_z < 135.0, "coast is a believable distance from the village (z=%.0f)" % coast_z)
	# each special water type exists near its island
	var found := {}
	for ang in range(0, 360, 20):
		for pair in [["swamp", Terrain.BOG, 80.0], ["arctic", Terrain.FROST, 75.0], ["deep", Terrain.TRENCH, 60.0]]:
			var c: Vector2 = pair[1]
			var q: Vector2 = c + Vector2.from_angle(deg_to_rad(ang)) * float(pair[2])
			if Terrain.water_type_at(q.x, q.y) == pair[0]:
				found[pair[0]] = true
	for w in ["swamp", "arctic", "deep"]:
		t.check(found.has(w), "%s water exists near its island" % w)
	t.check(Terrain.height_at(-20.0, 8.0) > 2.0, "village north is land")
	# deep water is not walkable; wading near shore is
	t.check(not Terrain.walkable(-20.0, 200.0), "open sea is not walkable")
	# lake edge: walkable on the bank, not 10 m in
	t.check(not Terrain.walkable(Terrain.LAKE_C.x, Terrain.LAKE_C.y + 10.0), "lake interior is not walkable")


func _starter_water(t) -> void:
	# a new player (twig rod, range 16 m) casting from the pier or the beach must
	# only ever reach permit-free shore water
	for start in [Vector2(-20, 128), Vector2(-20, 142), Vector2(-20, 150)]:
		var d := 3.0
		while d <= 16.0:
			var z: float = start.y + d
			if Terrain.water_level_at(start.x, z) != -INF and Terrain.height_at(start.x, z) < Terrain.water_level_at(start.x, z) - 0.3:
				var wt := Terrain.water_type_at(start.x, z)
				t.check(wt == "shore", "pier cast from z=%d at +%dm is shore water (got '%s')" % [int(start.y), int(d), wt])
			d += 4.0
	t.check(Terrain.water_type_at(-20, 260) == "ocean", "far open water is ocean (needs a permit)")
	t.check(Game_has_cove(), "new games start with the cove permit")


func Game_has_cove() -> bool:
	return Engine.get_main_loop().root.get_node("Game").permits.has("cove")
