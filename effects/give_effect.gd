extends Effect
class_name GiveEffectEffect

@export var given_effect: TriggeredEffect

func validate_possible_play(source_owner, ally_char, enemy_char, ally_board = null, enemy_board = null, is_cpu = false):
	var available_targets = []

	# check if has any minion target available
	if ally_board:
		for pos in ally_board.get_children():
			if pos.get_children():
				# has available target in this position
				if validate_play(pos.get_children()[0]):
					available_targets.append(pos.get_children()[0])

	if enemy_board:
		if not is_cpu:
			for pos in enemy_board.get_children():
				if pos.get_children():
					# has available target in this position
					if validate_play(pos.get_children()[0]):
						available_targets.append(pos.get_children()[0])

	return [not available_targets.is_empty(), available_targets]

func validate_play(target = null):
	if not target.is_in_group('minion'):
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
		target.triggered_effects.append(given_effect)
