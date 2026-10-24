extends Node2D

var game_state: GameState
var resolver: Resolver

@onready var minion_scene = load("res://Minion/Minion.tscn")
@onready var card_interface_scene = load("res://cards/CardInterface/CardInterface.tscn")
@onready var menu_card_interface_scene = load("res://cards/CardInterface/MenuCardInterface.tscn")

# vfxs
@onready var vfx_damage_scene = load("res://vfx/damage/damage.tscn")
@onready var vfx_powerup_scene = load("res://vfx/powerup/powerup.tscn")
@onready var vfx_play_card_scene = load("res://vfx/play_card/play_card.tscn")
# sounds
@onready var sound_player_scene = load("res://sound/SoundPlayer.tscn")
@onready var draw_sound = load("res://sound/draw.wav")
@onready var heal_sound = load("res://sound/heal.wav")
@onready var hit_sound = load("res://sound/hit.wav")
@onready var minion_spawn_sound = load("res://sound/minion_spawn.wav")
@onready var power_up_sound = load("res://sound/power_up.wav")
@onready var spell_sound = load("res://sound/spell.wav")

func _reset_game():
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# choose decks
	var p1_deck: Array
	var p2_deck: Array

	if Globals.p1_deck:
		if Globals.p1_deck == 'Test Deck':
			p1_deck = Globals.test_deck
		else:
			p1_deck = Globals.premade_decks[Globals.p1_deck]
	else:
		p1_deck = Globals.premade_decks.values().pick_random()

	if Globals.p2_deck:
		p2_deck = Globals.premade_decks[Globals.p2_deck]
	else:
		p2_deck = Globals.premade_decks.values().pick_random()

	game_state = GameState.new_game(p1_deck, p2_deck, rng)
	resolver = Resolver.new(game_state, rng)

	$Player.seat = GameEnums.Seat.P1
	$Player2.seat = GameEnums.Seat.P2
	$Board/PlayerChar/Char.owner_node = $Player
	$Board/CPUChar/Char.owner_node = $Player2
	$Board/PlayerChar/Char.main_scene = self
	$Board/CPUChar/Char.main_scene = self

	# draw initial cards
	for i in range(2):
		resolver.draw_card(GameEnums.Seat.P1)
		resolver.draw_card(GameEnums.Seat.P2)

	resolver.take_events()  # discard startup draw sounds

	sync_view_from_state()

	_set_turn_phase(GameEnums.Phase.UPKEEP)

func _ready():
	_reset_game()

func _process(delta):
	# FIXME: debug
	$Selected.text = str(selected_source)

	# ui
	var phase_text = ''
	match game_state.phase:
		GameEnums.Phase.UPKEEP:
			phase_text = 'UPKEEP'
		GameEnums.Phase.DRAW:
			phase_text = 'DRAW'
		GameEnums.Phase.PLAY:
			phase_text = 'PLAY'
		GameEnums.Phase.END:
			phase_text = 'END'

	$CurrentTurn.text = 'Turn: ' + str(game_state.turn) + \
						'\nPlayer: ' + str(game_state.active_seat) + \
						'\nPhase: ' + phase_text

	var player1_state = game_state.players[GameEnums.Seat.P1]
	var player2_state = game_state.players[GameEnums.Seat.P2]

	$PlayerMana.text = 'Mana: ' + str(player1_state.current_mana) + '/' + str(player1_state.mana)
	$CPUMana.text = 'Mana: ' + str(player2_state.current_mana) + '/' + str(player2_state.mana)
	$PlayerDeckCount.text = 'Deck: ' + str(player1_state.deck.size())
	$CPUDeckCount.text = 'Deck: ' + str(player2_state.deck.size())
	$PlayerHandCount.text = 'Hand: ' + str(player1_state.hand.size()) + '/7'
	$CPUHandCount.text = 'Hand: ' + str(player2_state.hand.size()) + '/7'

	char_of(GameEnums.Seat.P1).get_node("Health").text = str(player1_state.current_health)
	char_of(GameEnums.Seat.P2).get_node("Health").text = str(player2_state.current_health)

	# end game check
	if player1_state.current_health <= 0:
		$EndGameUI/Control/WinLabel.text = 'Player 2 Won!'
		end_game()
	if player2_state.current_health <= 0:
		$EndGameUI/Control/WinLabel.text = 'Player 1 Won!'
		end_game()

func _go_to_next_phase():
	_set_turn_phase(game_state.phase + 1)

