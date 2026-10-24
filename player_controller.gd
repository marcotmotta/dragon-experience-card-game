extends Node

# GameEnums.Seat
var seat : int
var main_scene

# Vestigial after Task 4.6: the player's state (deck/mana/hand) lives in game_state
# and input is driven by the controller building Actions. Kept as the P1 node that
# holds the seat and anchors owner_node references.

func _ready() -> void:
	main_scene = get_parent()
