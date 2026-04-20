class_name Player
extends CharacterBody2D

# ── Referencje ────────────────────────────────────────────────────────────────
@export var stats: PlayerStats

@onready var weapon_pivot: Node2D       = $WeaponPivot
@onready var weapon_node: Weapon        = $WeaponPivot/Weapon
@onready var weapon_node2: Weapon       = $WeaponPivot/Weapon2
@onready var inventory: WeaponInventory = $WeaponInventory
@onready var swap_prompt                = $SwapPrompt
@onready var upgrade_panel              = $UpgradePanel

const BASE_SPEED: float = 160.0

var _is_dead: bool = false

signal died
signal stats_changed(stats: PlayerStats)
signal weapon_switched(weapon: Weapon)

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	if stats == null:
		stats = PlayerStats.new()

	inventory.setup(weapon_node, weapon_node2, stats)

	# Podłącz SwapPrompt do inventory
	if swap_prompt and swap_prompt.has_method("setup"):
		swap_prompt.setup(inventory)

	# Podłącz UpgradePanel do inventory
	if upgrade_panel and upgrade_panel.has_method("setup"):
		upgrade_panel.setup(inventory)

	emit_signal("stats_changed", stats)
	emit_signal("weapon_switched", inventory.get_active_weapon())

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_handle_movement(delta)
	_handle_aim()
	_handle_shooting()
	_handle_reload()

# ── Ruch ──────────────────────────────────────────────────────────────────────
func _handle_movement(_delta: float) -> void:
	var input_dir = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()
	velocity = input_dir * BASE_SPEED * stats.speed
	move_and_slide()

# ── Celowanie ─────────────────────────────────────────────────────────────────
func _handle_aim() -> void:
	if weapon_pivot == null:
		return
	var mouse_pos = get_global_mouse_position()
	var aim_dir = mouse_pos - global_position
	weapon_pivot.rotation = aim_dir.angle()

	# Flip obu broni
	var lw = inventory.get_left_weapon()
	var rw = inventory.get_right_weapon()
	var flip_y = -1.0 if aim_dir.x < 0.0 else 1.0
	if lw:
		lw.scale.y = flip_y
	if rw:
		rw.scale.y = flip_y

# ── Strzelanie ────────────────────────────────────────────────────────────────
func _handle_shooting() -> void:
	if inventory.is_in_swap_mode():
		return

	var mouse_pos = get_global_mouse_position()

	if inventory.is_two_handed_equipped():
		# ── TRYB DWURĘCZNY ──────────────────────────────────────────
		var lw = inventory.get_left_weapon()
		if lw == null or lw.data == null:
			return

		var direction = (mouse_pos - lw.muzzle.global_position).normalized()
		var d = lw.data

		# LMB — główny atak
		if d.has_heavy_trigger:
			if Input.is_action_just_pressed("attack"):
				lw.begin_charge(direction)
			elif Input.is_action_just_released("attack"):
				lw.release_charge(direction)
		elif d.has_homerun:
			if Input.is_action_just_pressed("attack"):
				lw.begin_homerun(direction)
			elif Input.is_action_just_released("attack"):
				lw.release_homerun(direction)
		else:
			if Input.is_action_pressed("attack"):
				lw.try_fire(direction)

		# RMB — specjalny atak
		if Input.is_action_just_pressed("attack_secondary"):
			lw.try_alt_fire(direction)
		elif Input.is_action_pressed("attack_secondary") and d.is_melee:
			# Dla melee alt traktujemy jak hold — nic dodatkowego
			pass

	else:
		# ── TRYB DWÓCH JEDNORĘCZNYCH ────────────────────────────────
		var lw = inventory.get_left_weapon()
		var rw = inventory.get_right_weapon()

		# LMB — lewa ręka
		if lw and lw.data:
			var dir_l = (mouse_pos - lw.muzzle.global_position).normalized()
			var d = lw.data
			if d.has_heavy_trigger:
				if Input.is_action_just_pressed("attack"):
					lw.begin_charge(dir_l)
				elif Input.is_action_just_released("attack"):
					lw.release_charge(dir_l)
			elif d.has_homerun:
				if Input.is_action_just_pressed("attack"):
					lw.begin_homerun(dir_l)
				elif Input.is_action_just_released("attack"):
					lw.release_homerun(dir_l)
			else:
				if Input.is_action_pressed("attack"):
					lw.try_fire(dir_l)

		# RMB — prawa ręka
		if rw and rw.data:
			var dir_r = (mouse_pos - rw.muzzle.global_position).normalized()
			var d = rw.data
			if d.has_heavy_trigger:
				if Input.is_action_just_pressed("attack_secondary"):
					rw.begin_charge(dir_r)
				elif Input.is_action_just_released("attack_secondary"):
					rw.release_charge(dir_r)
			elif d.has_homerun:
				if Input.is_action_just_pressed("attack_secondary"):
					rw.begin_homerun(dir_r)
				elif Input.is_action_just_released("attack_secondary"):
					rw.release_homerun(dir_r)
			else:
				if Input.is_action_pressed("attack_secondary"):
					rw.try_fire(dir_r)

# ── Przeładowanie ─────────────────────────────────────────────────────────────
func _handle_reload() -> void:
	if Input.is_action_just_pressed("reload"):
		var lw = inventory.get_left_weapon()
		if lw:
			lw.start_reload()
		var rw = inventory.get_right_weapon()
		if rw:
			rw.start_reload()

# ── Input — wyrzucanie, swap prompt ──────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return

	# Prompt wymiany
	if inventory.is_in_swap_mode():
		if event is InputEventKey and event.pressed and not event.echo:
			if event.is_action("weapon_slot_1"):
				inventory.confirm_swap(0)
				emit_signal("weapon_switched", inventory.get_active_weapon())
			elif event.is_action("weapon_slot_2"):
				inventory.confirm_swap(1)
				emit_signal("weapon_switched", inventory.get_active_weapon())
			elif event.keycode == KEY_ESCAPE:
				inventory.cancel_swap()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_U:
			if upgrade_panel:
				upgrade_panel.toggle()
			return
		if event.is_action("drop_weapon"):
			inventory.drop_active()
			emit_signal("weapon_switched", inventory.get_active_weapon())

# ── Obrażenia ─────────────────────────────────────────────────────────────────
func take_damage(amount: float, _is_crit: bool = false) -> void:
	if _is_dead:
		return
	stats.take_damage(amount)
	emit_signal("stats_changed", stats)
	if stats.is_dead():
		_die()

func heal(amount: float) -> void:
	stats.heal(amount)
	emit_signal("stats_changed", stats)

func _die() -> void:
	_is_dead = true
	emit_signal("died")
	queue_free()

# ── Gettery ───────────────────────────────────────────────────────────────────
func get_active_weapon() -> Weapon:
	return inventory.get_active_weapon()
