class_name Assistants
extends RefCounted
## Hired assistant anglers. They fish in the background (even while the app is
## closed, capped at 8 hours) and drop their catch into the dock crate.

const MAX_OFFLINE := 28800.0


static func count() -> int:
	return Game.upgrade_level("assistants")


static func skill() -> int:
	return Game.upgrade_level("assistant_skill")


## Seconds one assistant needs per catch.
static func interval() -> float:
	return maxf(20.0, 75.0 - 9.0 * skill())


static func tick() -> void:
	var n := count()
	var now := Util.now()
	var last := float(Game.flags.get("assist_last", now))
	Game.flags["assist_last"] = now
	if n <= 0:
		Game.flags["assist_acc"] = 0.0
		return
	var acc := float(Game.flags.get("assist_acc", 0.0)) + clampf(now - last, 0.0, MAX_OFFLINE) * n
	var iv := interval()
	var caught := 0
	while acc >= iv and Game.crate.size() < Game.warehouse_capacity():
		acc -= iv
		var f := roll_assistant_catch()
		if not f.is_empty():
			Game.crate.append(f)
			caught += 1
	# Don't bank unlimited time while the crate is full.
	Game.flags["assist_acc"] = minf(acc, iv)
	if caught > 0:
		Game.facilities_changed.emit()
		if caught >= 1 and not Game.flags.get("crate_told", false):
			Game.flags["crate_told"] = true
			Game.notify.emit("Your assistants caught fish - collect them from the dock crate.", "info")


static func roll_assistant_catch(rng: RandomNumberGenerator = null) -> Dictionary:
	var waters: Array = []
	for w in ["shore", "lake", "river", "ocean", "swamp", "arctic", "deep"]:
		if Game.has_water_access(w):
			waters.append(w)
	if waters.is_empty():
		return {}
	var water: String = waters[(rng.randi() if rng else randi()) % waters.size()]
	var luck := 0.1 + 0.18 * skill()
	var f := FishLogic.roll_catch(water, luck, 0.0, 12.0, "clear", rng)
	if not f.is_empty():
		f["w"] = f["w"] * 0.9
	return f


## Moves crate contents into the backpack. Returns how many were moved.
static func collect_crate() -> int:
	var moved := 0
	while not Game.crate.is_empty() and Game.has_space():
		Game.add_fish(Game.crate.pop_front())
		moved += 1
	if moved > 0:
		Game.flags["crate_told"] = false
		Game.facilities_changed.emit()
	return moved
