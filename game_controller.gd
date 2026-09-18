extends Node2D

enum players {
	PLAYER,
	CPU
}

enum phases {
	UPKEEP,
	DRAW,
	PLAY,
	END
}

var current_turn_state = {
	'turn': 0,
	'owner': players.PLAYER,
	'phase': phases.UPKEEP
}

var player1_state = {
	'health': 30,
	'current_health': 30
	# TODO: put mana here
}

var player2_state = {
	'health': 30,
	'current_health': 30
	# TODO: put mana here
}

var slot_order_number = 0
var p1_slot_order
var p2_slot_order

# effects
enum TriggerType {
	ON_PLAY, # for spells
	ON_DEATH,
	ON_SUMMON,
	ON_ATTACK,
	ON_TURN_START,
	ON_TURN_END
}

var trigger_queue = []

@onready var minion_scene = load("res://Minion/Minion.tscn")
@onready var card_interface_scene = load("res://cards/CardInterface/CardInterface.tscn")

var cards

func _reset_game():
	$Board/PlayerChar/Char.owner_node = $Player
	$Board/CPUChar/Char.owner_node = $Player2
	$Board/PlayerChar/Char.main_scene = self
	$Board/CPUChar/Char.main_scene = self

	# initiate slot ordering
	for slot in $Board/PlayerHand.get_children():
		p1_slot_order = [slot, slot_order_number]
		slot_order_number += 1

	for slot in $Board/CPUHand.get_children():
		p2_slot_order = [slot, slot_order_number]
		slot_order_number += 1

	# choose begin play
	current_turn_state.owner = [players.PLAYER, players.CPU].pick_random()

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

	$Board/PlayerChar/Char.get_node("Health").text = str(player1_state.current_health)
	$Board/CPUChar/Char.get_node("Health").text = str(player2_state.current_health)

	# end game check
	if player1_state.current_health <= 0:
		$EndGameUI/Control/Label.text = 'Player 2 Won!'
		end_game()
	if player2_state.current_health <= 0:
		$EndGameUI/Control/Label.text = 'Player 1 Won!'
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
			var board_positions = ($Board/PlayerBoard if current_turn_state.owner == players.PLAYER else $Board/CPUBoard).get_children()
			for pos in board_positions:
				if pos.get_children():
					pos.get_child(0).attacked = false

			# gain mana
			if current_turn_state.owner == players.PLAYER:
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

			if current_turn_state.owner == players.PLAYER:
				$Player.draw_card_from_deck()
			else:
				$Player2.draw_card_from_deck()

			await get_tree().create_timer(0.5).timeout
			_go_to_next_phase()

		phases.PLAY:
			current_turn_state.phase = phases.PLAY
			clear_targeting()

			# enable end turn button if its the players turn
			if current_turn_state.owner == players.PLAYER:
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
			var board_positions = ($Board/PlayerBoard if current_turn_state.owner == players.PLAYER else $Board/CPUBoard).get_children()
			for pos in board_positions:
				if pos.get_children():
					pos.get_child(0).attacked = true

			# check triggered effects
			check_triggered_effects(TriggerType.ON_TURN_END)

			current_turn_state.turn += 1
			current_turn_state.owner = players.CPU if current_turn_state.owner == players.PLAYER else players.PLAYER

			# disable end turn button, no matter which turn
			$EndTurnButton.disabled = true

			_set_turn_phase(phases.UPKEEP)

func _on_end_turn_button_pressed() -> void:
	_go_to_next_phase()

# create card in hand
func create_card(card_owner, card_name):
	var owner_hand = $Board/PlayerHand if card_owner == players.PLAYER else $Board/CPUHand

	# check hand size
	var positions = owner_hand.get_children()

	for pos in positions:
		if not pos.get_children():
			# available position!
			# create card
			var card_interface_instance = card_interface_scene.instantiate()
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
			card_interface_instance.owner_node = ($Player if card_owner == players.PLAYER else $Player2)
			card_interface_instance.art = cards[card_name].art
			pos.add_child(card_interface_instance)
			#pos.slot_order = 0
			#reorder_slots()

			return true

	print('couldnt create card. hand full.')
	return false

