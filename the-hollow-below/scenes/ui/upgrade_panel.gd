extends CanvasLayer

const UPGRADES = [
	{
		"key": "has_echo",
		"name": "Echo",
		"desc": "Każdy pocisk zadaje 50% obrażeń ponownie po 0.3s",
		"melee_ok": false,
	},
	{
		"key": "has_firework",
		"name": "Firework",
		"desc": "Co 5 strzałów — eksplozja w 8 kierunkach (1.5× DMG)",
		"melee_ok": false,
	},
	{
		"key": "has_ghost",
		"name": "Ghost",
		"desc": "Zabity wróg wysyła duszę która atakuje pobliskich (1.4× DMG)",
		"melee_ok": false,
	},
	{
		"key": "has_homerun",
		"name": "Homerun",
		"desc": "Przytrzymaj LMB — naładowany strzał odpycha i ogłusza (do 3× DMG)",
		"melee_ok": false,
	},
	{
		"key": "has_heavy_trigger",
		"name": "Heavy Trigger",
		"desc": "Przytrzymaj LMB — wypuść serię skumulowanych strzałów",
		"melee_ok": false,
	},
	{
		"key": "has_double_barrel",
		"name": "Double Barrel",
		"desc": "Strzela z dwóch luf jednocześnie (2x pociski, +-20 offset)",
		"melee_ok": false,
	},
]

var _inventory: WeaponInventory = null
var _checkboxes: Array = []

@onready var panel: Panel                  = $Panel
@onready var title_label: Label            = $Panel/VBox/Title
@onready var weapon_label: Label           = $Panel/VBox/WeaponName
@onready var list_container: VBoxContainer = $Panel/VBox/List
@onready var hint_label: Label             = $Panel/VBox/Hint

func _ready() -> void:
	layer = 10
	visible = false

func setup(inventory: WeaponInventory) -> void:
	_inventory = inventory

func toggle() -> void:
	if visible:
		_close()
	else:
		_open()

func _open() -> void:
	_build_ui()
	visible = true

func _close() -> void:
	visible = false

func _build_ui() -> void:
	for child in list_container.get_children():
		child.queue_free()
	_checkboxes.clear()

	if _inventory == null:
		weapon_label.text = "Brak ekwipunku"
		return

	var s0: WeaponData = _inventory.slots[0]
	var s1: WeaponData = _inventory.slots[1]
	var dual = s0 != null and s1 != null and not _inventory.is_two_handed_equipped()

	if s0 == null:
		weapon_label.text = "Brak broni"
		return

	if dual:
		weapon_label.text = "Lewa: %s   |   Prawa: %s" % [s0.weapon_name, s1.weapon_name]
	else:
		weapon_label.text = "Bron: %s [%s]" % [s0.weapon_name, "2H" if s0.is_two_handed() else "1H"]

	if dual:
		_add_header("-- Lewa: %s --" % s0.weapon_name)
	_add_weapon_rows(s0, 0)

	if dual:
		_add_header("-- Prawa: %s --" % s1.weapon_name)
		_add_weapon_rows(s1, 1)

func _add_header(text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.modulate = Color(0.9, 0.85, 0.5)
	list_container.add_child(lbl)

func _add_weapon_rows(weapon_data: WeaponData, slot_index: int) -> void:
	for upg in UPGRADES:
		if weapon_data.is_melee and not upg["melee_ok"]:
			continue

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var cb = CheckBox.new()
		cb.text = upg["name"]
		cb.button_pressed = weapon_data.get(upg["key"])
		cb.custom_minimum_size = Vector2(130, 0)

		var desc = Label.new()
		desc.text = upg["desc"]
		desc.add_theme_font_size_override("font_size", 11)
		desc.modulate = Color(0.75, 0.75, 0.75)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var key_capture = upg["key"]
		var slot_capture = slot_index
		cb.toggled.connect(func(on: bool): _on_toggle(key_capture, slot_capture, on))

		row.add_child(cb)
		row.add_child(desc)
		list_container.add_child(row)
		_checkboxes.append({"checkbox": cb, "key": upg["key"], "slot": slot_index})

func _on_toggle(upgrade_key: String, slot_index: int, value: bool) -> void:
	if _inventory == null:
		return
	var wd = _inventory.slots[slot_index]
	if wd == null:
		return
	wd.set(upgrade_key, value)
	var wn = _inventory.weapon_nodes[slot_index]
	if wn:
		wn.set_weapon_data(wd)
