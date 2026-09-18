extends Resource
class_name TriggeredEffect

enum TriggerType {
	ON_PLAY, # for spells
	ON_DEATH,
	ON_SUMMON,
	ON_ATTACK,
	ON_TURN_START,
	ON_TURN_END
}

@export var trigger_type: TriggerType
@export var effects: Array[Effect]
