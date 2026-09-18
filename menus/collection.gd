extends Node2D

@onready var menu_card_interface_scene = load("res://cards/CardInterface/MenuCardInterface.tscn")

func create_new_pos(card_name):
	var pos = Control.new()
	pos.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER 
	pos.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER 

	$Control/ScrollContainer/GridContainer.add_child(pos)

	var menu_card_interface_instance = menu_card_interface_scene.instantiate()
	menu_card_interface_instance.card_name = Globals.cards[card_name].name
	menu_card_interface_instance.cost = Globals.cards[card_name].cost
	menu_card_interface_instance.rarity = Globals.cards[card_name].rarity
	menu_card_interface_instance.description = Globals.cards[card_name].description
	menu_card_interface_instance.attack = Globals.cards[card_name].attack
	menu_card_interface_instance.health = Globals.cards[card_name].health
	menu_card_interface_instance.type = Globals.cards[card_name].type
	menu_card_interface_instance.minion_type = Globals.cards[card_name].minion_type
	menu_card_interface_instance.art = Globals.cards[card_name].art
	pos.add_child(menu_card_interface_instance)

func _ready() -> void:
	for card in Globals.cards:
		create_new_pos(card)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://MainMenu.tscn")
