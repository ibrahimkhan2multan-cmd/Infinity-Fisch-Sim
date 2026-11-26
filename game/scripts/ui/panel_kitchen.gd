class_name PanelKitchen
extends PanelBase
## Kitchen pavilion: buy stations, start recipes with a fish from the backpack,
## collect finished dishes.

var _open_recipe := ""


func _init() -> void:
	super()
	title = "Kitchen"
	tab_names = ["Cook", "Stations"]
	live = true


func _populate(t: int) -> void:
	if t == 0:
		_recipes()
	else:
		_stations()


func _stations() -> void:
	content.add_child(UI.label("Money: " + Util.money(Game.money), UI.FONT, UI.C_GOLD))
	add_note("Each station cooks one dish at a time. Cooking continues while the game is closed.")
	for st in Kitchen.STATIONS:
		var info: Dictionary = Kitchen.STATIONS[st]
		var slot := Kitchen.slot_for(st)
		if slot >= 0:
			add_row(String(info["name"]) + "  (owned)", _slot_text(slot), _slot_actions(slot), UI.C_GOOD)
			if Kitchen.is_busy(slot) and not Kitchen.job_done(slot):
				var job: Dictionary = Game.kitchen[slot]["job"]
				var total := float(job["end"]) - float(job["start"])
				content.add_child(UI.bar(total - Kitchen.time_left(slot), total, UI.C_ACCENT, 14))
		else:
			var locked := Game.level < int(info["level"])
			add_row(String(info["name"]), "Requires level %d." % int(info["level"]),
				[[Util.money(int(info["cost"])) if not locked else "Lv %d" % int(info["level"]),
					func(): report(Kitchen.buy_station(st)), not locked and Game.money >= int(info["cost"]), UI.C_GOOD]])


func _slot_text(slot: int) -> String:
	if not Kitchen.is_busy(slot):
		return "Idle"
	var job: Dictionary = Game.kitchen[slot]["job"]
	var r: DataTypes.Recipe = Data.recipes[job["recipe"]]
	if Kitchen.job_done(slot):
		return "%s is ready!" % r.name
	return "Cooking %s · %s left" % [r.name, Util.duration(Kitchen.time_left(slot))]


func _slot_actions(slot: int) -> Array:
	if Kitchen.job_done(slot):
		return [["Collect", func(): report(Kitchen.collect(slot)), true, UI.C_GOOD]]
	return []


func _recipes() -> void:
	# quick status line + collect buttons for finished dishes
	for slot in Game.kitchen.size():
		if Kitchen.job_done(slot):
			add_row(_slot_text(slot), "Station: " + String(Kitchen.STATIONS[Game.kitchen[slot]["station"]]["name"]),
				_slot_actions(slot), UI.C_GOOD)
	add_note("Pick a recipe, then the fish to cook. Ingredients come from the General Store. Cooked dishes sell for far more than raw fish, or can be eaten for a buff.")
	for id in Data.recipes:
		var r: DataTypes.Recipe = Data.recipes[id]
		var slot := Kitchen.slot_for(r.station)
		var st_name := String(Kitchen.STATIONS[r.station]["name"])
		var missing := Kitchen.missing_ingredients(r)
		var ing_parts: Array[String] = []
		for iid in r.ingredients:
			var need := int(r.ingredients[iid])
			var have := int(Game.ingredients.get(iid, 0))
			ing_parts.append("%s %d/%d" % [Data.ingredients[iid].name, have, need])
		var fish_req := ""
		if r.fish_filter != "any":
			fish_req += " %swater fish" % ("fresh" if r.fish_filter == "fresh" else "salt")
		if r.min_rarity > 0:
			fish_req += " %s+" % Util.rarity_name(r.min_rarity)
		var sub := "%s · %s · %s\n%s%s" % [st_name, Util.duration(r.time * Kitchen.time_mult()), Kitchen.buff_text(r),
			", ".join(ing_parts), ("  ·  needs" + fish_req) if fish_req != "" else ""]
		var matches := Kitchen.matching_fish(r)
		var why := ""
		if slot < 0:
			why = "no station"
		elif Kitchen.is_busy(slot):
			why = "busy"
		elif not missing.is_empty():
			why = "missing items"
		elif matches.is_empty():
			why = "no fish"
		add_row(r.name, sub, [[("Cook" if why == "" else why.capitalize()), func():
			_open_recipe = id if _open_recipe != id else ""
			refresh(), why == "", UI.C_GOOD]],
			UI.C_TEXT if why == "" else UI.C_DIM)
		if _open_recipe == id and why == "":
			for f in matches.slice(0, 6):
				var uid := int(f["uid"])
				var est := r.base_value + int(round(FishLogic.fish_value(f) * r.fish_mult))
				add_row("      " + FishLogic.display_name(f), "%s · dish worth about %s" % [UI.fish_line(f), Util.money(est)],
					[["Use", func():
						var msg := Kitchen.start(id, uid)
						report(msg)
						if msg == "":
							_open_recipe = "", true, UI.C_GOOD]],
					Util.rarity_color(Data.fish[f["sp"]].rarity))
