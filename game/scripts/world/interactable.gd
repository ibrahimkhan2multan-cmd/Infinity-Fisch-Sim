class_name Interactable
extends Area3D
## A spot the player can use (shop counter, bed, ferry...). The player's sensor
## picks the nearest one and the HUD shows `prompt` on the action button.

var prompt := "Use"
var action := ""
var data: Dictionary = {}


func setup(p_prompt: String, p_action: String, radius := 3.2, p_data := {}) -> Interactable:
	prompt = p_prompt
	action = p_action
	data = p_data
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	monitorable = true
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius
	cs.shape = sh
	add_child(cs)
	add_to_group("interactables")
	return self
