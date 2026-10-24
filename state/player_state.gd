extends RefCounted
class_name PlayerState

# Dont hold objects, just references

var kind: int = GameEnums.EntityKind.HERO # discriminator for effects/selectors

var seat: int # GameEnums.Seat

var health: int = 30
var current_health: int = 30

var mana: int = 0
var current_mana: int = 0

var deck: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var board: Array = [] # the positions matter. can be [minion, null, minion, etc]

func take_damage(amount: int) -> void:
	current_health -= amount

func heal(amount: int) -> void:
	current_health = min(current_health + amount, health)

func get_health() -> Dictionary:
	return {'total': health, 'current': current_health}
