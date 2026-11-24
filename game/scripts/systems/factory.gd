class_name Factory
extends RefCounted
## Fish factory: processing lines, warehouse products, wholesale sales and
## supply contracts.
##
## Line:     {"job": {} | {"product","n","val","start","end","told"}}
## Contract: {"id","kind":"fish"|"product","need","filter","min_rarity","product","reward","xp","expires"}

const CONTRACT_SLOTS := 3
## Reference value of one raw fish per rarity, used to price contracts.
const FISH_REF: Array[float] = [14.0, 50.0, 170.0, 650.0, 2800.0, 13000.0]
const PRODUCT_REF := {"fillet": 28.0, "fishmeal": 10.0, "fish_oil": 18.0, "smoked": 60.0, "canned": 85.0}


static func line_count() -> int:
	return 1 + Game.upgrade_level("factory_lines")


static func batch_size() -> int:
	return 2 + 2 * Game.upgrade_level("factory_batch")


static func time_mult() -> float:
	return pow(0.88, Game.upgrade_level("factory_speed"))


static func ensure_lines() -> void:
	while Game.factory_lines.size() < line_count():
		Game.factory_lines.append({"job": {}})


static func is_busy(line: int) -> bool:
	return not (Game.factory_lines[line].get("job", {}) as Dictionary).is_empty()


static func time_left(line: int) -> float:
	if not is_busy(line):
		return 0.0
	return maxf(0.0, float(Game.factory_lines[line]["job"]["end"]) - Util.now())


static func is_done(line: int) -> bool:
	return is_busy(line) and time_left(line) <= 0.0


## Reserve warehouse space for jobs already running so we never overfill it.
static func reserved_units() -> int:
	var t := 0
	for l in Game.factory_lines:
		var job: Dictionary = l.get("job", {})
		if not job.is_empty():
			t += int(job["n"])
	return t


static func start(line: int, product_id: String, fish_uids: Array) -> String:
	ensure_lines()
	if line < 0 or line >= Game.factory_lines.size():
		return "No such line."
	var p: DataTypes.Product = Data.products.get(product_id)
	if p == null or not Game.unlocked_products.has(product_id):
		return "That product isn't unlocked yet."
	if is_busy(line):
		return "This line is busy."
	if fish_uids.is_empty():
		return "Choose some fish to process."
	if fish_uids.size() > batch_size():
		return "Batch limit is %d fish." % batch_size()
	if Game.products_total() + reserved_units() + fish_uids.size() > Game.warehouse_capacity():
		return "Warehouse full - sell or use some products first."
	var fish_list: Array = []
	for uid in fish_uids:
		var f := Game.find_fish(int(uid))
		if f.is_empty():
			return "A selected fish is missing."
		fish_list.append(f)
	var value := 0
	for f in fish_list:
		value += int(round(FishLogic.fish_value(f) * p.mult))
	for f in fish_list:
		Game.remove_fish(int(f["uid"]))
	var now := Util.now()
	Game.factory_lines[line]["job"] = {
		"product": product_id, "n": fish_list.size(), "val": value,
		"start": now, "end": now + p.time * time_mult(),
	}
	Game.facilities_changed.emit()
	Sfx.play("cook")
	return ""


static func tick() -> void:
	ensure_lines()
	for i in Game.factory_lines.size():
		var job: Dictionary = Game.factory_lines[i].get("job", {})
		if job.is_empty() or float(job["end"]) > Util.now():
			continue
		Game.add_product(job["product"], int(job["n"]), int(job["val"]))
		Game.stats["processed"] = int(Game.stats.get("processed", 0)) + int(job["n"])
		Game.add_xp(4 * int(job["n"]))
		Game.notify.emit("Factory finished %d× %s." % [int(job["n"]), Data.products[job["product"]].name], "good")
		Game.factory_lines[i]["job"] = {}
		Game.facilities_changed.emit()
	_maintain_contracts()


static func unlock_product(id: String) -> String:
	var p: DataTypes.Product = Data.products.get(id)
	if p == null or Game.unlocked_products.has(id):
		return "Already unlocked."
	if not Game.spend(p.unlock_cost):
		return "Not enough money."
	Game.unlocked_products.append(id)
	Game.facilities_changed.emit()
	Sfx.play("level_up")
	return ""


## Wholesale price multiplier, changes every in-game day.
static func wholesale_mult(product_id: String) -> float:
	return 0.9 + 0.35 * Util.hash01(Util.str_hash(product_id) * 31 + Clock.day * 104729)


static func sell_product(id: String, qty: int = -1) -> int:
	var have := Game.product_count(id)
	if have <= 0:
		return 0
	var n := have if qty < 0 else mini(qty, have)
	var value := Game.take_product(id, n)
	var pay := int(round(value * wholesale_mult(id)))
	Game.add_money(pay)
	Game.add_xp(maxi(1, pay / 30))
	Game.stats["sold"] = int(Game.stats.get("sold", 0)) + n
	Sfx.play("coin")
	return pay


