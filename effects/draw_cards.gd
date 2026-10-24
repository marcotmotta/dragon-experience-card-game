extends Effect
class_name DrawCardsEffect

@export var amount: int = 1

func execute_state(resolver, source, target = null) -> void:
	for i in range(amount):
		resolver.draw_card(source.owner)
