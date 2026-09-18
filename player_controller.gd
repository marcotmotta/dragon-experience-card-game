extends Node

var main_scene
var player_hand
var player_board

#@onready var deck = Globals.premade_decks.get('Elf Deck')
@onready var deck = Globals.premade_decks.values().pick_random().duplicate(true)

# mana system
var mana = 0
var current_mana = 0

# audio sfx
@onready var sound_player_scene = load("res://sound/SoundPlayer.tscn")
@onready var draw_sound = load("res://sound/draw.wav")

func _ready() -> void:
	main_scene = get_parent()
	player_hand = $"../Board/PlayerHand"
	player_board = $"../Board/PlayerBoard"

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

	if main_scene.create_card(main_scene.players.PLAYER, card_name):
		print('drew ', card_name)
		deck.erase(card_name)
		print('PLAYER drew a card!')

		# play sfx
		var sound_player_instance = sound_player_scene.instantiate()
		sound_player_instance.stream = draw_sound
		main_scene.add_child(sound_player_instance)

		return true

func validate_hand_cards():
	for pos in player_hand.get_children():
		if pos.get_children():
			var card = pos.get_children()[0]
			card.validate_self()
