class_name FishLogic
extends RefCounted
## Pure fishing rules: what bites, how big it is, mutations, genes and value.
## Everything takes explicit inputs (and an optional RNG) so it is unit-testable.

## id -> [display name, value multiplier, base chance]
const MUTATIONS := {
	"shiny": ["Shiny", 1.6, 0.060],
	"albino": ["Albino", 2.2, 0.030],
	"giant": ["Giant", 1.5, 0.025],
	"golden": ["Golden", 3.5, 0.008],
	"void": ["Void", 6.0, 0.002],
}


static func is_night(hour: float) -> bool:
	return hour < 5.5 or hour >= 19.5


## Weighted species pick for a water type. Returns a FishSpecies (or null).
static func pick_species(water: String, luck: float, hour: float, weather: String,
		rng: RandomNumberGenerator = null) -> DataTypes.FishSpecies:
	var pool: Array = Data.fish_for_water(water)
	if pool.is_empty():
		return null
	var weights: Array = []
	var night := is_night(hour)
	for sp: DataTypes.FishSpecies in pool:
		var w: float = Util.RARITY_WEIGHTS[sp.rarity]
		w *= 1.0 + luck * float(sp.rarity) * 0.6
		match sp.active:
			"night": w *= 2.2 if night else 0.12
			"day": w *= 1.6 if not night else 0.15
		if sp.weather != "any" and sp.weather == weather:
			w *= 2.5
		weights.append(w)
	var idx := Util.weighted_index(weights, rng)
	return pool[idx] if idx >= 0 else null


static func roll_mutation(luck: float, rng: RandomNumberGenerator = null) -> String:
	var r := (rng.randf() if rng else randf())
	var acc := 0.0
	var boost := 1.0 + clampf(luck, 0.0, 3.0) * 0.35
	# Check rarest first so the rare ones are not starved by the common ones.
	for key in ["void", "golden", "giant", "albino", "shiny"]:
		acc += float(MUTATIONS[key][2]) * boost
		if r < acc:
			return key
	return ""


static func roll_weight(sp: DataTypes.FishSpecies, size_bonus: float,
		rng: RandomNumberGenerator = null) -> float:
	var t := pow((rng.randf() if rng else randf()), 1.5)
	return lerpf(sp.min_w, sp.max_w * (1.0 + size_bonus), t)


static func random_genes(rng: RandomNumberGenerator = null) -> Dictionary:
	var r := rng if rng else RandomNumberGenerator.new()
	if not rng:
		r.randomize()
	return {
		"size": clampf(r.randfn(1.0, 0.18), 0.5, 1.6),
		"grow": clampf(r.randfn(1.0, 0.15), 0.6, 1.5),
		"fert": clampf(r.randfn(1.0, 0.15), 0.6, 1.5),
		"hue": clampf(r.randfn(0.0, 0.05), -0.15, 0.15),
	}


## Builds a fish instance dictionary (this is what is stored in inventories).
static func make_fish(species_id: String, weight: float, mutation: String = "",
		genes: Dictionary = {}) -> Dictionary:
	var f := {
		"uid": Game.next_uid(),
		"sp": species_id,
		"w": snappedf(weight, 0.001),
		"mut": mutation,
		"g": genes if not genes.is_empty() else random_genes(),
		"fav": false,
	}
	return f


## Rolls a complete caught fish for the current conditions.
static func roll_catch(water: String, luck: float, size_bonus: float, hour: float,
		weather: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var sp := pick_species(water, luck, hour, weather, rng)
	if sp == null:
		return {}
	var w := roll_weight(sp, size_bonus, rng)
	var mutation := roll_mutation(luck, rng)
	if mutation == "giant":
		w *= 1.5
	var f := make_fish(sp.id, w, mutation)
	return f


static func fish_value(f: Dictionary) -> int:
	var sp: DataTypes.FishSpecies = Data.fish.get(f.get("sp", ""))
	if sp == null:
		return 0
	var ratio := maxf(0.15, float(f.get("w", sp.avg_weight())) / sp.avg_weight())
	var v := float(sp.price) * pow(ratio, 0.8)
	var mut: String = f.get("mut", "")
	if MUTATIONS.has(mut):
		v *= float(MUTATIONS[mut][1])
	if f.get("farm", false):
		v *= Hatchery.FARM_VALUE_MULT
	if f.get("stage", "adult") == "fry":
		v *= 0.1
	return maxi(1, int(round(v)))


static func mutation_name(f: Dictionary) -> String:
	var m: String = f.get("mut", "")
	return MUTATIONS[m][0] if MUTATIONS.has(m) else ""


static func display_name(f: Dictionary) -> String:
	var sp: DataTypes.FishSpecies = Data.fish.get(f.get("sp", ""))
	if sp == null:
		return "Unknown fish"
	var mn := mutation_name(f)
	return (mn + " " + sp.name) if mn != "" else sp.name


## Difficulty (0..1) used by the reel minigame for this specific fish.
static func reel_difficulty(f: Dictionary) -> float:
	var sp: DataTypes.FishSpecies = Data.fish.get(f.get("sp", ""))
	if sp == null:
		return 0.3
	var size_part := clampf(float(f.get("w", 0.0)) / maxf(0.001, sp.max_w), 0.0, 1.0) * 0.1
	return clampf(sp.difficulty + size_part, 0.05, 1.0)


## Seconds for a bite given rod/bait/weather/time.
static func bite_wait(lure: float, weather_bite: float, rng: RandomNumberGenerator = null) -> float:
	var base := (rng.randf_range(5.0, 11.0) if rng else randf_range(5.0, 11.0))
	return maxf(1.5, base / maxf(0.2, lure * weather_bite))
