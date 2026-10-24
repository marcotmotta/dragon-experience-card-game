extends Condition
class_name HasMinionTypeCondition

@export var minion_type: String
@export var amount: int = 1
@export var include_source: bool = false

func check(resolver, source, target = null) -> bool:
	var board = resolver.state.players[source.owner].board

	var count := 0

	for minion in board:
		if minion and minion.minion_type == minion_type:
			if include_source or minion != source:
				count += 1

	return count >= amount
