extends TargetSelector
class_name RandomEnemySelector

func get_targets_state(state, source, source_seat: int, initial_target = null, rng: RandomNumberGenerator = null) -> Array:
	var enemies = []
	var opponent_seat = state.opponent_of(source_seat)

	for minion in state.players[opponent_seat].board:
		if minion != null and ((not conditional_target_type) or minion.minion_type == conditional_target_type):
			enemies.append(minion)

	if not conditional_target_type:
		enemies.append(state.players[opponent_seat])

	if enemies.is_empty():
		return []

	# use the Resolver's rng for determinism (not pick_random)
	if rng == null:
		return [enemies[0]]
	return [enemies[rng.randi_range(0, enemies.size() - 1)]]
