extends Resource
class_name TriggeredEffect

# this cant be re-ordered. new entries must come at the end
enum TriggerType {
	ON_PLAY, # for spells
	ON_DEATH,
	ON_SUMMON,
	ON_ATTACK,
	ON_TURN_START,
	ON_TURN_END,
	ON_TAKING_DAMAGE,
}

@export var trigger_type: TriggerType
@export var conditions: Array[Condition]
@export var effects: Array[Effect]
