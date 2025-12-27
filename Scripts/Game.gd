extends Node

signal gold_changed(amount: int)
signal health_changed(amount: int)
signal wave_countdown_changed(seconds_left: int)

var gold: int = 30000
var health: int = 20
var wave_countdown: float = 0.0
var is_selling_mode := false

var max_tower_tier: int = 1
# 1 = on ne peut construire / améliorer que jusqu’à MK1
# 2 = MK2 autorisé
# 3 = MK3 autorisé, etc.

signal crystals_changed(amount: int)

var crystals: int = 0

func add_crystals(amount: int) -> void:
	crystals += amount
	emit_signal("crystals_changed", crystals)


func add_gold(amount: int) -> void:
	gold += amount
	emit_signal("gold_changed", gold)

func can_spend(amount: int) -> bool:
	return gold >= amount

func try_spend(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		emit_signal("gold_changed", gold)
		return true
	return false

func lose_health(amount: int) -> void:
	health -= amount
	emit_signal("health_changed", health)
	if health <= 0:
		game_over()

func game_over() -> void:
	print("[Game] GAME OVER")
	
	
func set_wave_countdown(v: float) -> void:
	wave_countdown = max(v, 0.0)
	emit_signal("wave_countdown_changed", int(ceil(wave_countdown)))

var bank_crystals: int = 0
signal bank_crystals_changed(amount: int)

func add_bank_crystals(amount: int) -> void:
	bank_crystals += max(amount, 0)
	emit_signal("bank_crystals_changed", bank_crystals)
