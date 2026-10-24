extends RefCounted
class_name Events

# What just happened, as plain serializable data (mirrors Actions). The Resolver
# produces these; the view presents them (SFX/VFX/animations), and later the network
# sends them to the client to replay. Entities are referenced by id/seat — the
# polymorphic ones (damage/heal/attack) use the same {kind, ref} descriptor as Actions.

enum Type {
	MINION_SPAWNED,
	MINION_DESTROYED, # aftermatch of destroy effect, just a trigger like DAMAGE_DEALT
	MINION_DIED, # minion actually dying
	DAMAGE_DEALT,
	HEALED,
	STAT_BUFFED,
	SILENCED,
	PROPERTY_GAINED,
	CARD_DRAWN,
	CARD_PLAYED,
	ATTACKED,
}

static func minion_spawned(id: int) -> Dictionary:
	return {'type': Type.MINION_SPAWNED, 'id': id}

static func minion_destroyed(target: Dictionary) -> Dictionary:
	return {'type': Type.MINION_DESTROYED, 'target': target}

static func minion_died(id: int) -> Dictionary:
	return {'type': Type.MINION_DIED, 'id': id}

static func damage_dealt(target: Dictionary, amount: int) -> Dictionary:
	return {'type': Type.DAMAGE_DEALT, 'target': target, 'amount': amount}

static func healed(target: Dictionary, amount: int) -> Dictionary:
	return {'type': Type.HEALED, 'target': target, 'amount': amount}

static func stat_buffed(id: int, attack_amount: int, health_amount: int) -> Dictionary:
	return {'type': Type.STAT_BUFFED, 'id': id, 'attack_amount': attack_amount, 'health_amount': health_amount}

static func silenced(id: int) -> Dictionary:
	return {'type': Type.SILENCED, 'id': id}

static func property_gained(id: int, property_name: String) -> Dictionary:
	return {'type': Type.PROPERTY_GAINED, 'id': id, 'property_name': property_name}

static func card_drawn(seat: int) -> Dictionary:
	return {'type': Type.CARD_DRAWN, 'seat': seat}

static func card_played(seat: int, card_name: String) -> Dictionary:
	return {'type': Type.CARD_PLAYED, 'seat': seat, 'card_name': card_name}

static func attacked(attacker_id: int, target: Dictionary) -> Dictionary:
	return {'type': Type.ATTACKED, 'attacker_id': attacker_id, 'target': target}
