extends Effect
class_name HealTargetEffect

@export var amount: int = 1

func validate_play_state(target = null) -> bool:
	if target == null or target.get('kind') == null:
		return false
	if target_selector.conditional_target_type:
		if target.kind != GameEnums.EntityKind.MINION:
			return false
		if target_selector.conditional_target_type != target.minion_type:
			return false
	return true

func validate_possible_play_state(state, source_seat, is_cpu = false) -> Array:
	var available_targets = []
	var opponent_seat = state.opponent_of(source_seat)

	if validate_play_state(state.players[source_seat]):
		available_targets.append(state.players[source_seat])
	if not is_cpu and validate_play_state(state.players[opponent_seat]):
		available_targets.append(state.players[opponent_seat])

	for minion in state.players[source_seat].board:
		if minion != null and validate_play_state(minion):
			available_targets.append(minion)
	if not is_cpu:
		for minion in state.players[opponent_seat].board:
			if minion != null and validate_play_state(minion):
				available_targets.append(minion)

	# cpu only heals things that are actually damaged
	if is_cpu:
		available_targets = available_targets.filter(func(target): return target.get_health().current < target.get_health().total)

	return [not available_targets.is_empty(), available_targets]

func execute_state(resolver, source, target = null) -> void:
	if target:
		target.heal(amount)
		resolver.emit(Events.healed(Actions.descriptor_of(target), amount))
