extends Resource
class_name CardData

# shared
@export var name: String
@export var type: String
@export var minion_type: String
@export var rarity: String
@export var cost: int
@export var description: String

# for minions only
@export var attack: int
@export var health: int

# targeting rules
@export var requires_target: bool
@export var target_optional: bool = false
@export var target_restriction: TargetRestriction

# effects
@export var triggered_effects: Array[TriggeredEffect]

# art
@export var art: String = ''
