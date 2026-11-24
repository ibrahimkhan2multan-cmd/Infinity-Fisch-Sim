class_name Hatchery
extends RefCounted
## Fish tanks, feeding, breeding and growth.
##
## Tank dictionary: {"id", "feed", "fish": [fish dicts], "breed": {} | {"a","b","prog","need"}, "last"}
## Tank fish dictionaries gain "stage": "adult" | "fry" and, for fry, "gp" (growth progress, seconds).
## Progress runs off real timestamps, so tanks keep working while the app is closed
## (capped at MAX_OFFLINE seconds) - but only while the tank still has feed.

const MAX_FEED := 100.0
const MAX_OFFLINE := 43200.0  ## 12 h
const FARM_VALUE_MULT := 0.8  ## bred fish sell a little cheaper than wild ones


static func tank_count() -> int:
	return 1 + Game.upgrade_level("tank_count")


static func tank_capacity() -> int:
	return 4 + 2 * Game.upgrade_level("tank_tech")


static func speed_mult() -> float:
	return 1.0 + 0.3 * Game.upgrade_level("tank_tech")


static func ensure_tanks() -> void:
	while Game.tanks.size() < tank_count():
		Game.tanks.append({"id": Game.tanks.size() + 1, "feed": 0.0, "fish": [], "breed": {}, "last": Util.now()})


static func drain_rate(tank: Dictionary) -> float:
	var n := (tank["fish"] as Array).size()
	if n == 0:
		return 0.0
	return 0.10 + 0.03 * n


static func tick(_dt: float = 0.0) -> void:
	var now := Util.now()
	for i in Game.tanks.size():
		advance(i, now)


## Brings one tank up to date with `now`.
static func advance(index: int, now: float) -> void:
	var tank: Dictionary = Game.tanks[index]
	var elapsed := clampf(now - float(tank.get("last", now)), 0.0, MAX_OFFLINE)
	tank["last"] = now
	if elapsed <= 0.0:
		return
	var fish_list: Array = tank["fish"]
	var drain := drain_rate(tank)
	if drain <= 0.0:
		return
	var feed := float(tank.get("feed", 0.0))
	var eff := minf(elapsed, feed / drain)
	if eff <= 0.0:
		return
	tank["feed"] = maxf(0.0, feed - eff * drain)
	var mult := speed_mult()
	# growth
	for f: Dictionary in fish_list:
		if f.get("stage", "adult") == "fry":
			var sp: DataTypes.FishSpecies = Data.fish.get(f["sp"])
			var g: Dictionary = f.get("g", {})
			f["gp"] = float(f.get("gp", 0.0)) + eff * mult * float(g.get("grow", 1.0))
			if sp and float(f["gp"]) >= sp.grow_time:
				f["stage"] = "adult"
				f["w"] = adult_weight(sp, g, f.get("mut", ""))
				f.erase("gp")
				Game.notify.emit("%s grew up in tank %d!" % [FishLogic.display_name(f), int(tank["id"])], "good")
	# breeding
	var br: Dictionary = tank.get("breed", {})
	if not br.is_empty():
		br["prog"] = float(br.get("prog", 0.0)) + eff * mult
		if float(br["prog"]) >= float(br["need"]):
			_finish_breeding(tank)
	Game.facilities_changed.emit()


static func adult_weight(sp: DataTypes.FishSpecies, genes: Dictionary, mutation: String) -> float:
	var t := clampf((float(genes.get("size", 1.0)) - 0.5) / 1.1, 0.0, 1.0)
	var w := lerpf(sp.min_w, sp.max_w, t)
	if mutation == "giant":
		w *= 1.5
	return snappedf(w, 0.001)


static func fish_in_tank(tank_index: int, uid: int) -> Dictionary:
	for f in Game.tanks[tank_index]["fish"]:
		if int(f.get("uid", -1)) == uid:
			return f
	return {}


static func free_slots(tank_index: int) -> int:
	return tank_capacity() - (Game.tanks[tank_index]["fish"] as Array).size()


