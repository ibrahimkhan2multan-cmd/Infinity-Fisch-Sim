class_name Terrain
extends RefCounted
## Analytic world description: height, water level, water type and biome at any
## (x, z). The meshes, collision, props, walking limits and fishing spot checks
## all query these functions, so they can never disagree.
##
## Layout (metres, +x east, +z south):
##   main continent  : ellipse around (0,-10)  - Driftwood Village (south), Mirror Lake (north),
##                     Silverrun River (north-east -> east coast), Cannery district (east)
##   Mangrove Bog    : island south-east        (ferry)
##   Frostfin Isle   : island north-west        (ferry)
##   Trench Platform : small island far south-west (ferry)

const WORLD_HALF := 400.0
const SEA_LEVEL := 0.0

const VILLAGE := Vector2(-20, 58)
const VILLAGE_R := 40.0
const VILLAGE_Y := 3.2
const FACTORY := Vector2(112, 14)
const FACTORY_R := 32.0
const FACTORY_Y := 3.6
const HAMLET := Vector2(-24, -60)
const HAMLET_R := 15.0
const HAMLET_Y := 4.6

const LAKE_C := Vector2(30, -72)
const LAKE_R := 34.0
const LAKE_LEVEL := 1.5

const BOG := Vector2(235, 190)
const BOG_R := 55.0
const FROST := Vector2(-255, -205)
const FROST_R := 50.0
const TRENCH := Vector2(-290, 250)
const TRENCH_R := 26.0
const ISLAND_Y := 2.6

const RIVER := [Vector2(62, -68), Vector2(85, -60), Vector2(105, -48), Vector2(126, -40),
	Vector2(142, -24), Vector2(158, -14), Vector2(178, -8)]
const RIVER_HALF := 3.4
const RIVER_WL_START := 1.5
const RIVER_WL_END := 0.35

static var _hills := FastNoiseLite.new()
static var _coast := FastNoiseLite.new()
static var _inited := false
## Oriented rectangles (piers, docks) where walking over water is allowed:
## {"c": Vector2, "yaw": float, "hl": half-length along local Z, "hw": half-width}
static var walk_zones: Array = []


static func init_noise() -> void:
	if _inited:
		return
	_inited = true
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.seed = 1337
	_hills.frequency = 0.011
	_hills.fractal_octaves = 3
	_coast.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_coast.seed = 99
	_coast.frequency = 0.016
	_coast.fractal_octaves = 2


## Signed "inland distance" in metres: >0 land, <0 sea.
static func signed_dist(x: float, z: float) -> float:
	var qx := x / 175.0
	var qz := (z + 10.0) / 130.0
	var best := (1.0 - sqrt(qx * qx + qz * qz)) * 140.0
	best = maxf(best, BOG_R - Vector2(x, z).distance_to(BOG))
	best = maxf(best, FROST_R - Vector2(x, z).distance_to(FROST))
	best = maxf(best, TRENCH_R - Vector2(x, z).distance_to(TRENCH))
	return best + _coast.get_noise_2d(x, z) * 14.0


## Nearest point info on the river polyline: returns [distance, t(0..1)].
static func river_info(x: float, z: float) -> Array:
	var p := Vector2(x, z)
	var best_d := 1e9
	var best_t := 0.0
	var n := RIVER.size() - 1
	for i in n:
		var a: Vector2 = RIVER[i]
		var b: Vector2 = RIVER[i + 1]
		var ab := b - a
		var u := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := p.distance_to(a + ab * u)
		if d < best_d:
			best_d = d
			best_t = (float(i) + u) / n
	return [best_d, best_t]


static func river_level(t: float) -> float:
	return lerpf(RIVER_WL_START, RIVER_WL_END, t)


static func height_at(x: float, z: float) -> float:
	var sd := signed_dist(x, z)
	var h: float
	if sd > 0.0:
		h = smoothstep(0.0, 14.0, sd) * 4.2
		h += _hills.get_noise_2d(x, z) * smoothstep(18.0, 70.0, sd) * 9.0 + smoothstep(18.0, 70.0, sd) * 2.0
	else:
		h = maxf(-70.0, sd * 0.8)
	var p := Vector2(x, z)
	# flat building plateaus
	h = _flatten(h, p, VILLAGE, VILLAGE_R, VILLAGE_Y)
	h = _flatten(h, p, FACTORY, FACTORY_R, FACTORY_Y)
	h = _flatten(h, p, HAMLET, HAMLET_R, HAMLET_Y)
	h = _flatten(h, p, BOG, 30.0, ISLAND_Y)
	h = _flatten(h, p, FROST, 28.0, ISLAND_Y)
	h = _flatten(h, p, TRENCH, 14.0, ISLAND_Y)
	# lake basin
	var dl := p.distance_to(LAKE_C)
	if dl < LAKE_R + 12.0:
		var k := 1.0 - smoothstep(LAKE_R - 10.0, LAKE_R + 8.0, dl)
		h = lerpf(h, -3.5, k)
	# river channel
	var ri := river_info(x, z)
	var rd: float = ri[0]
	if rd < RIVER_HALF + 6.0:
		var wl := river_level(ri[1])
		var bed := wl - 1.4
		if rd <= RIVER_HALF:
			h = bed
		else:
			var k2 := smoothstep(RIVER_HALF, RIVER_HALF + 6.0, rd)
			h = lerpf(bed, maxf(h, wl + 0.45), k2)
			h = maxf(h, bed)
	return h


