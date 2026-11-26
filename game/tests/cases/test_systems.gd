extends RefCounted
## End-to-end flows through the facility systems (hatchery, kitchen, factory,
## economy, assistants) and the save file. Time is simulated by passing future
## timestamps / rewinding job end times, never by sleeping.

var Game
var Save
var Clock
var _done := 0   # a runtime error aborts a section silently, so count the ones that finished


func run(t) -> void:
	var loop := Engine.get_main_loop() as SceneTree
	Game = loop.root.get_node("Game")
	Save = loop.root.get_node("Save")
	Clock = loop.root.get_node("Clock")
	_fresh()
	_hatchery(t)
	_fresh()
	_kitchen(t)
	_fresh()
	_factory(t)
	_fresh()
	_economy(t)
	_fresh()
	_assistants(t)
	_fresh()
	_save_roundtrip(t)
	t.check(_done == 6, "all 6 system flows ran to the end (%d)" % _done)


func _fresh() -> void:
	Game.reset_new_game()
	Game.money = 100000
	Hatchery.ensure_tanks()
	Kitchen.ensure_slots()
	Factory.ensure_lines()


func _fish(species: String, w := 1.0, mut := "") -> Dictionary:
	var f := FishLogic.make_fish(species, w, mut)
	Game.add_fish(f)
	return f


func _hatchery(t) -> void:
	print("   hatchery")
	var sp: DataTypes.FishSpecies = Data.fish_for_water("shore")[0]
	var a := _fish(sp.id, 1.0)
	var b := _fish(sp.id, 1.2)
	t.check(Hatchery.add_from_inventory(0, int(a["uid"])) == "", "add first fish to tank")
	t.check(Hatchery.add_from_inventory(0, int(b["uid"])) == "", "add second fish to tank")
	t.check(Game.find_fish(int(a["uid"])).is_empty(), "fish left the backpack")
	t.check(Hatchery.start_breeding(0, int(a["uid"]), int(b["uid"])) != "", "cannot breed a hungry tank")
	Game.feed_pellets = 5
	t.check(Hatchery.add_feed(0, "pellet") == "", "feeding with a pellet works")
	t.check(float(Game.tanks[0]["feed"]) > 20.0, "feed meter rose")
	t.check(Hatchery.start_breeding(0, int(a["uid"]), int(b["uid"])) == "", "breeding starts")
	t.check(Hatchery.start_breeding(0, int(a["uid"]), int(b["uid"])) != "", "cannot start a second breeding in the same tank")
	var need := float(Game.tanks[0]["breed"]["need"])
	Game.tanks[0]["feed"] = 100.0
	Game.tanks[0]["last"] = Util.now() - 10.0
	Hatchery.advance(0, Util.now() + need * 2.0)
	var fry := 0
	for f in Game.tanks[0]["fish"]:
		if f.get("stage", "adult") == "fry":
			fry += 1
	t.check(fry >= 1, "breeding produced fry (%d)" % fry)
	t.check((Game.tanks[0]["breed"] as Dictionary).is_empty(), "breeding job cleared")
	# grow the fry up: keep feeding and advance time
	for i in 40:
		Game.tanks[0]["feed"] = 100.0
		Hatchery.advance(0, float(Game.tanks[0]["last"]) + 600.0)
	var adults := 0
	var grown: Dictionary = {}
	for f in Game.tanks[0]["fish"]:
		if f.get("stage", "adult") == "adult" and int(f["uid"]) != int(a["uid"]) and int(f["uid"]) != int(b["uid"]):
			adults += 1
			grown = f
	t.check(adults >= 1, "fry grew into adults")
	if not grown.is_empty():
		t.check(float(grown["w"]) > 0.0, "grown fish has a weight")
		t.check(Hatchery.harvest(0, int(grown["uid"])) == "", "harvest a grown fish")
		var back: Dictionary = Game.find_fish(int(grown["uid"]))
		t.check(not back.is_empty() and back.get("farm", false), "harvested fish is in the backpack and marked farmed")
		t.check(Util.str_hash("x") == Util.str_hash("x"), "hash helper is stable")
	# incompatible parents are refused
	_fresh()
	var rare: DataTypes.FishSpecies = Data.fish_for_water("deep")[-1]
	var common: DataTypes.FishSpecies = Data.fish_for_water("shore")[0]
	var r := _fish(rare.id, 5.0)
	var c := _fish(common.id, 1.0)
	Hatchery.add_from_inventory(0, int(r["uid"]))
	Hatchery.add_from_inventory(0, int(c["uid"]))
	Game.tanks[0]["feed"] = 100.0
	t.check(Hatchery.start_breeding(0, int(r["uid"]), int(c["uid"])) != "", "incompatible species are refused")
	# tank capacity is enforced
	_fresh()
	var added := 0
	for i in 10:
		var f := _fish(common.id, 1.0)
		if Hatchery.add_from_inventory(0, int(f["uid"])) == "":
			added += 1
	t.check(added == Hatchery.tank_capacity(), "tank holds exactly its capacity (%d)" % added)
	_done += 1


