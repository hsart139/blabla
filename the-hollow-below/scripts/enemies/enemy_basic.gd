class_name EnemyBasic
extends CharacterBody2D

@export var max_hp: float = 50.0
@export var move_speed: float = 80.0
@export var armor: float = 0.0

var hp: float = max_hp
var player: Node = null

func _ready() -> void:
	# Znajdź gracza
	player = get_tree().get_first_node_in_group("player")
	# Warstwy kolizji
	collision_layer = 2   # "enemy"
	collision_mask = 1    # "world"

func _physics_process(_delta: float) -> void:
	if player == null:
		return
	var dir = (player.global_position - global_position).normalized()
	velocity = dir * move_speed
	move_and_slide()

func take_damage(amount: float, is_crit: bool = false) -> void:
	var actual = amount * (100.0 / (100.0 + armor))
	hp -= actual

	# Feedback wizualny
	var color = Color.RED if not is_crit else Color.ORANGE
	_flash(color)

	if hp <= 0.0:
		die()

func die() -> void:
	queue_free()

func _flash(color: Color) -> void:
	var rect = $ColorRect
	rect.color = color
	await get_tree().create_timer(0.1).timeout
	rect.color = Color(1, 0, 0, 1)  # oryginalny czerwony kolor wroga
