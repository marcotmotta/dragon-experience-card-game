extends Effect
class_name SummonMinionEffect

@export var minion_type: String

func execute(source, target = null):
	var player = source.card_owner if 'card_owner' in source else source.minion_owner

	source.main_scene.spawn_minion(player, minion_type)
