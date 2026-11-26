class_name PanelFactory
extends PanelBase
## Cannery: run processing lines, sell products wholesale, unlock new product
## types, and deliver contracts for big payouts.

var _line := 0
var _product := "fillet"
var _pick: Array[int] = []


func _init() -> void:
	super()
	title = "Cannery"
	tab_names = ["Processing", "Warehouse", "Contracts"]
	live = true


func _on_open() -> void:
	_pick.clear()


func _populate(t: int) -> void:
	content.add_child(UI.label("Money: %s    Day %d wholesale prices" % [Util.money(Game.money), Clock.day], UI.FONT, UI.C_GOLD))
	match t:
		0: _processing()
		1: _warehouse()
		2: _contracts()


func _processing() -> void:
	Factory.ensure_lines()
	add_header("Production lines")
	for i in Game.factory_lines.size():
		var job: Dictionary = Game.factory_lines[i].get("job", {})
		if job.is_empty():
			add_row("Line %d" % (i + 1), "Idle", [["Use", func():
				_line = i
				refresh(), i != _line]], UI.C_DIM)
		else:
			var p: DataTypes.Product = Data.products[job["product"]]
			var done := Factory.is_done(i)
			add_row("Line %d  -  %d x %s" % [i + 1, int(job["n"]), p.name],
				"Finished!" if done else "%s left" % Util.duration(Factory.time_left(i)), [], UI.C_GOOD)
			if not done:
				var total := float(job["end"]) - float(job["start"])
				content.add_child(UI.bar(total - Factory.time_left(i), total, UI.C_ACCENT, 14))
	if Game.factory_lines.size() <= _line or Factory.is_busy(_line):
		for i in Game.factory_lines.size():
			if not Factory.is_busy(i):
				_line = i
				break
	if Factory.is_busy(_line):
		add_note("All lines are busy. Upgrade Factory Line at the Guild to run more at once.")
		return
	add_header("Start a batch on line %d  (max %d fish)" % [_line + 1, Factory.batch_size()])
	var prod_row := HBoxContainer.new()
	content.add_child(prod_row)
	for pid in Game.unlocked_products:
		var p: DataTypes.Product = Data.products[pid]
		var b := UI.button(p.name, func():
			_product = pid
			refresh(), true, Vector2(180, 56))
		if pid != _product:
			b.add_theme_stylebox_override("normal", UI.style(Color(0.2, 0.3, 0.4), 12, 0, Color.TRANSPARENT, 14))
		prod_row.add_child(b)
	var prod: DataTypes.Product = Data.products.get(_product)
	if prod == null:
		_product = "fillet"
		return
	add_note("%s · takes %s · value x%.2f of the fish" % [prod.desc, Util.duration(prod.time * Factory.time_mult()), prod.mult], UI.C_TEXT)
	_pick = _pick.filter(func(u): return not Game.find_fish(u).is_empty())
	var expected := 0
	for u in _pick:
		expected += int(round(FishLogic.fish_value(Game.find_fish(u)) * prod.mult))
	var go_row := HBoxContainer.new()
	content.add_child(go_row)
	go_row.add_child(UI.button("Start (%d fish, ~%s)" % [_pick.size(), Util.money(expected)], func():
		var msg := Factory.start(_line, _product, _pick.duplicate())
		report(msg)
		if msg == "":
			_pick.clear(), _pick.size() > 0, Vector2(320, 64), UI.C_GOOD))
	go_row.add_child(UI.button("Fill cheapest", func():
		_pick.clear()
		var cheap: Array = Game.fish.filter(func(f): return not f.get("fav", false))
		cheap.sort_custom(func(a, b): return FishLogic.fish_value(a) < FishLogic.fish_value(b))
		for f in cheap:
			if _pick.size() >= Factory.batch_size():
				break
			_pick.append(int(f["uid"]))
		refresh(), true, Vector2(220, 64)))
	go_row.add_child(UI.button("Clear", func():
		_pick.clear()
		refresh(), _pick.size() > 0, Vector2(140, 64)))
	var list: Array = Game.fish.duplicate()
	list.sort_custom(func(a, b): return FishLogic.fish_value(a) < FishLogic.fish_value(b))
	if list.is_empty():
		add_note("Your backpack has no fish to process.")
	for f in list:
		var uid := int(f["uid"])
		var picked := _pick.has(uid)
		add_row(FishLogic.display_name(f) + ("  *" if f.get("fav", false) else ""),
			"%s · %s" % [UI.fish_line(f), Util.money(FishLogic.fish_value(f))],
			[["Remove" if picked else "Add", func():
				if _pick.has(uid):
					_pick.erase(uid)
				elif _pick.size() < Factory.batch_size():
					_pick.append(uid)
				refresh(), picked or _pick.size() < Factory.batch_size(), UI.C_BAD if picked else UI.C_ACCENT]],
			Util.rarity_color(Data.fish[f["sp"]].rarity))


func _warehouse() -> void:
	add_header("Warehouse  %d / %d" % [Game.products_total(), Game.warehouse_capacity()])
	add_note("Wholesale prices drift every in-game day. Fishmeal can also feed your tanks.")
	for pid in Data.products:
		var p: DataTypes.Product = Data.products[pid]
		if not Game.unlocked_products.has(pid):
			add_row(p.name + "  (locked)", p.desc, [[Util.money(p.unlock_cost), func(): report(Factory.unlock_product(pid)),
				Game.money >= p.unlock_cost, UI.C_GOOD]], UI.C_DIM)
			continue
		var n := Game.product_count(pid)
		var mult := Factory.wholesale_mult(pid)
		var total := 0
		if n > 0:
			total = int(round(float(Game.products[pid]["v"]) * mult))
		add_row("%s x%d" % [p.name, n], "Today's wholesale: x%.2f%s" % [mult, ("  ·  stock worth %s" % Util.money(total)) if n > 0 else ""],
			[
				["Sell 1", func(): Factory.sell_product(pid, 1), n > 0],
				["Sell all", func(): Factory.sell_product(pid), n > 0, UI.C_GOOD],
			])


func _contracts() -> void:
	add_note("Contracts pay well above market price. New ones appear as you complete them.")
	for i in Game.contracts.size():
		var c: Dictionary = Game.contracts[i]
		var have := ""
		if c.get("kind") == "product":
			have = "You have %d" % Game.product_count(c["product"])
		else:
			have = "Matching fish in backpack: %d" % Factory.contract_candidates(c).size()
		add_row(Factory.contract_text(c), "Reward %s + %d XP · %s" % [Util.money(int(c["reward"])), int(c["xp"]), have],
			[["Deliver", func(): report(Factory.deliver(i)), Factory.can_deliver(c), UI.C_GOOD]])
