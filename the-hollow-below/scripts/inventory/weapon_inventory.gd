class_name WeaponInventory
extends Node

# ── Sygnały ───────────────────────────────────────────────────────────────────
signal inventory_changed(left_data: WeaponData, right_data: WeaponData)
signal active_slot_changed(slot_index: int)
signal swap_prompt_requested(pickup: WeaponPickup)
signal swap_prompt_dismissed()

# ── Stałe ─────────────────────────────────────────────────────────────────────
const MAX_ONE_HANDED_SLOTS: int = 2
const PICKUP_SCENE = preload("res://scenes/pickups/weapon_pickup.tscn")

# ── Stan ──────────────────────────────────────────────────────────────────────
# slots[0] = lewa ręka (lub jedyna broń 2H)
# slots[1] = prawa ręka (tylko 1H, puste jeśli trzymamy 2H)
var slots: Array[WeaponData] = [null, null]
var active_slot: int = 0   # używane przy swap prompt

# Referencje do węzłów broni
var weapon_nodes: Array[Weapon] = []
var owner_stats: PlayerStats = null

# Prompt wymiany
var _pending_pickup: WeaponPickup = null
var _swap_mode: bool = false

# ─────────────────────────────────────────────────────────────────────────────
func setup(w1: Weapon, w2: Weapon, stats: PlayerStats) -> void:
	weapon_nodes = [w1, w2]
	owner_stats = stats

	for i in range(MAX_ONE_HANDED_SLOTS):
		if weapon_nodes[i] and weapon_nodes[i].data:
			slots[i] = weapon_nodes[i].data

	_sync_weapons()
	_apply_layout()

# ── Pomocniki stanu ───────────────────────────────────────────────────────────
func is_two_handed_equipped() -> bool:
	return slots[0] != null and slots[0].is_two_handed()

func get_left_weapon() -> Weapon:
	if weapon_nodes[0] and slots[0]:
		return weapon_nodes[0]
	return null

func get_right_weapon() -> Weapon:
	if not is_two_handed_equipped() and weapon_nodes[1] and slots[1]:
		return weapon_nodes[1]
	return null

# Zwraca aktywną broń (kompatybilność z resztą kodu)
func get_active_weapon() -> Weapon:
	return get_left_weapon()

func get_active_data() -> WeaponData:
	return slots[0]

# ── Podnoszenie ───────────────────────────────────────────────────────────────
func try_pickup(pickup: WeaponPickup) -> void:
	if pickup == null or pickup.data == null:
		return

	var new_data = pickup.data

	if new_data.is_two_handed():
		# Broń dwuręczna — zajmuje oba sloty → pyta o wymianę całości
		# jeśli jakikolwiek slot zajęty
		if slots[0] != null or slots[1] != null:
			_pending_pickup = pickup
			_swap_mode = true
			emit_signal("swap_prompt_requested", pickup)
		else:
			_place_two_handed(new_data)
			pickup.queue_free()
	else:
		# Jednoreczna — najpierw szukamy wolnego slotu
		# Jeśli mamy 2H, zwalniamy slot[1] który jest NULL → wkładamy w slot[0] albo [1]
		if is_two_handed_equipped():
			# Możemy wymienić 2H na 1H
			_pending_pickup = pickup
			_swap_mode = true
			emit_signal("swap_prompt_requested", pickup)
			return
		for i in range(MAX_ONE_HANDED_SLOTS):
			if slots[i] == null:
				_place_in_slot(i, new_data)
				pickup.queue_free()
				return
		# Oba sloty zajęte
		_pending_pickup = pickup
		_swap_mode = true
		emit_signal("swap_prompt_requested", pickup)

