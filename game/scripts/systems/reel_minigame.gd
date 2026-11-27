class_name ReelMinigame
extends RefCounted
## The reeling fight. A horizontal track (0..1): keep the player's bar over the
## fish while holding/releasing the reel button. Pure logic - no nodes - so it
## can be unit-tested and driven by the HUD.

enum State { PLAYING, WON, LOST }

var state: State = State.PLAYING
var fish_pos := 0.5
var bar_pos := 0.5
var bar_vel := 0.0
var bar_size := 0.3
var progress := 0.35
var elapsed := 0.0
var difficulty := 0.3

var _gain := 0.2
var _loss := 0.15
var _fish_target := 0.5
var _retarget_in := 1.0
var _dash_left := 0.0
var _calm := 0.0   ## charms: fraction the fish is slowed by
var _rng := RandomNumberGenerator.new()

const MAX_SPEED := 0.95
const ACCEL := 5.5
const GRACE := 1.2
const TIME_LIMIT := 50.0


func setup(fish_difficulty: float, control: float, resilience: float, seed_value: int = -1, calm: float = 0.0) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	difficulty = clampf(fish_difficulty, 0.0, 1.0)
	_calm = clampf(calm, 0.0, CharmDB.MAX_CALM)
	bar_size = clampf(control, 0.15, 0.9)
	_gain = 0.19 + 0.08 * (1.0 - difficulty)
	_loss = (0.10 + 0.20 * difficulty) * (1.0 - 0.6 * clampf(resilience, 0.0, 1.0))
	fish_pos = _rng.randf_range(0.3, 0.7)
	_fish_target = fish_pos
	bar_pos = 0.5
	bar_vel = 0.0
	progress = 0.35
	elapsed = 0.0
	state = State.PLAYING
	_retarget_in = 0.8


func in_zone() -> bool:
	return absf(fish_pos - bar_pos) <= bar_size * 0.5


func update(dt: float, holding: bool) -> void:
	if state != State.PLAYING:
		return
	elapsed += dt
	# --- player bar ---
	var target_vel := MAX_SPEED if holding else -MAX_SPEED
	bar_vel = move_toward(bar_vel, target_vel, ACCEL * dt)
	bar_pos += bar_vel * dt
	var lo := bar_size * 0.5
	var hi := 1.0 - bar_size * 0.5
	if bar_pos < lo:
		bar_pos = lo
		bar_vel = maxf(0.0, bar_vel * -0.2)
	elif bar_pos > hi:
		bar_pos = hi
		bar_vel = minf(0.0, bar_vel * -0.2)
	# --- fish ---
	_retarget_in -= dt
	if _retarget_in <= 0.0:
		_retarget_in = lerpf(1.5, 0.45, difficulty) * _rng.randf_range(0.7, 1.3)
		_fish_target = _rng.randf_range(0.06, 0.94)
		if difficulty > 0.5 and _rng.randf() < difficulty * 0.35:
			_dash_left = 0.35 * (1.0 - _calm)
	var speed := lerpf(0.28, 0.85, difficulty) * (1.0 - _calm)
	if _dash_left > 0.0:
		_dash_left -= dt
		speed *= 2.2
	fish_pos = move_toward(fish_pos, _fish_target, speed * dt)
	# --- progress ---
	if in_zone():
		progress += _gain * dt
	elif elapsed > GRACE:
		progress -= _loss * dt
	progress = clampf(progress, 0.0, 1.0)
	if progress >= 1.0:
		state = State.WON
	elif progress <= 0.0 or elapsed > TIME_LIMIT:
		state = State.LOST


## Simple bot used by tests: chases the fish with a little look-ahead.
func bot_holding() -> bool:
	var predicted := bar_pos + bar_vel * 0.18
	return predicted < fish_pos
