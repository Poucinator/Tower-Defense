extends Node

signal gold_changed(amount: int)
signal health_changed(amount: int)
signal wave_countdown_changed(seconds_left: int)

var gold: int = 300
var health: int = 20
var wave_countdown: float = 0.0
var is_selling_mode: bool = false

var max_tower_tier: int = 1

# ==========================================================
#        UPGRADES ECONOMY (InterLevel Asha)
# ==========================================================
const U_START_GOLD: StringName = &"start_gold"
const U_BUILDING_HP: StringName = &"building_hp"
const U_WAVE_SKIP_GOLD: StringName = &"wave_skip_gold"
# Base (niveau 0)
const BASE_START_GOLD: int = 300

# Bonus additif par niveau (1..5)
const START_GOLD_BONUS_BY_LEVEL: Array[int] = [100, 300, 500, 800, 1200]


# Multiplicateur PV bâtiments par niveau (1..5) ; niveau 0 = x1.0
const BUILDING_HP_MULT_BY_LEVEL: Array[float] = [1.5, 2.0, 3.0, 4.0, 5.0]
const WAVE_SKIP_GOLD_MULT_BY_LEVEL: Array[float] = [1.5, 2.0, 3.0, 4.0, 5.0]

func _meta_upgrade_level_key(upgrade_id: StringName) -> StringName:
	return StringName("meta_upgrade_level_%s" % String(upgrade_id))

func get_upgrade_level(upgrade_id: StringName) -> int:
	# Niveau 0 si pas acheté
	return int(get_meta(_meta_upgrade_level_key(upgrade_id), 0))




# =========================================================
# DEV / GODMODE (laisser à 0 en prod)
# =========================================================
@export var dev_enable: bool = true
@export var dev_bank_crystals_bonus: int = 0
@export var dev_run_crystals_bonus: int = 0




# ==========================================================
#        PROGRESSION LABO : HEAL (3 upgrades) ✅
# ==========================================================
signal heal_cooldown_level_changed(level: int)
signal heal_revive_level_changed(level: int)
signal heal_invincible_level_changed(level: int)

var heal_cooldown_level: int = 0
var heal_revive_level: int = 0
var heal_invincible_level: int = 0

# BASE
const HEAL_BASE_COOLDOWN: float = 20.0
const HEAL_BASE_REVIVE_BONUS: int = 0
const HEAL_BASE_INVINCIBLE: float = 5.0

# --- Cooldown ---
const HEAL_COOLDOWN_COSTS: Array[int] = [50, 200, 1000]
const HEAL_COOLDOWN_SECONDS: Array[float] = [17.0, 14.0, 10.0]

# --- Revive barracks (+X) ---
const HEAL_REVIVE_COSTS: Array[int] = [50, 200, 1000]
const HEAL_REVIVE_BONUS: Array[int] = [1, 2, 3]

# --- Invincibilité ---
const HEAL_INV_COSTS: Array[int] = [200, 1000, 3000]
const HEAL_INV_SECONDS: Array[float] = [8.0, 11.0, 15.0]



# ==========================================================
#                 CRISTAUX
# ==========================================================
signal bank_crystals_changed(amount: int)
signal run_crystals_changed(amount: int)
signal crystals_changed(amount: int) # compat

var bank_crystals: int = 0
var run_crystals: int = 0

# --------------------------
# Helpers DEV (bonus visible)
# --------------------------
func _bank_bonus() -> int:
	return dev_bank_crystals_bonus if dev_enable else 0

func _run_bonus() -> int:
	return dev_run_crystals_bonus if dev_enable else 0

func get_bank_crystals_total() -> int:
	return bank_crystals + _bank_bonus()

func get_run_crystals_total() -> int:
	return run_crystals + _run_bonus()

func _emit_bank_changed() -> void:
	# On émet le TOTAL pour que l'UI affiche "vrai + bonus"
	var total := get_bank_crystals_total()
	bank_crystals_changed.emit(total)
	crystals_changed.emit(total)

func _emit_run_changed() -> void:
	run_crystals_changed.emit(get_run_crystals_total())

# --------------------------
# API Bank
# --------------------------
func add_bank_crystals(amount: int) -> void:
	if amount <= 0:
		return
	bank_crystals += amount
	_emit_bank_changed()

func set_bank_crystals(value: int) -> void:
	bank_crystals = max(value, 0)
	_emit_bank_changed()

func can_spend_bank_crystals(cost: int) -> bool:
	return get_bank_crystals_total() >= cost

