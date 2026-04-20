class_name WeaponPresets

static func pistol() -> WeaponData:
	var w = WeaponData.new()
	w.weapon_name = "Pistol"
	w.hand_type = WeaponData.HandType.ONE_HANDED
	w.damage = 10.0
	w.attack_speed = 2.0
	w.range = 450.0
	w.crit_chance = 5.0
	w.shot_speed = 380.0
	w.spread = 1
	w.spread_angle = 3.0
	w.max_ammo = 12
	w.reload_time = 1.0
	w.projectile_color = Color(1, 0.9, 0.2)
	w.projectile_size = 4.0
	return w

static func shotgun() -> WeaponData:
	var w = WeaponData.new()
	w.weapon_name = "Shotgun"
	w.hand_type = WeaponData.HandType.TWO_HANDED
	w.damage = 8.0
	w.attack_speed = 0.8
	w.range = 250.0
	w.crit_chance = 2.0
	w.shot_speed = 420.0
	w.spread = 6
	w.spread_angle = 30.0
	w.max_ammo = 6
	w.reload_time = 2.0
	w.projectile_color = Color(1, 0.5, 0.1)
	w.projectile_size = 3.0
	return w

static func revolver() -> WeaponData:
	var w = WeaponData.new()
	w.weapon_name = "Revolver"
	w.hand_type = WeaponData.HandType.ONE_HANDED
	w.damage = 22.0
	w.attack_speed = 1.1
	w.range = 520.0
	w.crit_chance = 15.0
	w.shot_speed = 500.0
	w.spread = 1
	w.spread_angle = 1.0
	w.max_ammo = 6
	w.reload_time = 1.8
	w.projectile_color = Color(1, 0.8, 0.0)
	w.projectile_size = 5.0
	return w

static func smg() -> WeaponData:
	var w = WeaponData.new()
	w.weapon_name = "SMG"
	w.hand_type = WeaponData.HandType.TWO_HANDED
	w.damage = 5.0
	w.attack_speed = 8.0
	w.range = 320.0
	w.crit_chance = 3.0
	w.shot_speed = 450.0
	w.spread = 1
	w.spread_angle = 8.0
	w.max_ammo = 30
	w.reload_time = 1.5
	w.projectile_color = Color(0.8, 1.0, 0.2)
	w.projectile_size = 3.0
	return w

# ── NOWE BRONIE ───────────────────────────────────────────────────────────────

# Katana — jednoręczna melee. W parze: LMB=lewa ręka, RMB=prawa ręka
static func katana() -> WeaponData:
	var w = WeaponData.new()
	w.weapon_name = "Katana"
	w.hand_type = WeaponData.HandType.ONE_HANDED
	w.weapon_type = WeaponData.WeaponType.AGI
	w.is_melee = true
	w.damage = 18.0
	w.attack_speed = 3.0
	w.range = 80.0
	w.crit_chance = 12.0
	w.shot_speed = 0.0
	w.spread = 1
	w.spread_angle = 0.0
	w.max_ammo = -1
	w.reload_time = 0.0
	w.projectile_color = Color(0.6, 0.9, 1.0)
	w.projectile_size = 0.0
	# arc zamachu
	w.melee_arc_deg = 90.0
	w.alt_damage_mult = 1.0
	w.alt_range = 80.0
	w.alt_arc_deg = 90.0
	return w

# Greatsword — dwuręczny miecz.
# LMB: szeroki zamach (arc 140°, dużo wrogów)
# RMB: pchnięcie (arc 30°, 2x dmg pojedynczy cel)
static func greatsword() -> WeaponData:
	var w = WeaponData.new()
	w.weapon_name = "Greatsword"
	w.hand_type = WeaponData.HandType.TWO_HANDED
	w.weapon_type = WeaponData.WeaponType.AGI
	w.is_melee = true
	w.damage = 45.0
	w.attack_speed = 1.2
	w.range = 100.0
	w.crit_chance = 8.0
	w.shot_speed = 0.0
	w.spread = 1
	w.spread_angle = 0.0
	w.max_ammo = -1
	w.reload_time = 0.0
	w.projectile_color = Color(1.0, 0.3, 0.3)
	w.projectile_size = 0.0
	w.melee_arc_deg = 140.0
	# alt attack: pchnięcie
	w.alt_damage_mult = 2.0
	w.alt_range = 130.0
	w.alt_arc_deg = 30.0
	return w