# ---- Contracts --------------------------------------------------------------

static var _contract_id := 1


static func _maintain_contracts() -> void:
	var day := Clock.day
	var changed := false
	for i in range(Game.contracts.size() - 1, -1, -1):
		if int(Game.contracts[i].get("expires", 0)) < day:
			Game.contracts.remove_at(i)
			changed = true
	while Game.contracts.size() < CONTRACT_SLOTS:
		Game.contracts.append(generate_contract())
		changed = true
	if changed:
		Game.facilities_changed.emit()


static func generate_contract(rng: RandomNumberGenerator = null) -> Dictionary:
	var r := rng if rng else RandomNumberGenerator.new()
	if not rng:
		r.randomize()
	_contract_id += 1
	var c := {"id": int(Time.get_ticks_usec() % 1000000) + _contract_id, "expires": Clock.day + 2 + r.randi() % 3}
	var make_product := Game.level >= 5 and r.randf() < 0.4
	if make_product:
		var options: Array = []
		for id in Game.unlocked_products:
			if id != "fishmeal":
				options.append(id)
		if options.is_empty():
			make_product = false
		else:
			var pid: String = options[r.randi() % options.size()]
			var need := r.randi_range(3, 10)
			c["kind"] = "product"
			c["product"] = pid
			c["need"] = need
			c["reward"] = int(round(need * float(PRODUCT_REF.get(pid, 20.0)) * r.randf_range(1.4, 1.9) * (1.0 + Game.level * 0.04)))
			c["xp"] = 20 + need * 3
	if not make_product:
		var max_r := mini(3, Game.level / 4)
		var weights: Array = []
		for i in max_r + 1:
			weights.append(float(max_r + 1 - i) * 2.0)
		var rarity := Util.weighted_index(weights, r)
		var filters := ["any", "fresh", "salt"]
		var filter: String = filters[r.randi() % 3]
		var need := maxi(2, int(round(r.randi_range(4, 12) / (1.0 + rarity * 0.7))))
		c["kind"] = "fish"
		c["filter"] = filter
		c["min_rarity"] = rarity
		c["need"] = need
		c["reward"] = int(round(need * FISH_REF[rarity] * r.randf_range(1.5, 1.9)))
		c["xp"] = 20 + need * (4 + rarity * 6)
	return c


static func contract_text(c: Dictionary) -> String:
	if c.get("kind") == "product":
		return "Deliver %d× %s" % [int(c["need"]), Data.products[c["product"]].name]
	var f := ""
	match c.get("filter", "any"):
		"fresh": f = "freshwater "
		"salt": f = "saltwater "
	var rar := ""
	if int(c.get("min_rarity", 0)) > 0:
		rar = " (%s+)" % Util.rarity_name(int(c["min_rarity"]))
	return "Deliver %d× %sfish%s" % [int(c["need"]), f, rar]


static func contract_fish_matches(c: Dictionary, f: Dictionary) -> bool:
	if f.get("stage", "adult") != "adult":
		return false
	var sp: DataTypes.FishSpecies = Data.fish.get(f.get("sp", ""))
	if sp == null or sp.rarity < int(c.get("min_rarity", 0)):
		return false
	match c.get("filter", "any"):
		"fresh": return not sp.is_salt()
		"salt": return sp.is_salt()
	return true


## Fish in the backpack that could be used for the contract, cheapest first
## (favourites are never used automatically).
static func contract_candidates(c: Dictionary) -> Array:
	var out: Array = []
	for f in Game.fish:
		if not f.get("fav", false) and contract_fish_matches(c, f):
			out.append(f)
	out.sort_custom(func(x, y): return FishLogic.fish_value(x) < FishLogic.fish_value(y))
	return out


static func can_deliver(c: Dictionary) -> bool:
	if c.get("kind") == "product":
		return Game.product_count(c["product"]) >= int(c["need"])
	return contract_candidates(c).size() >= int(c["need"])


static func deliver(index: int) -> String:
	if index < 0 or index >= Game.contracts.size():
		return "No such contract."
	var c: Dictionary = Game.contracts[index]
	if not can_deliver(c):
		return "You don't have enough to deliver yet."
	if c.get("kind") == "product":
		Game.take_product(c["product"], int(c["need"]))
	else:
		var cand := contract_candidates(c)
		for i in int(c["need"]):
			Game.remove_fish(int(cand[i]["uid"]))
	Game.add_money(int(c["reward"]))
	Game.add_xp(int(c["xp"]))
	Game.notify.emit("Contract complete! +%s" % Util.money(int(c["reward"])), "good")
	Sfx.play("coin")
	Game.contracts.remove_at(index)
	Game.contracts.append(generate_contract())
	Game.facilities_changed.emit()
	return ""
