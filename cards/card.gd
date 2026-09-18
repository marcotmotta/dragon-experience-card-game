extends Resource
class_name CardData

# shared
@export var name: String
@export var type: String
@export var minion_type: String
@export var rarity: String
@export var cost: int
@export var description: String
@export var requires_target: bool

# for minions
@export var attack: int
@export var health: int

# effects
@export var triggered_effects: Array[TriggeredEffect]

# art
@export var art: String = ''
