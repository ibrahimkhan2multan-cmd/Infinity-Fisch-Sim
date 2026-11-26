class_name PanelFerry
extends PanelBase
## Ferry map: travel between the village and the islands. Travel itself is done
## by the game session (fade + teleport); this panel only validates and asks.

signal travel_requested(dest_id: String)

var destinations: Dictionary = {}


func _init() -> void:
	super()
	title = "Ferry"


func _populate(_t: int) -> void:
	content.add_child(UI.label("Money: " + Util.money(Game.money), UI.FONT, UI.C_GOLD))
	add_note("Pick a destination. Islands need their fishing permit (buy it at the Fishing Guild) before the captain will sail.")
	for id in destinations:
		var d: Dictionary = destinations[id]
		var permit: String = d.get("permit", "")
		var fare := int(d.get("fare", 0))
		var loc: DataTypes.Location = Data.locations.get(permit)
		var has := permit == "" or Game.has_permit(permit)
		var sub := "Fare %s" % (Util.money(fare) if fare > 0 else "free")
		if not has and loc != null:
			sub += " · needs the %s permit (%s, level %d)" % [loc.name, Util.money(loc.cost), loc.level_req]
		var can := has and Game.money >= fare
		add_row(String(d["name"]), sub, [["Sail", func():
			close_panel()
			travel_requested.emit(id), can, UI.C_GOOD]],
			UI.C_TEXT if has else UI.C_DIM)
