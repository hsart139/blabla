class_name Projectile
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var damage: float = 10.0
var max_range: float = 500.0
var is_crit: bool = false
var shooter: Node = null

# Hard upgrade hooks
var hit_callback: Callable        # ECHO / GHOST — wywoływane przy trafieniu
var homerun_knockback: float = 0.0
var homerun_stun: bool = false

# Wewnętrzne
var _traveled: float = 0.0
var _color: Color = Color.YELLOW
var _size: float = 4.0
var _setup_done: bool = false

@onready var visual: ColorRect = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D

# ─────────────────────────────────────────────────────────────────────────────
func setup(
	p_direction: Vector2,
	p_speed: float,
	p_damage: float,
	p_range: float,
	p_color: Color,
	p_size: float,
	p_is_crit: bool,
	p_shooter: Node
) -> void:
	direction   = p_direction.normalized()
	speed       = p_speed
	damage      = p_damage
	max_range   = p_range
	_color      = p_color
	_size       = p_size
	is_crit     = p_is_crit
	shooter     = p_shooter
	rotation    = direction.angle()

	if _setup_done:
		_apply_visuals()

func _ready() -> void:
	_setup_done = true
	_apply_visuals()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _apply_visuals() -> void:
	if not is_instance_valid(visual):
		return
	var col = _color.lightened(0.3) if is_crit else _color
	visual.color = col
	visual.size = Vector2(_size * 2.0, _size)
	visual.position = Vector2(-_size, -_size / 2.0)

	if collision and collision.shape is RectangleShape2D:
		collision.shape.size = Vector2(_size * 2.0, _size)

func _physics_process(delta: float) -> void:
	var move = direction * speed * delta
	global_position += move
	_traveled += move.length()
	if _traveled >= max_range:
		_destroy()

# ── Kolizje ───────────────────────────────────────────────────────────────────
func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	_hit(body)

func _on_area_entered(area: Node) -> void:
	if area == shooter:
		return
	_hit(area)

func _hit(target: Node) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage, is_crit)

	# HOMERUN — knockback i opcjonalny stun
	if homerun_knockback > 0.0 and target.has_method("apply_knockback"):
		target.apply_knockback(direction * homerun_knockback, homerun_stun)

	# ECHO / GHOST callback
	if hit_callback.is_valid():
		hit_callback.call(target, damage, is_crit)

	_destroy()

func _destroy() -> void:
	queue_free()