# ── Potwierdzenie wymiany ─────────────────────────────────────────────────────
# slot_index: 0 = wyrzuć lewą/2H, 1 = wyrzuć prawą
func confirm_swap(slot_index: int) -> void:
	if not _swap_mode or _pending_pickup == null:
		return

	var new_data = _pending_pickup.data
	var drop_pos = _pending_pickup.global_position

	if new_data.is_two_handed():
		# Nowa broń 2H — wyrzuć wszystko i zastąp
		if slots[0]:
			_drop_weapon(slots[0], drop_pos)
		if slots[1]:
			_drop_weapon(slots[1], drop_pos + Vector2(30, 0))
		slots[0] = null
		slots[1] = null
		_place_two_handed(new_data)
	else:
		# Nowa 1H — wymiana wybranego slotu
		var old_data = slots[slot_index]

		# Jeśli mieliśmy 2H, zwalniamy go najpierw
		if is_two_handed_equipped():
			_drop_weapon(slots[0], drop_pos)
			slots[0] = null
			slots[1] = null

		if old_data:
			_drop_weapon(old_data, drop_pos)
		_place_in_slot(slot_index, new_data)

	_pending_pickup.queue_free()
	_pending_pickup = null
	_swap_mode = false
	emit_signal("swap_prompt_dismissed")

func cancel_swap() -> void:
	_pending_pickup = null
	_swap_mode = false
	emit_signal("swap_prompt_dismissed")

# ── Wyrzucanie [G] ────────────────────────────────────────────────────────────
func drop_active() -> void:
	# Wyrzuć broń z lewej ręki (lub 2H). Minimum: musi zostać coś w ręku.
	if slots[0] == null:
		return
	# Jedyna broń w slots[0], brak broni w slots[1] i nie jest 2H → nie wyrzucaj
	if slots[1] == null and not is_two_handed_equipped():
		return

	var player = get_parent()
	var drop_pos = player.global_position + Vector2(50, 0)

	if is_two_handed_equipped():
		# Wyrzuć 2H — oba sloty zajęte przez tę samą broń (slot[1] zawsze null przy 2H)
		_drop_weapon(slots[0], drop_pos)
		slots[0] = null
		slots[1] = null
	else:
		# Mamy 2 pistolety — wyrzuć lewą, przesuń prawą na lewą
		_drop_weapon(slots[0], drop_pos)
		slots[0] = slots[1]
		slots[1] = null

	_apply_layout()

# ── Wewnętrzne — umieszczanie broni ──────────────────────────────────────────
func _place_two_handed(data: WeaponData) -> void:
	slots[0] = data
	slots[1] = null
	weapon_nodes[0].set_weapon_data(data)
	weapon_nodes[0].visible = true
	weapon_nodes[1].visible = false
	emit_signal("inventory_changed", slots[0], slots[1])

func _place_in_slot(index: int, data: WeaponData) -> void:
	slots[index] = data
	weapon_nodes[index].set_weapon_data(data)
	_apply_layout()
	emit_signal("inventory_changed", slots[0], slots[1])

func _apply_layout() -> void:
	if is_two_handed_equipped():
		weapon_nodes[0].set_weapon_data(slots[0])
		weapon_nodes[0].visible = true
		weapon_nodes[1].visible = false
	else:
		if slots[0] != null:
			weapon_nodes[0].set_weapon_data(slots[0])
			weapon_nodes[0].visible = true
		else:
			weapon_nodes[0].visible = false
		if slots[1] != null:
			weapon_nodes[1].set_weapon_data(slots[1])
			weapon_nodes[1].visible = true
		else:
			weapon_nodes[1].visible = false
	emit_signal("active_slot_changed", 0)
	emit_signal("inventory_changed", slots[0], slots[1])

func _sync_weapons() -> void:
	for i in range(MAX_ONE_HANDED_SLOTS):
		if weapon_nodes[i]:
			weapon_nodes[i].owner_stats = owner_stats
			weapon_nodes[i].visible = false

func _drop_weapon(data: WeaponData, pos: Vector2) -> void:
	var pickup = PICKUP_SCENE.instantiate()
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = pos
	pickup.setup(data)

func is_in_swap_mode() -> bool:
	return _swap_mode

# Kompatybilność wsteczna
func switch_to_slot(_index: int) -> void:
	pass  # w nowym systemie nie ma "aktywnego slotu" — oba działają równocześnie

func cycle(_direction: int) -> void:
	pass