func try_spend_bank_crystals(cost: int) -> bool:
	if cost <= 0:
		return true

	var available := get_bank_crystals_total()
	if available < cost:
		return false

	# 1) Consomme le bonus DEV d'abord
	if dev_enable and dev_bank_crystals_bonus > 0:
		var take := mini(dev_bank_crystals_bonus, cost)
		dev_bank_crystals_bonus -= take
		cost -= take

	# 2) Puis les vrais cristaux
	if cost > 0:
		bank_crystals -= cost

	_emit_bank_changed()
	return true

# --------------------------
# API Run
# --------------------------
func reset_run_crystals() -> void:
	run_crystals = 0
	if dev_enable:
		dev_run_crystals_bonus = 0
	_emit_run_changed()

func add_run_crystals(amount: int) -> void:
	if amount <= 0:
		return
	run_crystals += amount
	_emit_run_changed()

func commit_run_crystals_to_bank() -> int:
	# On commit seulement les "vrais" run crystals
	if run_crystals <= 0:
		return 0

	var earned := run_crystals
	run_crystals = 0
	_emit_run_changed()

	add_bank_crystals(earned)
	return earned

# --------------------------
# Compat ancienne API "crystals"
# --------------------------
var crystals: int:
	get:
		# On renvoie le TOTAL pour tout l'existant qui lit "Game.crystals"
		return get_bank_crystals_total()
	set(value):
		set_bank_crystals(value)

func add_crystals(amount: int) -> void:
	add_bank_crystals(amount)


# ==========================================================
#            PROGRESSION LABO (MK par tourelle)
# ==========================================================
signal tower_unlocked_tier_changed(tower_id: StringName, tier: int)
signal tower_mk3_unlocked_changed(tower_id: StringName, unlocked: bool)

var tower_unlocked_tier := {
	&"barracks": 1,
	&"gun": 1,
	&"snipe": 1,
	&"missile": 1,
}

func get_tower_unlocked_tier(tower_id: StringName) -> int:
	return int(tower_unlocked_tier.get(tower_id, 1))

func set_tower_unlocked_tier(tower_id: StringName, tier: int) -> void:
	var t: int = maxi(1, tier)
	var prev := get_tower_unlocked_tier(tower_id)
	if t <= prev:
		return

	tower_unlocked_tier[tower_id] = t
	tower_unlocked_tier_changed.emit(tower_id, t)

	if t >= 3:
		tower_mk3_unlocked_changed.emit(tower_id, true)

func is_tower_mk3_unlocked(tower_id: StringName) -> bool:
	return get_tower_unlocked_tier(tower_id) >= 3

func can_upgrade_tower_to(tower_id: StringName, target_tier: int) -> bool:
	var effective_max: int = maxi(max_tower_tier, get_tower_unlocked_tier(tower_id))
	return target_tier <= effective_max

func try_unlock_tower_mk3(tower_id: StringName, cost: int) -> bool:
	if is_tower_mk3_unlocked(tower_id):
		return true
	if not try_spend_bank_crystals(cost):
		return false
	set_tower_unlocked_tier(tower_id, 3)
	return true

func reset_run_tower_progression() -> void:
	max_tower_tier = 1

# ==========================================================
#                 GOLD (MONNAIE EN JEU)
# ==========================================================
func add_gold(amount: int) -> void:
	if amount == 0:
		return
	gold = max(gold + amount, 0)
	gold_changed.emit(gold)

func try_spend(amount: int) -> bool:
	if amount <= 0:
		return true
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		return true
	return false

# ==========================================================
#                 VIE / GAME OVER
# ==========================================================
func lose_health(amount: int) -> void:
	health -= amount
	health_changed.emit(health)
	if health <= 0:
		game_over()

func game_over() -> void:
	print("[Game] GAME OVER")

# ==========================================================
#                 WAVES
# ==========================================================
func set_wave_countdown(v: float) -> void:
	wave_countdown = max(v, 0.0)
	wave_countdown_changed.emit(int(ceil(wave_countdown)))

# ==========================================================
#        PROGRESSION LABO : BARRACKS AURA BUFF
# ==========================================================
signal barracks_aura_level_changed(level: int)
var barracks_aura_level: int = 0

const BARRACKS_AURA_COSTS: Array[int] = [50, 100, 150]
const BARRACKS_AURA_BONUS: Array[float] = [0.30, 0.40, 0.60]

func get_barracks_aura_level() -> int:
	return barracks_aura_level

func get_barracks_aura_max_level() -> int:
	return BARRACKS_AURA_COSTS.size()

