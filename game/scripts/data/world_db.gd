class_name WorldDB
extends RefCounted
## Fishing locations (permits) and business upgrades.

static func build_locations() -> Dictionary:
	var rows: Array = [
		["cove", "Driftwood Cove", ["shore"], 1, 0, "Calm shallows around the home village. Free to fish."],
		["mirror_lake", "Mirror Lake & Silverrun River", ["lake", "river"], 3, 300, "Fresh water north of the village."],
		["open_sea", "Open Sea", ["ocean"], 6, 1500, "Deep blue water beyond the shallows."],
		["mangrove", "Mangrove Bog", ["swamp"], 9, 4000, "Murky island waters reachable by ferry."],
		["frostfin", "Frostfin Isle", ["arctic"], 13, 12000, "Icy island waters reachable by ferry."],
		["abyss", "Abyss Trench", ["deep"], 18, 40000, "The deepest water. Ferry to the trench platform."],
	]
	var out := {}
	for r in rows:
		var l := DataTypes.Location.new()
		l.id = r[0]
		l.name = r[1]
		var ws: Array[String] = []
		for w in r[2]:
			ws.append(str(w))
		l.waters = ws
		l.level_req = r[3]
		l.cost = r[4]
		l.desc = r[5]
		out[l.id] = l
	return out


static func build_upgrades() -> Dictionary:
	var rows: Array = [
		# id, name, desc, max, base_cost, growth, level_req
		["backpack", "Bigger Backpack", "+8 fish slots per level.", 10, 150, 1.55, 1],
		["tank_count", "Extra Fish Tank", "Build another tank at the Hatchery.", 5, 800, 2.3, 4],
		["tank_tech", "Tank Technology", "Tanks hold more fish and breed & grow faster.", 5, 1200, 2.0, 5],
		["market_stalls", "Market Stall", "More customers can queue at once.", 3, 1000, 2.6, 3],
		["factory_lines", "Factory Line", "Process more batches at the same time.", 5, 2500, 2.2, 6],
		["factory_batch", "Bigger Batches", "+2 fish per factory batch.", 5, 2000, 2.0, 6],
		["factory_speed", "Faster Machinery", "Factory lines run 12% faster per level.", 5, 3000, 2.1, 7],
		["warehouse", "Warehouse", "Larger storage for products and assistant catches.", 8, 600, 1.7, 3],
		["kitchen_speed", "Pro Kitchen", "Cooking is 10% faster per level.", 5, 900, 1.9, 4],
		["assistants", "Hire Assistant Angler", "Assistants fish for you and fill the dock crate.", 5, 1500, 2.2, 5],
		["assistant_skill", "Assistant Training", "Assistants catch faster and better fish.", 5, 2500, 2.0, 7],
	]
	var out := {}
	for r in rows:
		var u := DataTypes.Upgrade.new()
		u.id = r[0]
		u.name = r[1]
		u.desc = r[2]
		u.max_level = r[3]
		u.base_cost = r[4]
		u.growth = r[5]
		u.level_req = r[6]
		out[u.id] = u
	return out


## Which location id unlocks a water type.
static func location_for_water(water: String) -> String:
	match water:
		"shore": return "cove"
		"lake", "river": return "mirror_lake"
		"ocean": return "open_sea"
		"swamp": return "mangrove"
		"arctic": return "frostfin"
		"deep": return "abyss"
	return "cove"
