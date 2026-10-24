extends TargetSelector
class_name EnemyHeroSelector

func get_targets_state(state, source, source_seat: int, initial_target = null, rng: RandomNumberGenerator = null) -> Array:
	var opponent_seat = state.opponent_of(source_seat)

	return [state.players[opponent_seat]]
