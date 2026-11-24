class_name Kitchen
extends RefCounted
## Cooking stations. One slot per unlocked station type (grill, pot, prep, oven).
## Slot: {"station": id, "job": {} | {"recipe","start","end","val","fish"}}

const STATIONS := {
	"grill": {"name": "Grill", "cost": 0, "level": 1},
	"prep": {"name": "Prep Table", "cost": 0, "level": 1},
	"pot": {"name": "Stew Pot", "cost": 400, "level": 3},
	"oven": {"name": "Oven", "cost": 1500, "level": 6},
}


static func ensure_slots() -> void:
	for st in Game.unlocked_stations:
		var found := false
		for s in Game.kitchen:
			if s.get("station") == st:
				found = true
				break
		if not found:
			Game.kitchen.append({"station": st, "job": {}})


static func slot_for(station: String) -> int:
	for i in Game.kitchen.size():
		if Game.kitchen[i].get("station") == station:
			return i
	return -1


static func time_mult() -> float:
	return pow(0.9, Game.upgrade_level("kitchen_speed"))


static func fish_matches(r: DataTypes.Recipe, f: Dictionary) -> bool:
	var sp: DataTypes.FishSpecies = Data.fish.get(f.get("sp", ""))
	if sp == null or sp.rarity < r.min_rarity:
		return false
	match r.fish_filter:
		"fresh": return not sp.is_salt()
		"salt": return sp.is_salt()
	return true


static func matching_fish(r: DataTypes.Recipe) -> Array:
	var out: Array = []
	for f in Game.fish:
		if fish_matches(r, f):
			out.append(f)
	out.sort_custom(func(x, y): return FishLogic.fish_value(x) < FishLogic.fish_value(y))
	return out


static func missing_ingredients(r: DataTypes.Recipe) -> Dictionary:
	var miss := {}
	for id in r.ingredients:
		var need := int(r.ingredients[id])
		var have := int(Game.ingredients.get(id, 0))
		if have < need:
			miss[id] = need - have
	return miss


static func is_busy(slot: int) -> bool:
	return slot >= 0 and not (Game.kitchen[slot].get("job", {}) as Dictionary).is_empty()


static func job_done(slot: int) -> bool:
	if not is_busy(slot):
		return false
	return float(Game.kitchen[slot]["job"]["end"]) <= Util.now()


static func time_left(slot: int) -> float:
	if not is_busy(slot):
		return 0.0
	return maxf(0.0, float(Game.kitchen[slot]["job"]["end"]) - Util.now())


## Returns "" on success or an error message.
static func start(recipe_id: String, fish_uid: int) -> String:
	var r: DataTypes.Recipe = Data.recipes.get(recipe_id)
	if r == null:
		return "Unknown recipe."
	var slot := slot_for(r.station)
	if slot < 0:
		return "You don't own a %s yet." % STATIONS[r.station]["name"]
	if is_busy(slot):
		return "The %s is busy." % STATIONS[r.station]["name"]
	var f := Game.find_fish(fish_uid)
	if f.is_empty() or not fish_matches(r, f):
		return "That fish doesn't fit this recipe."
	if not missing_ingredients(r).is_empty():
		return "You are missing ingredients."
	for id in r.ingredients:
		Game.ingredients[id] = int(Game.ingredients.get(id, 0)) - int(r.ingredients[id])
		if Game.ingredients[id] <= 0:
			Game.ingredients.erase(id)
	var value := FishLogic.fish_value(f)
	var name := FishLogic.display_name(f)
	Game.remove_fish(fish_uid)
	var t := r.time * time_mult()
	var now := Util.now()
	Game.kitchen[slot]["job"] = {"recipe": recipe_id, "start": now, "end": now + t, "val": value, "fish": name}
	Game.items_changed.emit()
	Game.facilities_changed.emit()
	Sfx.play("cook")
	return ""


static func collect(slot: int) -> String:
	if not job_done(slot):
		return "Not ready yet."
	var job: Dictionary = Game.kitchen[slot]["job"]
	var r: DataTypes.Recipe = Data.recipes[job["recipe"]]
	var value := r.base_value + int(round(float(job["val"]) * r.fish_mult))
	var list: Array = Game.dishes.get(r.id, [])
	list.append(value)
	Game.dishes[r.id] = list
	Game.kitchen[slot]["job"] = {}
	Game.stats["cooked"] = int(Game.stats.get("cooked", 0)) + 1
	Game.add_xp(10 + r.base_value / 10)
	Game.items_changed.emit()
	Game.facilities_changed.emit()
	Game.notify.emit("%s is ready!" % r.name, "good")
	Sfx.play("catch")
	return ""


static func tick() -> void:
	for i in Game.kitchen.size():
		var job: Dictionary = Game.kitchen[i].get("job", {})
		if not job.is_empty() and float(job["end"]) <= Util.now() and not job.get("told", false):
			job["told"] = true
			Game.notify.emit("%s is ready to collect at the kitchen." % Data.recipes[job["recipe"]].name, "good")
			Game.facilities_changed.emit()


static func eat(recipe_id: String) -> String:
	var list: Array = Game.dishes.get(recipe_id, [])
	if list.is_empty():
		return "You don't have that dish."
	var r: DataTypes.Recipe = Data.recipes[recipe_id]
	list.pop_back()
	if list.is_empty():
		Game.dishes.erase(recipe_id)
	for stat in r.buff:
		Game.add_buff(stat, float(r.buff[stat]), r.buff_time)
	Game.items_changed.emit()
	Game.notify.emit("Yum! %s" % buff_text(r), "good")
	Sfx.play("coin")
	return ""


static func buff_text(r: DataTypes.Recipe) -> String:
	if r.buff.is_empty():
		return "Tasty, but no special effect."
	var parts: Array[String] = []
	for stat in r.buff:
		parts.append("+%d%% %s" % [int(round(float(r.buff[stat]) * 100.0)), stat])
	return ", ".join(parts) + " for " + Util.duration(r.buff_time)


static func sell_dishes(recipe_id: String, count: int = -1) -> int:
	var list: Array = Game.dishes.get(recipe_id, [])
	if list.is_empty():
		return 0
	var n := list.size() if count < 0 else mini(count, list.size())
	var total := 0
	for i in n:
		total += int(list.pop_back())
	if list.is_empty():
		Game.dishes.erase(recipe_id)
	Game.add_money(total)
	Game.add_xp(total / 25)
	Game.stats["sold"] = int(Game.stats.get("sold", 0)) + n
	Game.items_changed.emit()
	Sfx.play("coin")
	return total


static func buy_station(station: String) -> String:
	var st: Dictionary = STATIONS.get(station, {})
	if st.is_empty() or Game.unlocked_stations.has(station):
		return "Already owned."
	if Game.level < int(st["level"]):
		return "Requires level %d." % int(st["level"])
	if not Game.spend(int(st["cost"])):
		return "Not enough money."
	Game.unlocked_stations.append(station)
	ensure_slots()
	Game.facilities_changed.emit()
	Sfx.play("level_up")
	return ""