func _set_turn_phase(new_phase):
	match new_phase:
		GameEnums.Phase.UPKEEP:
			game_state.phase = GameEnums.Phase.UPKEEP
			clear_targeting()

			# reset attack for the active seat's minions
			for minion in game_state.players[game_state.active_seat].board:
				if minion != null:
					minion.attacked = false

			# gain mana
			var player_state = game_state.players[game_state.active_seat]
			if player_state.mana < 10:
				player_state.mana += 1
			player_state.current_mana = player_state.mana

			resolver.check_triggered_effects(TriggeredEffect.TriggerType.ON_TURN_START, game_state.active_seat)

			await _present_and_sync(resolver.take_events())

			await get_tree().create_timer(0.5).timeout

			_go_to_next_phase()

		GameEnums.Phase.DRAW:
			game_state.phase = GameEnums.Phase.DRAW
			clear_targeting()

			resolver.draw_card(game_state.active_seat)

			await _present_and_sync(resolver.take_events())

			await get_tree().create_timer(0.5).timeout

			_go_to_next_phase()

		GameEnums.Phase.PLAY:
			game_state.phase = GameEnums.Phase.PLAY
			clear_targeting()

			if game_state.active_seat == GameEnums.Seat.P1:
				$EndTurnButton.disabled = false

			else:
				# cpu turn — pull actions until it has nothing left
				var guard = 0
				while await _cpu_take_action():
					guard += 1
					if guard > 100:
						break
					await get_tree().create_timer(1.5).timeout

				_go_to_next_phase()

		GameEnums.Phase.END:
			game_state.phase = GameEnums.Phase.END
			clear_targeting()

			# disable attack for the active seat's minions
			for minion in game_state.players[game_state.active_seat].board:
				if minion != null:
					minion.attacked = true

			resolver.check_triggered_effects(TriggeredEffect.TriggerType.ON_TURN_END, game_state.active_seat)

			await _present_and_sync(resolver.take_events())

			game_state.turn += 1
			game_state.active_seat = game_state.opponent_of(game_state.active_seat)

			$EndTurnButton.disabled = true

			_set_turn_phase(GameEnums.Phase.UPKEEP)

func _on_end_turn_button_pressed() -> void:
	_go_to_next_phase()

# asks the cpu for its next Action; applies it. returns false when it's done.
func _cpu_take_action() -> bool:
	var action = $Player2.next_action()
	if action == null:
		return false
	if not resolver.validate(action):
		# the CPU should only ever propose valid actions; if this fires, next_action has a
		# bug (its targeting is out of sync with the resolver) and the turn ends early
		push_warning("CPU proposed an invalid action, ending its turn: %s" % action)
		return false
	await _present_and_sync(resolver.resolve(action))
	return true

# Seat helpers {{{
func controller_of(seat: GameEnums.Seat) -> Node:
	return $Player if seat == GameEnums.Seat.P1 else $Player2

func board_of(seat: GameEnums.Seat) -> Node:
	return $Board/PlayerBoard if seat == GameEnums.Seat.P1 else $Board/CPUBoard

func hand_of(seat: GameEnums.Seat) -> Node:
	return $Board/PlayerHand if seat == GameEnums.Seat.P1 else $Board/CPUHand

func char_of(seat: GameEnums.Seat) -> Node:
	return $Board/PlayerChar/Char if seat == GameEnums.Seat.P1 else $Board/CPUChar/Char

func seat_of_char(c) -> GameEnums.Seat:
	return GameEnums.Seat.P1 if c == $Board/PlayerChar/Char else GameEnums.Seat.P2
# }}}

# view sync — reconciles the view nodes with the state (keeps stable nodes,
# creates/removes only what changed) {{{
func sync_view_from_state():
	_sync_zone($Board/PlayerHand, game_state.players[GameEnums.Seat.P1].hand, false)
	_sync_zone($Board/CPUHand, game_state.players[GameEnums.Seat.P2].hand, false)
	_sync_zone($Board/PlayerBoard, game_state.players[GameEnums.Seat.P1].board, true)
	_sync_zone($Board/CPUBoard, game_state.players[GameEnums.Seat.P2].board, true)

# Reconcile one zone's view nodes with the state, per position: keep a node that
# already represents the right entity (no flicker), otherwise create/remove. For the
# board, `entities` is the 7-slot array (may hold null); for a hand it's compact.
func _sync_zone(container, entities, is_board):
	var positions = container.get_children()
	for i in positions.size():
		var pos = positions[i]
		var desired = entities[i] if i < entities.size() else null
		var current = pos.get_child(0) if pos.get_child_count() > 0 else null

		# hands collapse empty slots so the remaining cards stay centered (a hidden
		# child is skipped by BoxContainer layout — no width, no separator). Board
		# slots are fixed positions and must always keep their place.
		if not is_board:
			pos.visible = desired != null

		# nothing should be here
		if desired == null:
			if current != null:
				pos.remove_child(current)
				current.free()
			continue

		# already showing this entity - leave it alone (its _process reads live state)
		if current != null and current.entity_id == desired.id:
			continue

		# replace whatever is here with a fresh view bound to the desired entity
		if current != null:
			pos.remove_child(current)
			current.free()

		var view_instance
		if is_board:
			view_instance = minion_scene.instantiate()
			view_instance.minion_owner = desired.owner
		else:
			view_instance = card_interface_scene.instantiate()
			view_instance.card_owner = desired.owner
		view_instance.main_scene = self
		view_instance.entity_id = desired.id
		view_instance.owner_node = controller_of(desired.owner)
		pos.add_child(view_instance)
