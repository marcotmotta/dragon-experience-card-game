extends Node

var main_scene
var cpu_hand
var cpu_board
var player_board
var player_char

enum TriggerType {
	ON_PLAY, # for spells
	ON_DEATH,
	ON_SUMMON,
	ON_ATTACK,
	ON_TURN_START,
	ON_TURN_END
}

var deck

# mana system
var mana = 0
var current_mana = 0

func _ready() -> void:
	main_scene = get_parent()
	cpu_hand = $"../Board/CPUHand"
	cpu_board = $"../Board/CPUBoard"
	player_board = $"../Board/PlayerBoard"
	player_char = $"../Board/PlayerChar/Char"

	# choose random deck
	deck = Globals.premade_decks.values().pick_random().duplicate(true)

func gain_max_mana(amount):
	mana += amount

func gain_current_mana(amount):
	current_mana += amount

func refresh_mana():
	current_mana = mana

func draw_card_from_deck():
	if deck.is_empty():
		print('deck empty.')
		return false

	var card_name = deck.pick_random()

	if main_scene.create_card(main_scene.players.CPU, card_name):
		deck.erase(card_name)
		print('CPU drew a card!')
		return true

# iterateable function
func iterate_available_actions():
	# 1. can play minions? {{{
	# must have board space, minion card in hand, and enough mana
	#
	# check available positions
	var positions = cpu_board.get_children()

	for pos in positions:
		if not pos.get_children():
			# available position!
			# now check if has minion in hand
			var hand = cpu_hand.get_children()

			for hand_card_space in hand:
				if hand_card_space.get_children():
					var card = hand_card_space.get_child(0)

					if card.type == 'minion':
						# has minion in hand!
						if card.cost <= current_mana:
							# has mana!
							# validate effects
							var triggers = card.triggered_effects.filter(func(trigger): return trigger.trigger_type == TriggerType.ON_PLAY)
							if not triggers:
								print('cpu playing card - minion.')
								card.play_card()
								return true
							else:
								for trigger in triggers:
									for effect in trigger.effects:
										var ally_char = main_scene.get_node('Board/CPUChar/Char')
										var enemy_char = main_scene.get_node('Board/PlayerChar/Char')
										var validation = effect.validate_possible_play(main_scene.get_node('Player2'),ally_char, enemy_char, cpu_board, player_board, true)
										if validation[0]:
											# effect validated! choosing target
											var target = validation[1].pick_random()
											print('cpu playing card - minion.')
											card.play_card(target)
											return true
	# }}}

	# 2. can play spells? {{{
	var hand = cpu_hand.get_children()

	for hand_card_space in hand:
		if hand_card_space.get_children():
			var card = hand_card_space.get_child(0)

			if card.type == 'spell':
				# has spell in hand!
				if card.cost <= current_mana:
					# has mana!
					for trigger in card.triggered_effects:
						if trigger.trigger_type == TriggerType.ON_PLAY:
							for effect in trigger.effects:
								var ally_char = main_scene.get_node('Board/CPUChar/Char')
								var enemy_char = main_scene.get_node('Board/PlayerChar/Char')
								var validation = effect.validate_possible_play(main_scene.get_node('Player2'),ally_char, enemy_char, cpu_board, player_board, true)
								if validation[0]:
									# spell validated! choosing target
									var target = validation[1].pick_random()
									print('cpu playing card - spell.')
									card.play_card(target)
									return true
	# }}}

	# 3. can attack? {{{
	# must have minions in board, at least one ally and enemy
	#
	# check available minions in ally board
	var ally_positions = cpu_board.get_children()
	ally_positions.shuffle()

	# check lethal
	for pos in ally_positions:
		if pos.get_children() and not pos.get_child(0).attacked:
			# available ally minion!
			var ally_minion = pos.get_child(0)

			# check enemy_health. if lethal, attack face.
			if (main_scene.player1_state.current_health - ally_minion.current_attack) <= 0:
				# has lethal! win the game
				ally_minion.attack(player_char)
				return true

	# check enemy minions
	for pos in ally_positions:
		if pos.get_children() and not pos.get_child(0).attacked:
			# available ally minion!
			# check enemy minions
			var enemy_positions = player_board.get_children()
			enemy_positions.shuffle()

			for ememy_pos in enemy_positions:
				if ememy_pos.get_children():
					# available enemy minion!
					var ally_minion = pos.get_child(0)
					var enemy_minion = ememy_pos.get_child(0)
					print('CPU attacking! %s -> %s' % [ally_minion.minion_name, enemy_minion.minion_name])
					ally_minion.attack(enemy_minion)
					return true
					
	# if neither, but have minions, attack face anyway
	for pos in ally_positions:
		if pos.get_children() and not pos.get_child(0).attacked:
			# available ally minion!
			var ally_minion = pos.get_child(0)

			# attack face
			ally_minion.attack(player_char)
			return true
	# }}}

	print('no more actions available')
	return false
