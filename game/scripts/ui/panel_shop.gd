class_name PanelShop
extends PanelBase
## Tackle Shop (rods, bait) and General Store (ingredients, tank feed).

var mode := "tackle"   ## "tackle" | "general"


func setup(p_mode: String) -> PanelShop:
	mode = p_mode
	if mode == "tackle":
		title = "Tackle Shop"
		tab_names = ["Rods", "Bait"]
	else:
		title = "General Store"
		tab_names = ["Ingredients", "Tank feed"]
	return self


func _populate(t: int) -> void:
	content.add_child(UI.label("Money: " + Util.money(Game.money), UI.FONT, UI.C_GOLD))
	if mode == "tackle":
		if t == 0:
			_rods()
		else:
			_baits()
	else:
		if t == 0:
			_ingredients()
		else:
			_feed()


func _rods() -> void:
	for id in Data.rods:
		var r: DataTypes.Rod = Data.rods[id]
		var owned: bool = Game.owned_rods.has(id)
		var stats := "Luck %+d%% · Lure x%.2f · Control %d%% · Range %dm · Size %+d%%" % [
			int(r.luck * 100.0), r.lure, int(r.control * 100.0), int(r.cast_range), int(r.size_bonus * 100.0)]
		if owned:
			var equipped: bool = id == Game.rod
			add_row(r.name + ("  (equipped)" if equipped else "  (owned)"), stats,
				[["Equip", func(): Game.equip_rod(id), not equipped]], UI.C_GOOD)
		else:
			var locked := Game.level < r.level_req
			var label := "Lv %d" % r.level_req if locked else Util.money(r.price)
			add_row(r.name, "%s\n%s" % [r.desc, stats],
				[[label, func(): Game.buy_rod(id), not locked and Game.money >= r.price, UI.C_GOOD]])


func _baits() -> void:
	add_note("Each cast uses one bait. Better bait finds rarer fish and bites faster.")
	for id in Data.baits:
		var b: DataTypes.Bait = Data.baits[id]
		var have := int(Game.baits.get(id, 0))
		add_row("%s  (you have %d)" % [b.name, have], "%s  Luck %+d%% · Lure x%.2f" % [b.desc, int(b.luck * 100.0), b.lure],
			[
				["x1  %s" % Util.money(b.price), func(): Game.buy_bait(id, 1), Game.money >= b.price],
				["x10  %s" % Util.money(b.price * 10), func(): Game.buy_bait(id, 10), Game.money >= b.price * 10],
			])


func _ingredients() -> void:
	add_note("Ingredients are used in recipes at the Kitchen pavilion.")
	for id in Data.ingredients:
		var ing: DataTypes.Ingredient = Data.ingredients[id]
		var have := int(Game.ingredients.get(id, 0))
		add_row("%s  (you have %d)" % [ing.name, have], ing.desc,
			[
				["x1  %s" % Util.money(ing.price), func(): Game.buy_ingredient(id, 1), Game.money >= ing.price],
				["x5  %s" % Util.money(ing.price * 5), func(): Game.buy_ingredient(id, 5), Game.money >= ing.price * 5],
			])


func _feed() -> void:
	add_note("Feed pellets keep the Hatchery tanks fed. You can also feed tanks with Fish Meal made at the Cannery.")
	add_row("Feed pellet  (you have %d)" % Game.feed_pellets, "Fills 30%% of a tank's feed meter.",
		[
			["x1  %s" % Util.money(15), func(): Game.buy_feed(1), Game.money >= 15],
			["x10  %s" % Util.money(150), func(): Game.buy_feed(10), Game.money >= 150],
		])
