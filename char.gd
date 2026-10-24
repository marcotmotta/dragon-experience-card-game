extends Area2D

var main_scene
var owner_node

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and Input.is_action_just_pressed('mouse1'):
		main_scene.on_object_clicked(self)
