class_name Weapon
extends Node2D

signal ammo_changed(current: int, max_ammo: int)
signal reloading(reload_time: float)

@export var data: WeaponData

@onready var muzzle: Marker2D = $MuzzlePoint
@onready var reload_timer: Timer = $ReloadTimer

var current_ammo: int = 0
var is_reloading: bool = false
var _fire_cooldown: float = 0.0
var _alt_cooldown: float = 0.0
var owner_stats: PlayerStats = null

const PROJECTILE_SCENE = preload("res://scenes/projectiles/projectile.tscn")
const GHOST_SOUL_SCENE = preload("res://scenes/projectiles/ghost_soul.tscn")

# ── Hard upgrade — stany wewnętrzne ──────────────────────────────────────────

# FIREWORK
const FIREWORK_INTERVAL: int = 5
var _firework_counter: int = 0

# HEAVY TRIGGER
var _heavy_charging: bool = false
var _heavy_charge_time: float = 0.0
const HEAVY_MAX_CHARGE: float = 2.0
const HEAVY_SHOTS_PER_SEC: float = 3.0

# HOMERUN
var _homerun_charging: bool = false
var _homerun_charge_time: float = 0.0
const HOMERUN_MAX_CHARGE: float = 1.5
const HOMERUN_FULL_CHARGE: float = 1.2

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	if data == null:
		data = WeaponPresets.pistol()

	if data.has_ammo():
		current_ammo = data.max_ammo
	else:
		current_ammo = -1

	reload_timer.wait_time = max(data.reload_time, 0.01)
	reload_timer.one_shot = true
	reload_timer.timeout.connect(_on_reload_finished)
	if data.has_ammo():
		emit_signal("ammo_changed", current_ammo, data.max_ammo)

