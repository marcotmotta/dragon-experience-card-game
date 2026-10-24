extends RefCounted
class_name Resolver

# The rules engine: takes an Action (data), validates it against the GameState, and
# applies it by mutating the state, recording what happened as Events. On the network
# the host runs this; clients send Actions and receive events/state.

var state: GameState
var rng: RandomNumberGenerator

# events produced by the current/last operation; drained via take_events()
var events: Array = []

func _init(game_state: GameState, rng_source: RandomNumberGenerator = null) -> void:
	state = game_state
	rng = rng_source if rng_source else RandomNumberGenerator.new()

# Validate then apply. Returns the events produced (empty when rejected).
func resolve(action: Dictionary) -> Array:
	if not validate(action):
		return []
	_apply(action)
	return take_events()

# Returns the accumulated events and clears the buffer. The turn machine calls the
# lifecycle methods (draw_card / check_triggered_effects) directly, so it drains here
# after those calls too.
func take_events() -> Array:
	var current_events = events
	events = []
	return current_events

# --- validation ---

func validate(action: Dictionary) -> bool:
	match action.type:
		Actions.Type.END_TURN:
			return _validate_end_turn(action)
		Actions.Type.PLAY_CARD:
			return _validate_play_card(action)
		Actions.Type.ATTACK:
			return _validate_attack(action)
	return false

func _validate_end_turn(action: Dictionary) -> bool:
	return action.by == state.active_seat and state.phase == GameEnums.Phase.PLAY

func _validate_play_card(action: Dictionary) -> bool:
	if action.by != state.active_seat:
		return false
	if state.phase != GameEnums.Phase.PLAY:
		return false
	var hand = state.players[action.by].hand
	if action.hand_index < 0 or action.hand_index >= hand.size():
		return false
	var card = hand[action.hand_index]
	if state.players[action.by].current_mana < card.data.cost:
		return false

	# minion cards need a free board slot
	if card.data.type == 'minion' and not state.players[action.by].board.has(null):
		return false

	# targeting gate
	if card.data.requires_target:
		if not has_legal_target(card, action.by):
			# no legal target: unplayable, unless the card lets you play without one
			if not card.data.target_optional:
				return false
		else:
			# a legal target exists → the player must pick a legal one
			if action.target == null:
				return false
			if not is_legal_target(card, resolve_target(action.target), action.by):
				return false
	else:
		# untargeted (AoE / no-target): keep the per-effect "has something to do" check
		for trigger in card.data.triggered_effects:
			if trigger.trigger_type == TriggeredEffect.TriggerType.ON_PLAY:
				for effect in trigger.effects:
					if not effect.validate_possible_play_state(state, action.by, false)[0]:
						return false
	return true

# Is `target` a legal target for playing `card`? A card-level TargetRestriction (hard
# gate) decides when present; otherwise the target must be accepted by EVERY ON_PLAY
# effect (effects that don't care about the target return true via base validate_play_state).
func is_legal_target(card, target, seat: int) -> bool:
	if target == null:
		return false
	if card.data.target_restriction != null:
		return card.data.target_restriction.allows(target, seat)
	for trigger in card.data.triggered_effects:
		if trigger.trigger_type == TriggeredEffect.TriggerType.ON_PLAY:
			for effect in trigger.effects:
				if not effect.validate_play_state(target):
					return false
	return true

# Every entity (heroes + board minions) that `card` could legally target right now.
func legal_targets_for_card(card, seat: int) -> Array:
	var out := []
	for candidate in _targetable_entities():
		if is_legal_target(card, candidate, seat):
			out.append(candidate)
	return out

func has_legal_target(card, seat: int) -> bool:
	for candidate in _targetable_entities():
		if is_legal_target(card, candidate, seat):
			return true
	return false

func _targetable_entities() -> Array:
	var out := []
	for s in [GameEnums.Seat.P1, GameEnums.Seat.P2]:
		out.append(state.players[s])
		for minion in state.players[s].board:
			if minion != null:
				out.append(minion)
	return out

# "Could this card be played at all right now?" — for the hand's playable highlight.
# Unlike validate(), it needs no chosen target: a targeted card counts as playable when
# a legal target exists (the player will pick one) or targeting is optional.
func can_play(card, seat: int) -> bool:
	if seat != state.active_seat or state.phase != GameEnums.Phase.PLAY:
		return false
	if state.players[seat].current_mana < card.data.cost:
		return false
	if card.data.type == 'minion' and not state.players[seat].board.has(null):
		return false
	if card.data.requires_target:
		return card.data.target_optional or has_legal_target(card, seat)
	for trigger in card.data.triggered_effects:
		if trigger.trigger_type == TriggeredEffect.TriggerType.ON_PLAY:
			for effect in trigger.effects:
				if not effect.validate_possible_play_state(state, seat, false)[0]:
					return false
	return true

