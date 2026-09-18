extends Effect
class_name DrawCardsEffect

@export var amount: int = 1

func execute(source, target = null):
	var player = source.owner_node

	for i in range(amount):
		player.draw_card_from_deck()