static func _flatten(h: float, p: Vector2, c: Vector2, r: float, y: float) -> float:
	var d := p.distance_to(c)
	if d >= r + 16.0:
		return h
	return lerpf(h, y, 1.0 - smoothstep(r, r + 16.0, d))


## Surface height of the water at this point, or -INF when it is dry land.
static func water_level_at(x: float, z: float) -> float:
	var h := height_at(x, z)
	var p := Vector2(x, z)
	if p.distance_to(LAKE_C) < LAKE_R + 4.0 and h < LAKE_LEVEL:
		return LAKE_LEVEL
	var ri := river_info(x, z)
	if ri[0] < RIVER_HALF + 3.0:
		var wl := river_level(ri[1])
		if h < wl:
			return wl
	if h < SEA_LEVEL:
		return SEA_LEVEL
	return -INF


## "" if not water, otherwise: shore | ocean | lake | river | swamp | arctic | deep
const SHORE_DEPTH := 30.0
const PIER_TIP := Vector2(-20.0, 152.0)
const PIER_COVE_R := 24.0


static func water_type_at(x: float, z: float) -> String:
	var h := height_at(x, z)
	var p := Vector2(x, z)
	if p.distance_to(LAKE_C) < LAKE_R + 4.0 and h < LAKE_LEVEL:
		return "lake"
	var ri := river_info(x, z)
	if ri[0] < RIVER_HALF + 3.0 and h < river_level(ri[1]):
		return "river"
	if h >= SEA_LEVEL:
		return ""
	if p.distance_to(BOG) < 100.0:
		return "swamp"
	if p.distance_to(FROST) < 100.0:
		return "arctic"
	if p.distance_to(TRENCH) < 130.0:
		return "deep"
	# Starter cove: everything a basic rod can reach from the beach, plus the water
	# around the village pier tip. Only long casts out to deep water are "ocean".
	if -h < SHORE_DEPTH or p.distance_to(PIER_TIP) < PIER_COVE_R:
		return "shore"
	return "ocean"


## Can the player stand here? (They may wade up to ~0.9 m of water.)
static func walkable(x: float, z: float) -> bool:
	if absf(x) > WORLD_HALF - 6.0 or absf(z) > WORLD_HALF - 6.0:
		return false
	if on_walk_zone(x, z):
		return true
	var wl := water_level_at(x, z)
	if wl == -INF:
		return true
	return height_at(x, z) > wl - 0.9


static func add_walk_zone(start: Vector2, yaw: float, length: float, width: float) -> void:
	# pier runs from `start` along local +Z rotated by yaw
	var dir := Vector2(sin(yaw), cos(yaw))
	walk_zones.append({"c": start + dir * length * 0.5, "yaw": yaw, "hl": length * 0.5, "hw": width * 0.5})


static func on_walk_zone(x: float, z: float) -> bool:
	for zn in walk_zones:
		var d := Vector2(x, z) - (zn["c"] as Vector2)
		var yaw: float = zn["yaw"]
		var along := d.x * sin(yaw) + d.y * cos(yaw)
		var across := d.x * cos(yaw) - d.y * sin(yaw)
		if absf(along) <= float(zn["hl"]) and absf(across) <= float(zn["hw"]):
			return true
	return false


static func biome_color(x: float, z: float, h: float) -> Color:
	var p := Vector2(x, z)
	var snow := p.distance_to(FROST) < FROST_R + 18.0 and h > 0.9
	var bog := p.distance_to(BOG) < BOG_R + 18.0 and h > -2.0
	if h < -0.4:
		return Color("c9b88c") if h > -3.0 else Color("6f7f8a")
	if snow:
		return Color("eef6fb") if h > 1.2 else Color("c9d8e0")
	if h < 1.0:
		return Color("e3d49c")  # sand
	if bog:
		return Color("55663a") if h < 3.0 else Color("46572f")
	if p.distance_to(TRENCH) < TRENCH_R + 10.0:
		return Color("6d6a66")
	var rd: float = river_info(x, z)[0]
	if rd < RIVER_HALF + 3.0 or p.distance_to(LAKE_C) < LAKE_R + 5.0:
		return Color("c6b985")
	# village plazas
	for c in [VILLAGE, FACTORY, HAMLET]:
		var r := VILLAGE_R if c == VILLAGE else (FACTORY_R if c == FACTORY else HAMLET_R)
		if p.distance_to(c) < r * 0.62:
			return Color("a9a089") if c != FACTORY else Color("8f9296")
	if h > 9.5:
		return Color("8a8f86")  # rock
	var t := clampf((h - 1.0) / 9.0, 0.0, 1.0)
	return Color("4f9440").lerp(Color("37742f"), t)
