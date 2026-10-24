extends Condition
class_name TargetMinionCondition

enum TARGET_OWNER {
	BOTH,
	ALLY,
	ENEMY
}

@export var minion_type: String
@export var minion_owner: TARGET_OWNER

func check(resolver, source, target = null) -> bool:
	# check if its minion
	if target == null or target.get('kind') != GameEnums.EntityKind.MINION:
		return false

	# check minion owner
	if minion_owner == TARGET_OWNER.ALLY and target.owner != source.owner:
		return false

	if minion_owner == TARGET_OWNER.ENEMY and target.owner == source.owner:
		return false

	# check minion type
	if target.minion_type != minion_type:
		return false

	return true
