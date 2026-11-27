extends RefCounted
## Luck/calm charms (shop rules, slots, bonuses, saves, effect on the reel fight)
## and the movement rules (swimming, island isolation).

var Game
var Save
var _done := 0


func run(t) -> void:
	var loop := Engine.get_main_loop() as SceneTree
	Game = loop.root.get_node("Game")
	Save = loop.root.get_node("Save")
	Terrain.init_noise()
	_catalog(t)
	_shop_and_slots(t)
	_bonuses(t)
	_save(t)
	_calm_effect(t)
	_swim_rules(t)
	_islands(t)
	_player_constants(t)
	t.check(_done == 8, "all 8 charm/movement sections ran to the end (%d)" % _done)


func _fresh() -> void:
	Game.reset_new_game()
	Game.money = 1_000_000
	Game.level = 30


func _catalog(t) -> void:
	var n := 0
	var luck_total := 0.0
	var calm_total := 0.0
	for id in Data.charms:
		var c: DataTypes.Charm = Data.charms[id]
		n += 1
		t.check(c.id == id and c.name != "" and c.price > 0 and c.level_req >= 1, "charm %s is well formed" % id)
		t.check(c.luck > 0.0 or c.calm > 0.0, "charm %s gives luck or calm" % id)
		luck_total += c.luck
		calm_total += c.calm
	t.check(n == 10, "10 charms in the catalogue (%d)" % n)
	t.check(luck_total > 1.0 and calm_total > 0.5, "both luck and calm charms exist")
	_done += 1


func _shop_and_slots(t) -> void:
	_fresh()
	Game.level = 1
	Game.money = 100000
	t.check(not Game.buy_charm("horseshoe"), "high-level charm is locked at level 1")
	t.check(Game.money == 100000 and Game.charms_owned.is_empty(), "failed purchase costs nothing")
	t.check(not Game.buy_charm("no_such_charm"), "unknown charm id is rejected")
	Game.money = 10
	t.check(not Game.buy_charm("clover"), "cannot buy without enough money")
	Game.money = 100000
	t.check(Game.buy_charm("clover"), "buy a level-1 charm")
	t.check(Game.charms_owned.has("clover") and Game.charms_equipped.has("clover"), "bought charm is equipped when a slot is free")
	t.check(not Game.buy_charm("clover"), "cannot buy the same charm twice")
	_fresh()
	for id in ["clover", "shell", "knot", "coin"]:
		t.check(Game.buy_charm(id), "buy %s" % id)
	t.check(Game.charms_equipped.size() == CharmDB.SLOTS, "only %d charms can be worn" % CharmDB.SLOTS)
	t.check(not Game.charms_equipped.has("coin"), "the 4th charm stays in the bag")
	t.check(Game.equip_charm("coin") != "", "equipping into full slots is refused with a reason")
	Game.unequip_charm("clover")
	t.check(Game.equip_charm("coin") == "" and Game.charms_equipped.has("coin"), "take one off, then equip another")
	t.check(Game.equip_charm("starfall") != "", "cannot equip a charm you do not own")
	_done += 1


func _bonuses(t) -> void:
	_fresh()
	var luck0: float = Game.fishing_stat("luck")
	t.check(is_zero_approx(Game.fishing_stat("calm")), "no calm without charms")
	Game.buy_charm("clover")
	t.check(Game.fishing_stat("luck") > luck0, "luck charm raises luck")
	t.check(absf((Game.fishing_stat("luck") - luck0) - 0.10) < 0.0001, "clover adds exactly +0.10 luck")
	Game.buy_charm("shell")
	t.check(absf(Game.fishing_stat("calm") - 0.08) < 0.0001, "shell adds 0.08 calm")
	Game.buy_charm("knot")
	t.check(absf(Game.fishing_stat("calm") - 0.15) < 0.0001, "calm stacks across charms")
	Game.unequip_charm("clover")
	Game.unequip_charm("shell")
	Game.unequip_charm("knot")
	t.check(is_zero_approx(Game.fishing_stat("calm")) and absf(Game.fishing_stat("luck") - luck0) < 0.0001, "taking charms off removes the bonus")
	# calm is capped no matter what is worn
	Game.charms_owned = ["tooth", "pearl", "moonstone"]
	Game.charms_equipped = ["tooth", "pearl", "moonstone"]
	t.check(Game.fishing_stat("calm") <= CharmDB.MAX_CALM + 0.0001, "calm is capped at %.2f (%.2f)" % [CharmDB.MAX_CALM, Game.fishing_stat("calm")])
	_done += 1


