extends Area2D

var location = 'hand'

# card data
var card_name = 'knight'
var type = 'minion'
var minion_type
var rarity
var cost = 0
var attack
var health
var description
var requires_target = false

var card_owner = 0
var owner_node = null

var main_scene

# effects
enum TriggerType {
	ON_PLAY, # for spells
	ON_DEATH,
	ON_SUMMON,
	ON_ATTACK,
	ON_TURN_START,
	ON_TURN_END
}

var triggered_effects = []

# art
var art

@onready var card_back_scene = load("res://assets/card_back.png")
@onready var card_bronze_scene = load("res://assets/card_bronze.png")
@onready var card_silver_scene = load("res://assets/card_silver.png")
@onready var card_gold_scene = load("res://assets/card_gold.png")
@onready var card_purple_scene = load("res://assets/card_purple.png")
@onready var card_red_scene = load("res://assets/card_red.png")

var valid_for_play = false

@onready var line = $Line2D

func _ready():
	# TODO: fix this
	main_scene = get_parent().get_parent().get_parent().get_parent()

	if owner_node == main_scene.get_node('Player'):
		$UI/CardName.text = card_name
		$UI/Cost.text = str(cost)
		$UI/MinionType.text = minion_type

		var bold_keywords = [
			'On Play',
			'On Death',
			'End of Turn',
			'Start of Turn',
			'Protection',
		]

		for keyword in bold_keywords:
			var bold_keyword = "[b]" + keyword + "[/b]"
			description = description.replace(keyword, bold_keyword)

		$UI/Description.text = description

		if type == 'minion':
			$UI/Attack.text = str(attack)
			$UI/Health.text = str(health)
		else:
			$UI/Attack.text = ''
			$UI/Health.text = ''

		# art
		$UI/CardArt.texture = load(art)

		match rarity:
			'legendary':
				$UI/Sprite2D.texture = card_red_scene
			'epic':
				$UI/Sprite2D.texture = card_purple_scene
			'rare':
				$UI/Sprite2D.texture = card_gold_scene
			'uncommon':
				$UI/Sprite2D.texture = card_silver_scene
			'common':
				$UI/Sprite2D.texture = card_bronze_scene

	else:
		$UI.visible = false
		$CardBack.visible = true

	scale = Vector2(0.5, 0.5)

func _process(delta: float) -> void:
	# validate self
	$UI/Outline.visible = validate_self()

	# line
	if main_scene.selected_source == self:
		line.visible = true
		var start = Vector2.ZERO
		var end = to_local(get_global_mouse_position())

		line.points = [start, end]

	else:
		line.visible = false

func play_card(target = null):
	if not validate_self():
		return false

	# validate target. is any effect invalid, return.
	for trigger in triggered_effects:
		# just need to validate on_play effects here
		if trigger.trigger_type == TriggerType.ON_PLAY:
			for effect in trigger.effects:
				if target:
					# does it make sense to validate without target? not currently
					if not effect.validate_play(target):
						print('invalid target.')
						return false

	# place card in playing slot.
	var old_parent = get_parent()
	self.reparent(main_scene.get_node('Board/PlayingSlot'))

	if type == 'minion':
		# give minion triggered effects
		var selected_effects = triggered_effects.filter(func(triggered_effect): return triggered_effect.trigger_type != TriggerType.ON_PLAY)
		# spawn minion from card. if couldnt spawn, doesnt consume the card
		if not main_scene.spawn_minion(card_owner, card_name, selected_effects):
			# revert card from playing slot
			self.reparent(old_parent)
			return false

	owner_node.current_mana -= cost

	# Trigger on_play effects
	for trigger in triggered_effects:
		if trigger.trigger_type == TriggerType.ON_PLAY:
			for effect in trigger.effects:
				var board1 = main_scene.get_node('Board/PlayerBoard') if owner_node.name == 'Player' else main_scene.get_node('Board/CPUBoard')
				var board2 = main_scene.get_node('Board/PlayerBoard') if not owner_node.name == 'Player' else main_scene.get_node('Board/CPUBoard')
				var char1 = main_scene.get_node('Board/PlayerChar/Char') if owner_node.name == 'Player' else main_scene.get_node('Board/CPUChar/Char')
				var char2 = main_scene.get_node('Board/PlayerChar/Char') if not owner_node.name == 'Player' else main_scene.get_node('Board/CPUChar/Char')

				var targets = effect.target_selector.get_targets(self, target, owner_node, char1, char2, board1, board2)

				if targets:
					for t in targets:
						effect.execute(self, t)

				else:
					effect.execute(self, null)

	queue_free()

func validate_self():
	# check if its owners turn
	if main_scene.current_turn_state.owner != card_owner:
		#print('invalid. not owners turn.')
		return false

	# check turn phase (play)
	if main_scene.current_turn_state.phase != main_scene.phases.PLAY:
		#print('invalid. not play phase.')
		return false

	# check if card is in hand
	if location != 'hand':
		#print('invalid. card not in hand.')
		return false

	# check if owner has enough mana
	if owner_node.current_mana < cost:
		# does not have enough mana
		#print('invalid. not enough mana.')
		return false

	# validate effects. is any affect invalid, return.
	var board1 = main_scene.get_node('Board/PlayerBoard') if owner_node.name == 'Player' else main_scene.get_node('Board/CPUBoard')
	var board2 = main_scene.get_node('Board/PlayerBoard') if not owner_node.name == 'Player' else main_scene.get_node('Board/CPUBoard')
	var char1 = main_scene.get_node('Board/PlayerChar/Char') if owner_node.name == 'Player' else main_scene.get_node('Board/CPUChar/Char')
	var char2 = main_scene.get_node('Board/PlayerChar/Char') if not owner_node.name == 'Player' else main_scene.get_node('Board/CPUChar/Char')
	for trigger in triggered_effects:
		# just need to validate on_play effects here
		if trigger.trigger_type == TriggerType.ON_PLAY:
			for effect in trigger.effects:
				if not effect.validate_possible_play(owner_node, char1, char2, board1, board2)[0]:
					#print('invalid. effect not possible to be played.')
					return false

	return true

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and Input.is_action_just_pressed('mouse1'):
		# only the player can play cards by this action
		if card_owner != main_scene.players.PLAYER:
			print('only the player can play cards by mouse action.')
			return

		main_scene.on_object_clicked(self)

# zoom in and out
func _on_mouse_entered() -> void:
	if location == 'hand' and card_owner == main_scene.players.PLAYER:
		$UI.scale = Vector2(2, 2)
		$UI.position.y -= 400
		$UI.z_index += 10

func _on_mouse_exited() -> void:
	if location == 'hand' and card_owner == main_scene.players.PLAYER:
		$UI.scale = Vector2(1, 1)
		$UI.position.y += 400
		$UI.z_index -= 10
