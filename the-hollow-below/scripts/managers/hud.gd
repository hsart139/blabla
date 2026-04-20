class_name HUD
extends CanvasLayer

# ─── REFERENCJE DO GRACZA ────────────────────────────────────────
var player: Player = null
var weapon: Weapon = null

# ─── WĘZŁY — TOP BAR ─────────────────────────────────────────────
@onready var label_hp:     Label = $TopBar/HP/Value
@onready var label_armor:  Label = $TopBar/Armor/Value
@onready var label_speed:  Label = $TopBar/Speed/Value
@onready var label_stress: Label = $TopBar/Stress/Value

# Ukryte staty (toggle TAB)
@onready var hidden_stats:      Control = $TopBar/HiddenStats
@onready var label_dodge:       Label   = $TopBar/HiddenStats/Dodge/Value
@onready var label_crit_player: Label   = $TopBar/HiddenStats/Crit/Value
@onready var label_vision:      Label   = $TopBar/HiddenStats/Vision/Value
@onready var label_karma:       Label   = $TopBar/HiddenStats/Karma/Value
@onready var label_luck:        Label   = $TopBar/HiddenStats/Luck/Value

# ─── WĘZŁY — LEWY PANEL ──────────────────────────────────────────
@onready var label_str: Label = $LeftPanel/Attributes/STR/Value
@onready var label_int: Label = $LeftPanel/Attributes/INT/Value
@onready var label_agi: Label = $LeftPanel/Attributes/AGI/Value

@onready var weapon_stats_panel: Control = $LeftPanel/WeaponStats
@onready var label_weapon_name:  Label   = $LeftPanel/WeaponStats/Name
@onready var label_dmg:          Label   = $LeftPanel/WeaponStats/DMG/Value
@onready var label_atk_speed:    Label   = $LeftPanel/WeaponStats/AtkSpeed/Value
@onready var label_range:        Label   = $LeftPanel/WeaponStats/Range/Value
@onready var label_crit_weapon:  Label   = $LeftPanel/WeaponStats/Crit/Value
@onready var label_shot_speed:   Label   = $LeftPanel/WeaponStats/ShotSpeed/Value
@onready var label_spread:       Label   = $LeftPanel/WeaponStats/Spread/Value
@onready var label_ammo:         Label   = $LeftPanel/WeaponStats/Ammo/Value
@onready var reload_bar:         ProgressBar = $LeftPanel/WeaponStats/ReloadBar

# ─── WĘZŁY — BOTTOM SLOTS ────────────────────────────────────────
@onready var slot_weapon1:       TextureRect = $BottomBar/Slot1/Icon
@onready var slot_weapon2:       TextureRect = $BottomBar/Slot2/Icon
@onready var slot_grenade:       TextureRect = $BottomBar/GrenadeSlot/Icon
@onready var slot_active:        TextureRect = $BottomBar/ActiveSlot/Icon
@onready var label_active_desc:  Label       = $BottomBar/ActiveSlot/Desc
@onready var slot1_highlight:    Panel       = $BottomBar/Slot1/Highlight
@onready var slot2_highlight:    Panel       = $BottomBar/Slot2/Highlight

# ─── WĘZŁY — PRAWY GÓRNY ─────────────────────────────────────────
@onready var space_item_icon:  TextureRect = $TopRight/SpaceItem/Icon
@onready var space_item_label: Label       = $TopRight/SpaceItem/Name
@onready var minimap:          TextureRect = $TopRight/Minimap

# ─── WĘZŁY — PRAWY DOLNY ─────────────────────────────────────────
@onready var label_currency:      Label      = $BottomRight/Currency/Gold/Value
@onready var label_currency_keys: Label      = $BottomRight/Currency/Keys/Value
@onready var passive_items_grid:  GridContainer = $BottomRight/PassiveItems

# ─── STAN WEWNĘTRZNY ─────────────────────────────────────────────
var _show_hidden_stats: bool = false
var _reload_timer_max: float = 1.0
var _reload_elapsed: float = 0.0
var _is_reloading: bool = false

# ─── INICJALIZACJA ───────────────────────────────────────────────
func _ready() -> void:
	hidden_stats.visible = false
	reload_bar.visible = false
	reload_bar.min_value = 0.0
	reload_bar.max_value = 1.0
	reload_bar.value = 0.0

	# Szukaj gracza po grupie
	await get_tree().process_frame
	_connect_to_player()

func _connect_to_player() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("HUD: nie znaleziono gracza w grupie 'player'")
		return

	weapon = player.weapon

	if weapon:
		weapon.ammo_changed.connect(_on_ammo_changed)
		weapon.reloading.connect(_on_reloading_started)

	# Pierwsze wypełnienie
	_refresh_all()

