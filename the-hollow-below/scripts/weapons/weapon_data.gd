class_name WeaponData
extends Resource

enum WeaponType { AGI, INT }
enum HandType { ONE_HANDED, TWO_HANDED }

@export var weapon_name: String = "Pistol"
@export var weapon_type: WeaponType = WeaponType.AGI
@export var hand_type: HandType = HandType.ONE_HANDED

# ─── CZY BROŃ BIAŁA ──────────────────────────────────────────
@export var is_melee: bool = false
# Kąt zamachu w stopniach (melee główny atak)
@export var melee_arc_deg: float = 90.0

# ─── ALT ATTACK (RMB przy 2H, lub osobna ręka przy 1H) ───────
# Mnożnik obrażeń alt ataku względem bazowych
@export var alt_damage_mult: float = 1.0
# Zasięg alt ataku (melee) lub override shot_speed (ranged)
@export var alt_range: float = 0.0
# Kąt zamachu alt ataku (melee)
@export var alt_arc_deg: float = 30.0

# ─── STATYSTYKI ──────────────────────────────────────────────
@export var damage: float = 10.0
@export var attack_speed: float = 1.0     # strzałów/s
@export var range: float = 500.0          # px
@export var crit_chance: float = 0.0      # 0–100
@export var shot_speed: float = 400.0     # px/s
@export var spread: int = 1               # ilość pocisków
@export var spread_angle: float = 0.0     # kąt rozrzutu w stopniach

# ─── WIZUALNE ────────────────────────────────────────────────
@export var projectile_color: Color = Color.YELLOW
@export var projectile_size: float = 4.0

# ─── AMUNICJA ────────────────────────────────────────────────
# -1 = brak amunicji (broń biała)
@export var max_ammo: int = 12
@export var reload_time: float = 1.2      # sekundy

# ─── HARD UPGRADE FLAGI ──────────────────────────────────────
@export var has_echo: bool = false
@export var has_firework: bool = false
@export var has_ghost: bool = false
@export var has_homerun: bool = false
@export var has_heavy_trigger: bool = false
@export var has_double_barrel: bool = false

# ─── HELPER ──────────────────────────────────────────────────
func is_two_handed() -> bool:
	return hand_type == HandType.TWO_HANDED

func has_ammo() -> bool:
	return max_ammo != -1

func get_upgrade_summary() -> String:
	var upgrades: Array[String] = []
	if has_echo:         upgrades.append("Echo")
	if has_firework:     upgrades.append("Firework")
	if has_ghost:        upgrades.append("Ghost")
	if has_homerun:      upgrades.append("Homerun")
	if has_heavy_trigger: upgrades.append("Heavy Trigger")
	if has_double_barrel: upgrades.append("Double Barrel")
	if upgrades.is_empty():
		return ""
	return " | ".join(upgrades)
