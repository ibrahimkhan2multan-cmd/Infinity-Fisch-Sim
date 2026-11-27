extends RefCounted
## Data integrity + pure game rules.


func run(t) -> void:
	_data(t)
	_fishing(t)
	_minigame(t)
	_economy_basics(t)


func _data(t) -> void:
	t.check(Data.fish.size() >= 45, "at least 45 fish species (have %d)" % Data.fish.size())
	for w in ["shore", "lake", "river", "ocean", "swamp", "arctic", "deep"]:
		var pool := Data.fish_for_water(w)
		t.check(pool.size() >= 6, "water '%s' has >= 6 species (have %d)" % [w, pool.size()])
		var rarities := {}
		for sp in pool:
			rarities[sp.rarity] = true
		t.check(rarities.has(0) and rarities.has(2) and rarities.has(4), "water '%s' spans common..legendary" % w)
	for sp in Data.fish.values():
		t.check(sp.min_w > 0.0 and sp.max_w > sp.min_w, "%s weight range valid" % sp.id)
		t.check(sp.price > 0 and sp.difficulty > 0.0 and sp.difficulty <= 1.0, "%s price/difficulty valid" % sp.id)
	t.check(Data.rods.size() >= 8, "8 rods")
	t.check(Data.recipes.size() >= 8, "8 recipes")
	for r in Data.recipes.values():
		for id in r.ingredients:
			t.check(Data.ingredients.has(id), "recipe %s ingredient %s exists" % [r.id, id])
	var last := -1
	for r in Data.rods.values():
		t.check(r.price >= last, "rods are sorted by price")
		last = r.price


