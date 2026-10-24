extends Node2D

func _process(delta: float) -> void:
	$ChosenDeck.text = 'Chosen Deck: ' + Globals.p1_deck

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://Main.tscn")

func _on_collection_pressed() -> void:
	get_tree().change_scene_to_file("res://menus/Collection.tscn")

func _on_elf_deck_pressed() -> void:
	Globals.p1_deck = 'Elven Reunion'

func _on_undead_deck_pressed() -> void:
	Globals.p1_deck = 'Deal With the Dead'

func _on_dwarf_deck_pressed() -> void:
	Globals.p1_deck = 'Dwarven Brigade'

func _on_streets_deck_pressed() -> void:
	Globals.p1_deck = 'Lost in the City Streets'

func _on_fiend_deck_pressed() -> void:
	Globals.p1_deck = 'From the Hells!'

func _on_test_deck_pressed() -> void:
	Globals.p1_deck = 'Test Deck'
