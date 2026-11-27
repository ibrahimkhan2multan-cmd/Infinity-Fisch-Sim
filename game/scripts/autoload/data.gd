extends Node
## Static game data tables (autoload "Data"). Built once at startup from the
## *DB classes so everything is defined in code and easy to extend.

var fish: Dictionary = {}         # id -> DataTypes.FishSpecies
var rods: Dictionary = {}         # id -> DataTypes.Rod
var baits: Dictionary = {}        # id -> DataTypes.Bait
var ingredients: Dictionary = {}  # id -> DataTypes.Ingredient
var recipes: Dictionary = {}      # id -> DataTypes.Recipe
var products: Dictionary = {}     # id -> DataTypes.Product
var locations: Dictionary = {}    # id -> DataTypes.Location
var upgrades: Dictionary = {}     # id -> DataTypes.Upgrade
var charms: Dictionary = {}       # id -> DataTypes.Charm

var _by_water: Dictionary = {}


func _init() -> void:
	fish = FishDB.build()
	rods = GearDB.build_rods()
	baits = GearDB.build_baits()
	ingredients = FoodDB.build_ingredients()
	recipes = FoodDB.build_recipes()
	products = FoodDB.build_products()
	locations = WorldDB.build_locations()
	upgrades = WorldDB.build_upgrades()
	charms = CharmDB.build()
	for sp in fish.values():
		for w in sp.waters:
			if not _by_water.has(w):
				_by_water[w] = []
			_by_water[w].append(sp)


func fish_for_water(water: String) -> Array:
	return _by_water.get(water, [])


func water_types() -> Array:
	return _by_water.keys()


func species(id: String) -> DataTypes.FishSpecies:
	return fish.get(id)
