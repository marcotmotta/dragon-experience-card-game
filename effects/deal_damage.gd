extends Effect
class_name DealDamageEffect

@export var amount: int = 1

func validate_possible_play(source_owner, ally_char, enemy_char, ally_board = null, enemy_board = null, is_cpu = false):
	var available_targets = []

	# Here I validate_play everytime i try to add an available target.

	# add chars as target
	if not is_cpu:
		if validate_play(ally_char):
			available_targets.append(ally_char)

	if validate_play(enemy_char):
		available_targets.append(enemy_char)

	# check if has any minion target available
	if ally_board:
		if not is_cpu:
			for pos in ally_board.get_children():
				if pos.get_children():
					# has available target in this position
					if validate_play(pos.get_children()[0]):
						available_targets.append(pos.get_children()[0])

	if enemy_board:
		for pos in enemy_board.get_children():
			if pos.get_children():
				# has available target in this position
				if validate_play(pos.get_children()[0]):
					available_targets.append(pos.get_children()[0])

	return [not available_targets.is_empty(), available_targets]

func validate_play(target = null):
	if not target.is_in_group('minion') and not target.is_in_group('char'):
		return false

	if target_selector.conditional_target_type:
		var type = target.get('type')

		if not type:
			return false

		if target_selector.conditional_target_type != type:
			return false

	return true

func execute(source, target = null):
	if target:
		target.take_damage(amount)
