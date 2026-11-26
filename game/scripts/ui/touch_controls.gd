class_name TouchControls
extends Control
## Virtual joystick, camera-drag pad and action buttons for phones.
## Everything is tracked per finger index, so you can hold the stick, drag the
## camera and press Cast at the same time. On desktop the mouse is emulated as
## finger 0 (project setting emulate_touch_from_mouse), WASD/F/E also work.

signal use_pressed
signal pause_pressed
signal bag_pressed
signal dex_pressed

const DEAD := 0.14

var player: Player
var fishing: FishingController
var enabled := true : set = _set_enabled

var action_btn: TouchButton
var use_btn: TouchButton
var jump_btn: TouchButton
var run_btn: TouchButton
var pause_btn: TouchButton
var bag_btn: TouchButton
var dex_btn: TouchButton

var _buttons: Array[TouchButton] = []
var _finger_button: Dictionary = {}   ## finger index -> TouchButton
var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_finger := -1
var _move := Vector2.ZERO
var _joy_zone := Rect2()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	action_btn = _add_button("CAST", 74.0, Color(0.1, 0.6, 0.85))
	use_btn = _add_button("USE", 54.0, Color(0.25, 0.7, 0.4))
	jump_btn = _add_button("JUMP", 42.0, Color(0.5, 0.45, 0.75))
	run_btn = _add_button("RUN", 42.0, Color(0.75, 0.55, 0.2))
	pause_btn = _add_button("MENU", 36.0, Color(0.35, 0.4, 0.5))
	bag_btn = _add_button("BAG", 36.0, Color(0.35, 0.4, 0.5))
	dex_btn = _add_button("DEX", 36.0, Color(0.35, 0.4, 0.5))
	for b in [action_btn, use_btn, jump_btn, run_btn]:
		(b as TouchButton).font_size = 22
	for b in [pause_btn, bag_btn, dex_btn]:
		(b as TouchButton).font_size = 18
	use_btn.tapped.connect(func(): use_pressed.emit())
	pause_btn.tapped.connect(func(): pause_pressed.emit())
	bag_btn.tapped.connect(func(): bag_pressed.emit())
	dex_btn.tapped.connect(func(): dex_pressed.emit())
	jump_btn.pressed_down.connect(_do_jump)
	run_btn.tapped.connect(func():
		if player:
			player.run_toggle = not player.run_toggle)
	action_btn.pressed_down.connect(_action_down)
	action_btn.released.connect(_action_up)
	use_btn.visible = false
	resized.connect(layout)
	Settings.changed.connect(layout)
	layout()


func _add_button(text: String, radius: float, tint: Color) -> TouchButton:
	var b := TouchButton.new(text, radius, tint)
	add_child(b)
	_buttons.append(b)
	return b


func bind(p: Player) -> void:
	player = p
	fishing = p.fishing


## Places buttons and the joystick zone for the current screen size and handedness.
func layout() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0:
		w = 1280.0
		h = 720.0
	var left := Settings.left_handed
	var sc := clampf(Settings.joystick_scale, 0.7, 1.5)
	_place(action_btn, Vector2(w - 125.0, h - 135.0), left)
	_place(use_btn, Vector2(w - 285.0, h - 105.0), left)
	_place(jump_btn, Vector2(w - 85.0, h - 290.0), left)
	_place(run_btn, Vector2(w - 230.0, h - 250.0), left)
	pause_btn.position = Vector2(w - 50.0 - pause_btn.radius, 14.0)
	bag_btn.position = Vector2(w - 50.0 - pause_btn.radius * 3.0 - 14.0, 14.0)
	dex_btn.position = Vector2(w - 50.0 - pause_btn.radius * 5.0 - 28.0, 14.0)
	var zw := w * 0.42 * sc
	_joy_zone = Rect2(0.0, h * 0.32, zw, h * 0.68)
	if left:
		_joy_zone.position.x = w - zw
	queue_redraw()


func _place(b: TouchButton, center_pos: Vector2, mirror: bool) -> void:
	var c := center_pos
	if mirror:
		c.x = size.x - c.x
	b.position = c - b.size * 0.5


func _set_enabled(v: bool) -> void:
	enabled = v
	visible = v
	if not v:
		release_all()


func release_all() -> void:
	for f in _finger_button.keys():
		(_finger_button[f] as TouchButton).set_down(false)
	_finger_button.clear()
	_stick_finger = -1
	_look_finger = -1
	_apply_move(Vector2.ZERO)
	queue_redraw()


