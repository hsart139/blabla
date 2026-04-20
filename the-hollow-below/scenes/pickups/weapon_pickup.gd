class_name WeaponPickup
extends Area2D

@export var preset: String = "pistol"  # "pistol" | "shotgun" | "revolver" | "smg" | "katana" | "greatsword"

var data: WeaponData = null
var _player_nearby: bool = false

@onready var visual: ColorRect          = $Visual
@onready var label: Label               = $Label
@onready var prompt: Label              = $Prompt
@onready var stats_panel: Control       = $StatsPanel
@onready var collision: CollisionShape2D = $CollisionShape2D

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Jeśli data zostało już ustawione przez setup() (np. wyrzucona broń),
	# nie nadpisuj go presetem
	if data == null:
		match preset:
			"shotgun":    data = WeaponPresets.shotgun()
			"revolver":   data = WeaponPresets.revolver()
			"smg":        data = WeaponPresets.smg()
			"katana":     data = WeaponPresets.katana()
			"greatsword": data = WeaponPresets.greatsword()
			_:            data = WeaponPresets.pistol()

	_apply_visuals()
	prompt.visible = false
	if stats_panel:
		stats_panel.visible = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func setup(p_data: WeaponData) -> void:
	data = p_data
	if is_node_ready():
		_apply_visuals()

func _apply_visuals() -> void:
	if data == null:
		return
	visual.color = data.projectile_color if not data.is_melee else Color(0.7, 0.7, 0.85)
	label.text = data.weapon_name

func _process(_delta: float) -> void:
	if _player_nearby and Input.is_action_just_pressed("interact"):
		var player = get_tree().get_first_node_in_group("player") as Player
		if player:
			player.inventory.try_pickup(self)

# ── Kolizje ───────────────────────────────────────────────────────────────────
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		prompt.visible = true
		_show_stats(true)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
		prompt.visible = false
		_show_stats(false)

func _show_stats(show: bool) -> void:
	if stats_panel == null or data == null:
		return
	stats_panel.visible = show
	if not show:
		return

	# Zbuduj tekst statystyk
	var lines: Array[String] = []
	lines.append("[%s]" % ("1H" if not data.is_two_handed() else "2H"))
	lines.append("DMG: %d" % int(data.damage))
	if data.is_melee:
		lines.append("SPD: %.1f atk/s" % data.attack_speed)
		lines.append("Range: %dpx" % int(data.range))
		lines.append("Arc: %d°" % int(data.melee_arc_deg))
	else:
		lines.append("SPD: %.1f/s" % data.attack_speed)
		lines.append("Range: %dpx" % int(data.range))
		if data.max_ammo > 0:
			lines.append("Ammo: %d" % data.max_ammo)
		if data.spread > 1:
			lines.append("Spread: %d (%.0f°)" % [data.spread, data.spread_angle])
	if data.crit_chance > 0:
		lines.append("CRIT: %d%%" % int(data.crit_chance))

	# Ulepszenia
	var upgrades = data.get_upgrade_summary()
	if upgrades != "":
		lines.append("✦ " + upgrades)

	# Szukamy Label w panelu
	var stat_label = stats_panel.get_node_or_null("StatLabel")
	if stat_label:
		stat_label.text = "\n".join(lines)

func show_swap_prompt(vis: bool) -> void:
	prompt.visible = vis