static func compatible(a: Dictionary, b: Dictionary) -> bool:
	if int(a.get("uid", 0)) == int(b.get("uid", 1)):
		return false
	if a.get("stage", "adult") != "adult" or b.get("stage", "adult") != "adult":
		return false
	var sa: DataTypes.FishSpecies = Data.fish.get(a["sp"])
	var sb: DataTypes.FishSpecies = Data.fish.get(b["sp"])
	if sa == null or sb == null:
		return false
	if sa.id == sb.id:
		return true
	# hybrids: same water family and neighbouring rarity
	return sa.waters[0] == sb.waters[0] and absi(sa.rarity - sb.rarity) <= 1


static func add_from_inventory(tank_index: int, uid: int) -> String:
	if free_slots(tank_index) <= 0:
		return "That tank is full."
	var f := Game.remove_fish(uid)
	if f.is_empty():
		return "Fish not found."
	f["stage"] = "adult"
	(Game.tanks[tank_index]["fish"] as Array).append(f)
	Game.facilities_changed.emit()
	return ""


static func harvest(tank_index: int, uid: int) -> String:
	var tank: Dictionary = Game.tanks[tank_index]
	var fish_list: Array = tank["fish"]
	for i in fish_list.size():
		var f: Dictionary = fish_list[i]
		if int(f.get("uid", -1)) != uid:
			continue
		if f.get("stage", "adult") != "adult":
			return "Still growing."
		var br: Dictionary = tank.get("breed", {})
		if not br.is_empty() and (int(br["a"]) == uid or int(br["b"]) == uid):
			return "Currently breeding."
		if not Game.has_space():
			return "Your backpack is full."
		fish_list.remove_at(i)
		f.erase("stage")
		f["farm"] = true
		Game.add_fish(f)
		Game.facilities_changed.emit()
		return ""
	return "Fish not found."


static func add_feed(tank_index: int, source: String) -> String:
	var tank: Dictionary = Game.tanks[tank_index]
	if float(tank["feed"]) >= MAX_FEED - 0.5:
		return "The tank is already full of feed."
	var amount := 0.0
	if source == "pellet":
		if Game.feed_pellets <= 0:
			return "No feed pellets - buy some at the General Store."
		Game.feed_pellets -= 1
		amount = Game.FEED_PER_PELLET
	else:
		var p: DataTypes.Product = Data.products.get(source)
		if p == null or p.feed_value <= 0.0 or Game.product_count(source) <= 0:
			return "None of that in stock."
		Game.take_product(source, 1)
		amount = p.feed_value
	# bring the tank up to date first so feed isn't "retroactively" burned
	advance(tank_index, Util.now())
	tank["feed"] = minf(MAX_FEED, float(tank["feed"]) + amount)
	Game.items_changed.emit()
	Game.facilities_changed.emit()
	return ""


static func start_breeding(tank_index: int, uid_a: int, uid_b: int) -> String:
	advance(tank_index, Util.now())
	var tank: Dictionary = Game.tanks[tank_index]
	if not (tank.get("breed", {}) as Dictionary).is_empty():
		return "This tank is already breeding."
	var a := fish_in_tank(tank_index, uid_a)
	var b := fish_in_tank(tank_index, uid_b)
	if a.is_empty() or b.is_empty():
		return "Pick two fish from this tank."
	if not compatible(a, b):
		return "Those fish are not compatible. Use the same species, or neighbouring rarities from the same waters."
	if float(tank["feed"]) < 5.0:
		return "Add feed first - the fish are too hungry to breed."
	if free_slots(tank_index) < 1:
		return "No room for offspring - harvest or make space."
	var sa: DataTypes.FishSpecies = Data.fish[a["sp"]]
	var sb: DataTypes.FishSpecies = Data.fish[b["sp"]]
	var fert := (float(a["g"].get("fert", 1.0)) + float(b["g"].get("fert", 1.0))) * 0.5
	var need := (60.0 + 45.0 * (sa.rarity + sb.rarity) * 0.5) / clampf(fert, 0.5, 1.5)
	tank["breed"] = {"a": uid_a, "b": uid_b, "prog": 0.0, "need": need}
	Game.facilities_changed.emit()
	return ""


static func breed_time_left(tank: Dictionary) -> float:
	var br: Dictionary = tank.get("breed", {})
	if br.is_empty():
		return 0.0
	return maxf(0.0, (float(br["need"]) - float(br["prog"])) / speed_mult())


