class_name Economy
extends RefCounted
## Market: demand, customer orders and quick selling.
##
## Order: {"id","name","kind":"species"|"rarity"|"water"|"dish","target": String|int,
##         "mult": float, "expires": unix}

const NAMES: Array[String] = ["Maya", "Omar", "Lena", "Kofi", "Rosa", "Ibrahim", "Yuki", "Tariq",
	"Sofia", "Diego", "Aisha", "Bjorn", "Priya", "Hana", "Leo", "Nadia", "Marco", "Zara"]

static var _spawn_timer := 6.0
static var _order_counter := 0


static func demand(species_id: String) -> float:
	return 0.75 + 0.6 * Util.hash01(Util.str_hash(species_id) * 17 + Clock.day * 7919)


static func stall_count() -> int:
	return 1 + Game.upgrade_level("market_stalls")


static func sell_price(f: Dictionary) -> int:
	return int(round(FishLogic.fish_value(f) * demand(f.get("sp", ""))))


## Sells one fish at the stall. Returns the payment (0 if it failed).
static func sell_fish(uid: int) -> int:
	var f := Game.find_fish(uid)
	if f.is_empty():
		return 0
	var pay := sell_price(f)
	Game.remove_fish(uid)
	_after_sale(f, pay)
	return pay


static func sell_all(max_rarity: int = 5, skip_favorites := true) -> int:
	var total := 0
	var to_sell: Array = []
	for f in Game.fish:
		var sp: DataTypes.FishSpecies = Data.fish.get(f["sp"])
		if sp == null or sp.rarity > max_rarity:
			continue
		if skip_favorites and f.get("fav", false):
			continue
		to_sell.append(f)
	for f in to_sell:
		total += sell_fish(int(f["uid"]))
	return total


static func _after_sale(f: Dictionary, pay: int) -> void:
	Game.add_money(pay)
	Game.stats["sold"] = int(Game.stats.get("sold", 0)) + 1
	var sp: DataTypes.FishSpecies = Data.fish.get(f.get("sp", ""))
	Game.add_xp(maxi(1, pay / 25) + (sp.rarity * 2 if sp else 0))
	Sfx.play("coin")


# ---- Customers ------------------------------------------------------------------

static func tick(dt: float) -> void:
	var changed := false
	var now := Util.now()
	for i in range(Game.orders.size() - 1, -1, -1):
		if float(Game.orders[i].get("expires", 0.0)) < now:
			Game.orders.remove_at(i)
			changed = true
	while Game.orders.size() > stall_count():
		Game.orders.pop_back()
		changed = true
	if Game.orders.size() < stall_count():
		_spawn_timer -= dt
		if _spawn_timer <= 0.0:
			var o := generate_order()
			if not o.is_empty():
				Game.orders.append(o)
				changed = true
				Game.notify.emit("%s is at the market with an order." % o["name"], "info")
			_spawn_timer = randf_range(25.0, 60.0) / (1.0 + 0.2 * Game.upgrade_level("market_stalls"))
	if changed:
		Game.facilities_changed.emit()


static func _accessible_waters() -> Array:
	var out: Array = []
	for w in Data.water_types():
		if Game.has_water_access(w):
			out.append(w)
	return out


