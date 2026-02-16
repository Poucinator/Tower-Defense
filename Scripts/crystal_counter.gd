# res://ui/crystal_counter.gd
extends HBoxContainer
class_name CrystalCounter

@onready var label: Label = $CrystalsLabel

func _ready() -> void:
	# ✅ Affiche tout de suite le TOTAL (bank + bonus dev éventuel)
	_update(Game.get_bank_crystals_total())

	# ✅ Le signal bank_crystals_changed émet déjà le TOTAL
	if not Game.bank_crystals_changed.is_connected(_update):
		Game.bank_crystals_changed.connect(_update)

func _exit_tree() -> void:
	# ✅ évite des connexions pendantes si tu changes de scène souvent
	if Game.bank_crystals_changed.is_connected(_update):
		Game.bank_crystals_changed.disconnect(_update)

func _update(amount_total: int) -> void:
	label.text = str(amount_total)
