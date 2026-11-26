class_name WorldDB
extends RefCounted
## Fishing locations (permits) and business upgrades.

static func build_locations() -> Dictionary:
	var rows: Array = [
		["cove", "Driftwood Cove", ["shore"], 1, 0, "Calm shallows around the home village. Free to fish."],
		["mirror_lake", "Mirror Lake & Silverrun River", ["lake", "river"], 3, 150, "Fresh water north of the village."],
		["open_sea", "Open Sea", ["ocean"], 6, 700, "Deep blue water beyond the shallows."],
		["mangrove", "Mangrove Bog", ["swamp"], 9, 1800, "Murky island waters reachable by ferry."],
		["frostfin", "Frostfin Isle", ["arctic"], 13, 5000, "Icy island waters reachable by ferry."],
		["abyss", "Abyss Trench", ["deep"], 18, 16000, "The deepest water. Ferry to the trench platform."],
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
		["backpack", "Bigger Backpack", "+8 fish slots per level.", 10, 80, 1.45, 1],
		["tank_count", "Extra Fish Tank", "Build another tank at the Hatchery.", 5, 400, 1.9, 4],
		["tank_tech", "Tank Technology", "Tanks hold more fish and breed & grow faster.", 5, 600, 1.8, 5],
		["market_stalls", "Market Stall", "More customers can queue at once.", 3, 500, 2.1, 3],
		["factory_lines", "Factory Line", "Process more batches at the same time.", 5, 1200, 1.9, 6],
		["factory_batch", "Bigger Batches", "+2 fish per factory batch.", 5, 1000, 1.8, 6],
		["factory_speed", "Faster Machinery", "Factory lines run 12% faster per level.", 5, 1500, 1.8, 7],
		["warehouse", "Warehouse", "Larger storage for products and assistant catches.", 8, 300, 1.5, 3],
		["kitchen_speed", "Pro Kitchen", "Cooking is 10% faster per level.", 5, 450, 1.7, 4],
		["assistants", "Hire Assistant Angler", "Assistants fish for you and fill the dock crate.", 5, 700, 1.9, 5],
		["assistant_skill", "Assistant Training", "Assistants catch faster and better fish.", 5, 1200, 1.8, 7],
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
