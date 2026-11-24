class_name FishDB
extends RefCounted
## All 50 fish species. Compact table -> FishSpecies objects.
## Columns: id, name, rarity, waters, price, min_kg, max_kg, difficulty,
##          active, weather, colour1, colour2, shape, description

const _ROWS: Array = [
	# ---- Shallows (shore, salt) ----
	["sand_dab", "Sand Dab", 0, ["shore"], 9, 0.2, 0.8, 0.12, "any", "any", "c9b27a", "8c7650", 3, "Flat and sandy, hides on the seabed."],
	["silver_sprat", "Silver Sprat", 0, ["shore"], 6, 0.05, 0.2, 0.10, "any", "any", "cfd8e6", "9aa8bd", 0, "Tiny shoaling fish that glitters in the sun."],
	["striped_mullet", "Striped Mullet", 0, ["shore"], 14, 0.5, 2.2, 0.2, "any", "any", "a3b3b8", "5d6f75", 0, "A coastal grazer with bold dark stripes."],
	["sea_bream", "Sea Bream", 1, ["shore"], 42, 1.0, 3.5, 0.30, "any", "any", "e68c99", "b85563", 1, "A rosy, round-bodied favourite of local cooks."],
	["red_snapper", "Red Snapper", 2, ["shore"], 130, 2.0, 9.0, 0.45, "any", "rain", "d93a3a", "8c1f1f", 0, "Bites hardest when the rain rolls in."],
	["pearl_seahorse", "Pearl Seahorse", 3, ["shore"], 520, 0.1, 0.35, 0.60, "night", "any", "f4e9f5", "c9a8d6", 2, "Glows softly under the moon in quiet bays."],
	["coral_ghostfish", "Coral Ghostfish", 4, ["shore"], 2400, 2.0, 6.0, 0.75, "night", "clear", "b6f2f2", "6fc4c4", 0, "A translucent legend of the shallows."],
	# ---- Mirror Lake (lake, fresh) ----
	["pond_minnow", "Pond Minnow", 0, ["lake"], 7, 0.02, 0.1, 0.08, "any", "any", "c7d7a0", "86a05a", 0, "The tiniest lake dweller."],
	["bluegill", "Bluegill", 0, ["lake"], 12, 0.2, 0.9, 0.15, "any", "any", "4f86c9", "e9b44c", 1, "Cheeky, round and always hungry."],
	["silver_carp", "Silver Carp", 0, ["lake"], 16, 1.0, 5.0, 0.25, "any", "any", "c9d1d6", "8997a0", 0, "Leaps out of the water when startled."],
	["rainbow_trout", "Rainbow Trout", 1, ["lake"], 48, 0.7, 3.0, 0.32, "any", "any", "f2a6c6", "6cc7a8", 0, "A shimmering stripe runs along its flank."],
	["northern_pike", "Northern Pike", 2, ["lake"], 150, 2.0, 10.0, 0.50, "any", "any", "6f9c4f", "3d5a2c", 2, "A toothy ambush hunter."],
	["golden_koi", "Golden Koi", 3, ["lake"], 620, 1.0, 5.0, 0.60, "day", "clear", "ffc233", "ff8a1f", 0, "Prized for its blazing golden scales."],
	["ghost_sturgeon", "Ghost Sturgeon", 4, ["lake"], 2800, 8.0, 40.0, 0.80, "night", "any", "cfd8ee", "8a96b8", 4, "An ancient, pale giant of the deep lake."],
	["dragon_koi", "Moonlit Dragon Koi", 5, ["lake"], 15000, 3.0, 12.0, 0.95, "night", "clear", "7f66ff", "e5d9ff", 2, "Legend says it only surfaces on clear moonlit nights."],
	# ---- Silverrun River (river, fresh) ----
	["river_chub", "River Chub", 0, ["river"], 9, 0.2, 1.0, 0.15, "any", "any", "98a77c", "667555", 0, "Common in every riffle."],
	["river_perch", "River Perch", 0, ["river"], 11, 0.2, 1.2, 0.18, "any", "any", "c9b04a", "6b6e2c", 1, "Striped and feisty."],
	["brown_trout", "Brown Trout", 1, ["river"], 36, 0.5, 3.0, 0.30, "any", "any", "b88a5a", "6e4a2c", 0, "Spotted and wary of shadows."],
	["pink_salmon", "Pink Salmon", 1, ["river"], 55, 2.0, 6.0, 0.40, "day", "any", "ff8a7a", "c9534a", 0, "Runs upstream in the bright daylight."],
	["channel_catfish", "Channel Catfish", 2, ["river"], 140, 3.0, 15.0, 0.50, "night", "any", "6f7a85", "3d454d", 4, "A whiskered night prowler."],
	["electric_eel", "Electric Eel", 3, ["river"], 700, 2.0, 9.0, 0.70, "any", "storm", "4c73e8", "27388f", 2, "Crackles with energy during storms."],
	["emerald_arowana", "Emerald Arowana", 4, ["river"], 3000, 3.0, 10.0, 0.80, "day", "any", "35d98c", "128a55", 0, "A shining green dragon of the river."],
	# ---- Open Sea (ocean, salt) ----
	["atlantic_mackerel", "Atlantic Mackerel", 0, ["ocean"], 18, 0.4, 1.5, 0.25, "any", "any", "4d8fb8", "1f4a63", 0, "Fast, oily and everywhere."],
	["herring", "Herring", 0, ["ocean"], 13, 0.2, 0.7, 0.18, "any", "any", "b9c9d6", "6f8296", 0, "Swims in vast silver shoals."],
	["reef_squid", "Reef Squid", 1, ["ocean"], 60, 0.5, 4.0, 0.35, "night", "any", "e6a0cc", "9a5a86", 1, "Rises to the surface at night."],
	["yellowfin_tuna", "Yellowfin Tuna", 2, ["ocean"], 210, 12.0, 60.0, 0.55, "any", "any", "3a62b0", "e8c93a", 4, "Powerful and fast - a proper fight."],
	["mahi_mahi", "Mahi-Mahi", 2, ["ocean"], 190, 5.0, 20.0, 0.50, "day", "any", "35d97a", "e6d23a", 4, "Dazzling colours under the midday sun."],
	["swordfish", "Swordfish", 3, ["ocean"], 900, 30.0, 120.0, 0.70, "any", "any", "5a6f8c", "2b3a52", 4, "Its bill can slice through nets."],
	["blue_marlin", "Blue Marlin", 4, ["ocean"], 4200, 80.0, 250.0, 0.85, "any", "storm", "2455d6", "9ac2ff", 4, "The storm-chaser of the open sea."],
	["tempest_leviathan", "Tempest Leviathan Pup", 5, ["ocean"], 25000, 300.0, 600.0, 0.98, "any", "storm", "3f4d8c", "b9d4ff", 4, "A baby sea-giant born of thunderstorms."],
	# ---- Mangrove Bog (swamp, salt/brackish) ----
	["mudskipper", "Mudskipper", 0, ["swamp"], 10, 0.05, 0.3, 0.12, "any", "any", "8a8a56", "55552e", 0, "Walks on mud with its fins."],
	["mangrove_jack", "Mangrove Jack", 0, ["swamp"], 17, 0.5, 3.0, 0.22, "any", "any", "c4684a", "7a3a2a", 0, "Lurks among tangled roots."],
	["snakehead", "Snakehead", 1, ["swamp"], 50, 1.0, 6.0, 0.38, "any", "any", "6c7a3a", "3d4620", 2, "Can breathe air for short spells."],
	["alligator_gar", "Alligator Gar", 2, ["swamp"], 170, 5.0, 40.0, 0.55, "any", "rain", "7f8f4a", "4a5530", 2, "Armoured like a crocodile."],
	["ghost_frogfish", "Ghost Frogfish", 3, ["swamp"], 650, 0.5, 3.0, 0.65, "night", "fog", "d6e68a", "8a9c3c", 1, "Vanishes into the swamp mist."],
	["bog_dragon_eel", "Bog Dragon Eel", 4, ["swamp"], 3300, 5.0, 30.0, 0.82, "night", "rain", "58e068", "1f7a38", 2, "A glowing serpent of the rainy marsh."],
	["mire_warden", "Mire Warden", 5, ["swamp"], 18000, 40.0, 160.0, 0.96, "night", "fog", "3a7a45", "c9ff9a", 4, "Guardian of the bog. Seen by almost no-one."],
	# ---- Frostfin Waters (arctic) ----
	["arctic_char", "Arctic Char", 0, ["arctic"], 20, 0.4, 2.0, 0.25, "any", "any", "a8d6e8", "e8774a", 0, "Hardy and cold-loving."],
	["ice_cod", "Ice Cod", 0, ["arctic"], 22, 1.0, 6.0, 0.28, "any", "any", "d8e6ee", "8ea6b4", 0, "A pale cod from beneath the ice."],
	["frost_salmon", "Frost Salmon", 1, ["arctic"], 70, 2.0, 8.0, 0.40, "any", "any", "9ad0f0", "4a86c0", 0, "Ice-blue scales, ice-cold flesh."],
	["glacier_trout", "Glacier Trout", 2, ["arctic"], 240, 2.0, 10.0, 0.55, "day", "any", "cfeeff", "5aa3d6", 0, "Only bites in the pale daylight."],
	["ice_anglerfish", "Ice Anglerfish", 3, ["arctic"], 1000, 2.0, 12.0, 0.70, "night", "any", "7ad0ff", "2a5a8c", 1, "Lures prey with a frozen glow."],
	["crystal_icefish", "Crystal Icefish", 4, ["arctic"], 4800, 1.0, 5.0, 0.85, "any", "clear", "e6fbff", "9ad6f0", 0, "Nearly invisible, like living glass."],
	["aurora_whalepup", "Aurora Whale Pup", 5, ["arctic"], 30000, 200.0, 500.0, 0.98, "night", "clear", "5affc8", "9a6aff", 4, "Rippling like the northern lights."],
	# ---- Abyss Trench (deep) ----
	["lanternfish", "Lanternfish", 0, ["deep"], 40, 0.05, 0.4, 0.30, "any", "any", "3a5a8c", "7ad9ff", 0, "Thousands of tiny lights."],
	["viperfish", "Viperfish", 1, ["deep"], 130, 0.3, 2.0, 0.45, "any", "any", "3a4a5a", "7aa0b8", 2, "Fangs too big for its mouth."],
	["gulper_eel", "Gulper Eel", 2, ["deep"], 420, 1.0, 8.0, 0.60, "any", "any", "2a2a3a", "6a3a5a", 2, "A mouth like an umbrella."],
	["fangtooth", "Fangtooth", 3, ["deep"], 1600, 0.5, 5.0, 0.75, "any", "any", "2a3040", "9a8a6a", 1, "The most fearsome face in the trench."],
	["giant_squid", "Giant Squid", 4, ["deep"], 7000, 50.0, 250.0, 0.90, "night", "any", "a8386a", "e8a0c0", 1, "Eyes the size of dinner plates."],
	["abyssal_leviathan", "Abyssal Leviathan", 5, ["deep"], 60000, 400.0, 900.0, 0.99, "any", "storm", "1a1a3a", "ff4d6d", 4, "Mythic. Rumoured to guard the bottom of the world."],
]

const _GROW_TIME: Array[float] = [120.0, 180.0, 300.0, 480.0, 720.0, 1200.0]
const _FERTILITY: Array[float] = [0.90, 0.75, 0.55, 0.40, 0.25, 0.12]


static func build() -> Dictionary:
	var out := {}
	for row in _ROWS:
		var f := DataTypes.FishSpecies.new()
		f.id = row[0]
		f.name = row[1]
		f.rarity = row[2]
		var waters: Array[String] = []
		for w in row[3]:
			waters.append(str(w))
		f.waters = waters
		f.price = row[4]
		f.min_w = row[5]
		f.max_w = row[6]
		f.difficulty = row[7]
		f.active = row[8]
		f.weather = row[9]
		f.c1 = Color(row[10])
		f.c2 = Color(row[11])
		f.shape = row[12]
		f.desc = row[13]
		f.grow_time = _GROW_TIME[f.rarity]
		f.fertility = _FERTILITY[f.rarity]
		out[f.id] = f
	return out
