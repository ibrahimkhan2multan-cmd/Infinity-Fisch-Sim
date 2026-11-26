class_name PanelCollection
extends PanelBase
## Fishdex: every species grouped by water type. Undiscovered ones are hidden
## but show where to look.

const WATER_ORDER: Array[String] = ["shore", "lake", "river", "ocean", "swamp", "arctic", "deep"]


func _init() -> void:
	super()
	title = "Fishdex"


func _populate(_t: int) -> void:
	add_header("Discovered %d / %d" % [Game.discovered_count(), Data.fish.size()])
	for w in WATER_ORDER:
		var list: Array = Data.fish_for_water(w)
		if list.is_empty():
			continue
		var found := 0
		for sp in list:
			if Game.collection.has(sp.id):
				found += 1
		var loc: DataTypes.Location = Data.locations.get(WorldDB.location_for_water(w))
		var where := "" if loc == null else "  -  " + loc.name
		content.add_child(UI.label("%s  %d/%d%s" % [Util.WATER_NAMES.get(w, w), found, list.size(), where],
			UI.FONT, UI.C_ACCENT))
		for sp in list:
			var entry: Dictionary = Game.collection.get(sp.id, {})
			if entry.is_empty():
				var hint := "Found in %s waters" % w
				if sp.active != "any":
					hint += " · %s only" % sp.active
				add_row("???", "%s · %s" % [Util.rarity_name(sp.rarity), hint], [], UI.C_DIM)
			else:
				var muts := ""
				var mdict: Dictionary = entry.get("muts", {})
				if mdict.size() > 0:
					var names: Array[String] = []
					for m in mdict:
						names.append(String(FishLogic.MUTATIONS[m][0]) if FishLogic.MUTATIONS.has(m) else String(m))
					muts = " · variants: " + ", ".join(names)
				add_row(sp.name, "Caught %d · best %s%s" % [int(entry.get("n", 0)), Util.weight_text(float(entry.get("best", 0.0))), muts],
					[], Util.rarity_color(sp.rarity))
