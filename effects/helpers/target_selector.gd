extends Resource
class_name TargetSelector

@export var conditional_target_type: String

# Operates on the GameState and returns targetable instances (MinionInstance /
# PlayerState). `source_seat` is the owner seat; `rng` is the Resolver's rng (used
# only by random selectors).
func get_targets_state(state, source, source_seat: int, initial_target = null, rng: RandomNumberGenerator = null) -> Array:
	return []
