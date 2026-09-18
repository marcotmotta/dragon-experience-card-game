extends TargetSelector
class_name AllAllyMinionsSelector

func get_targets(source, initial_target, source_owner, ally_char = null, enemy_char = null, ally_board = null, enemy_board = null):
	var allies = []

	for pos in ally_board.get_children():
		if pos.get_children():
			var ally = pos.get_child(0)
			if (not conditional_target_type) or (ally.type == conditional_target_type):
				allies.append(ally)

	return allies
