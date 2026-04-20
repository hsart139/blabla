extends CanvasLayer

# ── Referencje do labelek (pasują do HUD.tscn) ───────────────────────────────

# TopBar — widoczne
@onready var hp_value: Label        = $TopBar/HP/Value
@onready var armor_value: Label     = $TopBar/Armor/Value
@onready var speed_value: Label     = $TopBar/Speed/Value
@onready var stress_value: Label    = $TopBar/Stress/Value

# TopBar — ukryte (HiddenStats)
@onready var dodge_value: Label     = $TopBar/HiddenStats/Dodge/Value
@onready var crit_value: Label      = $TopBar/HiddenStats/Crit/Value
@onready var vision_value: Label    = $TopBar/HiddenStats/Vision/Value
@onready var karma_value: Label     = $TopBar/HiddenStats/Karma/Value
@onready var luck_value: Label      = $TopBar/HiddenStats/Luck/Value

# LeftPanel — Atrybuty
@onready var str_value: Label       = $LeftPanel/Attributes/STR/Value
@onready var int_value: Label       = $LeftPanel/Attributes/INT/Value
@onready var agi_value: Label       = $LeftPanel/Attributes/AGI/Value

# LeftPanel — Statystyki broni
@onready var weapon_name_label: Label   = $LeftPanel/WeaponStats/Name
@onready var dmg_value: Label           = $LeftPanel/WeaponStats/DMG/Value
@onready var atkspeed_value: Label      = $LeftPanel/WeaponStats/AtkSpeed/Value
@onready var range_value: Label         = $LeftPanel/WeaponStats/Range/Value
@onready var crit_weapon_value: Label   = $LeftPanel/WeaponStats/Crit/Value
@onready var shotspeed_value: Label     = $LeftPanel/WeaponStats/ShotSpeed/Value
@onready var spread_value: Label        = $LeftPanel/WeaponStats/Spread/Value
@onready var ammo_value: Label          = $LeftPanel/WeaponStats/Ammo/Value
@onready var reload_bar: ProgressBar    = $LeftPanel/WeaponStats/ReloadBar

# ── Stan ─────────────────────────────────────────────────────────────────────
var _player: Player = null
var _stats: PlayerStats = null
var _karma_visible: bool = false
var _hidden_stats_visible: bool = false

# Pełna przeładowywana animacja
var _reload_tween: Tween = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Schowaj ukryte statystyki dopóki nie odblokowane
	$TopBar/HiddenStats.visible = false

	# Poczekaj jedną klatkę żeby gracz zdążył się dodać do sceny
	await get_tree().process_frame
	_find_player()

func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player == null:
		push_warning("HUD: nie znaleziono gracza!")
		return

	_stats = _player.stats

	# Podłącz sygnały gracza
	_player.stats_changed.connect(_on_stats_changed)

	# Podłącz inventory_changed zamiast weapon_switched — obsługuje obie bronie
	_player.inventory.inventory_changed.connect(_on_inventory_changed)

	# Pierwsze odświeżenie
	_refresh_stats()
	_on_inventory_changed(_player.inventory.slots[0], _player.inventory.slots[1])

# ── Sygnały ──────────────────────────────────────────────────────────────────
func _on_stats_changed(_new_stats: PlayerStats) -> void:
	_refresh_stats()

func _on_inventory_changed(left_data: WeaponData, right_data: WeaponData) -> void:
	# Zawsze podłącz oba weapon_nodes niezależnie od tego czy slot jest zajęty
	_connect_weapon_node(_player.inventory.weapon_nodes[0])
	_connect_weapon_node(_player.inventory.weapon_nodes[1])
	_refresh_weapon_from_data(left_data, right_data)

func _connect_weapon_node(weapon: Weapon) -> void:
	if weapon == null:
		return
	if not weapon.ammo_changed.is_connected(_on_any_ammo_changed):
		weapon.ammo_changed.connect(_on_any_ammo_changed)
	if not weapon.reloading.is_connected(_on_reloading):
		weapon.reloading.connect(_on_reloading)

# Zachowaj dla kompatybilności wstecznej
func _on_weapon_switched(weapon: Weapon) -> void:
	if weapon:
		_connect_weapon_node(weapon)
	_refresh_weapon()

