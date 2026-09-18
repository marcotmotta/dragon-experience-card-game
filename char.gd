extends Area2D

var main_scene
var owner_node

# audio sfx
@onready var sound_player_scene = load("res://sound/SoundPlayer.tscn")
@onready var hit_sound = load("res://sound/hit.wav")
@onready var heal_sound = load("res://sound/heal.wav")

func get_health():
	return main_scene.get_player_health(self)

func take_damage(amount):
	main_scene.handle_player_health(self, 'damage', amount)

	# play sfx
	var sound_player_instance = sound_player_scene.instantiate()
	sound_player_instance.stream = hit_sound
	main_scene.add_child(sound_player_instance)

func heal(amount):
	main_scene.handle_player_health(self, 'heal', amount)

	# play sfx
	var sound_player_instance = sound_player_scene.instantiate()
	sound_player_instance.stream = heal_sound
	main_scene.add_child(sound_player_instance)

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and Input.is_action_just_pressed('mouse1'):
		main_scene.on_object_clicked(self)
