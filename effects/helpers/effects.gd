extends Resource
class_name Effect

@export var target_selector: TargetSelector

# validate simply if the card can be played (has available targets)
#
# returns:
# [true: bool, list of possible targets: []
#
func validate_possible_play(source_owner, ally_char, enemy_char, ally_board = null, enemy_board = null, is_cpu = false) -> Array:
	return [true, []]

# validate if selected target is valid
func validate_play(target = null):
	return true

# assume target is already validated
func execute(source, target = null):
	pass
