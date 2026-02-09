extends HBoxContainer


@onready var label: Label = $CrystalsLabel

func _ready() -> void:
	_update(Game.bank_crystals)
	if not Game.bank_crystals_changed.is_connected(_update):
		Game.bank_crystals_changed.connect(_update)

func _update(amount: int) -> void:
	label.text = str(amount)
