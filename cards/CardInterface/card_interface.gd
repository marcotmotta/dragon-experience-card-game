extends Area2D

var location = 'hand'
var entity_id: int = 0
var card_owner = 0
var owner_node = null
var main_scene

@onready var card_bronze_scene = load("res://assets/card_bronze.png")
@onready var card_silver_scene = load("res://assets/card_silver.png")
@onready var card_gold_scene = load("res://assets/card_gold.png")
@onready var card_purple_scene = load("res://assets/card_purple.png")
@onready var card_red_scene = load("res://assets/card_red.png")

@onready var line = $Line2D

func _get_instance():
	if main_scene == null or main_scene.game_state == null:
		return null
	return main_scene.game_state.entities.get(entity_id)

func _ready():
	var card_instance = _get_instance()
	if card_instance == null:
		return

	# TODO(mp): trocar por 'card_owner == local_seat' quando houver perspectiva de rede
	if card_owner == GameEnums.Seat.P1:
		var card_data = card_instance.data
		$UI/CardName.text = card_data.name
		$UI/Cost.text = str(card_data.cost)
		$UI/MinionType.text = card_data.minion_type

		var description = card_data.description
		var bold_keywords = [
			'On Play',
			'On Death',
			'On Attack',
			'End of Turn',
			'Start of Turn',
			'Resilient',
			'Sentinel',
		]

		for keyword in bold_keywords:
			description = description.replace(keyword, "[b]" + keyword + "[/b]")

		$UI/Description.text = description
		
		if description.length() > 68:
			$UI/Description.set("theme_override_font_sizes/normal_font_size", 15)
			$UI/Description.set("theme_override_font_sizes/bold_font_size", 15)
			$UI/Description.set("theme_override_font_sizes/bold_italics_font_size", 15)
			$UI/Description.set("theme_override_font_sizes/italics_font_size", 15)
			$UI/Description.set("theme_override_font_sizes/mono_font_size", 15)

		if card_data.type == 'minion':
			$UI/Attack.text = str(card_data.attack)
			$UI/Health.text = str(card_data.health)
		else:
			$UI/Attack.text = ''
			$UI/Health.text = ''

		$UI/CardArt.texture = load(card_data.art)

		match card_data.rarity:
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
	# the entity can be gone from state while this node awaits removal in the next sync
	# (e.g. the card was just played/unregistered); skip the frame until then
	var instance = _get_instance()
	if instance == null:
		return

	# playable highlight (asks the resolver via the controller)
	$UI/Outline.visible = main_scene.can_play_card(entity_id)

	# properties description
	var description = instance.data.description
	$PropertiesDescriptions/ResilientDescription.visible = description.contains('Resilient')
	$PropertiesDescriptions/SentinelDescription.visible = description.contains('Sentinel')

	# line
	if main_scene.selected_source == self:
		line.visible = true
		line.points = [Vector2.ZERO, to_local(get_global_mouse_position())]
	else:
		line.visible = false

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and Input.is_action_just_pressed('mouse1'):
		# only the local player (P1) drives cards by mouse
		if card_owner != GameEnums.Seat.P1:
			return
		main_scene.on_object_clicked(self)

# zoom in and out
func _on_mouse_entered() -> void:
	if location == 'hand' and card_owner == GameEnums.Seat.P1:
		$UI.scale = Vector2(2, 2)
		$UI.position.y -= 400
		$UI.z_index += 10
		$PropertiesDescriptions.visible = true

func _on_mouse_exited() -> void:
	if location == 'hand' and card_owner == GameEnums.Seat.P1:
		$UI.scale = Vector2(1, 1)
		$UI.position.y += 400
		$UI.z_index -= 10
		$PropertiesDescriptions.visible = false
