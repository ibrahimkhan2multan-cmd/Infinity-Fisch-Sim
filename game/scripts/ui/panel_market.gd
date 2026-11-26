class_name PanelMarket
extends PanelBase
## Fish market: serve customer orders, sell fish in bulk or one by one, sell dishes.

var _open_order := -1   ## order id whose candidate list is expanded


func _init() -> void:
	super()
	title = "Fish Market"
	tab_names = ["Customers", "Sell fish", "Dishes"]
	live = true


func _populate(t: int) -> void:
	content.add_child(UI.label("Money: " + Util.money(Game.money), UI.FONT, UI.C_GOLD))
	match t:
		0: _customers()
		1: _sell()
		2: _dishes()


func _customers() -> void:
	add_note("Customers pay a bonus for exactly what they want. New customers arrive over time; more stalls mean more customers.")
	if Game.orders.is_empty():
		add_note("No customers right now. Check back soon.")
		return
	for o in Game.orders:
		var oid := int(o["id"])
		var left := maxf(0.0, float(o.get("expires", 0.0)) - Util.now())
		var title_text := "%s  -  %s" % [o["name"], Economy.order_text(o)]
		var sub := "Pays x%.2f of the fish value · leaves in %s" % [float(o["mult"]), Util.duration(left)]
		var actions: Array = []
		if o.get("kind") == "dish":
			var rid: String = o["target"]
			var have := (Game.dishes.get(rid, []) as Array).size()
			actions.append(["Serve (%d)" % have, func(): Economy.fulfill_with_dish(oid, rid), have > 0, UI.C_GOOD])
		else:
			var cands := _candidates(o)
			actions.append(["Choose fish (%d)" % cands.size(), func():
				_open_order = oid if _open_order != oid else -1
				refresh(), cands.size() > 0, UI.C_GOOD])
		actions.append(["Dismiss", func(): Economy.dismiss(oid), true, UI.C_BAD])
		add_row(title_text, sub, actions)
		if _open_order == oid:
			for f in _candidates(o).slice(0, 6):
				var uid := int(f["uid"])
				var pay := int(round(FishLogic.fish_value(f) * float(o["mult"])))
				add_row("      " + FishLogic.display_name(f), "%s · pays %s" % [UI.fish_line(f), Util.money(pay)],
					[["Give", func():
						Economy.fulfill_with_fish(oid, uid)
						_open_order = -1, true, UI.C_GOOD]],
					Util.rarity_color(Data.fish[f["sp"]].rarity))


func _candidates(o: Dictionary) -> Array:
	var out: Array = []
	for f in Game.fish:
		if Economy.order_matches_fish(o, f):
			out.append(f)
	out.sort_custom(func(a, b): return FishLogic.fish_value(a) < FishLogic.fish_value(b))
	return out


func _sell() -> void:
	add_note("Prices follow demand and change as you sell the same species. Favourites are never sold in bulk.")
	var bar := HBoxContainer.new()
	content.add_child(bar)
	bar.add_child(UI.button("Sell Commons", func(): _bulk(0), true, Vector2(180, 60)))
	bar.add_child(UI.button("Up to Uncommon", func(): _bulk(1), true, Vector2(220, 60)))
	bar.add_child(UI.button("Everything", func(): _bulk(5), true, Vector2(180, 60), UI.C_GOOD))
	if Game.fish.is_empty():
		add_note("Your backpack has no fish.")
		return
	var list: Array = Game.fish.duplicate()
	list.sort_custom(func(a, b): return Economy.sell_price(a) > Economy.sell_price(b))
	for f in list:
		var uid := int(f["uid"])
		var sp: DataTypes.FishSpecies = Data.fish[f["sp"]]
		var fav: bool = f.get("fav", false)
		add_row(FishLogic.display_name(f) + ("  *" if fav else ""), UI.fish_line(f),
			[["Sell " + Util.money(Economy.sell_price(f)), func(): Economy.sell_fish(uid), true, UI.C_GOOD]],
			Util.rarity_color(sp.rarity))


func _bulk(max_rarity: int) -> void:
	var got := Economy.sell_all(max_rarity)
	if got > 0:
		Game.notify.emit("Sold fish for %s." % Util.money(got), "good")
	else:
		Game.notify.emit("Nothing to sell.", "info")


func _dishes() -> void:
	if Game.dishes.is_empty():
		add_note("No dishes. Cook some at the Kitchen pavilion - cooked food sells for much more than raw fish.")
		return
	for id in Game.dishes:
		var r: DataTypes.Recipe = Data.recipes[id]
		var list: Array = Game.dishes[id]
		var total := 0
		for v in list:
			total += int(v)
		add_row("%s x%d" % [r.name, list.size()], "Worth %s in total" % Util.money(total),
			[
				["Sell 1", func(): Kitchen.sell_dishes(id, 1), true],
				["Sell all", func(): Kitchen.sell_dishes(id), true, UI.C_GOOD],
			])
