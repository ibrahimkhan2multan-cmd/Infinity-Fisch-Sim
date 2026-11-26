class_name CustomerManager
extends Node3D
## Keeps visible customers at the market stalls in sync with Game.orders.

var slots: Array[Vector3] = []
var _npcs: Dictionary = {}   # order id -> Npc


func setup(p_slots: Array[Vector3]) -> void:
	slots = p_slots
	Game.facilities_changed.connect(sync)
	sync()


func sync() -> void:
	# remove customers whose order is gone
	var live := {}
	for o in Game.orders:
		live[int(o["id"])] = true
	for id in _npcs.keys():
		if not live.has(id):
			var n: Npc = _npcs[id]
			_npcs.erase(id)
			_leave(n)
	# add new customers into free slots
	var used := {}
	for id in _npcs:
		used[(_npcs[id] as Npc).get_meta("slot")] = true
	for o in Game.orders:
		var id := int(o["id"])
		if _npcs.has(id):
			(_npcs[id] as Npc).title = Economy.order_text(o)
			continue
		var slot := -1
		for i in slots.size():
			if not used.has(i):
				slot = i
				break
		if slot < 0:
			continue
		used[slot] = true
		var n := Npc.new()
		var hue := Util.hash01(id)
		n.setup(Color.from_hsv(hue, 0.55, 0.85), Color("3a3a4a"), Color("e0b08a") if hue > 0.5 else Color("a8744f"),
			Color.from_hsv(fmod(hue + 0.5, 1.0), 0.5, 0.8), "cap" if hue > 0.4 else "hood")
		n.init_npc(str(o["name"]), Economy.order_text(o), 0.0)
		n.set_meta("slot", slot)
		add_child(n)
		var dest := slots[slot]
		n.position = dest + Vector3(randf_range(-8, 8), 0, 14.0)
		var tw := n.create_tween()
		tw.tween_property(n, "position", dest, 4.0)
		_npcs[id] = n


func _leave(n: Npc) -> void:
	if not is_instance_valid(n):
		return
	var tw := n.create_tween()
	tw.tween_property(n, "position", n.position + Vector3(randf_range(-10, 10), 0, 16.0), 3.5)
	tw.tween_callback(n.queue_free)
