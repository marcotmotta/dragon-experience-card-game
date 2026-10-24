extends TargetSelector
class_name RandomAllyMinionSelector

func get_targets_state(state, source, source_seat: int, initial_target = null, rng: RandomNumberGenerator = null) -> Array:
	var allies = []

	for minion in state.players[source_seat].board:
		if minion != null and ((not conditional_target_type) or minion.minion_type == conditional_target_type):
			allies.append(minion)

	if allies.is_empty():
		return []

	# use the Resolver's rng for determinism (not pick_random)
	if rng == null:
		return [allies[0]]
	return [allies[rng.randi_range(0, allies.size() - 1)]]
