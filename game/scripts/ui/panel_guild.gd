class_name PanelGuild
extends PanelBase
## Fishing Guild: reinvest in upgrades, buy permits for new waters, manage
## assistant anglers and the dock crate, see lifetime stats.


func _init() -> void:
	super()
	title = "Fishing Guild"
	tab_names = ["Upgrades", "Permits", "Assistants", "Stats"]
	live = true


func _populate(t: int) -> void:
	content.add_child(UI.label("Money: %s   Level %d" % [Util.money(Game.money), Game.level], UI.FONT, UI.C_GOLD))
	match t:
		0: _upgrades()
		1: _permits()
		2: _assistants()
		3: _stats()


func _upgrades() -> void:
	for id in Data.upgrades:
		var u: DataTypes.Upgrade = Data.upgrades[id]
		var lv := Game.upgrade_level(id)
		var title_text := "%s  Lv %d / %d" % [u.name, lv, u.max_level]
		if lv >= u.max_level:
			add_row(title_text, u.desc, [["Maxed", Callable(), false]], UI.C_GOOD)
		elif Game.level < u.level_req:
			add_row(title_text, u.desc + "  (needs player level %d)" % u.level_req, [["Lv %d" % u.level_req, Callable(), false]], UI.C_DIM)
		else:
			var cost := u.cost_at(lv)
			add_row(title_text, u.desc,
				[[Util.money(cost), func(): Game.buy_upgrade(id), Game.money >= cost, UI.C_GOOD]])


func _permits() -> void:
	add_note("Permits unlock new waters. Reach islands by ferry from the village pier (or the dock of any island).")
	for id in Data.locations:
		var l: DataTypes.Location = Data.locations[id]
		if Game.has_permit(id):
			add_row(l.name + "  (unlocked)", l.desc, [], UI.C_GOOD)
		elif Game.level < l.level_req:
			add_row(l.name, l.desc + "  Requires level %d." % l.level_req, [["Lv %d" % l.level_req, Callable(), false]], UI.C_DIM)
		else:
			add_row(l.name, l.desc, [[Util.money(l.cost), func(): Game.buy_permit(id), Game.money >= l.cost, UI.C_GOOD]])


func _assistants() -> void:
	var n := Assistants.count()
	if n == 0:
		add_note("Hire an assistant angler (Upgrades tab) and they will fish for you - even while the game is closed - and fill the dock crate at the pier.")
	else:
		add_note("%d assistant%s · one catch every ~%s each · training level %d" % [
			n, "" if n == 1 else "s", Util.duration(Assistants.interval()), Assistants.skill()], UI.C_TEXT)
	add_header("Dock crate  %d / %d" % [Game.crate.size(), Game.warehouse_capacity()])
	add_row("Collect catches", "Moves fish from the crate into your backpack (%d free slots)." % maxi(0, Game.capacity() - Game.fish.size()),
		[["Collect", func():
			var moved := Assistants.collect_crate()
			Game.notify.emit("Collected %d fish." % moved if moved > 0 else "Nothing could be collected.", "good" if moved > 0 else "info"),
			Game.crate.size() > 0, UI.C_GOOD]])
	for f in Game.crate.slice(0, 12):
		add_row(FishLogic.display_name(f), UI.fish_line(f), [], Util.rarity_color(Data.fish[f["sp"]].rarity))
	if Game.crate.size() > 12:
		add_note("...and %d more." % (Game.crate.size() - 12))


func _stats() -> void:
	var rows := [
		["Fish caught", str(int(Game.stats.get("caught", 0)))],
		["Species discovered", "%d / %d" % [Game.discovered_count(), Data.fish.size()]],
		["Total earned", Util.money(int(Game.stats.get("earned", 0)))],
		["Items sold", str(int(Game.stats.get("sold", 0)))],
		["Dishes cooked", str(int(Game.stats.get("cooked", 0)))],
		["Fish bred", str(int(Game.stats.get("bred", 0)))],
		["Fish processed", str(int(Game.stats.get("processed", 0)))],
		["Play time", Util.duration(Game.play_time)],
	]
	for r in rows:
		add_row(r[0], "", [])
		var last := content.get_child(content.get_child_count() - 1)
		var v := UI.label(r[1], UI.FONT, UI.C_GOLD)
		(last.get_child(0) as HBoxContainer).add_child(v)
