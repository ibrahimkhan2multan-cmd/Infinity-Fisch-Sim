class_name Bob
extends MeshInstance3D
## Gentle bobbing/rocking for moored boats.

var _t := 0.0
var _ready_done := false
var _base_pos := Vector3.ZERO
var _base_rot := Vector3.ZERO


func _process(delta: float) -> void:
	if not _ready_done:
		_ready_done = true
		_base_pos = position
		_base_rot = rotation
		_t = randf() * 10.0
	_t += delta
	position.y = _base_pos.y + sin(_t * 1.1) * 0.06
	rotation.z = _base_rot.z + sin(_t * 0.9 + 1.0) * 0.022
	rotation.x = _base_rot.x + sin(_t * 0.7) * 0.018
