extends TargetSelector
class_name RandomEnemySelector

func get_targets(source, initial_target, source_owner, ally_char = null, enemy_char = null, ally_board = null, enemy_board = null):
	var enemies = []

	for pos in enemy_board.get_children():
		if pos.get_children():
			var enemy = pos.get_child(0)
			if (not conditional_target_type) or (enemy.type == conditional_target_type):
				enemies.append(enemy)

	if not conditional_target_type:
		enemies.append(enemy_char)

	return [enemies.pick_random()]
