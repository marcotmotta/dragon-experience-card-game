extends Node2D

# One-shot "played card" flourish: renders the played card, flies it from `from_pos`
# to the screen center while scaling up, holds briefly so it's readable, then fades out
# and frees itself. Tween-based for now — play() can later be swapped for an
# AnimationPlayer timeline without changing the caller.

const MENU_CARD_INTERFACE := preload("res://cards/CardInterface/MenuCardInterface.tscn")

func play(card_name: String, from_pos: Vector2) -> void:
	_render(card_name)
	z_index = 100 # draw above board/hand
	global_position = from_pos
	scale = Vector2(0.4, 0.4)
	modulate.a = 1.0

	var center := get_viewport_rect().size / 2.0

	var t := create_tween()
	t.tween_property(self, "global_position", center, 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "scale", Vector2(0.8, 0.8), 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.1) # hold at center
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	await t.finished
	queue_free()

func _render(card_name: String) -> void:
	var data = Globals.cards[card_name]
	var card = MENU_CARD_INTERFACE.instantiate()
	card.location = 'zoom_ui'
	card.card_name = data.name
	card.cost = data.cost
	card.rarity = data.rarity
	card.description = data.description
	card.attack = data.attack
	card.health = data.health
	card.type = data.type
	card.minion_type = data.minion_type
	card.art = data.art
	card.input_pickable = false        # don't capture mouse while flying
	add_child(card)
