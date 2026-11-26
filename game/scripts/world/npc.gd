class_name Npc
extends CharacterModel
## A standing villager: idles, turns to look at the player when they are near.

var title := ""
var look_range := 9.0
var _t := 0.0
var _base_yaw := 0.0
var _player: Node3D = null
var _label: Label3D


func init_npc(npc_name: String, p_title: String, base_yaw: float) -> Npc:
	title = p_title
	_base_yaw = base_yaw
	rotation.y = base_yaw
	_t = randf() * 10.0
	_label = Props.label(npc_name if p_title == "" else "%s\n%s" % [npc_name, p_title], 0.42, Color("fff4c7"))
	_label.position = Vector3(0, 2.45, 0)
	add_child(_label)
	return self


func _process(delta: float) -> void:
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var target_yaw := _base_yaw
	if _player:
		var d := _player.global_position - global_position
		d.y = 0.0
		if d.length() < look_range:
			target_yaw = atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 4.0))
	pose = "idle"
	animate(delta, 0.0)
	body_root.position.y = sin(_t * 1.8) * 0.012
	arm_r.rotation.x = sin(_t * 1.3) * 0.05
