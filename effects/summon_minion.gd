extends Effect
class_name SummonMinionEffect

@export var minion_type: String

func execute_state(resolver, source, target = null) -> void:
	resolver.spawn_minion(source.owner, minion_type)
