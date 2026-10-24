extends RefCounted
class_name CardInstance

# Just adds a layer that holds the card ownership.

var id: int
var owner: int # GameEnums.Seat
var card_name: String
var data: CardData # actual info.
