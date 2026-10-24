extends Node

# GameEnums.Seat
var seat : int

var main_scene

func _ready() -> void:
	main_scene = get_parent()

# Produces the next Action the CPU wants to take, or null when it's done. Reads the
# GameState and returns a serializable Action — exactly what a human/remote would emit.
# Every returned action is one validate() accepts, so a bad proposal never ends the turn.
func next_action():
	var game_state = main_scene.game_state
	var my_player_state = game_state.players[seat]
	var opponent_seat = game_state.opponent_of(seat)
	var opponent_player_state = game_state.players[opponent_seat]

	# 1. play a minion (needs a board slot + mana)
	if my_player_state.board.has(null):
		for hand_index in my_player_state.hand.size():
			var card = my_player_state.hand[hand_index]
			if card.data.type != 'minion':
				continue
			# can_play is the same gate the resolver validates with (mana/slot/phase), so we
			# never propose an invalid action (which would end the turn before the CPU attacks)
			if not main_scene.resolver.can_play(card, seat):
				continue
			if card.data.requires_target:
				var target = _cpu_pick_target(card)
				if target != null:
					return Actions.play_card(seat, hand_index, target)
				# playable but no target the CPU wants to use: play targetless only when there's
				# genuinely no legal target (optional cards); else skip and keep its own minions
				if card.data.target_optional and not main_scene.resolver.has_legal_target(card, seat):
					return Actions.play_card(seat, hand_index, null)
				continue
			if _cpu_untargeted_useful(card):
				return Actions.play_card(seat, hand_index, null)
			continue

	# 2. play a spell
	for hand_index in my_player_state.hand.size():
		var card = my_player_state.hand[hand_index]
		if card.data.type != 'spell':
			continue
		if not main_scene.resolver.can_play(card, seat):
			continue
		if card.data.requires_target:
			var target = _cpu_pick_target(card)
			if target != null:
				return Actions.play_card(seat, hand_index, target)
			if card.data.target_optional and not main_scene.resolver.has_legal_target(card, seat):
				return Actions.play_card(seat, hand_index, null)
			continue
		if _cpu_untargeted_useful(card):
			return Actions.play_card(seat, hand_index, null)
		continue

	# 3. attack
	var attackers = []
	for minion in my_player_state.board:
		# cpu does not attack with 0 attack minions
		if minion != null and not minion.attacked and minion.current_attack > 0:
			attackers.append(minion)
	if attackers.is_empty():
		return null

	# legal targets respect Sentinel (same source of truth the resolver validates with).
	# all attackers share the same enemy board, so compute once from the first.
	var targets = main_scene.resolver.legal_attack_targets(attackers[0])
	if targets.is_empty():
		return null

	# lethal → go face (only if the hero is actually attackable, i.e. no Sentinel)
	if opponent_player_state in targets:
		var sum_attacks = 0
		for minion in attackers:
			sum_attacks += minion.current_attack

		if opponent_player_state.current_health - sum_attacks <= 0:
			return Actions.attack(seat, attackers[0].id, Actions.hero_target(opponent_seat))

	# prefer hitting a minion (if Sentinel is up, these are only the Sentinel minions)
	var minion_targets = []
	for target in targets:
		if target is MinionInstance:
			minion_targets.append(target)
	if not minion_targets.is_empty():
		return Actions.attack(seat, attackers[0].id, Actions.minion_target(minion_targets.pick_random().id))

	# else only the hero is attackable → go face
	return Actions.attack(seat, attackers[0].id, Actions.hero_target(opponent_seat))

func _on_play_triggers(card) -> Array:
	var triggers = []
	for trigger in card.data.triggered_effects:
		if trigger.trigger_type == TriggeredEffect.TriggerType.ON_PLAY:
			triggers.append(trigger)
	return triggers

# A target descriptor the CPU actually WANTS to use for a requires_target card, or null.
# - Restricted cards: any target the restriction allows (e.g. Bloated Corpse → an ally).
# - Unrestricted cards: the AI's own per-effect preference (ownership-aware via is_cpu —
#   offensive effects only list enemies), narrowed to targets valid for the WHOLE card.
#   So Staff (silence + damage) only aims at an enemy minion: never a hero (silence can't)
#   and never the CPU's own minions (not in the is_cpu lists). With no such target it
#   returns null, and the CPU simply skips the card instead of wasting it.
func _cpu_pick_target(card):
	var game_state = main_scene.game_state
	if card.data.target_restriction != null:
		var legal = card.data.target_restriction.legal_targets(game_state, seat)
		return Actions.descriptor_of(legal.pick_random()) if not legal.is_empty() else null

	var pool = []
	for trigger in _on_play_triggers(card):
		for effect in trigger.effects:
			for t in effect.validate_possible_play_state(game_state, seat, true)[1]:
				if not pool.has(t) and main_scene.resolver.is_legal_target(card, t, seat):
					pool.append(t)
	return Actions.descriptor_of(pool.pick_random()) if not pool.is_empty() else null

# Whether an untargeted card is worth playing for the CPU: a plain body/draw (no ON_PLAY
# effect) always is; otherwise at least one ON_PLAY effect must affect the CPU's own side.
# Uses is_cpu lists (which exclude enemy-only hits), so the CPU won't waste e.g. Blessing
# when only the opponent has the matching tribe.
func _cpu_untargeted_useful(card) -> bool:
	var game_state = main_scene.game_state
	var has_on_play = false
	for trigger in _on_play_triggers(card):
		for effect in trigger.effects:
			has_on_play = true
			if effect.validate_possible_play_state(game_state, seat, true)[0]:
				return true
	return not has_on_play