# }}}

# presentation — plays SFX/VFX from the events, THEN reconciles the view.
# Order matters: impact vfx spawns on the target node while it still exists (before
# sync removes a dying minion). {{{
func _present_and_sync(events) -> void:
	_presenting = true
	await _present(events)
	sync_view_from_state()
	_presenting = false

func _present(events) -> void:
	for event in events:
		match event.type:
			Events.Type.CARD_PLAYED:
				if Globals.cards[event.card_name].type == 'spell':
					GlobalAudioPlayer.play_sound(spell_sound)
				_display_played_card(event.card_name, event.seat)
				# the played card's hand node lingers as a ghost (its entity left the state).
				# remove ONLY that node and fly a copy from its spot — don't sync the hand, or
				# cards this same play draws would pop in before their CARD_DRAWN events.
				var from_pos = _take_played_card(event.seat)
				var play_anim = vfx_play_card_scene.instantiate()
				add_child(play_anim)
				await play_anim.play(event.card_name, from_pos)
				#await get_tree().create_timer(1.0).timeout
			Events.Type.ATTACKED:
				var attacker_node = _target_node(Actions.minion_target(event.attacker_id))
				var target_node = _target_node(event.target)
				if attacker_node != null and target_node != null:
					await attacker_node.play_attack_anim(target_node)
			Events.Type.MINION_SPAWNED:
				GlobalAudioPlayer.play_sound(minion_spawn_sound)
			Events.Type.MINION_DESTROYED:
				GlobalAudioPlayer.play_sound(hit_sound)
				var target_node = _target_node(event.target)
				if target_node != null:
					var vfx_damage_instance = vfx_damage_scene.instantiate()
					vfx_damage_instance.global_position = target_node.global_position
					vfx_damage_instance.emitting = true
					add_child(vfx_damage_instance)
			Events.Type.DAMAGE_DEALT:
				GlobalAudioPlayer.play_sound(hit_sound)
				var target_node = _target_node(event.target)
				if target_node != null:
					var vfx_damage_instance = vfx_damage_scene.instantiate()
					vfx_damage_instance.global_position = target_node.global_position
					vfx_damage_instance.emitting = true
					add_child(vfx_damage_instance)
			Events.Type.HEALED:
				GlobalAudioPlayer.play_sound(heal_sound)
				var target_node = _target_node(event.target)
				if target_node != null:
					var vfx_powerup_instance = vfx_powerup_scene.instantiate()
					vfx_powerup_instance.global_position = target_node.global_position
					vfx_powerup_instance.emitting = true
					add_child(vfx_powerup_instance)
			Events.Type.STAT_BUFFED:
				GlobalAudioPlayer.play_sound(power_up_sound)
				var target_node = _target_node(Actions.minion_target(event.id))
				if target_node != null:
					var vfx_powerup_instance = vfx_powerup_scene.instantiate()
					vfx_powerup_instance.global_position = target_node.global_position
					vfx_powerup_instance.emitting = true
					add_child(vfx_powerup_instance)
			Events.Type.CARD_DRAWN:
				GlobalAudioPlayer.play_sound(draw_sound)

func _display_played_card(card_name: String, seat: GameEnums.Seat) -> void:
	# mostra zoomed card apenas do oponente
	# FIXME: isso deve ser mudado quando entrar multiplayer, provavelmente
	if seat == GameEnums.Seat.P1:
		return

	var card_ui = $ZoomUI.get_node_or_null('MenuCardInterface')
	if card_ui:
		card_ui.free()

	var menu_card_interface_instance = menu_card_interface_scene.instantiate()
	menu_card_interface_instance.location = 'zoom_ui'
	menu_card_interface_instance.card_name = Globals.cards[card_name].name
	menu_card_interface_instance.cost = Globals.cards[card_name].cost
	menu_card_interface_instance.rarity = Globals.cards[card_name].rarity
	menu_card_interface_instance.description = Globals.cards[card_name].description
	menu_card_interface_instance.attack = Globals.cards[card_name].attack
	menu_card_interface_instance.health = Globals.cards[card_name].health
	menu_card_interface_instance.type = Globals.cards[card_name].type
	menu_card_interface_instance.minion_type = Globals.cards[card_name].minion_type
	menu_card_interface_instance.art = Globals.cards[card_name].art
	$ZoomUI.add_child(menu_card_interface_instance)

	$ZoomUI.visible = true
	$ZoomUI/ZoomUITimer.start()