func _process(delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	if _alt_cooldown > 0.0:
		_alt_cooldown -= delta

	if data and data.has_heavy_trigger and _heavy_charging:
		_heavy_charge_time = min(_heavy_charge_time + delta, HEAVY_MAX_CHARGE)

	if data and data.has_homerun and _homerun_charging:
		_homerun_charge_time = min(_homerun_charge_time + delta, HOMERUN_MAX_CHARGE)

# ─────────────────────────────────────────────────────────────────────────────
func can_fire() -> bool:
	if data == null:
		return false
	if data.is_melee:
		return _fire_cooldown <= 0.0
	return not is_reloading and _fire_cooldown <= 0.0 and (not data.has_ammo() or current_ammo > 0)

func can_alt_fire() -> bool:
	if data == null:
		return false
	if data.is_melee:
		return _alt_cooldown <= 0.0
	return not is_reloading and _alt_cooldown <= 0.0 and (not data.has_ammo() or current_ammo > 0)

# ── Główne wejście (LMB / lewa ręka) ─────────────────────────────────────────
func try_fire(target_direction: Vector2) -> void:
	if data and data.is_melee:
		_melee_attack(target_direction, false)
		return

	# Heavy trigger i homerun obsługiwane przez begin/release
	if data and (data.has_heavy_trigger or data.has_homerun):
		return

	if not can_fire():
		if data.has_ammo() and current_ammo <= 0 and not is_reloading:
			start_reload()
		return

	_fire_cooldown = 1.0 / data.attack_speed
	if data.has_ammo():
		current_ammo -= 1
		emit_signal("ammo_changed", current_ammo, data.max_ammo)

	_spawn_projectiles(target_direction)
	_post_shot_effects(target_direction)

	if data.has_ammo() and current_ammo <= 0:
		start_reload()

# ── Alt fire (RMB przy 2H: specjalny atak / przy 1H: to samo co try_fire) ─────
func try_alt_fire(target_direction: Vector2) -> void:
	if data == null:
		return
	if data.is_melee:
		_melee_attack(target_direction, true)
		return
	# Bronie strzelające 2H — RMB to specjalny strzał (np. celowany, ciężki)
	# Domyślna implementacja: strzał z 2x dmg i 0.5x prędkością
	if not can_alt_fire():
		if data.has_ammo() and current_ammo <= 0 and not is_reloading:
			start_reload()
		return
	_alt_cooldown = 1.5 / data.attack_speed
	if data.has_ammo():
		current_ammo -= 1
		emit_signal("ammo_changed", current_ammo, data.max_ammo)
	_spawn_alt_projectile(target_direction)
	if data.has_ammo() and current_ammo <= 0:
		start_reload()

# ── MELEE ATTACK ──────────────────────────────────────────────────────────────
func _melee_attack(direction: Vector2, is_alt: bool) -> void:
	if not can_fire() and not is_alt:
		return
	if is_alt and not can_alt_fire():
		return

	var cooldown = 1.0 / data.attack_speed
	if is_alt:
		_alt_cooldown = cooldown * 1.3
	else:
		_fire_cooldown = cooldown

	var arc_deg = data.melee_arc_deg if not is_alt else data.alt_arc_deg
	var reach = data.range if not is_alt else data.alt_range
	var dmg_mult = 1.0 if not is_alt else data.alt_damage_mult

	var base_dmg = data.damage * dmg_mult
	if owner_stats:
		base_dmg = owner_stats.calc_damage(data.damage) * dmg_mult

	var crit_chance = data.crit_chance
	if owner_stats:
		crit_chance = owner_stats.calc_crit(data.crit_chance)
	var is_crit = randf() * 100.0 < crit_chance
	if is_crit:
		base_dmg *= 2.0

	# Greatsword alt = dash do przodu z ciągnięciem wrogów
	if is_alt and data.weapon_name == "Greatsword":
		_greatsword_dash(direction, base_dmg, is_crit)
		return

	# Znajdź wszystkich wrogów w łuku
	var arc_rad = deg_to_rad(arc_deg)
	var base_angle = direction.angle()
	var hit_count = 0

	var bodies = get_tree().get_nodes_in_group("enemies")
	for enemy in bodies:
		if not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - global_position
		if to_enemy.length() > reach:
			continue
		var angle_diff = abs(wrapf(to_enemy.angle() - base_angle, -PI, PI))
		if angle_diff <= arc_rad / 2.0:
			if enemy.has_method("take_damage"):
				enemy.take_damage(base_dmg, is_crit)
				hit_count += 1

	_flash_melee(direction, arc_deg, reach, is_alt, is_crit)

func _flash_melee(direction: Vector2, arc_deg: float, reach: float, is_alt: bool, is_crit: bool) -> void:
	var slash = Node2D.new()
	get_tree().current_scene.add_child(slash)
	slash.global_position = global_position

	var is_greatsword = data.weapon_name == "Greatsword"
	var is_katana = data.weapon_name == "Katana"

	# Kolory
	var slash_color: Color
	if is_crit:
		slash_color = Color(1.0, 0.9, 0.1, 0.95)
	elif is_greatsword:
		slash_color = Color(1.0, 0.25, 0.25, 0.85) if not is_alt else Color(0.9, 0.5, 1.0, 0.85)
	elif is_katana:
		slash_color = Color(0.4, 0.85, 1.0, 0.85)
	else:
		slash_color = Color(0.9, 0.9, 0.9, 0.7)

	var base_angle = direction.angle()
	var arc_rad = deg_to_rad(arc_deg)
	var segments = max(8, int(arc_deg / 8))

	# Rysuj łuk za pomocą Line2D
	var line = Line2D.new()
	line.width = 6.0 if is_greatsword else 4.0
	if is_crit:
		line.width += 3.0
	line.default_color = slash_color
	slash.add_child(line)

	# Linia wewnętrzna (bliżej gracza) — efekt szerokości
	var line_inner = Line2D.new()
	line_inner.width = (line.width * 0.4)
	line_inner.default_color = Color(slash_color.r, slash_color.g, slash_color.b, slash_color.a * 0.5)
	slash.add_child(line_inner)

	var inner_reach = reach * 0.55

	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var angle = base_angle - arc_rad / 2.0 + arc_rad * t
		var pt = Vector2(cos(angle), sin(angle))
		line.add_point(pt * reach)
		line_inner.add_point(pt * inner_reach)

	# Linia od gracza do czubka (ostrze)
	var blade = Line2D.new()
	blade.width = 3.0 if is_greatsword else 2.0
	blade.default_color = Color(1, 1, 1, 0.6)
	slash.add_child(blade)
	blade.add_point(Vector2.ZERO)
	blade.add_point(direction.normalized() * reach)

	# Animacja zanikania
	var tween = slash.create_tween()
	var duration = 0.12 if is_katana else 0.18
	tween.tween_method(func(a: float):
		line.default_color = Color(slash_color.r, slash_color.g, slash_color.b, slash_color.a * a)
		line_inner.default_color = Color(slash_color.r, slash_color.g, slash_color.b, slash_color.a * 0.5 * a)
		blade.default_color = Color(1, 1, 1, 0.6 * a)
	, 1.0, 0.0, duration)
	tween.tween_callback(slash.queue_free)

# ── GREATSWORD DASH ───────────────────────────────────────────────────────────
# RMB: dash do przodu, przeciąga wszystkich wrogów z powrotem
func _greatsword_dash(direction: Vector2, base_dmg: float, is_crit: bool) -> void:
	var player = get_parent()
	if player == null:
		return

	var dash_dist = 140.0
	var start_pos = player.global_position
	var end_pos = start_pos + direction.normalized() * dash_dist

	# Wizualne ślady dashu
	_spawn_dash_trail(start_pos, end_pos, direction)

	# Przesuń gracza
	var tween = player.create_tween()
	tween.tween_property(player, "global_position", end_pos, 0.12).set_ease(Tween.EASE_OUT)

	# Po dojściu do celu — uderz i przyciągnij wszystkich wrogów w zasięgu
	await tween.finished

	var pull_radius = 110.0
	var pull_strength = 320.0
	var bodies = get_tree().get_nodes_in_group("enemies")
	var hit_any = false

	for enemy in bodies:
		if not is_instance_valid(enemy):
			continue
		var dist = (enemy.global_position - player.global_position).length()
		if dist <= pull_radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(base_dmg, is_crit)
				hit_any = true
			# Przyciągnij w kierunku gracza
			var pull_dir = (player.global_position - enemy.global_position).normalized()
			var enemy_tween = enemy.create_tween()
			enemy_tween.tween_property(enemy, "global_position",
				enemy.global_position + pull_dir * pull_strength * 0.18, 0.15)

	# Flash przy trafieniu
	_flash_melee(direction, 200.0, pull_radius, true, is_crit and hit_any)

func _spawn_dash_trail(start_pos: Vector2, end_pos: Vector2, _direction: Vector2) -> void:
	var trail = Line2D.new()
	trail.width = 10.0
	trail.default_color = Color(1.0, 0.3, 0.3, 0.6)
	get_tree().current_scene.add_child(trail)
	trail.add_point(start_pos)
	trail.add_point(end_pos)

	# Dodaj kilka smug po bokach
	var perp = Vector2(-(end_pos - start_pos).normalized().y, (end_pos - start_pos).normalized().x)
	for offset in [-8.0, 8.0]:
		var smuga = Line2D.new()
		smuga.width = 3.0
		smuga.default_color = Color(1.0, 0.5, 0.5, 0.3)
		get_tree().current_scene.add_child(smuga)
		smuga.add_point(start_pos + perp * offset)
		smuga.add_point(end_pos + perp * offset)
		var t2 = smuga.create_tween()
		t2.tween_method(func(a: float): smuga.default_color = Color(1.0, 0.5, 0.5, 0.3 * a), 1.0, 0.0, 0.25)
		t2.tween_callback(smuga.queue_free)

	var tween = trail.create_tween()
	tween.tween_method(func(a: float): trail.default_color = Color(1.0, 0.3, 0.3, 0.6 * a), 1.0, 0.0, 0.25)
	tween.tween_callback(trail.queue_free)

# ── HEAVY TRIGGER ─────────────────────────────────────────────────────────────
func begin_charge(_dir: Vector2) -> void:
	if not data or not data.has_heavy_trigger:
		return
	if is_reloading or (data.has_ammo() and current_ammo <= 0):
		return
	_heavy_charging = true
	_heavy_charge_time = 0.0

func release_charge(target_direction: Vector2) -> void:
	if not data or not data.has_heavy_trigger or not _heavy_charging:
		return
	_heavy_charging = false

	var shots = max(1, int(_heavy_charge_time * HEAVY_SHOTS_PER_SEC))
	if data.has_ammo():
		shots = min(shots, current_ammo)

	for i in range(shots):
		var offset = deg_to_rad(randf_range(-4.0, 4.0))
		var a = target_direction.angle() + offset
		_spawn_single(Vector2(cos(a), sin(a)))

	if data.has_ammo():
		current_ammo -= shots
		emit_signal("ammo_changed", current_ammo, data.max_ammo)
	_fire_cooldown = 1.0 / data.attack_speed
	if data.has_ammo() and current_ammo <= 0:
		start_reload()

# ── HOMERUN ───────────────────────────────────────────────────────────────────
func begin_homerun(_dir: Vector2) -> void:
	if not data or not data.has_homerun:
		return
	if is_reloading or (data.has_ammo() and current_ammo <= 0):
		return
	_homerun_charging = true
	_homerun_charge_time = 0.0

func release_homerun(target_direction: Vector2) -> void:
	if not data or not data.has_homerun or not _homerun_charging:
		return
	_homerun_charging = false

	var ratio = _homerun_charge_time / HOMERUN_MAX_CHARGE
	var is_full = _homerun_charge_time >= HOMERUN_FULL_CHARGE

	var base_dmg = data.damage
	if owner_stats:
		base_dmg = owner_stats.calc_damage(data.damage)
	var final_dmg = base_dmg * lerp(1.0, 3.0, ratio)

	var crit_chance = data.crit_chance
	if owner_stats:
		crit_chance = owner_stats.calc_crit(data.crit_chance)
	var is_crit = randf() * 100.0 < crit_chance
	if is_crit:
		final_dmg *= 2.0

	var proj = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = muzzle.global_position
	proj.setup(
		target_direction,
		data.shot_speed,
		final_dmg,
		data.range,
		Color.WHITE if is_full else data.projectile_color,
		data.projectile_size * lerp(1.0, 2.0, ratio),
		is_crit,
		owner
	)
	proj.homerun_knockback = lerp(200.0, 800.0, ratio)
	proj.homerun_stun = is_full

	if data.has_ammo():
		current_ammo -= 1
		emit_signal("ammo_changed", current_ammo, data.max_ammo)
	_fire_cooldown = 1.0 / data.attack_speed
	if data.has_ammo() and current_ammo <= 0:
		start_reload()

# ── Spawn pocisków ────────────────────────────────────────────────────────────
func _spawn_projectiles(base_dir: Vector2) -> void:
	if data.has_double_barrel:
		_spawn_double_barrel(base_dir)
		return

	var base_angle = base_dir.angle()
	for i in range(data.spread):
		var angle_offset: float = 0.0
		if data.spread > 1:
			angle_offset = lerp(
				-data.spread_angle / 2.0,
				data.spread_angle / 2.0,
				float(i) / float(data.spread - 1)
			)
		var a = base_angle + deg_to_rad(angle_offset)
		_spawn_single(Vector2(cos(a), sin(a)))

func _spawn_alt_projectile(base_dir: Vector2) -> void:
	# Specjalny strzał RMB dla broni strzelających 2H — celny, 2x dmg
	var final_dmg = data.damage * data.alt_damage_mult
	if owner_stats:
		final_dmg = owner_stats.calc_damage(data.damage) * data.alt_damage_mult

	var crit_chance = data.crit_chance
	if owner_stats:
		crit_chance = owner_stats.calc_crit(data.crit_chance)
	var is_crit = randf() * 100.0 < crit_chance
	if is_crit:
		final_dmg *= 2.0

	var proj = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = muzzle.global_position
	proj.setup(
		base_dir,
		data.shot_speed * 1.5,
		final_dmg,
		data.range * 1.3,
		Color.WHITE,
		data.projectile_size * 1.6,
		is_crit,
		owner
	)

# ── DOUBLE BARREL ─────────────────────────────────────────────────────────────
func _spawn_double_barrel(base_dir: Vector2) -> void:
	var base_angle = base_dir.angle()
	for barrel_offset in [-20.0, 20.0]:
		for i in range(data.spread):
			var angle_offset: float = 0.0
			if data.spread > 1:
				angle_offset = lerp(
					-data.spread_angle / 2.0,
					data.spread_angle / 2.0,
					float(i) / float(data.spread - 1)
				)
			var a = base_angle + deg_to_rad(angle_offset + barrel_offset)
			_spawn_single(Vector2(cos(a), sin(a)))

# ── Spawn jednego pocisku ─────────────────────────────────────────────────────
func _spawn_single(direction: Vector2) -> void:
	var proj = PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = muzzle.global_position

	var final_dmg = data.damage
	if owner_stats:
		final_dmg = owner_stats.calc_damage(data.damage)

	var crit_chance = data.crit_chance
	if owner_stats:
		crit_chance = owner_stats.calc_crit(data.crit_chance)
	var is_crit = randf() * 100.0 < crit_chance
	if is_crit:
		final_dmg *= 2.0

	proj.setup(
		direction,
		data.shot_speed,
		final_dmg,
		data.range,
		data.projectile_color,
		data.projectile_size,
		is_crit,
		owner
	)

	# ECHO
	if data.has_echo:
		var dmg_copy = final_dmg
		var crit_copy = is_crit
		proj.hit_callback = func(target: Node, _d, _c):
			_spawn_echo(target, dmg_copy, crit_copy)

	# GHOST
	if data.has_ghost:
		proj.hit_callback = func(target: Node, _d, _c):
			_spawn_ghost_soul(target)

# ── Efekty po strzale ─────────────────────────────────────────────────────────
func _post_shot_effects(target_direction: Vector2) -> void:
	if data.has_firework:
		_firework_counter += 1
		if _firework_counter >= FIREWORK_INTERVAL:
			_firework_counter = 0
			_spawn_firework(target_direction)

# ── FIREWORK ──────────────────────────────────────────────────────────────────
func _spawn_firework(_base_dir: Vector2) -> void:
	var firework_dmg = data.damage * 1.5
	if owner_stats:
		firework_dmg = owner_stats.calc_damage(data.damage) * 1.5

	for i in range(8):
		var angle = (TAU / 8.0) * i
		var proj = PROJECTILE_SCENE.instantiate()
		get_tree().current_scene.add_child(proj)
		proj.global_position = muzzle.global_position
		proj.setup(
			Vector2(cos(angle), sin(angle)),
			data.shot_speed * 0.7,
			firework_dmg,
			120.0,
			Color(1.0, 0.4, 0.0),
			data.projectile_size * 1.5,
			false,
			owner
		)

# ── ECHO ──────────────────────────────────────────────────────────────────────
func _spawn_echo(target: Node, original_dmg: float, is_crit: bool) -> void:
	if not is_instance_valid(target):
		return
	await get_tree().create_timer(0.3).timeout
	if not is_instance_valid(target):
		return
	target.take_damage(original_dmg * 0.5, is_crit)

# ── GHOST ─────────────────────────────────────────────────────────────────────
func _spawn_ghost_soul(target: Node) -> void:
	if not is_instance_valid(target):
		return
	var soul = GHOST_SOUL_SCENE.instantiate()
	get_tree().current_scene.add_child(soul)
	soul.global_position = target.global_position
	var soul_dmg = data.damage * 1.4
	if owner_stats:
		soul_dmg = owner_stats.calc_damage(data.damage) * 1.4
	soul.setup(soul_dmg, owner)

# ── Reload ─────────────────────────────────────────────────────────────────────
func start_reload() -> void:
	if not data.has_ammo():
		return
	if is_reloading or current_ammo == data.max_ammo:
		return
	is_reloading = true
	emit_signal("reloading", data.reload_time)
	reload_timer.start()

func _on_reload_finished() -> void:
	is_reloading = false
	current_ammo = data.max_ammo
	emit_signal("ammo_changed", current_ammo, data.max_ammo)

# ── Zmiana broni w locie ──────────────────────────────────────────────────────
func set_weapon_data(new_data: WeaponData) -> void:
	data = new_data
	if data.has_ammo():
		current_ammo = data.max_ammo
	else:
		current_ammo = -1
	is_reloading = false
	_heavy_charging = false
	_homerun_charging = false
	_firework_counter = 0
	reload_timer.stop()
	if data.has_ammo():
		reload_timer.wait_time = max(data.reload_time, 0.01)
		emit_signal("ammo_changed", current_ammo, data.max_ammo)

# ── Getter stanu ładowania (dla HUD / charge bar) ─────────────────────────────
func get_charge_ratio() -> float:
	if data and data.has_heavy_trigger and _heavy_charging:
		return _heavy_charge_time / HEAVY_MAX_CHARGE
	if data and data.has_homerun and _homerun_charging:
		return _homerun_charge_time / HOMERUN_MAX_CHARGE
	return 0.0