func get_barracks_aura_cost(level: int) -> int:
	if level <= 0:
		return 0
	var idx := clampi(level - 1, 0, BARRACKS_AURA_COSTS.size() - 1)
	return BARRACKS_AURA_COSTS[idx]

func get_barracks_aura_bonus(level: int) -> float:
	if level <= 0:
		return 0.0
	var idx := clampi(level - 1, 0, BARRACKS_AURA_BONUS.size() - 1)
	return BARRACKS_AURA_BONUS[idx]

func get_barracks_aura_next_cost() -> int:
	var next_level := barracks_aura_level + 1
	if next_level > get_barracks_aura_max_level():
		return 0
	return get_barracks_aura_cost(next_level)

func can_upgrade_barracks_aura() -> bool:
	var cost := get_barracks_aura_next_cost()
	return cost > 0 and can_spend_bank_crystals(cost)

func try_upgrade_barracks_aura() -> bool:
	var cost := get_barracks_aura_next_cost()
	if cost <= 0:
		return false
	if not try_spend_bank_crystals(cost):
		return false

	barracks_aura_level += 1
	barracks_aura_level_changed.emit(barracks_aura_level)
	return true

# ==========================================================
#        PROGRESSION LABO : GUN SLOW UPGRADE (par niveaux)
# ==========================================================
signal gun_slow_level_changed(level: int)
var gun_slow_level: int = 0

const GUN_SLOW_COSTS: Array[int] = [50, 100, 150]
const GUN_SLOW_FACTOR: Array[float] = [0.60, 0.30, 0.10]
const GUN_SLOW_DURATION: Array[float] = [1.2, 1.5, 1.8]

func get_gun_slow_level() -> int:
	return gun_slow_level

func get_gun_slow_max_level() -> int:
	return GUN_SLOW_COSTS.size()

func has_gun_slow() -> bool:
	return gun_slow_level > 0

func get_gun_slow_cost(level: int) -> int:
	if level <= 0:
		return 0
	var idx := clampi(level - 1, 0, GUN_SLOW_COSTS.size() - 1)
	return GUN_SLOW_COSTS[idx]

func get_gun_slow_factor_for_level(level: int) -> float:
	if level <= 0:
		level = 1
	var idx := clampi(level - 1, 0, GUN_SLOW_FACTOR.size() - 1)
	return GUN_SLOW_FACTOR[idx]

func get_gun_slow_duration_for_level(level: int) -> float:
	if level <= 0:
		level = 1
	var idx := clampi(level - 1, 0, GUN_SLOW_DURATION.size() - 1)
	return GUN_SLOW_DURATION[idx]

func get_gun_slow_factor() -> float:
	return get_gun_slow_factor_for_level(gun_slow_level)

func get_gun_slow_duration() -> float:
	return get_gun_slow_duration_for_level(gun_slow_level)

func get_gun_slow_next_cost() -> int:
	var next_level := gun_slow_level + 1
	if next_level > get_gun_slow_max_level():
		return 0
	return get_gun_slow_cost(next_level)

func can_upgrade_gun_slow() -> bool:
	var cost := get_gun_slow_next_cost()
	return cost > 0 and can_spend_bank_crystals(cost)

func try_upgrade_gun_slow() -> bool:
	var cost := get_gun_slow_next_cost()
	if cost <= 0:
		return false
	if not try_spend_bank_crystals(cost):
		return false

	gun_slow_level += 1
	gun_slow_level_changed.emit(gun_slow_level)
	return true

# ==========================================================
#        PROGRESSION LABO : SNIPE BREAK (perçage balle)
# ==========================================================
signal snipe_break_level_changed(level: int)
var snipe_break_level: int = 0

const SNIPE_BREAK_COSTS: Array[int] = [50, 100, 150]
const SNIPE_BREAK_EXTRA_HITS: Array[int] = [1, 2, 3]

func get_snipe_break_level() -> int:
	return snipe_break_level

func get_snipe_break_max_level() -> int:
	return SNIPE_BREAK_COSTS.size()

func has_snipe_break() -> bool:
	return snipe_break_level > 0

func get_snipe_break_cost(level: int) -> int:
	if level <= 0:
		return 0
	var idx := clampi(level - 1, 0, SNIPE_BREAK_COSTS.size() - 1)
	return SNIPE_BREAK_COSTS[idx]

func get_snipe_break_extra_hits_for_level(level: int) -> int:
	if level <= 0:
		return 0
	var idx := clampi(level - 1, 0, SNIPE_BREAK_EXTRA_HITS.size() - 1)
	return SNIPE_BREAK_EXTRA_HITS[idx]

