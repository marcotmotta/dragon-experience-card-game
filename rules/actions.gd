extends RefCounted
class_name Actions

# Player intents as plain, serializable data (dictionaries of ints + a small target
# descriptor). This is what will travel over the network. Entities are referenced by
# id (minions) or seat (heroes) — never by node. Use the factory functions below so
# the shape stays consistent.

enum Type {
	END_TURN,
	PLAY_CARD,
	ATTACK,
}

enum TargetKind {
	MINION,
	HERO,
}

# --- action factories ---

static func end_turn(by: int) -> Dictionary:
	return {'type': Type.END_TURN, 'by': by}

static func play_card(by: int, hand_index: int, target = null) -> Dictionary:
	return {'type': Type.PLAY_CARD, 'by': by, 'hand_index': hand_index, 'target': target}

static func attack(by: int, attacker_id: int, target: Dictionary) -> Dictionary:
	return {'type': Type.ATTACK, 'by': by, 'attacker_id': attacker_id, 'target': target}

# --- target descriptors ---

static func minion_target(id: int) -> Dictionary:
	return {'kind': TargetKind.MINION, 'ref': id}

static func hero_target(seat: int) -> Dictionary:
	return {'kind': TargetKind.HERO, 'ref': seat}

# builds a target descriptor from a state instance (minion or hero). duck-typed via
# `.kind` so this doesn't statically reference the state classes.
static func descriptor_of(instance) -> Dictionary:
	if instance.kind == GameEnums.EntityKind.MINION:
		return minion_target(instance.id)
	return hero_target(instance.seat)
