extends Node2D

@onready var menu_card_interface_scene = load("res://cards/CardInterface/MenuCardInterface.tscn")

var collection_cards = []

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
		collection_cards.append(
			{
				'name': Globals.cards[card].name,
				'cost': Globals.cards[card].cost,
				'rarity': _map_rarity_to_int(Globals.cards[card].rarity)
			}
		)

	present_by_order(null)

	# set container dimension
	var count = $Control/ScrollContainer/GridContainer.get_child_count() - 1
	$Control/ScrollContainer/GridContainer.custom_minimum_size.y = ((count / 5) + 1) * 300

func _map_rarity_to_int(rarity):
	match rarity:
		'common':
			return 0
		'uncommon':
			return 1
		'rare':
			return 2
		'epic':
			return 3
		'legendary':
			return 4

func sort_by_cost(a, b):
	if a['cost'] < b['cost']:
		return true
	return false

func sort_by_name(a, b):
	if a['name'] < b['name']:
		return true
	return false

func sort_by_rarity(a, b):
	if a['rarity'] < b['rarity']:
		return true
	return false

func present_by_order(order_by):
	for pos in $Control/ScrollContainer/GridContainer.get_children():
		pos.queue_free()

	if order_by == 'cost':
		# ordem by name first so the final order doesnt change
		collection_cards.sort_custom(sort_by_name)
		collection_cards.sort_custom(sort_by_cost)

	elif order_by == 'name':
		collection_cards.sort_custom(sort_by_name)

	elif order_by == 'rarity':
		# ordem by name first so the final order doesnt change
		collection_cards.sort_custom(sort_by_name)
		collection_cards.sort_custom(sort_by_rarity)

	for card in collection_cards:
		create_new_pos(card.name)

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _on_order_by_cost_pressed() -> void:
	present_by_order('cost')

func _on_order_by_name_pressed() -> void:
	present_by_order('name')

func _on_order_by_rarity_pressed() -> void:
	present_by_order('rarity')
