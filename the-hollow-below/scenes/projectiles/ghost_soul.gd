class_name GhostSoul
extends Area2D

# Dusza wyciągnięta z wroga przez upgrade Ghost.
# Porusza się powoli, może być zaatakowana przez gracza — bierze 1.4× DMG gracza.
# Sama zadaje obrażenia jeśli gracz w nią wejdzie (opcjonalnie można wyłączyć).

var soul_dmg: float = 10.0   # DMG gdy gracz ją zaatakuje
var owner_node: Node = null  # gracz — żeby dusza wiedziała kto ją "posiada"

const SOUL_SPEED: float = 30.0
const SOUL_LIFETIME: float = 8.0

var _lifetime: float = 0.0
var _drift_dir: Vector2

@onready var visual: ColorRect = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D

# ─────────────────────────────────────────────────────────────────────────────
func setup(p_dmg: float, p_owner: Node) -> void:
	soul_dmg  = p_dmg
	owner_node = p_owner
	# Losowy powolny dryftt
	_drift_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _ready() -> void:
	if visual:
		visual.color = Color(0.6, 0.9, 1.0, 0.7)  # bladoniebieski, półprzezroczysty
		visual.size = Vector2(16, 16)
		visual.position = Vector2(-8, -8)
	# Dusza nie trafia gracza bezpośrednio — wykrywanie przez pociski gracza
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_lifetime += delta
	if _lifetime >= SOUL_LIFETIME:
		queue_free()
		return

	# Powolny dryftt + lekkie falowanie
	var wobble = Vector2(sin(_lifetime * 2.0), cos(_lifetime * 1.5)) * 10.0
	global_position += (_drift_dir * SOUL_SPEED + wobble) * delta

	# Zanikanie pod koniec życia
	if visual:
		var alpha = 1.0 - (_lifetime / SOUL_LIFETIME)
		visual.modulate.a = alpha

func _on_body_entered(body: Node) -> void:
	# Jeśli pocisk gracza trafi duszę — nie rób nic tutaj,
	# dusza jest Area2D i reaguje gdy Projectile ją trafi przez area_entered
	pass

# Wywoływane przez projectile gdy trafi duszę
func take_damage(amount: float, _is_crit: bool = false) -> void:
	# Dusza przyjmuje obrażenia ale to ona ginie — i "eksploduje" zadając soul_dmg wrogom
	_explode(amount)

func _explode(trigger_dmg: float) -> void:
	# Zadaj obrażenia wszystkim wrogom w małym promieniu
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body == owner_node:
			continue
		if body.has_method("take_damage"):
			body.take_damage(soul_dmg, false)

	# Też sprawdź Areas (np. inne dusze)
	var areas = get_overlapping_areas()
	for area in areas:
		if area.has_method("take_damage") and area != self:
			area.take_damage(soul_dmg, false)

	queue_free()
