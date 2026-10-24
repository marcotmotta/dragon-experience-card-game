extends RefCounted
class_name GameState

# Source of truth
# Nothing here can hold a reference to a node

var turn: int = 0
var active_seat: int = GameEnums.Seat.P1 # owner of current turn
var phase: int = GameEnums.Phase.UPKEEP

const BOARD_SIZE = 7

var players: Dictionary = {}                       # { Seat.P1: PlayerState, Seat.P2: PlayerState }
var entities: Dictionary = {}                      # { id:int -> MinionInstance|CardInstance } global registry

var _next_id: int = 0

# Assigns a stable id to an entity and files it in the registry. Returns the id.
func register(entity) -> int:
	_next_id += 1
	entity.id = _next_id
	entities[entity.id] = entity
	return entity.id

# Removes an entity from the registry when it leaves play (minion removed, spell
# discarded). The id is retired forever — it is never reused.
func unregister(id: int) -> void:
	entities.erase(id)

func opponent_of(seat: int) -> int:
	return GameEnums.Seat.P2 if seat == GameEnums.Seat.P1 else GameEnums.Seat.P1

# Factory:
#
# begins match and shuffle decks
static func new_game(deck_names_p1: Array, deck_names_p2: Array, rng: RandomNumberGenerator) -> GameState:
	var game_state := GameState.new()
	
	var player_seats = [GameEnums.Seat.P1, GameEnums.Seat.P2]
	var decks = [deck_names_p1, deck_names_p2]

	for seat in player_seats:
		var player_state := PlayerState.new()
		player_state.seat = seat
		player_state.board.resize(BOARD_SIZE) # [null, null, ... xBOARD_SIZE]

		var names: Array = deck_names_p1 if seat == GameEnums.Seat.P1 else deck_names_p2

		# instantiate cards here. when players draw, card already exists and is popped
		for card_name in names:
			var card_instance := CardInstance.new()
			card_instance.owner = seat
			card_instance.card_name = card_name
			card_instance.data = Globals.cards[card_name]

			game_state.register(card_instance)

			player_state.deck.append(card_instance)

		_shuffle(player_state.deck, rng) # shuffle once; draw = pop_back()

		game_state.players[seat] = player_state

	# coin flip for who starts
	game_state.active_seat = GameEnums.Seat.P1 if rng.randi() % 2 == 0 else GameEnums.Seat.P2

	return game_state

# Fisher-Yates using the injected rng (deterministic given the seed).
static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
