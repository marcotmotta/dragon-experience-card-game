extends Resource
class_name Effect

@export var target_selector: TargetSelector

# State-based interface: operates on the GameState via the Resolver and on instances
# (MinionInstance / PlayerState) rather than nodes.

# [has_any_target: bool, targets: Array of instances]
func validate_possible_play_state(state, source_seat, is_cpu = false) -> Array:
	return [true, []]

func validate_play_state(target = null) -> bool:
	return true

# `resolver` gives access to state + rng + lifecycle helpers (spawn/draw/add_card).
func execute_state(resolver, source, target = null) -> void:
	pass
