extends CanvasLayer

@onready var panel: Panel              = $Panel
@onready var new_weapon_label: Label   = $Panel/VBox/NewWeapon
@onready var slot1_btn: Button         = $Panel/VBox/Slots/Slot1
@onready var slot2_btn: Button         = $Panel/VBox/Slots/Slot2
@onready var cancel_label: Label       = $Panel/VBox/CancelHint

var _inventory: WeaponInventory = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	visible = false
	slot1_btn.pressed.connect(func(): _on_slot_chosen(0))
	slot2_btn.pressed.connect(func(): _on_slot_chosen(1))

func setup(inventory: WeaponInventory) -> void:
	_inventory = inventory
	inventory.swap_prompt_requested.connect(_on_swap_requested)
	inventory.swap_prompt_dismissed.connect(_on_swap_dismissed)

func _on_swap_requested(pickup: WeaponPickup) -> void:
	if pickup == null or pickup.data == null:
		return

	var new_data = pickup.data
	var hand_tag = "[2H]" if new_data.is_two_handed() else "[1H]"
	new_weapon_label.text = "Podnieść: %s %s" % [hand_tag, new_data.weapon_name]

	var s0 = _inventory.slots[0]
	var s1 = _inventory.slots[1]

	if new_data.is_two_handed():
		# Nowa broń 2H — wyrzuci obie, pokazujemy oba sloty
		slot1_btn.text = "[1] Wyrzuć: %s" % (s0.weapon_name if s0 else "— pusty —")
		slot2_btn.visible = false
		slot1_btn.text = "[1] Wyrzuć wszystko i weź %s" % new_data.weapon_name
	else:
		slot2_btn.visible = true
		if _inventory.is_two_handed_equipped():
			slot1_btn.text = "[1] Zamień za: %s (2H)" % (s0.weapon_name if s0 else "—")
			slot2_btn.text = "[2] Anuluj"
		else:
			slot1_btn.text = "[1] Lewa ręka: %s" % (s0.weapon_name if s0 else "— pusty —")
			slot2_btn.text = "[2] Prawa ręka: %s" % (s1.weapon_name if s1 else "— pusty —")

	visible = true

func _on_swap_dismissed() -> void:
	visible = false
	slot2_btn.visible = true

func _on_slot_chosen(index: int) -> void:
	if _inventory:
		_inventory.confirm_swap(index)
