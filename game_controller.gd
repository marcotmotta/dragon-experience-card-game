extends Node2D

# Seat helpers {{{
enum Seat {
	P1,
	P2
}

func controller_of(seat: Seat) -> Node:
	return $Player if seat == Seat.P1 else $Player2

func board_of(seat: Seat) -> Node:
	return $Board/PlayerBoard if seat == Seat.P1 else $Board/CPUBoard

func hand_of(seat: Seat) -> Node:
	return $Board/PlayerHand if seat == Seat.P1 else $Board/CPUHand

func char_of(seat: Seat) -> Node:
	return $Board/PlayerChar/Char if seat == Seat.P1 else $Board/CPUChar/Char

func opponent_of(seat: Seat) -> Seat:
	return Seat.P2 if seat == Seat.P1 else Seat.P1

func seat_of_char(c) -> Seat:
	return Seat.P1 if c == $Board/PlayerChar/Char else Seat.P2
# }}}

enum phases {
	UPKEEP,
	DRAW,
	PLAY,
	END
}

var current_turn_state = {
	'turn': 0,
	'owner': Seat.P1,
	'phase': phases.UPKEEP
}

var player_state = {
	Seat.P1: { 'health': 30, 'current_health': 30 },
	Seat.P2: { 'health': 30, 'current_health': 30 },
}


# effects
var trigger_queue = []

@onready var minion_scene = load("res://Minion/Minion.tscn")
@onready var card_interface_scene = load("res://cards/CardInterface/CardInterface.tscn")

var cards

func _reset_game():
	$Player.seat = Seat.P1
	$Player2.seat = Seat.P2
	$Board/PlayerChar/Char.owner_node = $Player
	$Board/CPUChar/Char.owner_node = $Player2
	$Board/PlayerChar/Char.main_scene = self
	$Board/CPUChar/Char.main_scene = self

	# choose begin play
	current_turn_state.owner = [Seat.P1, Seat.P2].pick_random()

	# draw initial cards
	for i in range(2):
		$Player.draw_card_from_deck()
		$Player2.draw_card_from_deck()

	# begin game
	_set_turn_phase(phases.UPKEEP)

func _ready():
	cards = Globals.cards

	_reset_game()

func _process(delta):
	handle_trigger_queue()

	# debug
	$Selected.text = str(selected_source)
	
	# ui
	var phase_text = ''
	
	match current_turn_state.phase:
		phases.UPKEEP:
			phase_text = 'UPKEEP'
		phases.DRAW:
			phase_text = 'DRAW'
		phases.PLAY:
			phase_text = 'PLAY'
		phases.END:
			phase_text = 'END'

	$CurrentTurn.text = 'Turn: ' + str(current_turn_state.turn) + \
						'\nPlayer: ' + str(current_turn_state.owner) + \
						'\nPhase: ' + phase_text

	$CPUMana.text = 'Mana: ' + str($Player2.current_mana) + '/' + str($Player2.mana)
	$PlayerMana.text = 'Mana: ' + str($Player.current_mana) + '/' + str($Player.mana)

	$PlayerDeckCount.text = 'Deck: ' + str($Player.deck.size())
	$CPUDeckCount.text = 'Deck: ' + str($Player2.deck.size())

	var player_hand_count = 0
	for pos in $Board/PlayerHand.get_children():
		if pos.get_children():
			player_hand_count += 1
	$PlayerHandCount.text = 'Hand: ' + str(player_hand_count) + '/7'

	var cpu_hand_count = 0
	for pos in $Board/CPUHand.get_children():
		if pos.get_children():
			cpu_hand_count += 1
	$CPUHandCount.text = 'Hand: ' + str(cpu_hand_count) + '/7'

	char_of(Seat.P1).get_node("Health").text = str(player_state[Seat.P1].current_health)
	char_of(Seat.P2).get_node("Health").text = str(player_state[Seat.P2].current_health)

	# end game check
	if player_state[Seat.P1].current_health <= 0:
		$EndGameUI/Control/WinLabel.text = 'Player 2 Won!'
		end_game()
	if player_state[Seat.P2].current_health <= 0:
		$EndGameUI/Control/WinLabel.text = 'Player 1 Won!'
		end_game()

func _go_to_next_phase():
	_set_turn_phase(current_turn_state.phase + 1)

