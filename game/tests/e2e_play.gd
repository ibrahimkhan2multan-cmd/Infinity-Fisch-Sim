extends Node
## End-to-end playthrough of the real main scene using simulated touch input.
##   godot --headless --path game res://tests/e2e_play.tscn
## With a rendering driver and `-- /some/dir` it also writes screenshots.
## Exit code 1 if any check fails.

var checks := 0
var failures: Array[String] = []
var shots_dir := ""
var main: Node
var session: GameSession


func check(ok: bool, msg: String) -> void:
	checks += 1
	if not ok:
		failures.append(msg)
		print("  FAIL: ", msg)
	else:
		print("  ok:   ", msg)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func shot(name: String) -> void:
	if shots_dir == "":
		return
	await frames(3)
	await RenderingServer.frame_post_draw
	var img := get_tree().root.get_texture().get_image()
	img.save_png("%s/%s.png" % [shots_dir, name])


func touch(pos: Vector2, pressed: bool, idx := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	get_viewport().push_input(e, true)  # already in viewport coordinates


func drag(pos: Vector2, rel: Vector2, idx := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	e.relative = rel
	get_viewport().push_input(e, true)  # already in viewport coordinates


func _ready() -> void:
	get_tree().create_timer(170.0).timeout.connect(func():
		print("WATCHDOG: e2e timed out")
		get_tree().quit(2))
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		shots_dir = args[0]
		DirAccess.make_dir_recursive_absolute(shots_dir)
	_run()


func _run() -> void:
	await get_tree().process_frame
	# clean slate: no leftover save from a previous run
	Save.delete_save()
	var packed: PackedScene = load("res://scenes/main.tscn")
	main = packed.instantiate()
	get_tree().root.add_child(main)
	await frames(5)

	print("== main menu")
	var menu := _find(main, "MainMenu")
	check(menu != null, "main menu is shown")
	await shot("01_menu")
	menu.new_game.emit()

	print("== loading + world build")
	var waited := 0
	while not Game.in_game and waited < 600:
		await get_tree().process_frame
		waited += 1
	check(Game.in_game, "world built and game running (%d frames)" % waited)
	session = main.get_node("Session")
	check(session != null and session.world != null, "session + world exist")
	await frames(10)
	var player: Player = session.world.player
	await shot("02_hud_village")

	print("== joystick moves the player")
	var start := player.global_position
	var cam_pos := Vector2(200, 560)
	touch(cam_pos, true, 1)
	await frames(2)
	drag(cam_pos + Vector2(0, -80), Vector2(0, -80), 1)
	await frames(45)
	var moved := player.global_position.distance_to(start)
	check(moved > 1.5, "dragging the joystick walks the player (moved %.1f m)" % moved)
	await shot("03_walking")
	touch(cam_pos + Vector2(0, -80), false, 1)
	await frames(5)
	check(session.touch.joystick_vector() == Vector2.ZERO, "releasing the stick stops movement")

	print("== camera drag")
	var yaw0 := player.cam_yaw
	touch(Vector2(900, 300), true, 2)
	drag(Vector2(960, 300), Vector2(60, 0), 2)
	touch(Vector2(960, 300), false, 2)
	await frames(2)
	check(absf(player.cam_yaw - yaw0) > 0.01, "dragging the right side turns the camera")

	print("== swimming: walk from the bank into the lake")
	var bank := Vector3(30, 6.2, -26)
	player.teleport(bank, 0.0)    # facing -Z, towards the lake centre
	player.cam_yaw = 0.0
	await frames(20)
	check(not player.swimming, "standing on the bank is not swimming")
	var stick := Vector2(200, 560)
	touch(stick, true, 1)
	await frames(2)
	drag(stick + Vector2(0, -80), Vector2(0, -80), 1)
	var w := 0
	while not player.swimming and w < 900:
		await get_tree().process_frame
		w += 1
	check(player.swimming, "walking into deep water starts swimming (%d frames)" % w)
	await frames(30)
	await shot("03b_swimming")
	var lvl := Terrain.water_level_at(player.global_position.x, player.global_position.z)
	check(lvl != -INF and absf(player.global_position.y - (lvl - 1.0)) < 0.8,
		"swimmer floats at the surface (y %.2f, water %.2f)" % [player.global_position.y, lvl])
	var z0 := player.global_position.z
	w = 0
	while player.global_position.z > Terrain.LAKE_C.y + 4.0 and w < 1500:
		await get_tree().process_frame
		w += 1
	check(player.global_position.z < z0 - 5.0 and Terrain.passable(player.global_position.x, player.global_position.z),
		"keeps swimming across the lake (z %.1f -> %.1f)" % [z0, player.global_position.z])
	touch(stick + Vector2(0, -80), false, 1)
	await frames(5)
	player.teleport(Vector3(30, 6.2, -26), 0.0)
	await frames(10)
	check(not player.swimming, "back on the bank the swim state ends")

	print("== fishing from the pier with touch buttons")
	player.teleport(Vector3(-20, 3.2, 142), PI)
	await frames(10)
	var btn := session.touch.action_btn
	var c := btn.center()
	var fishing := player.fishing
	# give plenty of bait and a quick bite so the run is short
	Game.baits["worm"] = 20
	Game.bait = "worm"
	touch(c, true, 3)
	await frames(3)
	check(fishing.state == FishingController.State.CHARGING, "holding CAST starts charging")
	await frames(20)
	await shot("04_charging")
	fishing.message.connect(func(t: String, k: String): print("    [msg] ", t))
	print("    aim=", player.aim_dir(), " pos=", player.global_position, " power=", fishing.power, " range=", Game.fishing_stat("range"))
	touch(c, false, 3)
	await frames(3)
	check(fishing.state == FishingController.State.CASTING or fishing.state == FishingController.State.WAITING,
		"releasing CAST throws the line")
	waited = 0
	while fishing.state != FishingController.State.WAITING and waited < 200:
		await get_tree().process_frame
		waited += 1
	check(fishing.state == FishingController.State.WAITING, "bobber landed in water")
	check(fishing.water_type != "", "cast hit a water type: " + fishing.water_type)
	fishing._wait_left = 0.2
	waited = 0
	while fishing.state != FishingController.State.BITE and waited < 200:
		await get_tree().process_frame
		waited += 1
	check(fishing.state == FishingController.State.BITE, "a fish bites")
	await shot("05_bite")
	var fish_before: int = Game.fish.size()
	touch(c, true, 3)
	await frames(2)
	check(fishing.state == FishingController.State.REELING, "tapping HOOK starts the reel minigame")
	# hold / release like a player would, using the real button
	var t := 0
	while fishing.state == FishingController.State.REELING and t < 3000:
		var mg := fishing.minigame
		var want_hold := mg != null and (mg.bar_pos + mg.bar_vel * 0.18) < mg.fish_pos
		if want_hold != session.touch.action_btn.is_down:
			if want_hold:
				touch(c, true, 3)
			else:
				touch(c, false, 3)
		if t == 120:
			await shot("06_reeling")
		await get_tree().process_frame
		t += 1
	touch(c, false, 3)
	await frames(3)
	var caught: bool = Game.fish.size() > fish_before or Game.stats.get("caught", 0) > 0 or fishing.state == FishingController.State.RESULT
	check(fishing.state in [FishingController.State.RESULT, FishingController.State.IDLE],
		"reel minigame finished (state %d, frames %d)" % [fishing.state, t])
	if caught:
		check(Game.fish.size() > fish_before, "the catch is in the backpack")
		await shot("07_catch_popup")
	else:
		print("  (fish escaped this time - minigame is skill based; not a failure)")
	await frames(200)

	print("== panels")
	for name in ["inventory", "collection", "tackle", "general", "market", "hatchery", "kitchen", "factory", "guild", "ferry", "settings", "pause"]:
		session.open_panel(name)
		await frames(4)
		var p: PanelBase = session.panels[name]
		check(p.visible and p.content.get_child_count() > 0, "panel '%s' opens with content" % name)
		check(not session.touch.enabled, "touch controls are disabled while '%s' is open" % name)
		await shot("panel_" + name)
		p.close_panel()
		await frames(2)
		check(session.touch.enabled, "touch controls return after closing '%s'" % name)

	print("== buying through the UI path")
	Game.money = 5000
	var ing_before: int = 0
	for k in Game.ingredients:
		ing_before += int(Game.ingredients[k])
	var general: PanelShop = session.panels["general"]
	session.open_panel("general")
	await frames(3)
	var pressed := _press_first(general.content, "$")
	check(pressed, "found a buy button in the general store")
	await frames(3)
	var ing_after: int = 0
	for k in Game.ingredients:
		ing_after += int(Game.ingredients[k])
	check(ing_after > ing_before and Game.money < 5000, "pressing a shop button really buys and charges money")
	general.close_panel()
	await frames(2)

	print("== charms through the UI")
	Game.money = 5000
	var tackle: PanelShop = session.panels["tackle"]
	session.open_panel("tackle")
	await frames(2)
	tackle.tab = 2
	tackle.refresh()
	await frames(3)
	var charms_before: int = Game.charms_owned.size()
	var luck_before: float = Game.fishing_stat("luck")
	check(_press_first(tackle.content, "$"), "found a buy button on the Charms tab")
	await frames(3)
	check(Game.charms_owned.size() == charms_before + 1, "pressing Buy on a charm really buys it")
	check(Game.fishing_stat("luck") > luck_before or Game.fishing_stat("calm") > 0.0, "the bought charm is active")
	await shot("panel_charms")
	tackle.close_panel()
	await frames(2)
	session.open_panel("inventory")
	await frames(3)
	var inv: PanelBase = session.panels["inventory"]
	inv.tab = 1   # Gear
	inv.refresh()
	await frames(3)
	check(inv.content.get_child_count() > 3, "Gear tab lists rods, bait and charms")
	await shot("panel_inventory_charms")
	inv.close_panel()
	await frames(2)

	print("== rest, save and reload")
	var day0: int = Clock.day
	session._rest()
	await get_tree().create_timer(2.6).timeout
	check(Clock.day > day0 or Clock.hour == 6.0, "resting skips to morning")
	check(Save.has_save(), "resting writes a save file")
	var money_saved: int = Game.money
	var level_saved: int = Game.level
	Game.money = 1
	check(Save.load_game(), "save loads")
	check(Game.money == money_saved and Game.level == level_saved, "money and level survive the save round-trip")

	print("== ferry travel")
	Game.add_money(2000)
	Game.level = maxi(Game.level, 10)
	if not Game.permits.has("mangrove"):
		Game.permits.append("mangrove")
	var before_pos := player.global_position
	session._travel("bog")
	await get_tree().create_timer(2.4).timeout
	check(player.global_position.distance_to(before_pos) > 100.0, "ferry moved the player to the island")
	await shot("08_island")

	print("== back to the main menu")
	session._quit_to_menu()
	await frames(5)
	check(not Game.in_game, "leaving the session stops the game loop")
	check(_find(main, "MainMenu") != null, "main menu is back")

	print("")
	print("E2E checks: %d  failures: %d" % [checks, failures.size()])
	for m in failures:
		print("  - ", m)
	Save.delete_save()
	get_tree().quit(1 if failures.size() > 0 else 0)


func _find(node: Node, cls: String) -> Node:
	for c in node.get_children():
		if c.get_script() != null and (c.get_script() as GDScript).get_global_name() == cls:
			return c
	return null


## Emulates a tap on the first enabled button whose text contains `needle`.
func _press_first(node: Node, needle: String) -> bool:
	if node is Button and not (node as Button).disabled and (node as Button).text.contains(needle):
		(node as Button).pressed.emit()
		return true
	for c in node.get_children():
		if _press_first(c, needle):
			return true
	return false