func _save(t) -> void:
	_fresh()
	Save.delete_save()
	Game.buy_charm("clover")
	Game.buy_charm("shell")
	Game.buy_charm("coin")
	Game.buy_charm("moonstone")   # 4th: owned but not worn
	var owned: Array = Game.charms_owned.duplicate()
	var worn: Array = Game.charms_equipped.duplicate()
	t.check(Save.save_game(true), "save with charms")
	Game.reset_new_game()
	t.check(Game.charms_owned.is_empty(), "new game starts without charms")
	t.check(Save.load_game(), "load")
	t.check(Game.charms_owned == owned and Game.charms_equipped == worn, "owned and worn charms round-trip")
	# corrupt / hostile data: unknown ids dropped, too many worn charms capped, worn-but-not-owned dropped
	Game.from_dict({"charms_owned": ["clover", "bogus", "coin", "shell", "moonstone"],
		"charms_equipped": ["clover", "coin", "shell", "moonstone", "starfall", "bogus"]})
	t.check(not Game.charms_owned.has("bogus"), "unknown owned charm is dropped on load")
	t.check(Game.charms_equipped.size() <= CharmDB.SLOTS, "worn charms are capped to the slot count on load")
	t.check(not Game.charms_equipped.has("starfall") and not Game.charms_equipped.has("bogus"), "worn charm that is not owned is dropped")
	# an old save without charm keys still loads
	Game.from_dict({"money": 5})
	t.check(Game.money == 5 and Game.charms_owned.is_empty(), "old save without charms loads")
	Save.delete_save()
	_done += 1


func _calm_effect(t) -> void:
	# Same fish, same seeds: a calm charm must make the fight measurably easier,
	# and must not make it trivial.
	var base := _bot_wins(0.95, 0.30, 0.10, 0.0, 150)
	var calm := _bot_wins(0.95, 0.30, 0.10, 0.36, 150)
	print("   calm effect (hard fish, weak rod): no charm=%.2f  calm .36=%.2f" % [base, calm])
	t.check(calm > base + 0.05, "calm charm raises the win rate (%.2f -> %.2f)" % [base, calm])
	var m0 := ReelMinigame.new()
	m0.setup(0.8, 0.4, 0.2, 5, 0.0)
	var m1 := ReelMinigame.new()
	m1.setup(0.8, 0.4, 0.2, 5, 5.0)   # absurd value must be clamped
	var d0 := _fish_travel(m0)
	var d1 := _fish_travel(m1)
	t.check(d1 < d0 * 0.75, "calmer fish moves less (%.2f vs %.2f)" % [d1, d0])
	t.check(d1 > d0 * 0.3, "calm is capped: the fish still moves (%.2f vs %.2f)" % [d1, d0])
	_done += 1


func _fish_travel(m: ReelMinigame) -> float:
	# average fish speed (distance per played frame) so a fight that ends early
	# does not skew the comparison
	var travel := 0.0
	var last := m.fish_pos
	var frames := 0
	for i in 1200:
		if m.state != ReelMinigame.State.PLAYING:
			break
		var predicted: float = m.bar_pos + m.bar_vel * 0.18
		m.update(1.0 / 60.0, predicted < m.fish_pos)
		travel += absf(m.fish_pos - last)
		last = m.fish_pos
		frames += 1
	return travel / maxf(1.0, float(frames)) * 60.0