func get_snipe_break_extra_hits() -> int:
	return get_snipe_break_extra_hits_for_level(snipe_break_level)

func get_snipe_break_next_cost() -> int:
	var next_level := snipe_break_level + 1
	if next_level > get_snipe_break_max_level():
		return 0
	return get_snipe_break_cost(next_level)

func can_upgrade_snipe_break() -> bool:
	var cost := get_snipe_break_next_cost()
	return cost > 0 and can_spend_bank_crystals(cost)

func try_upgrade_snipe_break() -> bool:
	var cost := get_snipe_break_next_cost()
	if cost <= 0:
		return false
	if not try_spend_bank_crystals(cost):
		return false

	snipe_break_level += 1
	snipe_break_level_changed.emit(snipe_break_level)
	return true

# ==========================================================
#        PROGRESSION LABO : MISSILE FIRE (embrasement) ✅
# ==========================================================
signal missile_fire_level_changed(level: int)

# 0 = pas acheté
var missile_fire_level: int = 0

# ⚠️ Placeholders : tu ajusteras plus tard les valeurs exactes
const MISSILE_FIRE_COSTS: Array[int] = [60, 120, 220]
const MISSILE_FIRE_CHANCE: Array[float] = [0.10, 0.20, 0.30]      # probabilité par tir
const MISSILE_FIRE_DPS_PCT: Array[float] = [0.60, 0.80, 1]     # % des dégâts de la tour / seconde
const MISSILE_FIRE_DURATION: Array[float] = [3.0, 5.0, 7.0]       # durée en secondes

func get_missile_fire_level() -> int:
	return missile_fire_level

func get_missile_fire_max_level() -> int:
	return MISSILE_FIRE_COSTS.size()

func has_missile_fire() -> bool:
	return missile_fire_level > 0

func get_missile_fire_cost(level: int) -> int:
	if level <= 0:
		return 0
	var idx := clampi(level - 1, 0, MISSILE_FIRE_COSTS.size() - 1)
	return MISSILE_FIRE_COSTS[idx]

func get_missile_fire_chance_for_level(level: int) -> float:
	if level <= 0:
		return 0.0
	var idx := clampi(level - 1, 0, MISSILE_FIRE_CHANCE.size() - 1)
	return MISSILE_FIRE_CHANCE[idx]

func get_missile_fire_dps_pct_for_level(level: int) -> float:
	if level <= 0:
		return 0.0
	var idx := clampi(level - 1, 0, MISSILE_FIRE_DPS_PCT.size() - 1)
	return MISSILE_FIRE_DPS_PCT[idx]

func get_missile_fire_duration_for_level(level: int) -> float:
	if level <= 0:
		return 0.0
	var idx := clampi(level - 1, 0, MISSILE_FIRE_DURATION.size() - 1)
	return MISSILE_FIRE_DURATION[idx]

# Valeurs "courantes"
func get_missile_fire_chance() -> float:
	return get_missile_fire_chance_for_level(missile_fire_level)

func get_missile_fire_dps_pct() -> float:
	return get_missile_fire_dps_pct_for_level(missile_fire_level)

func get_missile_fire_duration() -> float:
	return get_missile_fire_duration_for_level(missile_fire_level)

func get_missile_fire_next_cost() -> int:
	var next_level := missile_fire_level + 1
	if next_level > get_missile_fire_max_level():
		return 0
	return get_missile_fire_cost(next_level)

func can_upgrade_missile_fire() -> bool:
	var cost := get_missile_fire_next_cost()
	return cost > 0 and can_spend_bank_crystals(cost)

func try_upgrade_missile_fire() -> bool:
	var cost := get_missile_fire_next_cost()
	if cost <= 0:
		return false
	if not try_spend_bank_crystals(cost):
		return false

	missile_fire_level += 1
	missile_fire_level_changed.emit(missile_fire_level)
	return true


# ==========================================================
#        PROGRESSION LABO : FREEZE (3 upgrades) ✅
# ==========================================================
signal freeze_cooldown_level_changed(level: int)
signal freeze_strength_level_changed(level: int)
signal freeze_number_level_changed(level: int)

# 0 = pas amélioré (valeurs de base en jeu)
var freeze_cooldown_level: int = 0
var freeze_strength_level: int = 0
var freeze_number_level: int = 0

# Valeurs BASE (quand niveau 0)
const FREEZE_BASE_COOLDOWN: float = 20.0
const FREEZE_BASE_STRENGTH_FACTOR: float = 0.8  # vitesse x0.8
const FREEZE_BASE_MAX_CONCURRENT: int = 1