func _validate_attack(action: Dictionary) -> bool:
	if action.by != state.active_seat:
		return false
	if state.phase != GameEnums.Phase.PLAY:
		return false
	var attacker = state.entities.get(action.attacker_id)
	if attacker == null:
		return false
	if attacker.owner != action.by:
		return false
	if attacker.attacked:
		return false
	var target = resolve_target(action.target)
	if target == null:
		return false
	# target must be legal: enemy ownership + the Sentinel rule
	if not legal_attack_targets(attacker).has(target):
		return false
	return true

# The targets an attacker may legally hit: enemy minions + enemy hero — but if the
# enemy has any Sentinel minion, only the Sentinel minions (Sentinel forces attacks onto it).
func legal_attack_targets(attacker) -> Array:
	var opponent_seat = state.opponent_of(attacker.owner)
	var board = state.players[opponent_seat].board

	var sentinels = []
	var minions = []
	for minion in board:
		if minion != null:
			minions.append(minion)
			if 'Sentinel' in minion.properties:
				sentinels.append(minion)

	if not sentinels.is_empty():
		return sentinels
	return minions + [state.players[opponent_seat]]

# --- application ---

func _apply(action: Dictionary) -> void:
	match action.type:
		Actions.Type.END_TURN:
			pass  # EndTurn is driven by the turn machine (timers/UI), not here
		Actions.Type.PLAY_CARD:
			play_card(action.by, action.hand_index, action.target)
		Actions.Type.ATTACK:
			do_attack(action.attacker_id, action.target)

# --- helpers ---

# Turns a target descriptor into the actual state object: a MinionInstance (minion)
# or a PlayerState (hero). Returns null if it can't be resolved.
func resolve_target(descriptor):
	if descriptor == null:
		return null
	match descriptor.kind:
		Actions.TargetKind.MINION:
			return state.entities.get(descriptor.ref)
		Actions.TargetKind.HERO:
			return state.players.get(descriptor.ref)
	return null

# Effects mutate the instances directly and record what happened via emit().
func emit(event) -> void:
	events.append(event)

# --- entity lifecycle — the mutations that used to live in the nodes,
#     now on the state. Activates the entities registry + hand/board arrays. ---

func _find_board_slot(board):
	var slot_priority_order = [3, 2, 4, 1, 5, 0, 6]

	for slot in slot_priority_order:
		if board[slot] == null:
			return slot

	return -1

# Creates a minion on `seat`'s board (first empty slot). `triggered_effects` are the
# non-ON_PLAY effects a played card grants; summoned tokens pass []. Fires ON_SUMMON.
# Returns the MinionInstance, or null if the board was full.
func spawn_minion(seat: int, card_name: String, triggered_effects: Array = []):
	var board = state.players[seat].board
	var slot = _find_board_slot(board)
	if slot == -1:
		return null

	var card_data = Globals.cards[card_name]
	var minion = MinionInstance.new()
	minion.owner = seat
	minion.data = card_data
	minion.BASE_ATTACK = card_data.attack
	minion.BASE_HEALTH = card_data.health
	minion.max_attack = card_data.attack
	minion.max_health = card_data.health
	minion.current_attack = card_data.attack
	minion.current_health = card_data.health
	minion.minion_type = card_data.minion_type
	minion.attacked = true # can't attack the turn it's summoned
	minion.triggered_effects = triggered_effects
	state.register(minion)
	board[slot] = minion
	events.append(Events.minion_spawned(minion.id))

	for trigger in minion.triggered_effects:
		if trigger.trigger_type == TriggeredEffect.TriggerType.ON_SUMMON:
			_run_trigger(minion, trigger)

	return minion

# Plays the hand card at `hand_index`: spends mana, spawns (minion) or runs ON_PLAY
# (spell), then discards the card. Assumes validate() already passed.
func play_card(seat: int, hand_index: int, target_desc = null) -> void:
	var player_state = state.players[seat]
	var card = player_state.hand[hand_index]
	player_state.hand.remove_at(hand_index)
	player_state.current_mana -= card.data.cost
	events.append(Events.card_played(seat, card.card_name))

	# For a minion card, ON_PLAY runs after the minion is on the board, so the minion
	# (not the card) is the trigger source — lets a battlecry reference itself.
	var play_source = card
	if card.data.type == 'minion':
		var selected: Array = []
		for trigger in card.data.triggered_effects:
			if trigger.trigger_type != TriggeredEffect.TriggerType.ON_PLAY:
				selected.append(trigger)
		var summoned = spawn_minion(seat, card.card_name, selected)
		if summoned != null:
			play_source = summoned

	var target = resolve_target(target_desc)
	for trigger in card.data.triggered_effects:
		if trigger.trigger_type == TriggeredEffect.TriggerType.ON_PLAY:
			_run_trigger(play_source, trigger, target)

	state.unregister(card.id)
	_resolve_deaths()

