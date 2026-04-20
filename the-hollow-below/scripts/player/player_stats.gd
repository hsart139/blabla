class_name PlayerStats
extends Resource

# ─── CORE VISIBLE ───────────────────────────────────────────
@export var hp: float = 100.0
@export var max_hp: float = 100.0
@export var armor: float = 0.0
@export var speed: float = 1.0
@export var stress: float = 0.0      # 0–100

# ─── HIDDEN ─────────────────────────────────────────────────
@export var dodge: float = 0.0       # 0–70
@export var crit: float = 0.0        # 0–100
@export var vision_range: int = 5    # 1–10
@export var karma: float = 0.0       # -10–10
@export var luck: float = 1.0        # 0.1–3.0

# ─── POWER ──────────────────────────────────────────────────
@export var power: float = 1.0

# ─── ATTRIBUTES ─────────────────────────────────────────────
@export var strength: float = 0.0    # AD – bonus HP
@export var intelligence: float = 0.0 # INT – stress reduction
@export var agility: float = 0.0     # AGI – bonus dodge

# ─── RANK MULTIPLIERS ───────────────────────────────────────
const RANK_MULT: Dictionary = {
	"S": 1.0,
	"A": 0.7,
	"B": 0.5,
	"C": 0.2,
	"D": 0.1,
	"F": 0.0
}

var rank_s: String = "S"
var rank_i: String = "S"
var rank_a: String = "S"

# ─── FORMULAS ───────────────────────────────────────────────
func calc_damage(weapon_dmg: float) -> float:
	var rs = RANK_MULT.get(rank_s, 1.0)
	var ri = RANK_MULT.get(rank_i, 1.0)
	var ra = RANK_MULT.get(rank_a, 1.0)
	return power + (weapon_dmg
		+ (rs * strength)
		+ (ri * intelligence)
		+ (ra * agility))

func calc_crit(weapon_crit: float) -> float:
	return crit * (1.0 + weapon_crit / 100.0)

func calc_damage_taken(incoming: float) -> float:
	return incoming * (100.0 / (100.0 + armor))

func take_damage(amount: float) -> void:
	var roll = randf() * 100.0
	if roll < dodge:
		return  # uniknięto
	var actual = calc_damage_taken(amount)
	hp = max(0.0, hp - actual)

func heal(amount: float) -> void:
	hp = min(max_hp, hp + amount)

func is_dead() -> bool:
	return hp <= 0.0

# ─── STRESS ─────────────────────────────────────────────────
func add_stress(amount: float) -> void:
	# INT redukuje przyrost stresu
	var reduction = intelligence * 0.01
	stress = clamp(stress + amount * (1.0 - reduction), 0.0, 100.0)

func reduce_stress(amount: float) -> void:
	stress = clamp(stress - amount, 0.0, 100.0)

# ─── KARMA ──────────────────────────────────────────────────
func modify_karma(amount: float) -> void:
	karma = clamp(karma + amount, -10.0, 10.0)
