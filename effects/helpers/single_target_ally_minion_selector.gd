extends TargetSelector
class_name SingleTargetAllyMinionSelector

func get_targets_state(state, source, source_seat: int, initial_target = null, rng: RandomNumberGenerator = null) -> Array:
	# check if its minion
	if initial_target.get('kind') != GameEnums.EntityKind.MINION:
		return []

	# check for target type
	if conditional_target_type and \
	initial_target != null and \
	initial_target.minion_type != conditional_target_type:
		return []

	# check owner
	print(initial_target.owner, source_seat, initial_target.owner != source_seat)
	if initial_target.owner != source_seat:
		return []

	return [initial_target]
