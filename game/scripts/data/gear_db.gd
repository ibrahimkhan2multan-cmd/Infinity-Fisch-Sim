class_name GearDB
extends RefCounted
## Fishing rods and baits.

static func build_rods() -> Dictionary:
	var rows: Array = [
		# id, name, price, level, luck, lure, control, resilience, range, size_bonus, colour, desc
		["twig_rod", "Twig Rod", 0, 1, 0.00, 1.00, 0.30, 0.10, 16.0, 0.00, "8b5a2b", "A bendy stick with string. Everyone starts somewhere."],
		["bamboo_rod", "Bamboo Rod", 250, 2, 0.15, 1.15, 0.37, 0.15, 20.0, 0.03, "c9b46a", "Light, springy and surprisingly good."],
		["fiberglass_rod", "Fiberglass Rod", 900, 4, 0.30, 1.30, 0.44, 0.25, 24.0, 0.06, "3fa7a0", "Dependable all-round rod for serious anglers."],
		["carbon_rod", "Carbon Pro Rod", 3500, 7, 0.60, 1.50, 0.52, 0.35, 28.0, 0.10, "30343b", "Stiff, strong and sensitive. A real step up."],
		["reef_rod", "Reef Hunter", 12000, 10, 0.90, 1.70, 0.58, 0.45, 34.0, 0.14, "ff7a59", "Built to reach the open sea and haul big fish."],
		["frost_rod", "Frost Caster", 35000, 14, 1.30, 1.90, 0.64, 0.55, 38.0, 0.18, "9ad6ff", "Never freezes. Fine control in any water."],
		["abyss_rod", "Abyss Reaper", 100000, 18, 1.80, 2.10, 0.70, 0.65, 42.0, 0.24, "6a3aa8", "Forged for monsters from the trench."],
		["infinity_rod", "Golden Infinity Rod", 400000, 25, 2.50, 2.50, 0.78, 0.80, 48.0, 0.32, "ffcf3a", "The ultimate rod. Legends bite for this one."],
	]
	var out := {}
	for r in rows:
		var rod := DataTypes.Rod.new()
		rod.id = r[0]
		rod.name = r[1]
		rod.price = r[2]
		rod.level_req = r[3]
		rod.luck = r[4]
		rod.lure = r[5]
		rod.control = r[6]
		rod.resilience = r[7]
		rod.cast_range = r[8]
		rod.size_bonus = r[9]
		rod.color = Color(r[10])
		rod.desc = r[11]
		out[rod.id] = rod
	return out


static func build_baits() -> Dictionary:
	var rows: Array = [
		# id, name, price, luck, lure, night_bonus, desc
		["worm", "Earthworm", 5, 0.05, 1.10, 0.0, "Classic. Fish can't resist."],
		["shrimp", "Fresh Shrimp", 15, 0.15, 1.20, 0.0, "A tasty treat for sea and river fish."],
		["glow_lure", "Glow Lure", 40, 0.30, 1.35, 0.35, "Shines in the dark - extra luck at night."],
		["golden_bait", "Golden Bait", 150, 0.80, 1.50, 0.0, "Rare fish go wild for it."],
	]
	var out := {}
	for r in rows:
		var b := DataTypes.Bait.new()
		b.id = r[0]
		b.name = r[1]
		b.price = r[2]
		b.luck = r[3]
		b.lure = r[4]
		b.night_bonus = r[5]
		b.desc = r[6]
		out[b.id] = b
	return out