# --- Cooldown ---
const FREEZE_COOLDOWN_COSTS: Array[int] = [50, 200, 1000]
const FREEZE_COOLDOWN_SECONDS: Array[float] = [17.0, 14.0, 10.0]

func get_freeze_cooldown_level() -> int:
	return freeze_cooldown_level

func get_freeze_cooldown_max_level() -> int:
	return FREEZE_COOLDOWN_COSTS.size()

func get_freeze_cooldown_cost(level: int) -> int:
	if level <= 0:
		return 0
	var idx := clampi(level - 1, 0, FREEZE_COOLDOWN_COSTS.size() - 1)
	return FREEZE_COOLDOWN_COSTS[idx]

func get_freeze_cooldown_seconds_for_level(level: int) -> float:
	if level <= 0:
		return FREEZE_BASE_COOLDOWN
	var idx := clampi(level - 1, 0, FREEZE_COOLDOWN_SECONDS.size() - 1)
	return FREEZE_COOLDOWN_SECONDS[idx]

func get_freeze_cooldown_seconds() -> float:
	return get_freeze_cooldown_seconds_for_level(freeze_cooldown_level)

func get_freeze_cooldown_next_cost() -> int:
	var next_level := freeze_cooldown_level + 1
	if next_level > get_freeze_cooldown_max_level():
		return 0
	return get_freeze_cooldown_cost(next_level)

func can_upgrade_freeze_cooldown() -> bool:
	var cost := get_freeze_cooldown_next_cost()
	return cost > 0 and can_spend_bank_crystals(cost)

func try_upgrade_freeze_cooldown() -> bool:
	var cost := get_freeze_cooldown_next_cost()
	if cost <= 0:
		return false
	if not try_spend_bank_crystals(cost):
		return false
	freeze_cooldown_level += 1
	freeze_cooldown_level_changed.emit(freeze_cooldown_level)
	return true

# --- Strength (vitesse x...) ---
const FREEZE_STRENGTH_COSTS: Array[int] = [50, 200, 1000]
const FREEZE_STRENGTH_FACTOR: Array[float] = [0.6, 0.4, 0.0] # 0.0 = arrêt total

func get_freeze_strength_level() -> int:
	return freeze_strength_level

func get_freeze_strength_max_level() -> int:
	return FREEZE_STRENGTH_COSTS.size()

func get_freeze_strength_cost(level: int) -> int:
	if level <= 0:
		return 0
	var idx := clampi(level - 1, 0, FREEZE_STRENGTH_COSTS.size() - 1)
	return FREEZE_STRENGTH_COSTS[idx]

func get_freeze_strength_factor_for_level(level: int) -> float:
	if level <= 0:
		return FREEZE_BASE_STRENGTH_FACTOR
	var idx := clampi(level - 1, 0, FREEZE_STRENGTH_FACTOR.size() - 1)
	return FREEZE_STRENGTH_FACTOR[idx]

func get_freeze_strength_factor() -> float:
	return get_freeze_strength_factor_for_level(freeze_strength_level)

func get_freeze_strength_next_cost() -> int:
	var next_level := freeze_strength_level + 1
	if next_level > get_freeze_strength_max_level():
		return 0
	return get_freeze_strength_cost(next_level)

func can_upgrade_freeze_strength() -> bool:
	var cost := get_freeze_strength_next_cost()
	return cost > 0 and can_spend_bank_crystals(cost)

func try_upgrade_freeze_strength() -> bool:
	var cost := get_freeze_strength_next_cost()
	if cost <= 0:
		return false
	if not try_spend_bank_crystals(cost):
		return false
	freeze_strength_level += 1
	freeze_strength_level_changed.emit(freeze_strength_level)
	return true

# --- Number (instances simultanées) ---
const FREEZE_NUMBER_COSTS: Array[int] = [200, 1000, 3000]
const FREEZE_NUMBER_MAX_CONCURRENT: Array[int] = [2, 3, 4]

func get_freeze_number_level() -> int:
	return freeze_number_level

func get_freeze_number_max_level() -> int:
	return FREEZE_NUMBER_COSTS.size()

func get_freeze_number_cost(level: int) -> int:
	if level <= 0:
		return 0
	var idx := clampi(level - 1, 0, FREEZE_NUMBER_COSTS.size() - 1)
	return FREEZE_NUMBER_COSTS[idx]

