extends Node

@onready var sound_player_scene = load("res://sound/SoundPlayer.tscn")

var active_sounds: Dictionary = {}

func play_sound(stream: AudioStream):
	if not stream:
		return

	# If this EXACT sound is already playing, ignore the new request completely
	if active_sounds.has(stream) and is_instance_valid(active_sounds[stream]):
		if active_sounds[stream].is_playing():
			return

	# Otherwise, play it normally
	var sound_player_instance = sound_player_scene.instantiate()
	sound_player_instance.stream = stream
	add_child(sound_player_instance)

	active_sounds[stream] = sound_player_instance

	sound_player_instance.finished.connect(func():
		if active_sounds.get(stream) == sound_player_instance:
			active_sounds.erase(stream)
		sound_player_instance.queue_free()
	)

	sound_player_instance.play()
