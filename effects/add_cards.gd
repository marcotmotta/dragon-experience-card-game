extends Effect
class_name AddCardsEffect

@export var card: String = '' # add specific card (by name) or random card of chosen pool. they are mutually exclusive
@export var card_pool: String = ''
@export var amount: String

func execute_state(resolver, source, target = null) -> void:
	if card:
		for i in amount:
			resolver.add_card(source.owner, card)

	# else, choose from pool
	else:
		for i in amount:
			resolver.add_card(source.owner, Globals.card_pools[card_pool].pick_random())
