extends RefCounted
class_name MinionInstance

# References its static template (CardData) for what never changes (name, art, base stats, tribe, base effects).

var kind: int = GameEnums.EntityKind.MINION   # discriminator for effects/selectors

var id: int
var owner: int # GameEnums.Seat
var data: CardData # base info from CardData resource

var BASE_ATTACK: int
var BASE_HEALTH: int
var max_attack: int
var max_health: int
var current_attack: int
var current_health: int

var minion_type: String # tribe
var attacked: bool = true

var triggered_effects: Array = []
var properties: Array = []
var silenced: bool = false
var destroyed = false

func is_dead() -> bool:
	return ((current_health <= 0) or destroyed)

func take_damage(amount: int) -> void:
	var dmg = amount

	if 'Resilient' in properties:
		dmg = max(dmg - 1, 0)

	current_health -= dmg

func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)

func get_destroyed():
	destroyed = true

func get_health() -> Dictionary:
	return {'total': max_health, 'current': current_health}

func gain_status(attack_amount: int, health_amount: int) -> void:
	max_attack += attack_amount
	max_health += health_amount
	current_attack += attack_amount
	current_health += health_amount

func gain_property(property_name: String) -> void:
	# check if already has property
	if property_name in properties:
		return

	properties.append(property_name)

func get_silenced() -> void:
	triggered_effects = []
	properties = []

	if current_attack > BASE_ATTACK:
		max_attack = BASE_ATTACK
		current_attack = BASE_ATTACK

	if current_health > BASE_HEALTH:
		max_health = BASE_HEALTH
		current_health = BASE_HEALTH

	silenced = true
