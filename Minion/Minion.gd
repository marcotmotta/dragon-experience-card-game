extends Area2D

# TODO: this should be the players enum type?
@export var minion_owner = 0
var owner_node = null

var minion_name
var BASE_ATTACK = 2
var BASE_HEALTH = 3
var max_attack = 2
var max_health = 3
var current_attack
var current_health
var type = ''

var attacked = true

# aux for trigger queue
var is_dead = false

var main_scene

# effects
var triggered_effects = []

# properties
var properties = []

# TODO: should i have a sileced_triggered_effects and silenced_properties ?
# var is_silenced = false

@onready var property_icon_scene = load("res://Minion/PropertyIcon.tscn")
@onready var icon_protection = load("res://assets/icon_protection.png")

# art
var art

@onready var line = $Line2D

@onready var vfx_damage_scene = load("res://vfx/damage/damage.tscn")

# audio sfx
@onready var sound_player_scene = load("res://sound/SoundPlayer.tscn")
@onready var hit_sound = load("res://sound/hit.wav")
@onready var power_up_sound = load("res://sound/power_up.wav")
@onready var heal_sound = load("res://sound/heal.wav")

func _ready():
	# set values
	max_attack = BASE_ATTACK
	max_health = BASE_HEALTH
	current_attack = BASE_ATTACK
	current_health = BASE_HEALTH

	var health_label_settings = $Health.label_settings.duplicate()
	$Health.label_settings = health_label_settings
	var attack_label_settings = $Attack.label_settings.duplicate()
	$Attack.label_settings = attack_label_settings

	$OnDeathIcon.visible = false
	$EffectIcon.visible = false

	# art
	$MinionArt.texture = load(art)

	# trigger on summon effects
	for trigger in triggered_effects:
		if trigger.trigger_type == TriggeredEffect.TriggerType.ON_SUMMON:
			for effect in trigger.effects:
				var board1 = main_scene.board_of(owner_node.seat)
				var board2 = main_scene.board_of(main_scene.opponent_of(owner_node.seat))
				var char1 = main_scene.char_of(owner_node.seat)
				var char2 = main_scene.char_of(main_scene.opponent_of(owner_node.seat))

				var targets = effect.target_selector.get_targets(self, null, owner_node, char1, char2, board1, board2)

				if targets:
					for t in targets:
						effect.execute(self, t)

				else:
					effect.execute(self, null)

func _process(delta):
	$MinionName.text = minion_name
	$Attack.text = str(current_attack)
	$Health.text = str(current_health)

	$AttackedLabel.visible = not attacked

	if max_health > BASE_HEALTH:
		if current_health == max_health:
			$Health.label_settings.font_color = Color(0.0, 1.0, 0.0)
		else:
			$Health.label_settings.font_color = Color(1.0, 0.271, 0.271)
	else:
		if current_health == max_health:
			$Health.label_settings.font_color = Color(1.0, 1.0, 1.0)
		else:
			$Health.label_settings.font_color = Color(1.0, 0.271, 0.271)

	if current_attack > BASE_ATTACK:
		$Attack.label_settings.font_color = Color(0.0, 1.0, 0.0)
	else:
		$Attack.label_settings.font_color = Color(1.0, 1.0, 1.0)

	# effect icons
	for trigger in triggered_effects:
		if trigger.trigger_type == TriggeredEffect.TriggerType.ON_DEATH:
			$OnDeathIcon.visible = true
			break

	for trigger in triggered_effects:
		if (trigger.trigger_type == TriggeredEffect.TriggerType.ON_ATTACK) or \
			(trigger.trigger_type == TriggeredEffect.TriggerType.ON_TURN_START) or \
			(trigger.trigger_type == TriggeredEffect.TriggerType.ON_TURN_END):
				$EffectIcon.visible = true
				break

	# line
	if main_scene.selected_source == self:
		line.visible = true
		var start = Vector2.ZERO
		var end = to_local(get_global_mouse_position())

		line.points = [start, end]

	else:
		line.visible = false

func get_health():
	return {'total': max_health, 'current': current_health}

func attack(target):
	target.take_damage(current_attack)
	if target.is_in_group('minion'):
		take_damage(target.current_attack)

	attacked = true

func gain_property(property_name):
	if property_name in properties:
		# already have property
		return false

	properties.append(property_name)

	var property_icon_instance = property_icon_scene.instantiate()

	# ui icons
	match property_name:
		'Protection':
			property_icon_instance.get_node('PropertyIcon').texture = icon_protection

	$Properties.add_child(property_icon_instance)

func gain_status(attack_amount, health_amount):
	max_attack += attack_amount
	max_health += health_amount
	current_attack += attack_amount
	current_health += health_amount

	# play sfx
	var sound_player_instance = sound_player_scene.instantiate()
	sound_player_instance.stream = power_up_sound
	main_scene.add_child(sound_player_instance)

	if current_health <= 0:
		die()

func get_silenced():
	triggered_effects = []
	properties = []

	if current_attack < BASE_ATTACK:
		max_attack = BASE_ATTACK
		current_attack = BASE_ATTACK

	if current_health < BASE_HEALTH:
		max_health = BASE_HEALTH
		current_health = BASE_HEALTH

	$OnDeathIcon.visible = false
	$EffectIcon.visible = false

	for p in $Properties.get_children():
		p.queue_free()

	# minion can gain effects later, but cant ever be de-silenced, so this is permanent
	$SilenceIcon.visible = true

func take_damage(dmg):
	if 'Protection' in properties:
		dmg = max(dmg - 1, 0)

	current_health -= dmg

	# vfx damage
	var vfx_damage_instance = vfx_damage_scene.instantiate()
	vfx_damage_instance.global_position = global_position
	vfx_damage_instance.emitting = true
	main_scene.add_child(vfx_damage_instance)

	# play sfx
	var sound_player_instance = sound_player_scene.instantiate()
	sound_player_instance.stream = hit_sound
	main_scene.add_child(sound_player_instance)

	if current_health <= 0:
		die()

func heal(amount):
	current_health = min(current_health + amount, max_health)

	# play sfx
	var sound_player_instance = sound_player_scene.instantiate()
	sound_player_instance.stream = heal_sound
	main_scene.add_child(sound_player_instance)

func die():
	is_dead = true

func _on_mouse_entered():
	$Outline.visible = true

func _on_mouse_exited():
	$Outline.visible = false

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and Input.is_action_just_pressed('mouse1'):
		main_scene.on_object_clicked(self)
