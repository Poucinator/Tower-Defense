extends Node

signal gold_changed(amount: int)
signal health_changed(amount: int)
signal wave_countdown_changed(seconds_left: int)

var gold: int = 30000
var health: int = 20
var wave_countdown: float = 0.0
var is_selling_mode := false



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