func _fishing(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Rarity distribution: commons dominate, luck pushes rarity up.
	for water in ["shore", "lake", "ocean", "deep"]:
		var counts_lo := [0, 0, 0, 0, 0, 0]
		var counts_hi := [0, 0, 0, 0, 0, 0]
		for i in 3000:
			counts_lo[FishLogic.pick_species(water, 0.0, 12.0, "clear", rng).rarity] += 1
			counts_hi[FishLogic.pick_species(water, 2.5, 12.0, "clear", rng).rarity] += 1
		t.check(counts_lo[0] > counts_lo[2] and counts_lo[0] > 1000, "%s: commons dominate (%s)" % [water, counts_lo])
		var rare_lo: int = counts_lo[3] + counts_lo[4] + counts_lo[5]
		var rare_hi: int = counts_hi[3] + counts_hi[4] + counts_hi[5]
		t.check(rare_hi > rare_lo, "%s: luck increases epic+ catches (%d -> %d)" % [water, rare_lo, rare_hi])
	# Night / weather modifiers
	var night_hits := 0
	var day_hits := 0
	for i in 4000:
		if FishLogic.pick_species("lake", 1.0, 23.0, "clear", rng).id == "ghost_sturgeon":
			night_hits += 1
		if FishLogic.pick_species("lake", 1.0, 12.0, "clear", rng).id == "ghost_sturgeon":
			day_hits += 1
	t.check(night_hits > day_hits * 3, "night-only fish are far likelier at night (%d vs %d)" % [night_hits, day_hits])
	# weights & values
	var sp: DataTypes.FishSpecies = Data.fish["yellowfin_tuna"]
	for i in 200:
		var w := FishLogic.roll_weight(sp, 0.0, rng)
		t.check(w >= sp.min_w and w <= sp.max_w, "weight within species range")
	var f := FishLogic.make_fish("bluegill", 0.5)
	var v1 := FishLogic.fish_value(f)
	var heavy := FishLogic.make_fish("bluegill", 0.9)
	t.check(FishLogic.fish_value(heavy) > v1, "heavier fish is worth more")
	var golden := FishLogic.make_fish("bluegill", 0.5, "golden")
	t.check(FishLogic.fish_value(golden) > v1 * 3, "golden mutation > 3x value")
	t.check(FishLogic.fish_value(FishLogic.make_fish("not_a_fish", 1.0)) == 0, "unknown species has no value")
	# mutations occur at a sane rate
	var muts := 0
	for i in 10000:
		if FishLogic.roll_mutation(0.0, rng) != "":
			muts += 1
	t.check(muts > 400 and muts < 2000, "mutation rate ~12%% (%d/10000)" % muts)
	# bite timing scales with lure
	var slow := 0.0
	var fast := 0.0
	for i in 200:
		slow += FishLogic.bite_wait(1.0, 1.0, rng)
		fast += FishLogic.bite_wait(2.0, 1.0, rng)
	t.check(fast < slow * 0.7, "better lure bites sooner")


func _minigame(t) -> void:
	# A competent player (bot) should win easy fights with the starter rod and
	# usually beat hard fish with an endgame rod; hard fish + starter rod is hard.
	var easy_wins := _bot_win_rate(0.12, 0.30, 0.10, 100)
	var mid_wins := _bot_win_rate(0.55, 0.52, 0.35, 100)
	var hard_good := _bot_win_rate(0.95, 0.78, 0.80, 100)
	var hard_bad := _bot_win_rate(0.95, 0.30, 0.10, 100)
	print("   reel bot win rates: easy/twig=%.2f mid/carbon=%.2f hard/golden=%.2f hard/twig=%.2f" % [easy_wins, mid_wins, hard_good, hard_bad])
	t.check(easy_wins > 0.85, "easy fish with starter rod is reliably catchable (%.2f)" % easy_wins)
	t.check(mid_wins > 0.6, "mid fish with a mid rod is catchable (%.2f)" % mid_wins)
	t.check(hard_good > 0.5, "mythic with endgame rod is possible (%.2f)" % hard_good)
	t.check(hard_bad < easy_wins, "mythic with starter rod is harder than easy fish (%.2f)" % hard_bad)
	# Not holding at all must lose.
	var m := ReelMinigame.new()
	m.setup(0.6, 0.3, 0.1, 7)
	var guard := 0
	while m.state == ReelMinigame.State.PLAYING and guard < 100000:
		m.update(1.0 / 60.0, false)
		guard += 1
	t.check(m.state == ReelMinigame.State.LOST, "ignoring the reel button loses the fish")


func _bot_win_rate(diff: float, control: float, resil: float, runs: int) -> float:
	var wins := 0
	for i in runs:
		var m := ReelMinigame.new()
		m.setup(diff, control, resil, 1000 + i)
		var guard := 0
		var hist: Array[float] = []
		while m.state == ReelMinigame.State.PLAYING and guard < 6000:
			# human-like reaction: the bot only sees where the fish was ~0.25 s ago
			hist.append(m.fish_pos)
			var seen: float = hist[maxi(0, hist.size() - 16)]
			var predicted: float = m.bar_pos + m.bar_vel * 0.18
			m.update(1.0 / 60.0, predicted < seen)
			guard += 1
		if m.state == ReelMinigame.State.WON:
			wins += 1
	return float(wins) / runs


func _economy_basics(t) -> void:
	t.check(Util.money(1234) == "$1,234", "money formatting: %s" % Util.money(1234))
	t.check(Util.money(1_500_000) == "$1.50M", "money formatting M: %s" % Util.money(1_500_000))
	t.check(Util.duration(125) == "2m 05s", "duration formatting: %s" % Util.duration(125))
	t.check(Util.weight_text(0.25) == "250 g" and Util.weight_text(2.0) == "2.0 kg", "weight text")
	t.check(Game.xp_needed(1) < Game.xp_needed(10), "xp curve increases")
	# levelling must feel quick: a handful of common catches gives the first level-up,
	# and the whole 1 -> 40 climb stays within a sane total
	t.check(Game.xp_needed(1) <= 30, "first level-up needs little xp (%d)" % Game.xp_needed(1))
	var total := 0
	for lv in range(1, Game.MAX_LEVEL):
		total += Game.xp_needed(lv)
	t.check(total < 80000, "total xp to max level is moderate (%d)" % total)
	Game.reset_new_game()
	var common_xp: int = Util.RARITY_XP[0]
	Game.add_xp(common_xp)
	t.check(Game.xp == common_xp * 2 or Game.level > 1, "xp gains are doubled (%d)" % Game.xp)
	var guard := 0
	while Game.level < 2 and guard < 20:
		Game.add_xp(common_xp)
		guard += 1
	t.check(Game.level == 2 and guard <= 3, "level 2 after %d common catches" % (guard + 1))