func _set_turn_phase(new_phase):
	# What to do when some phase begin
	match new_phase:
		phases.UPKEEP:
			current_turn_state.phase = phases.UPKEEP
			clear_targeting()

			# reset minion attack
			var board_positions = board_of(current_turn_state.owner).get_children()
			for pos in board_positions:
				if pos.get_children():
					pos.get_child(0).attacked = false

			# gain mana
			if current_turn_state.owner == Seat.P1:
				if $Player.mana < 10:
					$Player.gain_max_mana(1)
				$Player.refresh_mana()
			else:
				if $Player2.mana < 10:
					$Player2.gain_max_mana(1)
				$Player2.refresh_mana()

			await get_tree().create_timer(0.5).timeout
			_go_to_next_phase()

		phases.DRAW:
			current_turn_state.phase = phases.DRAW
			clear_targeting()

			controller_of(current_turn_state.owner).draw_card_from_deck()

			await get_tree().create_timer(0.5).timeout
			_go_to_next_phase()

		phases.PLAY:
			current_turn_state.phase = phases.PLAY
			clear_targeting()

			# enable end turn button if its the players turn
			if current_turn_state.owner == Seat.P1:
				$EndTurnButton.disabled = false

			# cpu turn:
			else:
				# trigger cpu playing
				while ($Player2.iterate_available_actions()):
					await get_tree().create_timer(1.5).timeout
				_go_to_next_phase()

		phases.END:
			current_turn_state.phase = phases.END
			clear_targeting()

			# disable minion attack
			var board_positions = board_of(current_turn_state.owner).get_children()
			for pos in board_positions:
				if pos.get_children():
					pos.get_child(0).attacked = true

			# check triggered effects
			check_triggered_effects(TriggeredEffect.TriggerType.ON_TURN_END)

			current_turn_state.turn += 1
			current_turn_state.owner = Seat.P2 if current_turn_state.owner == Seat.P1 else Seat.P1

			# disable end turn button, no matter which turn
			$EndTurnButton.disabled = true

			_set_turn_phase(phases.UPKEEP)

func _on_end_turn_button_pressed() -> void:
	_go_to_next_phase()

# create card in hand
func create_card(card_owner, card_name):
	var owner_hand = hand_of(card_owner)

	# check hand size
	var positions = owner_hand.get_children()

	for pos in positions:
		if not pos.get_children():
			# available position!
			# create card
			var card_interface_instance = card_interface_scene.instantiate()
			card_interface_instance.main_scene = self
			card_interface_instance.card_name = cards[card_name].name
			card_interface_instance.cost = cards[card_name].cost
			card_interface_instance.rarity = cards[card_name].rarity
			card_interface_instance.description = cards[card_name].description
			card_interface_instance.attack = cards[card_name].attack
			card_interface_instance.health = cards[card_name].health
			card_interface_instance.type = cards[card_name].type
			card_interface_instance.minion_type = cards[card_name].minion_type
			card_interface_instance.triggered_effects = cards[card_name].triggered_effects
			card_interface_instance.requires_target = cards[card_name].requires_target
			card_interface_instance.card_owner = card_owner
			card_interface_instance.owner_node = controller_of(card_owner)
			card_interface_instance.art = cards[card_name].art
			pos.add_child(card_interface_instance)

			return true

	print('couldnt create card. hand full.')
	return false

# spawn minion on board
func spawn_minion(minion_owner, minion_name, triggered_effects = []):
	var board = board_of(minion_owner)

	# check available positions
	var positions = board.get_children()

	for pos in positions:
		if not pos.get_children():
			# available position!
			# spawn minion
			var minion_instance = minion_scene.instantiate()
			minion_instance.main_scene = self
			minion_instance.minion_name = cards[minion_name].name
			minion_instance.BASE_ATTACK = cards[minion_name].attack
			minion_instance.BASE_HEALTH = cards[minion_name].health
			minion_instance.type = cards[minion_name].minion_type
			minion_instance.triggered_effects = triggered_effects
			minion_instance.minion_owner = minion_owner
			minion_instance.owner_node = controller_of(minion_owner)
			minion_instance.art = cards[minion_name].art
			pos.add_child(minion_instance)

			return true

	# if arrived here, no available positions
	print('couldnt spawn minions. board full.')
	return false

# targeting system {{{
# TODO: levar pra outro arquivo?
enum TargetMode {
	NONE,
	ATTACK,
	PLAY_CARD
}