func _bot_wins(diff: float, control: float, resil: float, calm: float, runs: int) -> float:
	var wins := 0
	for i in runs:
		var m := ReelMinigame.new()
		m.setup(diff, control, resil, 2000 + i, calm)
		var guard := 0
		var hist: Array[float] = []
		while m.state == ReelMinigame.State.PLAYING and guard < 6000:
			hist.append(m.fish_pos)
			var seen: float = hist[maxi(0, hist.size() - 16)]
			var predicted: float = m.bar_pos + m.bar_vel * 0.18
			m.update(1.0 / 60.0, predicted < seen)
			guard += 1
		if m.state == ReelMinigame.State.WON:
			wins += 1
	return float(wins) / runs


func _swim_rules(t) -> void:
	var lc: Vector2 = Terrain.LAKE_C
	t.check(not Terrain.walkable(lc.x, lc.y), "lake centre is too deep to wade")
	t.check(Terrain.swimmable(lc.x, lc.y), "lake centre can be swum")
	t.check(Terrain.passable(lc.x, lc.y), "lake centre is passable")
	var ri: Vector2 = Terrain.RIVER[3]
	t.check(Terrain.passable(ri.x, ri.y), "river is passable")
	t.check(Terrain.passable(Terrain.VILLAGE.x, Terrain.VILLAGE.y) and not Terrain.swimmable(Terrain.VILLAGE.x, Terrain.VILLAGE.y), "village is dry land, not 'swimmable'")
	t.check(not Terrain.passable(399.0, 0.0) and not Terrain.swimmable(-399.0, 0.0), "world edge is blocked")
	# the open ocean far from every shore is never swimmable
	var ocean_swim := 0
	var ocean_n := 0
	for x in range(-380, 381, 20):
		for z in range(-380, 381, 20):
			if Terrain.water_type_at(float(x), float(z)) in ["ocean", "deep", "arctic", "swamp"]:
				ocean_n += 1
				if Terrain.swimmable(float(x), float(z)):
					ocean_swim += 1
	t.check(ocean_n > 100 and ocean_swim == 0, "open sea is not swimmable (%d of %d cells)" % [ocean_swim, ocean_n])
	_done += 1


func _islands(t) -> void:
	# Flood-fill everything the player can reach from the village on foot or by
	# swimming. The main island must be fully connected; the far islands must not.
	var step := 4.0
	var half := int(Terrain.WORLD_HALF / step)
	var size := half * 2 + 1
	var seen := PackedByteArray()
	seen.resize(size * size)
	var start := Vector2i(int(Terrain.VILLAGE.x / step) + half, int(Terrain.VILLAGE.y / step) + half)
	var stack: Array[Vector2i] = [start]
	seen[start.y * size + start.x] = 1
	var reached := 1
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= size or n.y >= size or seen[n.y * size + n.x] == 1:
				continue
			if Terrain.passable((n.x - half) * step, (n.y - half) * step):
				seen[n.y * size + n.x] = 1
				reached += 1
				stack.append(n)
	var is_reached := func(p: Vector2) -> bool:
		return seen[(int(roundf(p.y / step)) + half) * size + int(roundf(p.x / step)) + half] == 1
	print("   reachable cells from village: %d" % reached)
	for pair in [["factory", Terrain.FACTORY], ["hamlet", Terrain.HAMLET]]:
		t.check(is_reached.call(pair[1]), "%s is reachable on the main island" % pair[0])
	t.check(is_reached.call(Terrain.LAKE_C), "lake centre is reachable (by swimming)")
	for pair in [["bog island", Terrain.BOG], ["frost island", Terrain.FROST], ["trench platform", Terrain.TRENCH]]:
		t.check(not is_reached.call(pair[1]), "%s stays unreachable without the ferry" % pair[0])
	_done += 1


func _player_constants(t) -> void:
	t.check(Player.WALK_SPEED >= 6.5 and Player.RUN_SPEED >= 11.0, "base movement is faster than before (walk %.1f run %.1f)" % [Player.WALK_SPEED, Player.RUN_SPEED])
	t.check(Player.SWIM_SPEED > 3.0 and Player.SWIM_SPEED < Player.RUN_SPEED, "swimming is slower than running but usable")
	t.check(Player.COYOTE_TIME > 0.0 and Player.JUMP_BUFFER > 0.0, "jump forgiveness is enabled")
	_done += 1
