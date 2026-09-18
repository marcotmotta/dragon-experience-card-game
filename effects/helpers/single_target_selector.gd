extends TargetSelector
class_name SingleTargetSelector

func get_targets(source, initial_target, source_owner, ally_char = null, enemy_char = null, ally_board = null, enemy_board = null):
	if conditional_target_type and initial_target.is_in_group('minion') and initial_target.type != conditional_target_type:
		return []

	return [initial_target]