# Moves the top card of the deck to the hand (no-op if deck empty or hand full).
func draw_card(seat: int) -> void:
	var player_state = state.players[seat]
	if player_state.deck.is_empty():
		return
	if player_state.hand.size() >= 7:
		return
	player_state.hand.append(player_state.deck.pop_back())
	events.append(Events.card_drawn(seat))

# Creates a brand-new card straight into the hand (no-op if hand full).
func add_card(seat: int, card_name: String) -> void:
	var player_state = state.players[seat]
	if player_state.hand.size() >= 7:
		return
	var card_instance = CardInstance.new()
	card_instance.owner = seat
	card_instance.card_name = card_name
	card_instance.data = Globals.cards[card_name]
	state.register(card_instance)
	player_state.hand.append(card_instance)
	events.append(Events.card_drawn(seat))

# Minion attacks a target (minion or hero). Both take damage; a minion attacker
# only takes retaliation from a minion target. Then deaths resolve.
func do_attack(attacker_id: int, target_descriptor) -> void:
	var attacker = state.entities.get(attacker_id)
	var target = resolve_target(target_descriptor)
	if attacker == null or target == null:
		return

	# trigger ON_ATTACK effects
	for trigger in attacker.triggered_effects:
		if trigger.trigger_type == TriggeredEffect.TriggerType.ON_ATTACK:
			_run_trigger(attacker, trigger)

	var retaliation = target.current_attack if (target is MinionInstance) else 0
	events.append(Events.attacked(attacker_id, target_descriptor))

	deal_damage_to_target(target, attacker.current_attack)
	if target is MinionInstance:
		deal_damage_to_target(attacker, retaliation)

	attacker.attacked = true
	_resolve_deaths()

func deal_damage_to_target(target, amount: int) -> void:
	target.take_damage(amount)

	# ON_TAKING_DAMAGE só faz sentido pra minion. roda antes de _resolve_deaths().
	if target is MinionInstance:
		for trigger in target.triggered_effects:
			if trigger.trigger_type == TriggeredEffect.TriggerType.ON_TAKING_DAMAGE:
				_run_trigger(target, trigger)

	emit(Events.damage_dealt(Actions.descriptor_of(target), amount))

# Runs one trigger's effects: each effect's selector picks targets on the state, then
# execute_state runs. `source` is the MinionInstance/CardInstance owning the trigger.
func _run_trigger(source, trigger, initial_target = null) -> void:
	# check conditions for trigger
	for condition in trigger.conditions:
		if not condition.check(self, source, initial_target):
			return

	for effect in trigger.effects:
		var targets = effect.target_selector.get_targets_state(state, source, source.owner, initial_target, rng)
		if targets:
			for target in targets:
				effect.execute_state(self, source, target)
		else:
			effect.execute_state(self, source, null)

# Removes dead minions, firing their ON_DEATH triggers in a deterministic order.
# Loops because an ON_DEATH effect can kill further minions.
func _resolve_deaths() -> void:
	while true:
		var queued := []
		for seat in [GameEnums.Seat.P1, GameEnums.Seat.P2]:
			var board = state.players[seat].board
			for i in board.size():
				var minion = board[i]
				if minion != null and minion.is_dead():
					for trigger in minion.triggered_effects:
						if trigger.trigger_type == TriggeredEffect.TriggerType.ON_DEATH:
							queued.append({'source': minion, 'trigger': trigger})
					events.append(Events.minion_died(minion.id))
					board[i] = null
					state.unregister(minion.id)
		if queued.is_empty():
			return
		for queued_death in queued:
			_run_trigger(queued_death.source, queued_death.trigger)

# Fires all triggers of a given type on `seat`'s board (e.g. ON_TURN_END).
func check_triggered_effects(trigger_type: int, seat: int) -> void:
	for minion in state.players[seat].board:
		if minion != null:
			for trigger in minion.triggered_effects:
				if trigger.trigger_type == trigger_type:
					_run_trigger(minion, trigger)
	_resolve_deaths()