func _on_any_ammo_changed(_current: int, _max_ammo: int) -> void:
	# Odśwież wyświetlanie ammo dla obu broni
	_refresh_ammo_display()

func _refresh_ammo_display() -> void:
	if _player == null:
		return
	var inv = _player.inventory
	var s0 = inv.slots[0]
	var s1 = inv.slots[1]
	var wn0 = inv.weapon_nodes[0]
	var wn1 = inv.weapon_nodes[1]

	if s0 != null and s1 != null:
		# Dwie jednoręczne — pokaż oba ammo obok siebie
		var l_text = "%d/%d" % [wn0.current_ammo, s0.max_ammo] if s0.has_ammo() else "∞"
		var r_text = "%d/%d" % [wn1.current_ammo, s1.max_ammo] if s1.has_ammo() else "∞"
		ammo_value.text = "%s | %s" % [l_text, r_text]
	elif s0 != null:
		ammo_value.text = "%d / %d" % [wn0.current_ammo, s0.max_ammo] if s0.has_ammo() else "∞"
	else:
		ammo_value.text = "—"

func _on_reloading(reload_time: float) -> void:
	reload_bar.visible = true
	reload_bar.value = 0.0
	reload_bar.max_value = 100.0

	if _reload_tween:
		_reload_tween.kill()
	_reload_tween = create_tween()
	_reload_tween.tween_property(reload_bar, "value", 100.0, reload_time)

# ── Odświeżanie statystyk ─────────────────────────────────────────────────────
func _refresh_stats() -> void:
	if _stats == null:
		return

	hp_value.text    = "%d / %d" % [int(_stats.hp), int(_stats.max_hp)]
	armor_value.text = str(int(_stats.armor))
	speed_value.text = "%.1f×" % _stats.speed
	stress_value.text = "%d%%" % int(_stats.stress)

	# Atrybuty
	str_value.text = "%.1f" % _stats.strength
	int_value.text = "%.1f" % _stats.intelligence
	agi_value.text = "%.1f" % _stats.agility

	# Ukryte statystyki (pokazywane tylko gdy odblokowane)
	dodge_value.text  = "%d%%" % int(_stats.dodge)
	crit_value.text   = "%d%%" % int(_stats.crit)
	vision_value.text = str(_stats.vision_range)
	luck_value.text   = "%.2f×" % _stats.luck

	# Karma — widoczna tylko po odblokowaniu
	if _karma_visible:
		karma_value.text = "%.1f" % _stats.karma
	else:
		karma_value.text = "???"

func _refresh_weapon() -> void:
	if _player == null:
		return
	var inv = _player.inventory
	_refresh_weapon_from_data(inv.slots[0], inv.slots[1])

func _refresh_weapon_from_data(left_data: WeaponData, _right_data: WeaponData) -> void:
	# Wyświetlaj statystyki lewej / jedynej broni
	var d = left_data
	if d == null:
		weapon_name_label.text = "—"
		ammo_value.text = "—"
		return

	weapon_name_label.text = d.weapon_name

	# DMG z uwzględnieniem statystyk gracza
	var display_dmg = _stats.calc_damage(d.damage) if _stats else d.damage
	dmg_value.text       = "%.1f" % display_dmg
	atkspeed_value.text  = "%.1f/s" % d.attack_speed
	range_value.text     = "%d px" % int(d.range)
	crit_weapon_value.text = "%d%%" % int(d.crit_chance)
	shotspeed_value.text = "%d px/s" % int(d.shot_speed)
	spread_value.text    = "%d×" % d.spread

	_refresh_ammo_display()

# ── Publiczne API ─────────────────────────────────────────────────────────────

# Wywoływane przez The Third Eye / Telefon Oppo
func reveal_karma() -> void:
	_karma_visible = true
	_refresh_stats()

# Odblokuj ukryte statystyki (Telefon Oppo)
func reveal_hidden_stats() -> void:
	_hidden_stats_visible = true
	$TopBar/HiddenStats.visible = true
	_refresh_stats()

# Aktualizacja złota / kluczy (BottomRight)
func set_currency(gold: int, keys: int) -> void:
	var gold_label = get_node_or_null("BottomRight/Currency/Gold/Value")
	var keys_label = get_node_or_null("BottomRight/Currency/Keys/Value")
	if gold_label:
		gold_label.text = str(gold)
	if keys_label:
		keys_label.text = str(keys)