func get_freeze_number_value_for_level(level: int) -> int:
	if level <= 0:
		return FREEZE_BASE_MAX_CONCURRENT
	var idx := clampi(level - 1, 0, FREEZE_NUMBER_MAX_CONCURRENT.size() - 1)
	return FREEZE_NUMBER_MAX_CONCURRENT[idx]

func get_freeze_max_concurrent() -> int:
	return get_freeze_number_value_for_level(freeze_number_level)

func get_freeze_number_next_cost() -> int:
	var next_level := freeze_number_level + 1
	if next_level > get_freeze_number_max_level():
		return 0
	return get_freeze_number_cost(next_level)

func can_upgrade_freeze_number() -> bool:
	var cost := get_freeze_number_next_cost()
	return cost > 0 and can_spend_bank_crystals(cost)

func try_upgrade_freeze_number() -> bool:
	var cost := get_freeze_number_next_cost()
	if cost <= 0:
		return false
	if not try_spend_bank_crystals(cost):
		return false
	freeze_number_level += 1
	freeze_number_level_changed.emit(freeze_number_level)
	return true

# ==========================================================
#        PROGRESSION LABO : SUMMON (3 upgrades) ✅
# ==========================================================
signal summon_cooldown_level_changed(level: int)
signal summon_marine_level_changed(level: int)
signal summon_number_level_changed(level: int)

# 0 = pas amélioré (valeurs de base)
var summon_cooldown_level: int = 0
var summon_marine_level: int = 0
var summon_number_level: int = 0

# Valeurs BASE (niveau 0)
const SUMMON_BASE_COOLDOWN: float = 20.0
const SUMMON_BASE_MARINE_TIER: int = 1   # MK1
const SUMMON_BASE_MARINE_COUNT: int = 3

# --- Cooldown ---
const SUMMON_COOLDOWN_COSTS: Array[int] = [50, 200, 1000]
const SUMMON_COOLDOWN_SECONDS: Array[float] = [17.0, 14.0, 10.0]

func get_summon_cooldown_level() -> int:
	return summon_cooldown_level

func get_summon_cooldown_max_level() -> int:
	return SUMMON_COOLDOWN_COSTS.size()

func get_summon_cooldown_cost(level: int) -> int:
	if level <= 0:
		return 0
	var idx := clampi(level - 1, 0, SUMMON_COOLDOWN_COSTS.size() - 1)
	return SUMMON_COOLDOWN_COSTS[idx]

func get_summon_cooldown_seconds_for_level(level: int) -> float:
	if level <= 0:
		return SUMMON_BASE_COOLDOWN
	var idx := clampi(level - 1, 0, SUMMON_COOLDOWN_SECONDS.size() - 1)
	return SUMMON_COOLDOWN_SECONDS[idx]

func get_summon_cooldown_seconds() -> float:
	return get_summon_cooldown_seconds_for_level(summon_cooldown_level)

func get_summon_cooldown_next_cost() -> int:
	var next_level := summon_cooldown_level + 1
	if next_level > get_summon_cooldown_max_level():
		return 0
	return get_summon_cooldown_cost(next_level)

func can_upgrade_summon_cooldown() -> bool:
	var cost := get_summon_cooldown_next_cost()
	return cost > 0 and can_spend_bank_crystals(cost)

func try_upgrade_summon_cooldown() -> bool:
	var cost := get_summon_cooldown_next_cost()
	if cost <= 0:
		return false
	if not try_spend_bank_crystals(cost):
		return false
	summon_cooldown_level += 1
	summon_cooldown_level_changed.emit(summon_cooldown_level)
	return true


# --- Marine Lvl (MK1 -> MK2..MK5) ---
# level 1 => MK2, level 2 => MK3, level 3 => MK4, level 4 => MK5
const SUMMON_MARINE_COSTS: Array[int] = [50, 200, 1000, 3000]
const SUMMON_MARINE_TIERS: Array[int] = [2, 3, 4, 5]

func get_summon_marine_level() -> int:
	return summon_marine_level

func get_summon_marine_max_level() -> int:
	return SUMMON_MARINE_COSTS.size()

func get_summon_marine_cost(level: int) -> int:
	if level <= 0:
		return 0
	var idx := clampi(level - 1, 0, SUMMON_MARINE_COSTS.size() - 1)
	return SUMMON_MARINE_COSTS[idx]

func get_summon_marine_tier_for_level(level: int) -> int:
	if level <= 0:
		return SUMMON_BASE_MARINE_TIER
	var idx := clampi(level - 1, 0, SUMMON_MARINE_TIERS.size() - 1)
	return SUMMON_MARINE_TIERS[idx]

