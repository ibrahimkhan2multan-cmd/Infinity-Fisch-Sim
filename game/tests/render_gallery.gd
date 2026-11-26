extends SceneTree
## Dev tool (not part of the automated tests): close-up screenshots of the
## baked models (fish, rods, people, boat, buildings, trees) on a neutral stage.
##   xvfb-run -a godot --rendering-driver opengl3 --path game -s res://tests/render_gallery.gd -- /tmp/gallery

var _cam: Camera3D


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func(): print("WATCHDOG"); quit(2))
	var out_dir := "/tmp/gallery"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	var stage := Node3D.new()
	root.add_child(stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9fc4e8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.85)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("6fae58")
	floor_mi.material_override = fm
	stage.add_child(floor_mi)
	_cam = Camera3D.new()
	_cam.fov = 40
	stage.add_child(_cam)
	_cam.current = true

	# ---- fish: one of each shape, by species colours
	var species: Dictionary = FishDB.build()
	var by_shape := {0: [], 1: [], 2: [], 3: [], 4: []}
	for id in species:
		var sp: DataTypes.FishSpecies = species[id]
		if by_shape[sp.shape].size() < 3:
			by_shape[sp.shape].append(sp)
	var fish_root := Node3D.new()
	stage.add_child(fish_root)
	var x := 0.0
	for sh in by_shape:
		for sp: DataTypes.FishSpecies in by_shape[sh]:
			var mi := MeshInstance3D.new()
			mi.mesh = Props.fish_mesh(sp.c1, sp.c2, sp.shape)
			mi.position = Vector3(x, 0.8, 0)
			mi.rotation.y = deg_to_rad(-65)
			mi.scale = Vector3.ONE * 1.4
			fish_root.add_child(mi)
			x += 1.35
	await _shot(out_dir, "fish", Vector3(x * 0.5 - 0.7, 1.8, 7.5), Vector3(x * 0.5 - 0.7, 0.8, 0))
	fish_root.queue_free()

	# ---- rods laid out horizontally, grip left, tip right
	var rods: Dictionary = GearDB.build_rods()
	var rods_root := Node3D.new()
	stage.add_child(rods_root)
	var i := 0
	for id in rods:
		var built: Dictionary = RodModel.build(rods[id], 2.4)
		var mi2 := MeshInstance3D.new()
		mi2.mesh = built["mesh"]
		mi2.rotation.z = deg_to_rad(90)
		mi2.position = Vector3(-1.2, 3.0 - i * 0.55, 0)
		rods_root.add_child(mi2)
		i += 1
	await _shot(out_dir, "rods", Vector3(0.5, 1.6, 7.0), Vector3(0.1, 1.6, 0))
	await _shot(out_dir, "rods_grips", Vector3(-1.0, 1.7, 3.2), Vector3(-0.9, 1.7, 0))
	rods_root.queue_free()

	# ---- people
	var people := Node3D.new()
	stage.add_child(people)
	var specs := [[Color("e8584a"), Color("2f4a7a"), Color("e0b08a"), Color("f2c230"), "cap"],
		[Color("3aa6a0"), Color("5a4a3a"), Color("a8744f"), Color("e8cf86"), "straw"],
		[Color("8a5ac8"), Color("3a3a4a"), Color("e0b08a"), Color("6a6a7a"), "hood"],
		[Color("e0a030"), Color("2a3a5a"), Color("c68c62"), Color("d04a3a"), "cap"]]
	for k in specs.size():
		var m := CharacterModel.new()
		m.setup(specs[k][0], specs[k][1], specs[k][2], specs[k][3], specs[k][4])
		m.position = Vector3(-2.7 + k * 1.8, 0, 0)
		m.rotation.y = deg_to_rad(-15 + k * 8)
		people.add_child(m)
		if k == 0:
			m.pose = "fish"
			var holder := Node3D.new()
			m.rod_mount.add_child(holder)
			var rb: Dictionary = RodModel.build(rods["carbon_rod"], 2.4)
			var rmi := MeshInstance3D.new()
			rmi.mesh = rb["mesh"]
			holder.add_child(rmi)
			holder.rotation.x = 2.1 - 1.15
	for f in 20:
		for m in people.get_children():
			(m as CharacterModel).animate(0.1, 0.0)
	await _shot(out_dir, "people", Vector3(-0.2, 1.4, -5.4), Vector3(-0.2, 1.05, 0))
	await _shot(out_dir, "face", Vector3(-2.3, 1.9, -1.9), Vector3(-2.6, 1.72, 0))
	people.queue_free()

	# ---- boat, building, stall, trees
	var props := Node3D.new()
	stage.add_child(props)
	var boat := MeshInstance3D.new()
	boat.mesh = Props.boat()
	boat.position = Vector3(-7, 0.6, 0)
	boat.rotation.y = deg_to_rad(40)
	props.add_child(boat)
	var house := MeshInstance3D.new()
	house.mesh = Props.building(8, 6, 4.2, Color("d9b878"), Color("a8402c"), {"chimney": true})
	house.position = Vector3(3, 0, 0)
	house.rotation.y = deg_to_rad(-25)
	props.add_child(house)
	var st := MeshInstance3D.new()
	st.mesh = Props.stall(Color("d9534f"))
	st.position = Vector3(-1.5, 0, 6)
	props.add_child(st)
	var lp := MeshInstance3D.new()
	lp.mesh = Props.lantern_post()
	lp.position = Vector3(8.5, 0, 5)
	props.add_child(lp)
	await _shot(out_dir, "boat", Vector3(-3.2, 3.2, 8.0), Vector3(-7, 1.0, 0))
	await _shot(out_dir, "house", Vector3(5.0, 3.6, 14.0), Vector3(3, 2.4, 0))
	await _shot(out_dir, "stall", Vector3(-1.5, 2.2, 10.5), Vector3(-1.5, 1.4, 6))
	props.queue_free()
	var trees := Node3D.new()
	stage.add_child(trees)
	var kinds := ["pine", "frost_pine", "round", "palm", "mangrove", "dead", "bush", "reed", "grass", "flowers", "rock"]
	for k in kinds.size():
		var mi3 := MeshInstance3D.new()
		mi3.mesh = Props.rock_mesh() if kinds[k] == "rock" else Props.tree_mesh(kinds[k])
		mi3.position = Vector3(-18 + k * 3.6, 0, 0)
		trees.add_child(mi3)
	await _shot(out_dir, "trees_a", Vector3(-12, 3.5, 16), Vector3(-12, 2.2, 0))
	await _shot(out_dir, "trees_b", Vector3(10, 2.5, 11), Vector3(9, 0.8, 0))
	quit(0)


func _shot(dir: String, name: String, pos: Vector3, look: Vector3) -> void:
	_cam.position = pos
	_cam.look_at(look)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("saved ", name)
