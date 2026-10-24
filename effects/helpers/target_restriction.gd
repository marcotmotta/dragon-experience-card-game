extends Resource
class_name TargetRestriction

enum TargetSide {
	ANY,
	ALLY,
	ENEMY
}

@export var side: TargetSide = TargetSide.ANY
@export var minion_type: String = ''
@export var minions_only: bool = true

func allows(target, source_seat: int) -> bool:
	if target == null or target.get('kind') == null:
		return false
	if minions_only and target.kind != GameEnums.EntityKind.MINION:
		return false
	if minion_type and (target.kind != GameEnums.EntityKind.MINION or target.minion_type != minion_type):
		return false
	var owner = target.owner if target.kind == GameEnums.EntityKind.MINION else target.seat
	match side:
		TargetSide.ALLY:
			if owner != source_seat:
				return false
		TargetSide.ENEMY:
			if owner == source_seat:
				return false
	return true

# Every legal target currently on the board (+ heroes, when minions_only is false).
func legal_targets(state, source_seat: int) -> Array:
	var out := []
	for seat in [source_seat, state.opponent_of(source_seat)]:
		if allows(state.players[seat], source_seat):
			out.append(state.players[seat])
		for minion in state.players[seat].board:
			if minion != null and allows(minion, source_seat):
				out.append(minion)
	return out
