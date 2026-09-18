extends Effect
class_name AddCardsEffect

@export var card: String
@export var amount: String

func execute(source, target = null):
	var player = source.card_owner if 'card_owner' in source else source.minion_owner

	for i in amount:
		source.main_scene.create_card(player, card)
