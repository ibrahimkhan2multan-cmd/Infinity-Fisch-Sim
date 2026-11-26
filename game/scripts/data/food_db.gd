class_name FoodDB
extends RefCounted
## Ingredients, cooking recipes and factory products.

static func build_ingredients() -> Dictionary:
	var rows: Array = [
		["salt", "Sea Salt", 3, "Seasons everything."],
		["rice", "Sushi Rice", 6, "Short-grain rice."],
		["seaweed", "Nori Seaweed", 8, "Dried seaweed sheets."],
		["potato", "Potatoes", 5, "For chips and chowder."],
		["flour", "Flour", 6, "Batter and pastry."],
		["butter", "Butter", 10, "Rich and creamy."],
		["vegetables", "Fresh Vegetables", 7, "Carrots, leeks and greens."],
		["spices", "Spice Mix", 12, "A warm blend of herbs and spices."],
		["oil", "Cooking Oil", 9, "For frying."],
		["lemon", "Lemons", 6, "A squeeze of sunshine."],
	]
	var out := {}
	for r in rows:
		var i := DataTypes.Ingredient.new()
		i.id = r[0]
		i.name = r[1]
		i.price = r[2]
		i.desc = r[3]
		out[i.id] = i
	return out


static func build_recipes() -> Dictionary:
	var rows: Array = [
		# id, name, station, time, filter, min_rarity, ingredients, base, mult, buff, buff_time, desc
		["grilled_fish", "Grilled Fish", "grill", 25.0, "any", 0, {"salt": 1, "lemon": 1}, 20, 1.5, {}, 0.0,
			"Simple, smoky and delicious."],
		["fish_stew", "Fish Stew", "pot", 40.0, "any", 0, {"vegetables": 2, "spices": 1, "salt": 1}, 35, 1.7,
			{"control": 0.08}, 300.0, "Warming stew. Steadies your hands: +reel control."],
		["fish_and_chips", "Fish & Chips", "grill", 45.0, "any", 0, {"potato": 2, "flour": 1, "oil": 1, "salt": 1}, 40, 1.8,
			{"lure": 0.20}, 300.0, "Crispy and golden. Fish bite faster."],
		["sushi_roll", "Sushi Roll", "prep", 35.0, "salt", 1, {"rice": 2, "seaweed": 1}, 50, 2.0,
			{"luck": 0.25}, 300.0, "Needs an uncommon+ sea fish. Boosts luck."],
		["fish_pie", "Fish Pie", "oven", 60.0, "fresh", 0, {"flour": 2, "butter": 1, "vegetables": 1}, 60, 1.9,
			{"resilience": 0.12}, 300.0, "Freshwater fish baked in pastry. Boosts resilience."],
		["seafood_chowder", "Seafood Chowder", "pot", 55.0, "salt", 0, {"potato": 1, "butter": 1, "spices": 1, "vegetables": 1}, 80, 2.0,
			{"luck": 0.30, "resilience": 0.05}, 300.0, "Creamy chowder from sea fish."],
		["smoked_platter", "Smoked Fish Platter", "grill", 70.0, "any", 2, {"spices": 2, "salt": 1}, 120, 2.2,
			{"luck": 0.40}, 420.0, "Needs a rare+ fish. Smoky luck boost."],
		["royal_feast", "Royal Fish Feast", "oven", 120.0, "any", 3, {"butter": 2, "spices": 2, "lemon": 1, "vegetables": 2}, 400, 2.6,
			{"luck": 0.50, "lure": 0.30, "control": 0.10}, 600.0, "Epic+ fish only. A feast fit for a king."],
	]
	var out := {}
	for r in rows:
		var rc := DataTypes.Recipe.new()
		rc.id = r[0]
		rc.name = r[1]
		rc.station = r[2]
		rc.time = r[3]
		rc.fish_filter = r[4]
		rc.min_rarity = r[5]
		rc.ingredients = r[6]
		rc.base_value = r[7]
		rc.fish_mult = r[8]
		rc.buff = r[9]
		rc.buff_time = r[10]
		rc.desc = r[11]
		out[rc.id] = rc
	return out


static func build_products() -> Dictionary:
	var rows: Array = [
		# id, name, mult, time, unlock, feed_value, desc
		["fillet", "Fish Fillets", 1.20, 20.0, 0, 0.0, "Cleaned, boneless fillets."],
		["fishmeal", "Fishmeal", 0.35, 15.0, 0, 45.0, "Ground fish. Great tank feed."],
		["fish_oil", "Fish Oil", 0.55, 15.0, 500, 0.0, "Pressed oil, sold to wholesalers."],
		["smoked", "Smoked Fish", 1.55, 45.0, 2500, 0.0, "Slow-smoked in the factory kiln."],
		["canned", "Canned Fish", 1.90, 40.0, 8000, 0.0, "Sealed tins with a long shelf life."],
	]
	var out := {}
	for r in rows:
		var p := DataTypes.Product.new()
		p.id = r[0]
		p.name = r[1]
		p.mult = r[2]
		p.time = r[3]
		p.unlock_cost = r[4]
		p.feed_value = r[5]
		p.desc = r[6]
		out[p.id] = p
	return out
