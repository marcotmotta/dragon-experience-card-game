extends Node2D

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Main.tscn")

func _on_collection_pressed() -> void:
	get_tree().change_scene_to_file("res://menus/Collection.tscn")