func _kitchen(t) -> void:
	print("   kitchen")
	var rid := "grilled_fish"
	if not Data.recipes.has(rid):
		rid = Data.recipes.keys()[0]
	var r: DataTypes.Recipe = Data.recipes[rid]
	if Kitchen.slot_for(r.station) < 0:
		t.check(Kitchen.buy_station(r.station) == "", "buy the %s station" % r.station)
	var fish_in := _fish(Data.fish_for_water("shore")[0].id, 1.0)
	t.check(Kitchen.start(rid, int(fish_in["uid"])) != "", "cannot cook without ingredients")
	for id in r.ingredients:
		Game.ingredients[id] = int(r.ingredients[id])
	# some recipes want a specific fish kind: find any that matches
	var use: Dictionary = {}
	for f in Game.fish:
		if Kitchen.fish_matches(r, f):
			use = f
	if use.is_empty():
		use = _fish(Data.fish_for_water("lake")[-1].id, 2.0)
	t.check(Kitchen.start(rid, int(use["uid"])) == "", "cooking starts")
	var slot := Kitchen.slot_for(r.station)
	t.check(Kitchen.is_busy(slot) and not Kitchen.job_done(slot), "station is busy, dish not ready")
	t.check(Kitchen.collect(slot) != "", "cannot collect an unfinished dish")
	Game.kitchen[slot]["job"]["end"] = Util.now() - 1.0
	t.check(Kitchen.job_done(slot), "dish is ready after the time passed")
	t.check(Kitchen.collect(slot) == "", "dish collected")
	t.check(Game.dishes_total() == 1, "dish is in the inventory")
	var money_before: int = Game.money
	if not r.buff.is_empty():
		var stat: String = r.buff.keys()[0]
		t.check(Kitchen.eat(rid) == "", "eating a dish works")
		t.check(Game.buff_time_left(stat) > 0.0, "the food buff is active")
		t.check(Game.dishes_total() == 0, "the eaten dish is gone")
	else:
		t.check(Kitchen.sell_dishes(rid) > 0 and Game.money > money_before, "selling a dish pays money")
	# dishes can be sold too
	var f3 := _fish(Data.fish_for_water("shore")[0].id, 1.0)
	for id in r.ingredients:
		Game.ingredients[id] = int(r.ingredients[id])
	if Kitchen.fish_matches(r, f3):
		Kitchen.start(rid, int(f3["uid"]))
		Game.kitchen[slot]["job"]["end"] = Util.now() - 1.0
		Kitchen.collect(slot)
		var m1: int = Game.money
		t.check(Kitchen.sell_dishes(rid) > 0 and Game.money > m1, "selling a cooked dish pays money")
	_done += 1


func _factory(t) -> void:
	print("   factory")
	var sp: DataTypes.FishSpecies = Data.fish_for_water("lake")[0]
	var f1 := _fish(sp.id, 2.0)
	var f2 := _fish(sp.id, 2.0)
	t.check(Factory.start(0, "fillet", []) != "", "empty batch refused")
	var money0: int = Game.money
	t.check(Factory.start(0, "fillet", [int(f1["uid"]), int(f2["uid"])]) == "", "processing starts")
	t.check(Game.find_fish(int(f1["uid"])).is_empty(), "processed fish are consumed")
	t.check(Factory.is_busy(0) and not Factory.is_done(0), "line is busy")
	Game.factory_lines[0]["job"]["end"] = Util.now() - 1.0
	Factory.tick()
	t.check(not Factory.is_busy(0), "finished line is freed by tick")
	t.check(Game.product_count("fillet") == 2, "two fillets in the warehouse (%d)" % Game.product_count("fillet"))
	var got := Factory.sell_product("fillet")
	t.check(got > 0 and Game.money == money0 + got, "selling products pays money")
	t.check(Game.product_count("fillet") == 0, "warehouse emptied")
	# contracts exist and are well-formed
	Factory.tick()
	t.check(Game.contracts.size() > 0, "contracts are generated")
	for c in Game.contracts:
		t.check(int(c["reward"]) > 0 and Factory.contract_text(c) != "", "contract has a reward and text")
	_done += 1