func get_summon_marine_tier() -> int:
	return get_summon_marine_tier_for_level(summon_marine_level)

func get_summon_marine_next_cost() -> int:
	var next_level := summon_marine_level + 1
	if next_level > get_summon_marine_max_level():
		return 0
	return get_summon_marine_cost(next_level)

func can_upgrade_summon_marine() -> bool:
	var cost := get_summon_marine_next_cost()
	return cost > 0 and can_spend_bank_crystals(cost)

func try_upgrade_summon_marine() -> bool:
	var cost := get_summon_marine_next_cost()
	if cost <= 0:
		return false
	if not try_spend_bank_crystals(cost):
		return false
	summon_marine_level += 1
	summon_marine_level_changed.emit(summon_marine_level)
	return true


# --- Number (nombre de marines invoqués) ---
const SUMMON_NUMBER_COSTS: Array[int] = [200, 1000, 3000]
const SUMMON_NUMBER_COUNTS: Array[int] = [4, 5, 6]

func get_summon_number_level() -> int:
	return summon_number_level

func get_summon_number_max_level() -> int:
	return SUMMON_NUMBER_COSTS.size()

func get_summon_number_cost(level: int) -> int:
	if level <= 0:
		return 0
	var idx := clampi(level - 1, 0, SUMMON_NUMBER_COSTS.size() - 1)
	return SUMMON_NUMBER_COSTS[idx]

func get_summon_marine_count_for_level(level: int) -> int:
	if level <= 0:
		return SUMMON_BASE_MARINE_COUNT
	var idx := clampi(level - 1, 0, SUMMON_NUMBER_COUNTS.size() - 1)
	return SUMMON_NUMBER_COUNTS[idx]

func get_summon_marine_count() -> int:
	return get_summon_marine_count_for_level(summon_number_level)

func get_summon_number_next_cost() -> int:
	var next_level := summon_number_level + 1
	if next_level > get_summon_number_max_level():
		return 0
	return get_summon_number_cost(next_level)

func can_upgrade_summon_number() -> bool:
	var cost := get_summon_number_next_cost()
	return cost > 0 and can_spend_bank_crystals(cost)

func try_upgrade_summon_number() -> bool:
	var cost := get_summon_number_next_cost()
	if cost <= 0:
		return false
	if not try_spend_bank_crystals(cost):
		return false
	summon_number_level += 1
	summon_number_level_changed.emit(summon_number_level)
	return true

# -------------------------
# HEAL : Cooldown
# -------------------------
func get_heal_cooldown_level() -> int:
	return heal_cooldown_level

func get_heal_cooldown_max_level() -> int:
	return HEAL_COOLDOWN_COSTS.size()

func get_heal_cooldown_cost(level: int) -> int:
	if level <= 0: return 0
	var idx := clampi(level - 1, 0, HEAL_COOLDOWN_COSTS.size() - 1)
	return HEAL_COOLDOWN_COSTS[idx]

func get_heal_cooldown_seconds_for_level(level: int) -> float:
	if level <= 0: return HEAL_BASE_COOLDOWN
	var idx := clampi(level - 1, 0, HEAL_COOLDOWN_SECONDS.size() - 1)
	return HEAL_COOLDOWN_SECONDS[idx]

func get_heal_cooldown_seconds() -> float:
	return get_heal_cooldown_seconds_for_level(heal_cooldown_level)

func get_heal_cooldown_next_cost() -> int:
	var next := heal_cooldown_level + 1
	if next > get_heal_cooldown_max_level(): return 0
	return get_heal_cooldown_cost(next)

func can_upgrade_heal_cooldown() -> bool:
	var cost := get_heal_cooldown_next_cost()
	return cost > 0 and can_spend_bank_crystals(cost)

func try_upgrade_heal_cooldown() -> bool:
	var cost := get_heal_cooldown_next_cost()
	if cost <= 0: return false
	if not try_spend_bank_crystals(cost): return false
	heal_cooldown_level += 1
	heal_cooldown_level_changed.emit(heal_cooldown_level)
	return true


# -------------------------
# HEAL : Revive barracks
# -------------------------
func get_heal_revive_level() -> int:
	return heal_revive_level

func get_heal_revive_max_level() -> int:
	return HEAL_REVIVE_COSTS.size()

func get_heal_revive_cost(level: int) -> int:
	if level <= 0: return 0
	var idx := clampi(level - 1, 0, HEAL_REVIVE_COSTS.size() - 1)
	return HEAL_REVIVE_COSTS[idx]

