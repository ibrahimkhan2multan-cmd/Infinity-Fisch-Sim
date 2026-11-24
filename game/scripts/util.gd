class_name Util
extends RefCounted
## Small shared helpers (formatting, colours, deterministic noise).

const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"]
const RARITY_COLORS: Array[Color] = [
	Color("b8c4cc"), Color("5fd16a"), Color("4aa8ff"),
	Color("b569ff"), Color("ffb02e"), Color("ff4d6d"),
]
## Base selection weights per rarity for the fish roll.
const RARITY_WEIGHTS: Array[float] = [60.0, 25.0, 10.0, 4.0, 0.9, 0.1]
## XP awarded for catching a fish of each rarity.
const RARITY_XP: Array[int] = [5, 12, 30, 80, 200, 600]

const WATER_NAMES := {
	"shore": "Shallows", "ocean": "Open Sea", "lake": "Mirror Lake",
	"river": "Silverrun River", "swamp": "Mangrove Bog",
	"arctic": "Frostfin Waters", "deep": "Abyss Trench",
}


static func money(n: int) -> String:
	var neg := n < 0
	var v := absi(n)
	var s: String
	if v >= 1_000_000_000:
		s = "%.2fB" % (v / 1_000_000_000.0)
	elif v >= 10_000_000:
		s = "%.1fM" % (v / 1_000_000.0)
	elif v >= 1_000_000:
		s = "%.2fM" % (v / 1_000_000.0)
	else:
		s = _commas(v)
	return ("-$" if neg else "$") + s


static func _commas(v: int) -> String:
	var s := str(v)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


static func duration(sec: float) -> String:
	var t := maxi(0, int(ceil(sec)))
	if t >= 3600:
		return "%dh %02dm" % [t / 3600, (t % 3600) / 60]
	if t >= 60:
		return "%dm %02ds" % [t / 60, t % 60]
	return "%ds" % t


static func weight_text(kg: float) -> String:
	if kg < 1.0:
		return "%d g" % int(round(kg * 1000.0))
	return "%.1f kg" % kg


static func clock_text(hour: float) -> String:
	var h := int(hour) % 24
	var m := int((hour - floor(hour)) * 60.0)
	return "%02d:%02d" % [h, m]


static func rarity_color(r: int) -> Color:
	return RARITY_COLORS[clampi(r, 0, RARITY_COLORS.size() - 1)]


static func rarity_name(r: int) -> String:
	return RARITY_NAMES[clampi(r, 0, RARITY_NAMES.size() - 1)]


## Deterministic pseudo-random float in [0,1) from an int seed.
static func hash01(seed_value: int) -> float:
	var x := seed_value & 0x7fffffff
	x = ((x >> 16) ^ x) * 0x45d9f3b
	x = x & 0x7fffffff
	x = ((x >> 16) ^ x) * 0x45d9f3b
	x = x & 0x7fffffff
	x = (x >> 16) ^ x
	return float(x & 0xffff) / 65536.0


static func str_hash(s: String) -> int:
	return absi(s.hash()) & 0x7fffffff


## Picks an index according to a list of weights.
static func weighted_index(weights: Array, rng: RandomNumberGenerator = null) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return -1
	var r := (rng.randf() if rng else randf()) * total
	for i in weights.size():
		r -= float(weights[i])
		if r <= 0.0:
			return i
	return weights.size() - 1


static func now() -> float:
	return Time.get_unix_time_from_system()