# removes the just-played card's lingering hand node (its entity is already gone from
# state) and returns where it sat — the origin for the play animation. only that one node
# is touched, so cards drawn by the same play still appear later via the final sync.
func _take_played_card(seat) -> Vector2:
	for pos in hand_of(seat).get_children():
		for child in pos.get_children():
			if game_state.entities.get(child.entity_id) == null:
				var at = child.global_position
				child.queue_free()
				return at
	return get_viewport_rect().size / 2.0

# the node to animate for a {kind, ref} descriptor: the hero's char, or the minion
# view found by its entity id
func _target_node(descriptor):
	if descriptor == null:
		return null
	if descriptor.kind == Actions.TargetKind.HERO:
		return char_of(descriptor.ref)
	for container in [$Board/PlayerBoard, $Board/CPUBoard, $Board/PlayerHand, $Board/CPUHand]:
		for pos in container.get_children():
			for child in pos.get_children():
				if child.entity_id == descriptor.ref:
					return child
	return null
# }}}

# is this hand card playable right now (ignoring a specific target)?
func can_play_card(entity_id) -> bool:
	if game_state == null or resolver == null:
		return false
	var card_instance = game_state.entities.get(entity_id)
	if card_instance == null:
		return false
	var hand_index = game_state.players[card_instance.owner].hand.find(card_instance)
	if hand_index == -1:
		return false
	return resolver.can_play(card_instance, card_instance.owner)

# targeting system - builds Actions and submits them to the Resolver {{{
enum TargetMode {
	NONE,
	ATTACK,
	PLAY_CARD
}

var current_mode = TargetMode.NONE
var selected_source = null # a view node (minion/card)
var _presenting := false # true while animations/events play — blocks input

func clear_targeting():
	current_mode = TargetMode.NONE
	selected_source = null

func on_object_clicked(obj):
	if _presenting:
		return
	if current_mode == TargetMode.NONE:
		handle_selection(obj)
	else:
		handle_target(obj)

func handle_selection(obj):
	if obj.is_in_group('minion'):
		var minion = game_state.entities.get(obj.entity_id)
		if minion != null and not minion.attacked and minion.owner == game_state.active_seat:
			current_mode = TargetMode.ATTACK
			selected_source = obj

	elif obj.is_in_group('card'):
		var card_instance = game_state.entities.get(obj.entity_id)
		if card_instance == null:
			return
		# enter targeting only when the card needs a target AND a legal one exists;
		# otherwise play it straight (untargeted, or optional-target with none available)
		if card_instance.data.requires_target and resolver.has_legal_target(card_instance, card_instance.owner):
			current_mode = TargetMode.PLAY_CARD
			selected_source = obj
		else:
			_submit(Actions.play_card(card_instance.owner, _hand_index_of(card_instance), null))

func handle_target(target):
	# only minions and heroes are targetable; clicking anything else (e.g. a card in
	# hand) yields no descriptor — ignore it so the spell/attack isn't wasted and the
	# player stays in targeting mode (right-click still cancels).
	var descriptor = _descriptor_of(target)
	if descriptor == null:
		return

	var action = null
	match current_mode:
		TargetMode.ATTACK:
			if selected_source != null:
				action = Actions.attack(game_state.active_seat, selected_source.entity_id, descriptor)

		TargetMode.PLAY_CARD:
			var card_instance = game_state.entities.get(selected_source.entity_id)
			if card_instance != null:
				action = Actions.play_card(card_instance.owner, _hand_index_of(card_instance), descriptor)

	clear_targeting()
	if action != null:
		_submit(action)

func _submit(action):
	# resolve now (mutates state only, frees no nodes); present + rebuild deferred so we
	# never free the node whose input signal is on the stack, and so damage vfx can spawn
	# on the target node before sync removes anything.
	var events = resolver.resolve(action)
	_presenting = true  # close the one-frame gap before the deferred present
	_present_and_sync.call_deferred(events)

func _hand_index_of(card_instance) -> int:
	return game_state.players[card_instance.owner].hand.find(card_instance)

func _descriptor_of(target):
	if target.is_in_group('minion'):
		return Actions.minion_target(target.entity_id)
	elif target.is_in_group('char'):
		return Actions.hero_target(seat_of_char(target))
	return null
# }}}

func end_game():
	get_tree().paused = true
	$MenuUI.visible = false
	$EndGameUI.visible = true

func _input(event):
	if event.is_action_pressed('mouse2'):
		clear_targeting()

	if event.is_action_pressed('esc'):
		$MenuUI.visible = not $MenuUI.visible

	# FIXME: f1: restart the match (dev)
	if event.is_action_pressed('f1'):
		_reset_game()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _on_resume_pressed() -> void:
	$MenuUI.visible = false

func _on_zoom_ui_timer_timeout() -> void:
	$ZoomUI.visible = false
