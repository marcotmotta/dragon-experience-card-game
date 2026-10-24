extends Effect
class_name SilenceEffect

func validate_play_state(target = null) -> bool:
	if target == null or target.get('kind') != GameEnums.EntityKind.MINION:
		return false
	if target_selector.conditional_target_type and target_selector.conditional_target_type != target.minion_type:
		return false
	return true

func validate_possible_play_state(state, source_seat, is_cpu = false) -> Array:
	var available_targets = []
	var opponent_seat = state.opponent_of(source_seat)

	# silence: ally only when not cpu, enemy always (mirrors the old node logic)
	if not is_cpu:
		for minion in state.players[source_seat].board:
			if minion != null and validate_play_state(minion):
				available_targets.append(minion)
	for minion in state.players[opponent_seat].board:
		if minion != null and validate_play_state(minion):
			available_targets.append(minion)

	return [not available_targets.is_empty(), available_targets]

func execute_state(resolver, source, target = null) -> void:
	if target:
		target.get_silenced()
		resolver.emit(Events.silenced(target.id))
