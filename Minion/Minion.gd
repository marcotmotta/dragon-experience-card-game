extends Area2D

# View of a MinionInstance. Holds no game logic anymore (Task 4.6): it reads its
# bound instance from the GameState and renders it; clicks are reported to the
# controller which turns them into Actions.

var entity_id: int = 0
@export var minion_owner = 0
var owner_node = null
var main_scene

@onready var property_icon_scene = load("res://Minion/PropertyIcon.tscn")
@onready var icon_resilient = load("res://assets/icon_resilient.png")
@onready var icon_sentinel = load("res://assets/icon_sentinel.png")
@onready var line = $Line2D

@onready var card_bronze_scene = load("res://assets/card_bronze.png")
@onready var card_silver_scene = load("res://assets/card_silver.png")
@onready var card_gold_scene = load("res://assets/card_gold.png")
@onready var card_purple_scene = load("res://assets/card_purple.png")
@onready var card_red_scene = load("res://assets/card_red.png")

func _get_instance():
	if main_scene == null or main_scene.game_state == null:
		return null
	return main_scene.game_state.entities.get(entity_id)

func _ready():
	var minion = _get_instance()
	if minion == null:
		return

	var health_label_settings = $Health.label_settings.duplicate()
	$Health.label_settings = health_label_settings
	var attack_label_settings = $Attack.label_settings.duplicate()
	$Attack.label_settings = attack_label_settings

	$OnDeathIcon.visible = false
	$EffectIcon.visible = false

	# art
	var texture = load(minion.data.art)
	$MinionArt.texture = texture
	$CardInterfaceHover/UI/CardArt.texture = texture

	# render immediately so a freshly-created node never shows scene-default stats
	_render(minion)

func _process(delta):
	var minion = _get_instance()
	if minion == null:
		return

	_render(minion)

	# line
	if main_scene.selected_source == self:
		line.visible = true
		line.points = [Vector2.ZERO, to_local(get_global_mouse_position())]
	else:
		line.visible = false

func _render(minion):
	$MinionName.text = minion.data.name
	$Attack.text = str(minion.current_attack)
	$Health.text = str(minion.current_health)

	$Outline.visible = not minion.attacked
	#$AttackedLabel.visible = not minion.attacked

	if minion.max_health > minion.BASE_HEALTH:
		if minion.current_health == minion.max_health:
			$Health.label_settings.font_color = Color(0.0, 1.0, 0.0)
		else:
			$Health.label_settings.font_color = Color(1.0, 0.271, 0.271)
	else:
		if minion.current_health == minion.max_health:
			$Health.label_settings.font_color = Color(1.0, 1.0, 1.0)
		else:
			$Health.label_settings.font_color = Color(1.0, 0.271, 0.271)

	if minion.current_attack > minion.BASE_ATTACK:
		$Attack.label_settings.font_color = Color(0.0, 1.0, 0.0)
	else:
		$Attack.label_settings.font_color = Color(1.0, 1.0, 1.0)

	# effect icons
	$OnDeathIcon.visible = false
	$EffectIcon.visible = false
	for trigger in minion.triggered_effects:
		if trigger.trigger_type == TriggeredEffect.TriggerType.ON_DEATH:
			$OnDeathIcon.visible = true
		if trigger.trigger_type == TriggeredEffect.TriggerType.ON_ATTACK or \
			trigger.trigger_type == TriggeredEffect.TriggerType.ON_TAKING_DAMAGE or \
			trigger.trigger_type == TriggeredEffect.TriggerType.ON_TURN_START or \
			trigger.trigger_type == TriggeredEffect.TriggerType.ON_TURN_END:
			$EffectIcon.visible = true

	$SilenceIcon.visible = minion.silenced

	# property icons
	for p in $Properties.get_children():
		p.queue_free()

	$SentinelOutline.visible = false

	$CardInterfaceHover/PropertiesDescriptions/ResilientDescription.visible = false
	$CardInterfaceHover/PropertiesDescriptions/SentinelDescription.visible = false

	for property_name in minion.properties:
		match property_name:
			'Resilient':
				$CardInterfaceHover/PropertiesDescriptions/ResilientDescription.visible = true
				var property_icon_instance = property_icon_scene.instantiate()
				property_icon_instance.get_node('PropertyIcon').texture = icon_resilient
				$Properties.add_child(property_icon_instance)
			'Sentinel':
				$CardInterfaceHover/PropertiesDescriptions/SentinelDescription.visible = true
				$SentinelOutline.visible = true
				var property_icon_instance = property_icon_scene.instantiate()
				property_icon_instance.get_node('PropertyIcon').texture = icon_sentinel
				$Properties.add_child(property_icon_instance)

	# Associated Card Interface UI
	$CardInterfaceHover/UI/CardName.text = minion.data.name
	$CardInterfaceHover/UI/Cost.text = str(minion.data.cost)
	$CardInterfaceHover/UI/MinionType.text = minion.data.minion_type

	var bold_keywords = [
		'On Play',
		'On Death',
		'On Attack',
		'End of Turn',
		'Start of Turn',
		'Resilient',
		'Sentinel',
	]
	
	var description = minion.data.description

	for keyword in bold_keywords:
		var bold_keyword = "[b]" + keyword + "[/b]"
		description = description.replace(keyword, bold_keyword)

	$CardInterfaceHover/UI/Description.text = description

	if minion.data.type == 'minion':
		$CardInterfaceHover/UI/Attack.text = str(minion.data.attack)
		$CardInterfaceHover/UI/Health.text = str(minion.data.health)
	else:
		$CardInterfaceHover/UI/Attack.text = ''
		$CardInterfaceHover/UI/Health.text = ''

	match minion.data.rarity:
		'legendary':
			$CardInterfaceHover/UI/Sprite2D.texture = card_red_scene
		'epic':
			$CardInterfaceHover/UI/Sprite2D.texture = card_purple_scene
		'rare':
			$CardInterfaceHover/UI/Sprite2D.texture = card_gold_scene
		'uncommon':
			$CardInterfaceHover/UI/Sprite2D.texture = card_silver_scene
		'common':
			$CardInterfaceHover/UI/Sprite2D.texture = card_bronze_scene

# attack lunge: dash toward the target and back. awaited by the presenter.
func play_attack_anim(target_node) -> void:
	var home = global_position
	var toward = home + (target_node.global_position - home) * 0.6
	var tween = create_tween()
	tween.tween_property(self, 'global_position', toward, 0.12)
	tween.tween_property(self, 'global_position', home, 0.12)
	await tween.finished

func _on_mouse_entered():
	$Outline.modulate = '#ff00ff'
	$CardInterfaceHover.visible = true

func _on_mouse_exited():
	$Outline.modulate = '#ffffff'
	$CardInterfaceHover.visible = false

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and Input.is_action_just_pressed('mouse1'):
		main_scene.on_object_clicked(self)
