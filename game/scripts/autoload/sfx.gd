extends Node
## Procedurally generated sound effects (autoload "Sfx"). No audio files are
## needed: each sound is synthesised once at start-up into an AudioStreamWAV.
## Plays on the "SFX" bus, whose volume is controlled by Settings.

const RATE := 22050
const POOL := 8

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	# name: [f0, f1, duration, volume, noise, wave]
	_sounds["click"] = _synth(900, 700, 0.06, 0.35, 0.0, "sine")
	_sounds["coin"] = _chord([1318, 1760], 0.22, 0.4)
	_sounds["cast"] = _synth(300, 900, 0.28, 0.35, 0.5, "noise")
	_sounds["splash"] = _synth(500, 120, 0.35, 0.5, 0.9, "noise")
	_sounds["bite"] = _chord([880, 1175, 1568], 0.3, 0.55)
	_sounds["reel"] = _synth(220, 260, 0.08, 0.25, 0.2, "square")
	_sounds["catch"] = _chord([523, 659, 784, 1046], 0.5, 0.5)
	_sounds["rare"] = _chord([523, 659, 784, 1046, 1318, 1568], 0.9, 0.55)
	_sounds["error"] = _synth(200, 120, 0.18, 0.4, 0.0, "square")
	_sounds["level_up"] = _chord([392, 523, 659, 784], 0.7, 0.5)
	_sounds["thunder"] = _synth(90, 30, 1.2, 0.7, 0.9, "noise")
	_sounds["escape"] = _synth(600, 150, 0.35, 0.4, 0.2, "sine")
	_sounds["step"] = _synth(120, 80, 0.05, 0.12, 0.7, "noise")
	_sounds["cook"] = _synth(300, 300, 0.4, 0.25, 0.8, "noise")
	_sounds["ferry"] = _chord([196, 247, 294], 0.8, 0.4)


func play(sound: String, volume_scale := 1.0, pitch := 1.0) -> void:
	if not _sounds.has(sound) or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[sound]
	p.volume_db = linear_to_db(clampf(volume_scale, 0.01, 2.0))
	p.pitch_scale = pitch
	p.play()


func _synth(f0: float, f1: float, dur: float, vol: float, noise: float, wave: String) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += TAU * f / RATE
		var s: float
		match wave:
			"square": s = 1.0 if sin(phase) >= 0.0 else -1.0
			"noise": s = rng.randf_range(-1.0, 1.0)
			_: s = sin(phase)
		if noise > 0.0 and wave != "noise":
			s = lerpf(s, rng.randf_range(-1.0, 1.0), noise)
		var env := minf(1.0, t * 30.0) * pow(1.0 - t, 2.0)
		var v := int(clampf(s * env * vol, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	return _wav(data)


func _chord(freqs: Array, dur: float, vol: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / n
		var s := 0.0
		for k in freqs.size():
			# stagger note starts for an arpeggio feel
			var start := float(k) / freqs.size() * 0.5
			if t >= start:
				var local := (t - start) / (1.0 - start)
				s += sin(TAU * float(freqs[k]) * i / RATE) * pow(1.0 - local, 2.0)
		s /= float(freqs.size()) * 0.7
		var env := minf(1.0, t * 40.0)
		var v := int(clampf(s * env * vol, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
