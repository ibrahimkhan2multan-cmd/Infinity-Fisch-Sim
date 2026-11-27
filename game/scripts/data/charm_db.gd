class_name CharmDB
extends RefCounted
## Lucky charms. Equip up to CHARM_SLOTS at once: each adds Luck (rarer fish and
## mutations) and/or Calm (the fish moves slower in the reel bar, so it is easier
## to keep the bar on it).

const SLOTS := 3
const MAX_CALM := 0.5   ## combined calm is capped so the minigame never becomes trivial

static func build() -> Dictionary:
	var rows: Array = [
		# id, name, price, level, luck, calm, rarity, colour, desc
		["clover", "Four-Leaf Clover", 200, 1, 0.10, 0.00, 0, "5ccf6a", "A pressed lucky clover. Rarer fish take the bait a little more often."],
		["shell", "Seashell Charm", 250, 1, 0.00, 0.08, 0, "f2c9a0", "Hums like the sea. Fish move a little slower in the reel bar."],
		["knot", "Angler's Knot", 600, 3, 0.07, 0.07, 1, "d9c28a", "A sailor's knot: a bit of luck and a bit of calm."],
		["coin", "Lucky Coin", 800, 5, 0.20, 0.00, 1, "ffd23f", "Heads you win. A solid luck boost."],
		["moonstone", "Moonstone", 1000, 6, 0.00, 0.16, 2, "b9c8ff", "Cool and quiet. Fish tire out noticeably slower."],
		["horseshoe", "Golden Horseshoe", 3000, 10, 0.40, 0.00, 3, "ffb43a", "Pure good fortune. Big luck for rare and epic fish."],
		["pearl", "Tide Pearl", 3500, 11, 0.00, 0.26, 3, "9ff0e6", "The tide itself eases the fight. Fish are much slower."],
		["starfall", "Starfall Pendant", 9000, 16, 0.65, 0.00, 4, "ff9dd8", "A fallen star. Legendary fish notice you."],
		["tooth", "Leviathan Tooth", 10000, 17, 0.00, 0.36, 4, "e8e2d2", "Taken from something huge. Even monsters slow down for it."],
		["infinity", "Infinity Charm", 30000, 22, 0.80, 0.25, 5, "ffe066", "Luck without end and a calm sea. The ultimate charm."],
	]
	var out := {}
	for r in rows:
		var c := DataTypes.Charm.new()
		c.id = r[0]
		c.name = r[1]
		c.price = r[2]
		c.level_req = r[3]
		c.luck = r[4]
		c.calm = r[5]
		c.rarity = r[6]
		c.color = Color(r[7])
		c.desc = r[8]
		out[c.id] = c
	return out
