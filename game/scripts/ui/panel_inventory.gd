class_name PanelInventory
extends PanelBase
## Backpack: fish (favourite / release), gear (equip rods & bait, buffs),
## cooked dishes (eat) and factory products.


func _init() -> void:
	super()
	title = "Backpack"
	tab_names = ["Fish", "Gear", "Dishes", "Products"]
	live = true


func _populate(t: int) -> void:
	match t:
		0: _fish()
		1: _gear()
		2: _dishes()
		3: _products()


func _fish() -> void:
	add_header("Fish  %d / %d" % [Game.fish.size(), Game.capacity()])
	if Game.fish.is_empty():
		add_note("Nothing here yet - go catch something! Cast with the big button near the water.")
		return
	var list: Array = Game.fish.duplicate()
	list.sort_custom(func(a, b): return FishLogic.fish_value(a) > FishLogic.fish_value(b))
	for f in list:
		var sp: DataTypes.FishSpecies = Data.fish[f["sp"]]
		var uid := int(f["uid"])
		var fav: bool = f.get("fav", false)
		add_row(FishLogic.display_name(f), "%s · %s" % [UI.fish_line(f), Util.money(FishLogic.fish_value(f))],
			[
				["Fav" if not fav else "Unfav", func():
					f["fav"] = not fav
					Game.inventory_changed.emit(), true],
				["Release", func():
					Game.remove_fish(uid), not fav, UI.C_BAD],
			], Util.rarity_color(sp.rarity))


func _gear() -> void:
	add_header("Rods")
	for id in Game.owned_rods:
		var r: DataTypes.Rod = Data.rods[id]
		var equipped: bool = id == Game.rod
		add_row(r.name + ("  (equipped)" if equipped else ""),
			"Luck %+d%% · Lure x%.2f · Control %d%% · Range %dm" % [int(r.luck * 100.0), r.lure, int(r.control * 100.0), int(r.cast_range)],
			[["Equip", func(): Game.equip_rod(id), not equipped]])
	add_header("Bait")
	var any_bait := false
	for id in Game.baits:
		var n := int(Game.baits[id])
		if n <= 0:
			continue
		any_bait = true
		var b: DataTypes.Bait = Data.baits[id]
		var equipped: bool = id == Game.bait
		add_row("%s x%d%s" % [b.name, n, "  (equipped)" if equipped else ""], b.desc,
			[["Equip", func(): Game.equip_bait(id), not equipped]])
	if not any_bait:
		add_note("No bait. Buy some at the Tackle Shop (casting without bait still works, but it is slower).")
	add_header("Active food buffs")
	var any_buff := false
	for stat in Game.buffs:
		var left := Game.buff_time_left(stat)
		if left > 0.0:
			any_buff = true
			add_row("+%d%% %s" % [int(round(Game.buff_amount(stat) * 100.0)), stat], "%s left" % Util.duration(left))
	if not any_buff:
		add_note("Eat a cooked dish to gain a temporary fishing boost.")
	add_header("Supplies")
	add_row("Feed pellets: %d" % Game.feed_pellets, "Used to feed the tanks in the Hatchery.")
	for id in Game.ingredients:
		var n := int(Game.ingredients[id])
		if n > 0:
			add_row("%s x%d" % [Data.ingredients[id].name, n], Data.ingredients[id].desc)


func _dishes() -> void:
	add_header("Cooked dishes  (%d)" % Game.dishes_total())
	if Game.dishes.is_empty():
		add_note("Cook fish at the Kitchen pavilion in the village. Dishes can be eaten for buffs or sold.")
		return
	for id in Game.dishes:
		var r: DataTypes.Recipe = Data.recipes[id]
		var list: Array = Game.dishes[id]
		var best := 0
		for v in list:
			best = maxi(best, int(v))
		add_row("%s x%d" % [r.name, list.size()], "%s  ·  best %s" % [Kitchen.buff_text(r), Util.money(best)],
			[["Eat", func(): report(Kitchen.eat(id))]])


func _products() -> void:
	add_header("Factory products  (%d / %d)" % [Game.products_total(), Game.warehouse_capacity()])
	if Game.products.is_empty():
		add_note("Process fish at the Cannery to make products. They are sold wholesale, used as feed, or delivered for contracts.")
		return
	for id in Game.products:
		var p: DataTypes.Product = Data.products[id]
		var n := Game.product_count(id)
		if n > 0:
			add_row("%s x%d" % [p.name, n], p.desc)