# ---- input ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_finger_down(t.index, t.position)
		else:
			_finger_up(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_finger_move(d.index, d.position, d.relative)


func _finger_down(idx: int, pos: Vector2) -> void:
	for i in range(_buttons.size() - 1, -1, -1):
		var b := _buttons[i]
		if b.contains(pos):
			_finger_button[idx] = b
			b.set_down(true)
			return
	if _stick_finger == -1 and _joy_zone.has_point(pos):
		_stick_finger = idx
		_stick_origin = pos
		_stick_pos = pos
		queue_redraw()
		return
	if _look_finger == -1:
		_look_finger = idx


func _finger_up(idx: int) -> void:
	if _finger_button.has(idx):
		var b: TouchButton = _finger_button[idx]
		_finger_button.erase(idx)
		var was_down := b.is_down
		b.set_down(false)
		if was_down:
			b.tapped.emit()
		return
	if idx == _stick_finger:
		_stick_finger = -1
		_apply_move(Vector2.ZERO)
		queue_redraw()
	elif idx == _look_finger:
		_look_finger = -1


func _finger_move(idx: int, pos: Vector2, rel: Vector2) -> void:
	if idx == _stick_finger:
		var radius := 95.0 * clampf(Settings.joystick_scale, 0.7, 1.5)
		var off := pos - _stick_origin
		if off.length() > radius:
			# drag the origin along so the stick never "sticks" at the edge
			_stick_origin = pos - off.normalized() * radius
			off = pos - _stick_origin
		_stick_pos = _stick_origin + off
		var v := off / radius
		if v.length() < DEAD:
			v = Vector2.ZERO
		_apply_move(v.limit_length(1.0))
		queue_redraw()
	elif idx == _look_finger and player:
		player.add_look(rel)


func _apply_move(v: Vector2) -> void:
	_move = v
	_set_action("move_right", maxf(v.x, 0.0))
	_set_action("move_left", maxf(-v.x, 0.0))
	_set_action("move_back", maxf(v.y, 0.0))
	_set_action("move_forward", maxf(-v.y, 0.0))


func _set_action(a: String, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(a, strength)
	else:
		Input.action_release(a)


func joystick_vector() -> Vector2:
	return _move


# ---- buttons -------------------------------------------------------------------

func _do_jump() -> void:
	Input.action_press("jump")
	get_tree().create_timer(0.12).timeout.connect(func(): Input.action_release("jump"))


func _action_down() -> void:
	if fishing == null:
		return
	match fishing.state:
		FishingController.State.IDLE, FishingController.State.WAITING:
			fishing.press_cast()
		FishingController.State.BITE:
			fishing.hook()


func _action_up() -> void:
	if fishing == null:
		return
	if fishing.state == FishingController.State.CHARGING:
		fishing.release_cast()


func _process(_delta: float) -> void:
	if not enabled:
		return
	# keyboard parity for desktop testing
	if Input.is_action_just_pressed("cast"):
		_action_down()
		action_btn.is_down = true
	elif Input.is_action_just_released("cast"):
		action_btn.is_down = false
		_action_up()
	if Input.is_action_just_pressed("interact") and use_btn.visible:
		use_pressed.emit()
	if player == null or fishing == null:
		return
	# context-sensitive labels
	var st := fishing.state
	match st:
		FishingController.State.IDLE:
			action_btn.text = "CAST"
		FishingController.State.CHARGING:
			action_btn.text = "RELEASE"
		FishingController.State.CASTING:
			action_btn.text = "..."
		FishingController.State.WAITING:
			action_btn.text = "REEL\nIN"
		FishingController.State.BITE:
			action_btn.text = "HOOK!"
		FishingController.State.REELING:
			action_btn.text = "REEL"
		FishingController.State.RESULT:
			action_btn.text = "..."
	action_btn.pulse = st == FishingController.State.BITE
	action_btn.highlighted = st == FishingController.State.REELING
	if st == FishingController.State.REELING:
		fishing.set_reel(action_btn.is_down)
	# interact button
	var near := player.nearest
	var show_use := near != null and st == FishingController.State.IDLE
	if show_use:
		use_btn.text = "USE"
	use_btn.visible = show_use
	run_btn.text = "WALK" if player.run_toggle else "RUN"
	run_btn.highlighted = player.run_toggle
	queue_redraw_if_stick()


func queue_redraw_if_stick() -> void:
	if _stick_finger != -1:
		queue_redraw()


func _draw() -> void:
	# joystick: floating base where the thumb went down, knob follows
	if _stick_finger != -1:
		var radius := 95.0 * clampf(Settings.joystick_scale, 0.7, 1.5)
		draw_circle(_stick_origin, radius, Color(1, 1, 1, 0.12))
		draw_arc(_stick_origin, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 3.0, true)
		draw_circle(_stick_pos, radius * 0.42, Color(1, 1, 1, 0.55))
	elif enabled:
		# faint hint where the stick will appear
		var hint := _joy_zone.get_center() + Vector2(0, _joy_zone.size.y * 0.1)
		var r := 95.0 * clampf(Settings.joystick_scale, 0.7, 1.5)
		draw_arc(hint, r, 0.0, TAU, 48, Color(1, 1, 1, 0.16), 3.0, true)
