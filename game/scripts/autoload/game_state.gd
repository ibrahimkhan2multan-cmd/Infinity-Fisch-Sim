extends Node
## Central player/business state (autoload "Game"). Holds everything that is
## saved, plus signals the UI listens to. Business simulations live in
## scripts/systems/*.gd and operate on this state.

signal money_changed(amount: int)
signal xp_changed
signal level_up(level: int)
signal inventory_changed
signal items_changed
signal equipment_changed
signal collection_changed(species_id: String)
signal permits_changed
signal facilities_changed
signal notify(text: String, kind: String)  # kind: info | good | bad | rare

const BASE_CAPACITY := 20
const MAX_LEVEL := 40
const FEED_PER_PELLET := 30.0

# ---- Persistent state ------------------------------------------------------
var money: int = 60
var xp: int = 0
var level: int = 1
var _uid_counter: int = 1000

var fish: Array = []                 # caught fish dictionaries
var ingredients: Dictionary = {}     # id -> count
var baits: Dictionary = {}           # id -> count
var feed_pellets: int = 0
var dishes: Dictionary = {}          # recipe id -> Array[int] values
var products: Dictionary = {}        # product id -> {"n": int, "v": int}
var crate: Array = []                # fish caught by assistants

var charms_owned: Array = []
var charms_equipped: Array = []
var owned_rods: Array = ["twig_rod"]
var rod: String = "twig_rod"
var bait: String = ""
var upgrades: Dictionary = {}        # upgrade id -> level
var permits: Array = ["cove"]
var unlocked_products: Array = ["fillet", "fishmeal"]
var unlocked_stations: Array = ["grill", "prep"]
var collection: Dictionary = {}      # species id -> {"n","best","muts"}
var buffs: Dictionary = {}           # stat -> {"a": amount, "until": unix}
var flags: Dictionary = {}
var stats: Dictionary = {"caught": 0, "earned": 0, "sold": 0, "cooked": 0, "bred": 0, "processed": 0}

# Facility state (managed by the systems in scripts/systems)
var tanks: Array = []                # see Hatchery
var kitchen: Array = []              # see Kitchen   (one entry per unlocked station)
var factory_lines: Array = []        # see Factory
var contracts: Array = []            # see Factory
var orders: Array = []               # see Economy (market customers)
var last_day_seen: int = 0
var player_pos: Array = []           # [x, y, z] or empty
var play_time: float = 0.0

# ---- Runtime only ------------------------------------------------------------
var in_game := false
var _sys_accum := 0.0
var _assist_accum := 0.0


func _ready() -> void:
	reset_new_game()


func _process(delta: float) -> void:
	if not in_game:
		return
	play_time += delta
	_sys_accum += delta
	if _sys_accum >= 1.0:
		var dt := _sys_accum
		_sys_accum = 0.0
		Hatchery.tick(dt)
		Kitchen.tick()
		Factory.tick()
		Economy.tick(dt)
		Assistants.tick()


# ---- New game / (de)serialisation ------------------------------------------

func reset_new_game() -> void:
	money = 60
	xp = 0
	level = 1
	_uid_counter = 1000
	fish = []
	ingredients = {}
	baits = {"worm": 5}
	feed_pellets = 0
	dishes = {}
	products = {}
	crate = []
	owned_rods = ["twig_rod"]
	charms_owned = []
	charms_equipped = []
	rod = "twig_rod"
	bait = "worm"
	upgrades = {}
	permits = ["cove"]
	unlocked_products = ["fillet", "fishmeal"]
	unlocked_stations = ["grill", "prep"]
	collection = {}
	buffs = {}
	flags = {}
	stats = {"caught": 0, "earned": 0, "sold": 0, "cooked": 0, "bred": 0, "processed": 0}
	tanks = []
	kitchen = []
	factory_lines = []
	contracts = []
	orders = []
	last_day_seen = 0
	player_pos = []
	play_time = 0.0
	Hatchery.ensure_tanks()
	Kitchen.ensure_slots()
	Factory.ensure_lines()


