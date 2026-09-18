extends Area2D

var location = 'collection'

# card data
var card_name = 'knight'
var type = 'minion'
var minion_type
var rarity
var cost = 0
var attack
var health
var description

# art
var art

@onready var card_bronze_scene = load("res://assets/card_bronze.png")
@onready var card_silver_scene = load("res://assets/card_silver.png")
@onready var card_gold_scene = load("res://assets/card_gold.png")
@onready var card_purple_scene = load("res://assets/card_purple.png")
@onready var card_red_scene = load("res://assets/card_red.png")

func _ready():
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

	#scale = Vector2(0.75, 0.75)