static func _finish_breeding(tank: Dictionary) -> void:
	var br: Dictionary = tank["breed"]
	tank["breed"] = {}
	var fish_list: Array = tank["fish"]
	var a: Dictionary = {}
	var b: Dictionary = {}
	for f: Dictionary in fish_list:
		if int(f["uid"]) == int(br["a"]):
			a = f
		elif int(f["uid"]) == int(br["b"]):
			b = f
	if a.is_empty() or b.is_empty():
		return
	var sa: DataTypes.FishSpecies = Data.fish[a["sp"]]
	var sb: DataTypes.FishSpecies = Data.fish[b["sp"]]
	var free := tank_capacity() - fish_list.size()
	var fert := ((sa.fertility + sb.fertility) * 0.5) \
		* ((float(a["g"].get("fert", 1.0)) + float(b["g"].get("fert", 1.0))) * 0.5)
	var n := 1
	if randf() < fert:
		n += 1
	if randf() < fert * 0.4:
		n += 1
	n = mini(n, free)
	var rare_found := false
	for i in n:
		var child := make_offspring(a, b)
		if child.is_empty():
			continue
		var csp: DataTypes.FishSpecies = Data.fish[child["sp"]]
		if csp.rarity > maxi(sa.rarity, sb.rarity) or child.get("mut", "") != "":
			rare_found = true
		fish_list.append(child)
		Game.stats["bred"] = int(Game.stats.get("bred", 0)) + 1
	Game.notify.emit("Breeding finished in tank %d: %d new fry%s" % [int(tank["id"]), n,
		" - including a rare one!" if rare_found else "."], "rare" if rare_found else "good")
	Sfx.play("rare" if rare_found else "catch")
	Game.add_xp(8 * n)


## Creates one fry from two adult parents. Public so tests can call it directly.
static func make_offspring(a: Dictionary, b: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var r := rng if rng else RandomNumberGenerator.new()
	if not rng:
		r.randomize()
	var sa: DataTypes.FishSpecies = Data.fish[a["sp"]]
	var sb: DataTypes.FishSpecies = Data.fish[b["sp"]]
	var species: DataTypes.FishSpecies = sa if (sa.id == sb.id or r.randf() < 0.5) else sb
	# Rare "evolution": a neighbouring, rarer species from the same waters.
	var evo_chance := 0.05 + 0.02 * Game.upgrade_level("tank_tech")
	if r.randf() < evo_chance:
		var better: Array = []
		for s: DataTypes.FishSpecies in Data.fish_for_water(species.waters[0]):
			if s.rarity == species.rarity + 1:
				better.append(s)
		if not better.is_empty():
			species = better[r.randi() % better.size()]
	var genes := {}
	for k in ["size", "grow", "fert"]:
		var avg := (float(a["g"].get(k, 1.0)) + float(b["g"].get(k, 1.0))) * 0.5
		genes[k] = clampf(avg + r.randfn(0.0, 0.08), 0.5, 1.6)
	genes["hue"] = clampf((float(a["g"].get("hue", 0.0)) + float(b["g"].get("hue", 0.0))) * 0.5
		+ r.randfn(0.0, 0.02), -0.15, 0.15)
	# mutation: sometimes inherited, otherwise a boosted fresh roll
	var mutation := ""
	var parent_mut: String = a.get("mut", "") if a.get("mut", "") != "" else b.get("mut", "")
	if parent_mut != "" and r.randf() < 0.35:
		mutation = parent_mut
	else:
		mutation = FishLogic.roll_mutation(0.5 + 0.3 * Game.upgrade_level("tank_tech"), r)
	var f := FishLogic.make_fish(species.id, 0.0, mutation, genes)
	f["w"] = snappedf(adult_weight(species, genes, mutation) * 0.2, 0.001)
	f["stage"] = "fry"
	f["gp"] = 0.0
	f["farm"] = true
	return f


static func growth_fraction(f: Dictionary) -> float:
	if f.get("stage", "adult") != "fry":
		return 1.0
	var sp: DataTypes.FishSpecies = Data.fish.get(f["sp"])
	return clampf(float(f.get("gp", 0.0)) / maxf(1.0, sp.grow_time), 0.0, 1.0) if sp else 1.0