func to_dict() -> Dictionary:
	return {
		"money": money, "xp": xp, "level": level, "uid": _uid_counter,
		"fish": fish, "ingredients": ingredients, "baits": baits, "feed": feed_pellets,
		"dishes": dishes, "products": products, "crate": crate,
		"owned_rods": owned_rods, "rod": rod, "bait": bait,
		"charms_owned": charms_owned, "charms_equipped": charms_equipped,
		"upgrades": upgrades, "permits": permits,
		"unlocked_products": unlocked_products, "unlocked_stations": unlocked_stations,
		"collection": collection, "buffs": buffs, "flags": flags, "stats": stats,
		"tanks": tanks, "kitchen": kitchen, "factory_lines": factory_lines,
		"contracts": contracts, "orders": orders, "last_day_seen": last_day_seen,
		"player_pos": player_pos, "play_time": play_time,
	}


func from_dict(d: Dictionary) -> void:
	reset_new_game()
	money = int(d.get("money", money))
	xp = int(d.get("xp", 0))
	level = int(d.get("level", 1))
	_uid_counter = int(d.get("uid", 1000))
	fish = _arr(d.get("fish"))
	ingredients = _count_dict(d.get("ingredients"))
	baits = _count_dict(d.get("baits"))
	feed_pellets = int(d.get("feed", 0))
	dishes = _dict(d.get("dishes"))
	products = _dict(d.get("products"))
	crate = _arr(d.get("crate"))
	owned_rods = _arr(d.get("owned_rods", ["twig_rod"]))
	if owned_rods.is_empty():
		owned_rods = ["twig_rod"]
	charms_owned = _arr(d.get("charms_owned", [])).filter(func(c): return Data.charms.has(c))
	charms_equipped = _arr(d.get("charms_equipped", [])).filter(func(c): return charms_owned.has(c))
	if charms_equipped.size() > CharmDB.SLOTS:
		charms_equipped = charms_equipped.slice(0, CharmDB.SLOTS)
	rod = str(d.get("rod", "twig_rod"))
	bait = str(d.get("bait", ""))
	upgrades = _count_dict(d.get("upgrades"))
	permits = _arr(d.get("permits", ["cove"]))
	unlocked_products = _arr(d.get("unlocked_products", ["fillet", "fishmeal"]))
	unlocked_stations = _arr(d.get("unlocked_stations", ["grill", "prep"]))
	collection = _dict(d.get("collection"))
	buffs = _dict(d.get("buffs"))
	flags = _dict(d.get("flags"))
	var st := _dict(d.get("stats"))
	for k in st:
		stats[k] = st[k]
	tanks = _arr(d.get("tanks"))
	kitchen = _arr(d.get("kitchen"))
	factory_lines = _arr(d.get("factory_lines"))
	contracts = _arr(d.get("contracts"))
	orders = _arr(d.get("orders"))
	last_day_seen = int(d.get("last_day_seen", 0))
	player_pos = _arr(d.get("player_pos"))
	play_time = float(d.get("play_time", 0.0))
	Hatchery.ensure_tanks()
	Kitchen.ensure_slots()
	Factory.ensure_lines()
	if not Data.rods.has(rod) or not owned_rods.has(rod):
		rod = owned_rods[0]
	# sanity: JSON turns ints into floats
	for f in fish:
		f["uid"] = int(f.get("uid", 0))
	emit_all()


static func _arr(v: Variant) -> Array:
	return (v as Array).duplicate(true) if v is Array else []


static func _dict(v: Variant) -> Dictionary:
	return (v as Dictionary).duplicate(true) if v is Dictionary else {}


static func _count_dict(v: Variant) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k in v:
			out[str(k)] = int(v[k])
	return out


