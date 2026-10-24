extends TargetSelector
class_name SingleTargetSelector

func get_targets_state(state, source, source_seat: int, initial_target = null, rng: RandomNumberGenerator = null) -> Array:
	if conditional_target_type and initial_target != null and initial_target.get('kind') == GameEnums.EntityKind.MINION and initial_target.minion_type != conditional_target_type:
		return []

	return [initial_target]