func get_heal_revive_bonus_for_level(level: int) -> int:
	if level <= 0: return HEAL_BASE_REVIVE_BONUS
	var idx := clampi(level - 1, 0, HEAL_REVIVE_BONUS.size() - 1)
	return HEAL_REVIVE_BONUS[idx]

func get_heal_revive_bonus() -> int:
	return get_heal_revive_bonus_for_level(heal_revive_level)

func get_heal_revive_next_cost() -> int:
	var next := heal_revive_level + 1
	if next > get_heal_revive_max_level(): return 0
	return get_heal_revive_cost(next)

func can_upgrade_heal_revive() -> bool:
	var cost := get_heal_revive_next_cost()
	return cost > 0 and can_spend_bank_crystals(cost)

func try_upgrade_heal_revive() -> bool:
	var cost := get_heal_revive_next_cost()
	if cost <= 0: return false
	if not try_spend_bank_crystals(cost): return false
	heal_revive_level += 1
	heal_revive_level_changed.emit(heal_revive_level)
	return true


# -------------------------
# HEAL : Invincibilité
# -------------------------
func get_heal_invincible_level() -> int:
	return heal_invincible_level

func get_heal_invincible_max_level() -> int:
	return HEAL_INV_COSTS.size()

func get_heal_invincible_cost(level: int) -> int:
	if level <= 0: return 0
	var idx := clampi(level - 1, 0, HEAL_INV_COSTS.size() - 1)
	return HEAL_INV_COSTS[idx]

func get_heal_invincible_seconds_for_level(level: int) -> float:
	if level <= 0: return HEAL_BASE_INVINCIBLE
	var idx := clampi(level - 1, 0, HEAL_INV_SECONDS.size() - 1)
	return HEAL_INV_SECONDS[idx]

func get_heal_invincible_seconds() -> float:
	return get_heal_invincible_seconds_for_level(heal_invincible_level)

func get_heal_invincible_next_cost() -> int:
	var next := heal_invincible_level + 1
	if next > get_heal_invincible_max_level(): return 0
	return get_heal_invincible_cost(next)

func can_upgrade_heal_invincible() -> bool:
	var cost := get_heal_invincible_next_cost()
	return cost > 0 and can_spend_bank_crystals(cost)

func try_upgrade_heal_invincible() -> bool:
	var cost := get_heal_invincible_next_cost()
	if cost <= 0: return false
	if not try_spend_bank_crystals(cost): return false
	heal_invincible_level += 1
	heal_invincible_level_changed.emit(heal_invincible_level)
	return true

# --------------------------
# GOLD de départ (upgrade)
# --------------------------
func get_start_gold_total() -> int:
	var level := get_upgrade_level(U_START_GOLD)
	if level <= 0:
		return BASE_START_GOLD

	# level 1..5 -> index 0..4
	var idx := clampi(level - 1, 0, START_GOLD_BONUS_BY_LEVEL.size() - 1)
	return BASE_START_GOLD + int(START_GOLD_BONUS_BY_LEVEL[idx])

func reset_gold_to_start_value() -> void:
	# À appeler au début d’un niveau/run, une seule fois.
	gold = get_start_gold_total()
	gold_changed.emit(gold)


func get_building_hp_multiplier() -> float:
	var level := get_upgrade_level(U_BUILDING_HP)
	if level <= 0:
		return 1.0
	var idx := clampi(level - 1, 0, BUILDING_HP_MULT_BY_LEVEL.size() - 1)
	return float(BUILDING_HP_MULT_BY_LEVEL[idx])


func get_wave_skip_gold_multiplier() -> float:
	var level := get_upgrade_level(U_WAVE_SKIP_GOLD)
	if level <= 0:
		return 1.0
	var idx := clampi(level - 1, 0, WAVE_SKIP_GOLD_MULT_BY_LEVEL.size() - 1)
	return float(WAVE_SKIP_GOLD_MULT_BY_LEVEL[idx])


func compute_wave_skip_reward(seconds_left: float) -> int:
	# Récompense "base" : comme avant (arrondi au dessus)
	var base_reward := int(ceil(max(seconds_left, 0.0)))

	# Appliquer le multiplicateur Asha
	var mult := 1.0
	if has_method("get_wave_skip_gold_multiplier"):
		mult = get_wave_skip_gold_multiplier()

	# On arrondit proprement et on évite 0 si base > 0 (optionnel)
	var final_reward := int(round(float(base_reward) * mult))
	if base_reward > 0:
		final_reward = maxi(1, final_reward)

	return final_reward