# spawn minion on board
func spawn_minion(minion_owner, minion_name, triggered_effects = []):
	var board = $Board/PlayerBoard if minion_owner == players.PLAYER else $Board/CPUBoard

	# check available positions
	var positions = board.get_children()

	for pos in positions:
		if not pos.get_children():
			# available position!
			# spawn minion
			var minion_instance = minion_scene.instantiate()
			minion_instance.minion_name = cards[minion_name].name
			minion_instance.BASE_ATTACK = cards[minion_name].attack
			minion_instance.BASE_HEALTH = cards[minion_name].health
			minion_instance.type = cards[minion_name].minion_type
			minion_instance.triggered_effects = triggered_effects
			minion_instance.minion_owner = minion_owner
			minion_instance.owner_node = ($Player if minion_owner == players.PLAYER else $Player2)
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
	var board1 = $Board/PlayerBoard
	var board2 = $Board/CPUBoard

	for pos in board1.get_children():
		if pos.get_children():
			var minion = pos.get_child(0)
			if minion.is_dead:
				# queue trigger then remove from board
				for trigger in minion.triggered_effects:
					if trigger.trigger_type == TriggerType.ON_DEATH:
						trigger_queue.append({'source': minion, 'owner_node': minion.owner_node, 'trigger': trigger})
				print('freeing minion ', minion)
				minion.get_parent().remove_child(minion)

	for pos in board2.get_children():
		if pos.get_children():
			var minion = pos.get_child(0)
			if minion.is_dead:
				# queue trigger then remove from board
				for trigger in minion.triggered_effects:
					if trigger.trigger_type == TriggerType.ON_DEATH:
						trigger_queue.append({'source': minion, 'owner_node': minion.owner_node, 'trigger': trigger})
				print('freeing minion ', minion)
				minion.get_parent().remove_child(minion)

func resolve_trigger_queue():
	while trigger_queue.size() > 0:
		var dict = trigger_queue.pop_front()
		for effect in dict.trigger.effects:
			var owner_node = dict.owner_node
			var board1 = $Board/PlayerBoard if dict.owner_node.name == 'Player' else $Board/CPUBoard
			var board2 = $Board/PlayerBoard if not dict.owner_node.name == 'Player' else $Board/CPUBoard
			var char1 = $Board/PlayerChar/Char if dict.owner_node.name == 'Player' else $Board/CPUChar/Char
			var char2 = $Board/PlayerChar/Char if not dict.owner_node.name == 'Player' else $Board/CPUChar/Char

			var targets = effect.target_selector.get_targets(self, null, owner_node, char1, char2, board1, board2)
			print('tringgering effect for minion ', dict.source)

			if targets:
				for t in targets:
					effect.execute(dict.source, t)

			else:
				effect.execute(dict.source, null)

func clear_deaths():
	var board1 = $Board/PlayerBoard
	var board2 = $Board/CPUBoard

	for pos in board1.get_children():
		if pos.get_children():
			var minion = pos.get_child(0)
			if minion.is_dead:
				minion.queue_free()

	for pos in board2.get_children():
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
	var owner_node = $Player if current_turn_state.owner == players.PLAYER else $Player2
	var board1 = $Board/PlayerBoard if current_turn_state.owner == players.PLAYER else $Board/CPUBoard
	var board2 = $Board/PlayerBoard if current_turn_state.owner != players.PLAYER else $Board/CPUBoard
	var char1 = $Board/PlayerChar/Char if current_turn_state.owner == players.PLAYER else $Board/CPUChar/Char
	var char2 = $Board/PlayerChar/Char if current_turn_state.owner != players.PLAYER else $Board/CPUChar/Char

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
	if char == $Board/PlayerChar/Char:
		return {'total': player1_state.health, 'current': player1_state.current_health}

	return {'total': player2_state.health, 'current': player2_state.current_health}

# type: damage, heal
#
func handle_player_health(char, type, amount):
	if char == $Board/PlayerChar/Char:
		if type == 'damage':
			player1_state.current_health -= amount
		if type == 'heal':
			player1_state.current_health = min(player1_state.current_health + amount, player1_state.health)

	else:
		if type == 'damage':
			player2_state.current_health -= amount
		if type == 'heal':
			player2_state.current_health = min(player2_state.current_health + amount, player2_state.health)
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
		create_card(players.PLAYER, 'knight')

	# create cpu minion
	if event.is_action_pressed('f3'):
		spawn_minion(players.CPU, 'zombie')

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu.tscn")

func _on_resume_pressed() -> void:
	$MenuUI.visible = false