var current_mode = TargetMode.NONE
var selected_source = null

func clear_targeting():
	current_mode = TargetMode.NONE
	selected_source = null

func resolve_deaths():
	for i in range(2):
		var board = board_of(i)
		for pos in board.get_children():
			if pos.get_children():
				var minion = pos.get_child(0)
				if minion.is_dead:
					# queue trigger then remove from board
					for trigger in minion.triggered_effects:
						if trigger.trigger_type == TriggeredEffect.TriggerType.ON_DEATH:
							trigger_queue.append({'source': minion, 'owner_node': minion.owner_node, 'trigger': trigger})
					print('freeing minion ', minion)
					minion.get_parent().remove_child(minion)

func resolve_trigger_queue():
	while trigger_queue.size() > 0:
		var dict = trigger_queue.pop_front()
		for effect in dict.trigger.effects:
			var owner_node = dict.owner_node
			var board1 = board_of(owner_node.seat)
			var board2 = board_of(opponent_of(owner_node.seat))
			var char1 = char_of(owner_node.seat)
			var char2 = char_of(opponent_of(owner_node.seat))

			var targets = effect.target_selector.get_targets(self, null, owner_node, char1, char2, board1, board2)
			print('tringgering effect for minion ', dict.source)

			if targets:
				for t in targets:
					effect.execute(dict.source, t)

			else:
				effect.execute(dict.source, null)

func clear_deaths():
	for i in range(2):
		var board = board_of(i)
		for pos in board.get_children():
			if pos.get_children():
				var minion = pos.get_child(0)
				if minion.is_dead:
					minion.queue_free()

# this is used to solve trigger effects order when minions die
func handle_trigger_queue():
	resolve_deaths()
	resolve_trigger_queue()
	clear_deaths()

func check_triggered_effects(trigger_type):
	var owner_node = controller_of(current_turn_state.owner)
	var board1 = board_of(current_turn_state.owner)
	var board2 = board_of(opponent_of(current_turn_state.owner))
	var char1 = char_of(current_turn_state.owner)
	var char2 = char_of(opponent_of(current_turn_state.owner))

	for pos in board1.get_children():
		if pos.get_children():
			var minion = pos.get_child(0)

			for trigger in minion.triggered_effects:
				if trigger.trigger_type == trigger_type:
					for effect in trigger.effects:
						var targets = effect.target_selector.get_targets(minion, null, owner_node, char1, char2, board1, board2)

						if targets:
							for t in targets:
								effect.execute(minion, t)

						else:
							effect.execute(minion, null)

func handle_selection(obj):
	if obj.is_in_group('minion'):
		if not obj.attacked:
			current_mode = TargetMode.ATTACK
			selected_source = obj

	elif obj.is_in_group('card'):
		if obj.requires_target:
			current_mode = TargetMode.PLAY_CARD
			selected_source = obj
		else:
			obj.play_card()

func handle_target(target):
	match current_mode:
		TargetMode.ATTACK:
			if (target.is_in_group('minion') and selected_source.owner_node != target.owner_node) or \
			(target.is_in_group('char') and selected_source.owner_node != target.owner_node):
				selected_source.attack(target)

		TargetMode.PLAY_CARD:
			selected_source.play_card(target)

	clear_targeting()

func on_object_clicked(obj):
	if current_mode == TargetMode.NONE:
		handle_selection(obj)
	else:
		handle_target(obj)
# }}}

# player health from char node {{{
func get_player_health(char):
	var player_state_info = player_state[seat_of_char(char)]

	return {'total': player_state_info.health, 'current': player_state_info.current_health}

# type: damage, heal
#
func handle_player_health(char, type, amount):
	var player_state_info = player_state[seat_of_char(char)]

	if type == 'damage':
		player_state_info.current_health -= amount
	elif type == 'heal':
		player_state_info.current_health = min(player_state_info.current_health + amount, player_state_info.health)
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

	# DEBUG FUNCTIONS
	# pass phase
	if event.is_action_pressed('f1'):
		_reset_game()

	# create player minion
	if event.is_action_pressed('f2'):
		create_card(Seat.P1, 'knight')

	# create cpu minion
	if event.is_action_pressed('f3'):
		spawn_minion(Seat.P2, 'zombie')

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _on_resume_pressed() -> void:
	$MenuUI.visible = false
