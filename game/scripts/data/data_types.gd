class_name DataTypes
extends RefCounted
## Typed resource classes used by the data tables. Kept in one file so the
## database builders stay readable; each is a small value object.


class FishSpecies extends RefCounted:
	var id: String
	var name: String
	var rarity: int = 0
	var waters: Array[String] = []
	var price: int = 10          ## base value of an average-weight fish
	var min_w: float = 0.1       ## kg
	var max_w: float = 1.0       ## kg
	var difficulty: float = 0.2  ## 0..1 reel minigame hardness
	var active: String = "any"   ## any | day | night
	var weather: String = "any"  ## any | rain | storm | clear | fog (boosted)
	var c1: Color = Color.WHITE
	var c2: Color = Color.GRAY
	var shape: int = 0           ## 0 classic, 1 round, 2 long, 3 flat, 4 big/torpedo
	var grow_time: float = 120.0 ## seconds fry -> adult in a tank (before upgrades)
	var fertility: float = 0.5   ## 0..1 breeding output
	var desc: String = ""

	func avg_weight() -> float:
		return (min_w + max_w) * 0.5

	func is_salt() -> bool:
		for w in waters:
			if w in ["shore", "ocean", "deep", "swamp", "arctic"]:
				return true
		return false


class Rod extends RefCounted:
	var id: String
	var name: String
	var price: int
	var level_req: int = 1
	var luck: float = 0.0        ## rarity bias
	var lure: float = 1.0        ## bite speed multiplier
	var control: float = 0.3     ## reel bar size (fraction of track)
	var resilience: float = 0.1  ## reduces progress loss while off-target
	var cast_range: float = 16.0 ## metres
	var size_bonus: float = 0.0  ## upper-weight bonus
	var color: Color = Color("8b5a2b")
	var desc: String = ""


class Charm extends RefCounted:
	var id: String
	var name: String
	var price: int
	var level_req: int = 1
	var luck: float = 0.0        ## adds to rarity bias (like rod/bait luck)
	var calm: float = 0.0        ## fraction by which the fish moves slower in the reel bar
	var rarity: int = 0          ## 0..5, colours the name
	var color: Color = Color("ffd23f")
	var desc: String = ""


class Bait extends RefCounted:
	var id: String
	var name: String
	var price: int
	var luck: float = 0.0
	var lure: float = 1.0
	var night_bonus: float = 0.0
	var desc: String = ""


class Ingredient extends RefCounted:
	var id: String
	var name: String
	var price: int
	var desc: String = ""


class Recipe extends RefCounted:
	var id: String
	var name: String
	var station: String = "grill"  ## grill | pot | prep | oven
	var time: float = 30.0         ## seconds
	var fish_filter: String = "any"  ## any | fresh | salt
	var min_rarity: int = 0
	var ingredients: Dictionary = {}
	var base_value: int = 20
	var fish_mult: float = 1.5
	var buff: Dictionary = {}      ## stat -> amount
	var buff_time: float = 300.0
	var desc: String = ""


class Product extends RefCounted:
	var id: String
	var name: String
	var mult: float = 1.0          ## value multiplier over the raw fish
	var time: float = 20.0         ## seconds per batch
	var unlock_cost: int = 0
	var feed_value: float = 0.0    ## >0 means usable as tank feed
	var desc: String = ""


class Location extends RefCounted:
	var id: String
	var name: String
	var waters: Array[String] = []
	var level_req: int = 1
	var cost: int = 0
	var desc: String = ""


class Upgrade extends RefCounted:
	var id: String
	var name: String
	var desc: String
	var max_level: int = 5
	var base_cost: int = 200
	var growth: float = 1.7
	var level_req: int = 1

	func cost_at(level: int) -> int:
		return int(round(base_cost * pow(growth, level)))