func emit_all() -> void:
	money_changed.emit(money)
	xp_changed.emit()
	inventory_changed.emit()
	items_changed.emit()
	equipment_changed.emit()
	permits_changed.emit()
	facilities_changed.emit()


func next_uid() -> int:
	_uid_counter += 1
	return _uid_counter


# ---- Money / XP / levels -----------------------------------------------------

func add_money(amount: int, count_as_earned := true) -> void:
	money += amount
	if amount > 0 and count_as_earned:
		stats["earned"] = int(stats.get("earned", 0)) + amount
	money_changed.emit(money)


func can_afford(amount: int) -> bool:
	return money >= amount


func spend(amount: int) -> bool:
	if money < amount:
		notify.emit("Not enough money!", "bad")
		Sfx.play("error")
		return false
	money -= amount
	money_changed.emit(money)
	return true


## Levelling is deliberately quick: gentle curve and every XP source counts double.
const XP_GAIN := 2.0

static func xp_needed(lv: int) -> int:
	return int(round(25.0 * pow(float(lv), 1.35)))


func add_xp(amount: int) -> void:
	if level >= MAX_LEVEL:
		return
	xp += maxi(1, int(round(float(amount) * XP_GAIN)))
	while level < MAX_LEVEL and xp >= xp_needed(level):
		xp -= xp_needed(level)
		level += 1
		level_up.emit(level)
		notify.emit("Level up! You are now level %d." % level, "rare")
		Sfx.play("level_up")
	xp_changed.emit()


# ---- Inventory ---------------------------------------------------------------

func capacity() -> int:
	return BASE_CAPACITY + 8 * upgrade_level("backpack")


func warehouse_capacity() -> int:
	return 20 + 15 * upgrade_level("warehouse")


func has_space(n := 1) -> bool:
	return fish.size() + n <= capacity()


func add_fish(f: Dictionary) -> bool:
	if not has_space():
		return false
	fish.append(f)
	inventory_changed.emit()
	return true


func remove_fish(uid: int) -> Dictionary:
	for i in fish.size():
		if int(fish[i].get("uid", -1)) == uid:
			var f: Dictionary = fish[i]
			fish.remove_at(i)
			inventory_changed.emit()
			return f
	return {}


func find_fish(uid: int) -> Dictionary:
	for f in fish:
		if int(f.get("uid", -1)) == uid:
			return f
	return {}


func total_value(list: Array) -> int:
	var t := 0
	for f in list:
		t += FishLogic.fish_value(f)
	return t


# ---- Collection (fish-dex) -------------------------------------------------------

## Registers a catch in the collection. Returns true if the species is new.
func record_catch(f: Dictionary) -> bool:
	var id: String = f.get("sp", "")
	var is_new := not collection.has(id)
	var e: Dictionary = collection.get(id, {"n": 0, "best": 0.0, "muts": {}})
	e["n"] = int(e.get("n", 0)) + 1
	e["best"] = maxf(float(e.get("best", 0.0)), float(f.get("w", 0.0)))
	var m: String = f.get("mut", "")
	if m != "":
		var muts: Dictionary = e.get("muts", {})
		muts[m] = int(muts.get(m, 0)) + 1
		e["muts"] = muts
	collection[id] = e
	stats["caught"] = int(stats.get("caught", 0)) + 1
	collection_changed.emit(id)
	return is_new


func discovered_count() -> int:
	return collection.size()


# ---- Equipment & stats ------------------------------------------------------------

func rod_data() -> DataTypes.Rod:
	return Data.rods.get(rod, Data.rods["twig_rod"])


func bait_data() -> DataTypes.Bait:
	return Data.baits.get(bait)


func buff_amount(stat: String) -> float:
	var b: Dictionary = buffs.get(stat, {})
	if b.is_empty():
		return 0.0
	if float(b.get("until", 0.0)) < Util.now():
		return 0.0
	return float(b.get("a", 0.0))


