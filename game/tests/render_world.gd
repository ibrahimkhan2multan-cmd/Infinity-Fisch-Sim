extends SceneTree
## Dev tool (not part of the automated tests): renders screenshots of the world
##   xvfb-run -a godot --rendering-driver opengl3 --path game -s res://tests/render_world.gd -- /tmp/shots
## Each entry: [name, hour, weather, camera pos, look-at]

const SHOTS := [
	["village_day", 11.0, "clear", Vector3(-20, 11, 92), Vector3(-22, 3, 52)],
	["pier_sea", 15.0, "clear", Vector3(-20, 5, 125), Vector3(-20, 0, 190)],
	["aerial", 12.0, "clear", Vector3(0, 190, 330), Vector3(0, 0, 40)],
	["lake", 10.0, "clear", Vector3(-10, 14, -40), Vector3(40, 0, -75)],
	["factory", 14.0, "cloudy", Vector3(112, 12, 42), Vector3(112, 4, 8)],
	["village_night", 23.0, "clear", Vector3(-20, 11, 92), Vector3(-22, 3, 52)],
	["storm", 15.0, "storm", Vector3(-20, 6, 112), Vector3(-20, 1, 175)],
	["sunset", 17.4, "clear", Vector3(-20, 8, 118), Vector3(-60, 6, 160)],
]


func _initialize() -> void:
	# watchdog so a broken build can never hang the run
	create_timer(240.0).timeout.connect(func(): print("WATCHDOG: timed out"); quit(2))
	var out_dir := "/tmp/shots"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	# loaded at runtime: autoload names are not known when this script compiles
	var world_script: GDScript = load("res://scripts/world/world.gd")
	if world_script == null:
		push_error("world.gd failed to load")
		quit(1)
		return
	await process_frame  # let the root finish initialising before adding nodes
	var world = world_script.new()
	root.add_child(world)
	var t0 := Time.get_ticks_msec()
	await world.build_async()
	print("world built in %d ms" % (Time.get_ticks_msec() - t0))
	var cam := Camera3D.new()
	cam.far = 600.0
	world.add_child(cam)
	cam.current = true
	world.player.visible = false
	var clock = root.get_node("Clock")
	clock.running = false
	for s in SHOTS:
		clock.hour = s[1]
		clock.set_weather(s[2])
		cam.global_position = s[3]
		cam.look_at(s[4])
		world.sky.follow = cam
		for i in 4:
			world.sky._process(5.0)
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png("%s/%s.png" % [out_dir, s[0]])
		print("saved ", s[0], " ", img.get_size())
	quit(0)