static func generate_order(rng: RandomNumberGenerator = null) -> Dictionary:
	var r := rng if rng else RandomNumberGenerator.new()
	if not rng:
		r.randomize()
	_order_counter += 1
	var max_rarity := mini(4, 1 + Game.level / 5)
	var o := {
		"id": _order_counter * 1000 + r.randi() % 1000,
		"name": NAMES[r.randi() % NAMES.size()],
		"mult": snappedf(r.randf_range(1.3, 2.0), 0.05),
		"expires": Util.now() + r.randf_range(240.0, 420.0),
	}
	var roll := r.randf()
	if roll < 0.40:
		var waters := _accessible_waters()
		var pool: Array = []
		for w in waters:
			for sp: DataTypes.FishSpecies in Data.fish_for_water(w):
				if sp.rarity <= max_rarity:
					pool.append(sp)
		if pool.is_empty():
			return {}
		o["kind"] = "species"
		o["target"] = (pool[r.randi() % pool.size()] as DataTypes.FishSpecies).id
	elif roll < 0.65:
		o["kind"] = "rarity"
		o["target"] = r.randi_range(0, max_rarity)
	elif roll < 0.85:
		o["kind"] = "water"
		o["target"] = ["fresh", "salt"][r.randi() % 2]
	else:
		var recipes: Array = []
		for id in Data.recipes:
			var rc: DataTypes.Recipe = Data.recipes[id]
			if Game.unlocked_stations.has(rc.station) and rc.min_rarity <= max_rarity:
				recipes.append(id)
		if recipes.is_empty():
			return {}
		o["kind"] = "dish"
		o["target"] = recipes[r.randi() % recipes.size()]
		o["mult"] = snappedf(r.randf_range(1.8, 2.6), 0.05)
	return o


static func order_text(o: Dictionary) -> String:
	match o.get("kind"):
		"species":
			var sp: DataTypes.FishSpecies = Data.fish.get(o["target"])
			return "Wants a %s" % (sp.name if sp else "fish")
		"rarity":
			return "Wants any %s fish" % Util.rarity_name(int(o["target"]))
		"water":
			return "Wants any %swater fish" % ("fresh" if o["target"] == "fresh" else "salt")
		"dish":
			var rc: DataTypes.Recipe = Data.recipes.get(o["target"])
			return "Wants %s" % (rc.name if rc else "a dish")
	return "Wants fish"


static func order_matches_fish(o: Dictionary, f: Dictionary) -> bool:
	if f.get("stage", "adult") != "adult":
		return false
	var sp: DataTypes.FishSpecies = Data.fish.get(f.get("sp", ""))
	if sp == null:
		return false
	match o.get("kind"):
		"species": return sp.id == o["target"]
		"rarity": return sp.rarity == int(o["target"])
		"water": return sp.is_salt() == (o["target"] == "salt")
	return false


static func find_order(id: int) -> int:
	for i in Game.orders.size():
		if int(Game.orders[i]["id"]) == id:
			return i
	return -1


static func fulfill_with_fish(order_id: int, uid: int) -> int:
	var idx := find_order(order_id)
	if idx < 0:
		return 0
	var o: Dictionary = Game.orders[idx]
	var f := Game.find_fish(uid)
	if f.is_empty() or not order_matches_fish(o, f):
		return 0
	var pay := int(round(FishLogic.fish_value(f) * float(o["mult"])))
	Game.remove_fish(uid)
	Game.orders.remove_at(idx)
	_after_sale(f, pay)
	Game.add_xp(10)
	Game.notify.emit("%s paid %s." % [o["name"], Util.money(pay)], "good")
	Game.facilities_changed.emit()
	return pay


static func fulfill_with_dish(order_id: int, recipe_id: String) -> int:
	var idx := find_order(order_id)
	if idx < 0:
		return 0
	var o: Dictionary = Game.orders[idx]
	if o.get("kind") != "dish" or o["target"] != recipe_id:
		return 0
	var list: Array = Game.dishes.get(recipe_id, [])
	if list.is_empty():
		return 0
	var pay := int(round(float(list.pop_back()) * float(o["mult"])))
	if list.is_empty():
		Game.dishes.erase(recipe_id)
	Game.orders.remove_at(idx)
	Game.add_money(pay)
	Game.add_xp(25)
	Game.stats["sold"] = int(Game.stats.get("sold", 0)) + 1
	Game.items_changed.emit()
	Game.facilities_changed.emit()
	Game.notify.emit("%s paid %s for the dish." % [o["name"], Util.money(pay)], "good")
	Sfx.play("coin")
	return pay


static func dismiss(order_id: int) -> void:
	var idx := find_order(order_id)
	if idx >= 0:
		Game.orders.remove_at(idx)
		Game.facilities_changed.emit()