func buff_time_left(stat: String) -> float:
	var b: Dictionary = buffs.get(stat, {})
	return maxf(0.0, float(b.get("until", 0.0)) - Util.now()) if not b.is_empty() else 0.0


func add_buff(stat: String, amount: float, seconds: float) -> void:
	buffs[stat] = {"a": amount, "until": Util.now() + seconds}
	equipment_changed.emit()


## Effective fishing stats: rod + bait (if one is loaded) + food buffs.
func fishing_stat(stat: String, include_bait := true) -> float:
	var r := rod_data()
	var b := bait_data() if (include_bait and bait != "" and int(baits.get(bait, 0)) > 0) else null
	var v := 0.0
	match stat:
		"luck":
			v = r.luck + (b.luck if b else 0.0)
			if b and FishLogic.is_night(Clock.hour):
				v += b.night_bonus
			v += buff_amount("luck") + charm_total("luck")
		"lure":
			v = r.lure * (b.lure if b else 1.0) + buff_amount("lure")
		"control":
			v = r.control + buff_amount("control")
		"resilience":
			v = r.resilience + buff_amount("resilience")
		"range":
			v = r.cast_range
		"size":
			v = r.size_bonus
		"calm":
			v = minf(CharmDB.MAX_CALM, charm_total("calm"))
	return v


func consume_bait() -> void:
	if bait == "":
		return
	var n := int(baits.get(bait, 0))
	if n <= 0:
		return
	baits[bait] = n - 1
	if baits[bait] <= 0:
		baits.erase(bait)
		notify.emit("You ran out of %s." % Data.baits[bait].name, "info")
		bait = ""
	items_changed.emit()
	equipment_changed.emit()


func buy_rod(id: String) -> bool:
	var r: DataTypes.Rod = Data.rods.get(id)
	if r == null or owned_rods.has(id):
		return false
	if level < r.level_req:
		notify.emit("Requires level %d." % r.level_req, "bad")
		Sfx.play("error")
		return false
	if not spend(r.price):
		return false
	owned_rods.append(id)
	rod = id
	equipment_changed.emit()
	notify.emit("Bought %s!" % r.name, "good")
	Sfx.play("coin")
	return true


## Sum of one stat ("luck" | "calm") over the equipped charms.
func charm_total(stat: String) -> float:
	var v := 0.0
	for id in charms_equipped:
		var c: DataTypes.Charm = Data.charms.get(id)
		if c != null:
			v += c.luck if stat == "luck" else c.calm
	return v


func buy_charm(id: String) -> bool:
	var c: DataTypes.Charm = Data.charms.get(id)
	if c == null or charms_owned.has(id):
		return false
	if level < c.level_req:
		notify.emit("Requires level %d." % c.level_req, "bad")
		Sfx.play("error")
		return false
	if not spend(c.price):
		return false
	charms_owned.append(id)
	# put it straight on if a slot is free
	if charms_equipped.size() < CharmDB.SLOTS:
		charms_equipped.append(id)
	equipment_changed.emit()
	inventory_changed.emit()
	notify.emit("Bought %s!" % c.name, "good")
	Sfx.play("coin")
	return true


## "" on success, otherwise why not.
func equip_charm(id: String) -> String:
	if not charms_owned.has(id):
		return "You do not own that charm."
	if charms_equipped.has(id):
		return ""
	if charms_equipped.size() >= CharmDB.SLOTS:
		return "All %d charm slots are full - take one off first." % CharmDB.SLOTS
	charms_equipped.append(id)
	equipment_changed.emit()
	return ""


func unequip_charm(id: String) -> void:
	if charms_equipped.has(id):
		charms_equipped.erase(id)
		equipment_changed.emit()


func equip_rod(id: String) -> void:
	if owned_rods.has(id):
		rod = id
		equipment_changed.emit()


