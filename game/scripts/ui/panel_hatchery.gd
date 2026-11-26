class_name PanelHatchery
extends PanelBase
## Hatchery: one tab per tank. Feed the tank, move fish in from the backpack,
## pick two compatible parents to breed, and harvest grown fish.

var _sel: Array[int] = []


func _init() -> void:
	super()
	title = "Hatchery"
	live = true


func refresh() -> void:
	tab_names = []
	for i in Game.tanks.size():
		tab_names.append("Tank %d" % (i + 1))
	super()


func _on_open() -> void:
	_sel.clear()


func _populate(t: int) -> void:
	if t >= Game.tanks.size():
		return
	Hatchery.advance(t, Util.now())
	var tank: Dictionary = Game.tanks[t]
	var fish_list: Array = tank["fish"]
	var cap := Hatchery.tank_capacity()
	# keep only selections that still exist in this tank
	_sel = _sel.filter(func(u): return not Hatchery.fish_in_tank(t, u).is_empty())

	add_header("Tank %d   ·   fish %d / %d" % [t + 1, fish_list.size(), cap])
	# --- feed
	var feed := float(tank["feed"])
	var drain := Hatchery.drain_rate(tank)
	content.add_child(UI.bar(feed, Hatchery.MAX_FEED, UI.C_GOLD, 22))
	var feed_txt := "Feed %d%%" % int(feed)
	if drain > 0.0:
		feed_txt += " · lasts about %s" % Util.duration(feed / drain)
	else:
		feed_txt += " · fish only eat while they are in the tank"
	add_note(feed_txt, UI.C_TEXT)
	var feed_row := HBoxContainer.new()
	content.add_child(feed_row)
	feed_row.add_child(UI.button("+ Pellet (%d)" % Game.feed_pellets, func(): report(Hatchery.add_feed(t, "pellet")),
		Game.feed_pellets > 0, Vector2(200, 60)))
	for pid in Data.products:
		var p: DataTypes.Product = Data.products[pid]
		if p.feed_value > 0.0:
			feed_row.add_child(UI.button("+ %s (%d)" % [p.name, Game.product_count(pid)], func(): report(Hatchery.add_feed(t, pid)),
				Game.product_count(pid) > 0, Vector2(240, 60)))
	# --- breeding status
	var br: Dictionary = tank.get("breed", {})
	if not br.is_empty():
		add_header("Breeding in progress")
		content.add_child(UI.bar(float(br["prog"]), float(br["need"]), UI.C_ACCENT, 22))
		add_note("About %s left. Offspring appear as fry and grow into adults while the tank has feed." % Util.duration(Hatchery.breed_time_left(tank)), UI.C_TEXT)
	else:
		var ok := _sel.size() == 2
		var br_row := HBoxContainer.new()
		content.add_child(br_row)
		br_row.add_child(UI.button("Breed selected (%d/2)" % _sel.size(), func():
			var msg := Hatchery.start_breeding(t, _sel[0], _sel[1])
			report(msg)
			if msg == "":
				_sel.clear(), ok, Vector2(300, 64), UI.C_GOOD))
		add_note("Select two adults. Same species always match; neighbouring rarities from the same waters can cross-breed and may mutate or evolve.")
	# --- fish in tank
	add_header("In this tank")
	if fish_list.is_empty():
		add_note("Empty. Add fish from your backpack below.")
	for f in fish_list:
		var uid := int(f["uid"])
		var sp: DataTypes.FishSpecies = Data.fish[f["sp"]]
		var adult: bool = f.get("stage", "adult") == "adult"
		var g: Dictionary = f.get("g", {})
		var status := "Adult" if adult else "Fry %d%%" % int(Hatchery.growth_fraction(f) * 100.0)
		var sub := "%s · %s · size %.2f grow %.2f fert %.2f" % [status, UI.fish_line(f).get_slice(" · ", 0),
			float(g.get("size", 1.0)), float(g.get("grow", 1.0)), float(g.get("fert", 1.0))]
		var selected := _sel.has(uid)
		var breeding_now := not br.is_empty() and (int(br["a"]) == uid or int(br["b"]) == uid)
		add_row(FishLogic.display_name(f) + ("  [breeding]" if breeding_now else ""), sub, [
			["Selected" if selected else "Select", func():
				if _sel.has(uid):
					_sel.erase(uid)
				elif _sel.size() < 2:
					_sel.append(uid)
				refresh(), adult and br.is_empty()],
			["Harvest", func(): report(Hatchery.harvest(t, uid)), adult and not breeding_now, UI.C_GOOD],
		], Util.rarity_color(sp.rarity))
	# --- from backpack
	add_header("Add from backpack")
	var shown := 0
	var bag: Array = Game.fish.duplicate()
	bag.sort_custom(func(a, b): return Data.fish[a["sp"]].rarity > Data.fish[b["sp"]].rarity)
	for f in bag:
		if shown >= 16:
			add_note("(showing the 16 best)")
			break
		var uid := int(f["uid"])
		shown += 1
		add_row(FishLogic.display_name(f), UI.fish_line(f), [
			["Add", func(): report(Hatchery.add_from_inventory(t, uid)), Hatchery.free_slots(t) > 0]],
			Util.rarity_color(Data.fish[f["sp"]].rarity))
	if bag.is_empty():
		add_note("Your backpack has no fish.")
