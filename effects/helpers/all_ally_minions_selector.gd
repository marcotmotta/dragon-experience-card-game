extends TargetSelector
class_name AllAllyMinionsSelector

func get_targets_state(state, source, source_seat: int, initial_target = null, rng: RandomNumberGenerator = null) -> Array:
	var allies = []

	for minion in state.players[source_seat].board:
		if minion != null and ((not conditional_target_type) or minion.minion_type == conditional_target_type):
			allies.append(minion)

	return allies
