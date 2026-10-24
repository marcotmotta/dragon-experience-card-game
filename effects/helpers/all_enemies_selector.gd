extends TargetSelector
class_name AllEnemiesSelector

func get_targets_state(state, source, source_seat: int, initial_target = null, rng: RandomNumberGenerator = null) -> Array:
	var enemies = []
	var opponent_seat = state.opponent_of(source_seat)

	for minion in state.players[opponent_seat].board:
		if minion != null and ((not conditional_target_type) or minion.minion_type == conditional_target_type):
			enemies.append(minion)

	# enemy hero (only when not filtering by tribe)
	if not conditional_target_type:
		enemies.append(state.players[opponent_seat])

	return enemies