func _economy(t) -> void:
	print("   economy")
	var sp: DataTypes.FishSpecies = Data.fish_for_water("shore")[0]
	var f := _fish(sp.id, 1.0)
	var money0: int = Game.money
	var price := Economy.sell_price(f)
	t.check(price > 0, "fish has a sell price")
	t.check(Economy.sell_fish(int(f["uid"])) == price and Game.money == money0 + price, "selling pays exactly the quoted price")
	t.check(Game.fish.is_empty(), "sold fish leaves the backpack")
	# repeated sales of one species lower its price
	var p1 := Economy.sell_price(_fish(sp.id, 1.0))
	for i in 6:
		Economy.sell_fish(int(_fish(sp.id, 1.0)["uid"]))
	var p2 := Economy.sell_price(_fish(sp.id, 1.0))
	t.check(p2 <= p1, "saturating the market does not raise prices (%d -> %d)" % [p1, p2])
	# favourites are protected from bulk sales
	_fresh()
	var fav := _fish(sp.id, 1.0)
	fav["fav"] = true
	_fish(sp.id, 1.0)
	Economy.sell_all()
	t.check(Game.fish.size() == 1 and Game.fish[0].get("fav", false), "sell-all keeps favourites")
	# orders
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var matched := 0
	for i in 30:
		var o := Economy.generate_order(rng)
		t.check(o.has("id") and float(o["mult"]) > 1.0 and Economy.order_text(o) != "", "generated order is valid")
		if o.get("kind") != "dish":
			Game.orders.append(o)
			for k in Data.fish:
				var test_fish := FishLogic.make_fish(k, 1.0)
				if Economy.order_matches_fish(o, test_fish):
					matched += 1
					var uid := int(test_fish["uid"])
					Game.add_fish(test_fish)
					var m0: int = Game.money
					var paid := Economy.fulfill_with_fish(int(o["id"]), uid)
					t.check(paid > 0 and Game.money == m0 + paid, "fulfilling an order pays its bonus price")
					t.check(Economy.find_order(int(o["id"])) == -1, "fulfilled order is removed")
					break
		if matched >= 3:
			break
	t.check(matched >= 1, "at least one order could be fulfilled")
	_done += 1


func _assistants(t) -> void:
	print("   assistants")
	t.check(Assistants.count() == 0, "no assistants at the start")
	var c := Assistants.roll_assistant_catch()
	t.check(not c.is_empty() and Data.fish.has(c["sp"]), "an assistant catch is a real fish")
	Game.crate.append(c)
	var moved := Assistants.collect_crate()
	t.check(moved == 1 and Game.crate.is_empty() and Game.fish.size() == 1, "collecting the crate moves fish to the backpack")
	_done += 1


func _save_roundtrip(t) -> void:
	print("   save round-trip")
	Save.delete_save()
	_fish("sand_dab" if Data.fish.has("sand_dab") else Data.fish.keys()[0], 1.5, "golden")
	Game.money = 12345
	Game.level = 7
	Game.xp = 33
	Game.owned_rods.append("oak") if Data.rods.has("oak") and not Game.owned_rods.has("oak") else null
	Game.feed_pellets = 9
	Game.tanks[0]["feed"] = 55.0
	Game.permits.append("mirror_lake")
	Clock.hour = 15.5
	Clock.day = 4
	var fish_n: int = Game.fish.size()
	var owned: int = Game.owned_rods.size()
	t.check(Save.save_game(true), "save writes a file")
	t.check(Save.has_save(), "save file exists")
	var info: Dictionary = Save.save_info()
	t.check(int(info.get("level", 0)) == 7 and int(info.get("money", 0)) == 12345, "save_info shows level and money")
	Game.reset_new_game()
	Clock.hour = 8.0
	Clock.day = 1
	t.check(Game.money != 12345, "state was wiped")
	t.check(Save.load_game(), "save loads")
	t.check(Game.money == 12345 and Game.level == 7 and Game.xp == 33, "money / level / xp restored")
	t.check(Game.fish.size() == fish_n and Game.fish[0].get("mut", "") == "golden", "fish and mutations restored")
	t.check(Game.owned_rods.size() == owned and Game.feed_pellets == 9, "rods and supplies restored")
	t.check(is_equal_approx(float(Game.tanks[0]["feed"]), 55.0), "tank state restored")
	t.check(Game.permits.has("mirror_lake"), "permits restored")
	t.check(Clock.day == 4 and absf(Clock.hour - 15.5) < 0.01, "time of day restored")
	# a corrupt file must not crash the loader
	var f := FileAccess.open(Save.PATH, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	t.check(not Save.load_game(), "corrupt save is rejected without crashing")
	Save.delete_save()
	t.check(not Save.has_save(), "delete_save removes the file")
	_done += 1
