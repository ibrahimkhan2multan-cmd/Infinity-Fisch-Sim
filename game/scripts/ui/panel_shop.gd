class_name PanelShop
extends PanelBase
## Tackle Shop (rods, bait) and General Store (ingredients, tank feed).

var mode := "tackle"   ## "tackle" | "general"


func setup(p_mode: String) -> PanelShop:
	mode = p_mode
	if mode == "tackle":
		title = "Tackle Shop"
		tab_names = ["Rods", "Bait", "Charms"]
	else:
		title = "General Store"
		tab_names = ["Ingredients", "Tank feed"]
	return self


func _populate(t: int) -> void:
	content.add_child(UI.label("Money: " + Util.money(Game.money), UI.FONT, UI.C_GOLD))
	if mode == "tackle":
		match t:
			0: _rods()
			1: _baits()
			_: _charms()
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


static func charm_stats(c: DataTypes.Charm) -> String:
	var parts: PackedStringArray = []
	if c.luck > 0.0:
		parts.append("Luck %+d%%" % int(round(c.luck * 100.0)))
	if c.calm > 0.0:
		parts.append("Fish %d%% slower" % int(round(c.calm * 100.0)))
	return " · ".join(parts)


func _charms() -> void:
	add_note("Equip up to %d charms (%d on now). Luck finds rarer fish; Calm slows the fish in the reel bar (max %d%% total)." % [
		CharmDB.SLOTS, Game.charms_equipped.size(), int(CharmDB.MAX_CALM * 100.0)])
	for id in Data.charms:
		var c: DataTypes.Charm = Data.charms[id]
		var stats := charm_stats(c)
		var icon := CharmIcon.make(c)
		if Game.charms_owned.has(id):
			var on: bool = Game.charms_equipped.has(id)
			add_row(c.name + ("  (equipped)" if on else "  (owned)"), "%s\n%s" % [c.desc, stats],
				[["Take off" if on else "Equip", func():
					if on:
						Game.unequip_charm(id)
					else:
						report(Game.equip_charm(id)), true]], UI.C_GOOD, icon)
		else:
			var locked := Game.level < c.level_req
			var label := "Lv %d" % c.level_req if locked else Util.money(c.price)
			add_row(c.name, "%s\n%s" % [c.desc, stats],
				[[label, func(): Game.buy_charm(id), not locked and Game.money >= c.price, UI.C_GOOD]], Util.rarity_color(c.rarity), icon)


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