# ─── INPUT ───────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if player == null:
		return

	_refresh_stats()

	if _is_reloading:
		_reload_elapsed += delta
		reload_bar.value = _reload_elapsed / _reload_timer_max
		if _reload_elapsed >= _reload_timer_max:
			_is_reloading = false
			reload_bar.visible = false

	if Input.is_action_just_pressed("stats"):
		_toggle_hidden_stats()

# ─── ODŚWIEŻANIE STATÓW ──────────────────────────────────────────
func _refresh_all() -> void:
	_refresh_stats()
	_refresh_weapon()

func _refresh_stats() -> void:
	if player == null:
		return
	var s: PlayerStats = player.stats

	# Widoczne
	label_hp.text    = "%d / %d" % [int(s.hp), int(s.max_hp)]
	label_armor.text = str(int(s.armor))
	label_speed.text = "%.1fx" % s.speed
	label_stress.text = "%d%%" % int(s.stress)

	# Kolor HP
	var hp_ratio := s.hp / s.max_hp
	if hp_ratio > 0.5:
		label_hp.modulate = Color.WHITE
	elif hp_ratio > 0.25:
		label_hp.modulate = Color.YELLOW
	else:
		label_hp.modulate = Color.RED

	# Kolor Stress
	if s.stress < 40.0:
		label_stress.modulate = Color.WHITE
	elif s.stress < 70.0:
		label_stress.modulate = Color.YELLOW
	else:
		label_stress.modulate = Color.RED

	# Atrybuty
	label_str.text = "%.0f" % s.strength
	label_int.text = "%.0f" % s.intelligence
	label_agi.text = "%.0f" % s.agility

	# Ukryte
	if _show_hidden_stats:
		label_dodge.text       = "%d%%" % int(s.dodge)
		label_crit_player.text = "%d%%" % int(s.crit)
		label_vision.text      = str(s.vision_range)
		label_karma.text       = ("+" if s.karma >= 0 else "") + "%.1f" % s.karma
		label_luck.text        = "%.2fx" % s.luck

		# Karma color
		if s.karma > 0:
			label_karma.modulate = Color(0.4, 0.9, 1.0)
		elif s.karma < 0:
			label_karma.modulate = Color(1.0, 0.4, 0.4)
		else:
			label_karma.modulate = Color.WHITE

func _refresh_weapon() -> void:
	if weapon == null or weapon.data == null:
		return
	var d: WeaponData = weapon.data

	label_weapon_name.text  = d.weapon_name
	label_dmg.text          = str(int(d.damage))
	label_atk_speed.text    = "%.1fx" % d.attack_speed
	label_range.text        = str(int(d.range))
	label_crit_weapon.text  = "%d%%" % int(d.crit_chance)
	label_shot_speed.text   = "%.1fx" % (d.shot_speed / 400.0)
	label_spread.text       = str(d.spread)
	label_ammo.text         = "%d / %d" % [weapon.current_ammo, d.max_ammo]

	# Kolor ammo
	var ammo_ratio := float(weapon.current_ammo) / float(d.max_ammo)
	if ammo_ratio > 0.5:
		label_ammo.modulate = Color.WHITE
	elif ammo_ratio > 0.2:
		label_ammo.modulate = Color.YELLOW
	else:
		label_ammo.modulate = Color.RED

# ─── SYGNAŁY OD BRONI ────────────────────────────────────────────
func _on_ammo_changed(current: int, max_ammo: int) -> void:
	label_ammo.text = "%d / %d" % [current, max_ammo]
	var ratio := float(current) / float(max_ammo)
	if ratio > 0.5:
		label_ammo.modulate = Color.WHITE
	elif ratio > 0.2:
		label_ammo.modulate = Color.YELLOW
	else:
		label_ammo.modulate = Color.RED

func _on_reloading_started(reload_time: float) -> void:
	_is_reloading = true
	_reload_timer_max = reload_time
	_reload_elapsed = 0.0
	reload_bar.visible = true
	reload_bar.value = 0.0

# ─── TOGGLE UKRYTYCH STATÓW ──────────────────────────────────────
func _toggle_hidden_stats() -> void:
	_show_hidden_stats = !_show_hidden_stats
	hidden_stats.visible = _show_hidden_stats
	if _show_hidden_stats:
		_refresh_stats()

# ─── PUBLICZNE API (do wywołania z zewnątrz) ─────────────────────

func set_currency(gold: int, keys: int) -> void:
	label_currency.text      = str(gold)
	label_currency_keys.text = str(keys)

func add_passive_item_icon(texture: Texture2D) -> void:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	passive_items_grid.add_child(icon)

func set_space_item(item_name: String, texture: Texture2D = null) -> void:
	space_item_label.text = item_name
	if texture:
		space_item_icon.texture = texture

func set_active_slot_desc(desc: String) -> void:
	label_active_desc.text = desc