func buy_bait(id: String, qty: int) -> bool:
	var b: DataTypes.Bait = Data.baits.get(id)
	if b == null or not spend(b.price * qty):
		return false
	baits[id] = int(baits.get(id, 0)) + qty
	if bait == "":
		bait = id
	items_changed.emit()
	equipment_changed.emit()
	Sfx.play("coin")
	return true


func equip_bait(id: String) -> void:
	if id == "" or int(baits.get(id, 0)) > 0:
		bait = id
		equipment_changed.emit()


func buy_ingredient(id: String, qty: int) -> bool:
	var ing: DataTypes.Ingredient = Data.ingredients.get(id)
	if ing == null or not spend(ing.price * qty):
		return false
	ingredients[id] = int(ingredients.get(id, 0)) + qty
	items_changed.emit()
	Sfx.play("coin")
	return true


func buy_feed(qty: int) -> bool:
	if not spend(15 * qty):
		return false
	feed_pellets += qty
	items_changed.emit()
	Sfx.play("coin")
	return true


# ---- Upgrades & permits -----------------------------------------------------------

func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


func upgrade_cost(id: String) -> int:
	var u: DataTypes.Upgrade = Data.upgrades[id]
	return u.cost_at(upgrade_level(id))


func buy_upgrade(id: String) -> bool:
	var u: DataTypes.Upgrade = Data.upgrades.get(id)
	if u == null:
		return false
	var lv := upgrade_level(id)
	if lv >= u.max_level:
		return false
	if level < u.level_req:
		notify.emit("Requires level %d." % u.level_req, "bad")
		Sfx.play("error")
		return false
	if not spend(u.cost_at(lv)):
		return false
	upgrades[id] = lv + 1
	Hatchery.ensure_tanks()
	Factory.ensure_lines()
	inventory_changed.emit()
	facilities_changed.emit()
	notify.emit("%s upgraded to level %d." % [u.name, lv + 1], "good")
	Sfx.play("level_up")
	return true


func has_permit(location_id: String) -> bool:
	return permits.has(location_id)


func has_water_access(water: String) -> bool:
	return permits.has(WorldDB.location_for_water(water))


func buy_permit(id: String) -> bool:
	var l: DataTypes.Location = Data.locations.get(id)
	if l == null or permits.has(id):
		return false
	if level < l.level_req:
		notify.emit("Requires level %d." % l.level_req, "bad")
		Sfx.play("error")
		return false
	if not spend(l.cost):
		return false
	permits.append(id)
	permits_changed.emit()
	notify.emit("Permit unlocked: %s" % l.name, "rare")
	Sfx.play("level_up")
	return true


# ---- Products & dishes (stored goods) ----------------------------------------------

func product_count(id: String) -> int:
	return int((products.get(id, {}) as Dictionary).get("n", 0))


func products_total() -> int:
	var t := 0
	for id in products:
		t += int(products[id].get("n", 0))
	return t


func add_product(id: String, n: int, total_value: int) -> void:
	var e: Dictionary = products.get(id, {"n": 0, "v": 0})
	e["n"] = int(e.get("n", 0)) + n
	e["v"] = int(e.get("v", 0)) + total_value
	products[id] = e
	items_changed.emit()


## Removes up to n units; returns the total value removed.
func take_product(id: String, n: int) -> int:
	var e: Dictionary = products.get(id, {})
	var have := int(e.get("n", 0))
	if have <= 0 or n <= 0:
		return 0
	var take := mini(n, have)
	var value := int(round(float(e.get("v", 0)) * take / have))
	e["n"] = have - take
	e["v"] = int(e.get("v", 0)) - value
	if e["n"] <= 0:
		products.erase(id)
	else:
		products[id] = e
	items_changed.emit()
	return value


func dish_count(id: String) -> int:
	return (dishes.get(id, []) as Array).size()


func dishes_total() -> int:
	var t := 0
	for id in dishes:
		t += (dishes[id] as Array).size()
	return t
