extends CanvasLayer

const DBG_CRYSTAL := true

# =========================================================
#     MODE "NON-TUTO" (SAFE: default false => lvl1 inchangé)
# =========================================================
@export var auto_unlock_from_game: bool = false
@export var show_crystal_panel_on_start: bool = false

# --- Références UI (haut) ---
@onready var gold_label:       Label          = $"HBoxContainer/GoldLabel"
@onready var health_label:     Label          = $"HBoxContainer/HealthLabel"
@onready var build_btn:        TextureButton  = $"HBoxContainer/BuildBlueBtn"
@onready var build_snipe_btn:  TextureButton  = $"HBoxContainer/BuildSnipeBtn"
@onready var build_missile_btn: TextureButton = $"HBoxContainer/BuildMissileBtn"
@onready var build_barracks_btn: TextureButton = $"HBoxContainer/BuildBarracksBtn"

@export var music_bus_name: StringName = &"Music"

# --- Timer + bouton à droite (haut) ---
@onready var timer_label:  Label  = $"HBoxContainer/TimerLabel"
@onready var next_btn:     Button = $"HBoxContainer/NextWaveBtn"

# --- Barre du bas : Pouvoirs ---
@onready var freeze_btn:   BaseButton = $"BottomBar/FreezeBtn"
@onready var freeze_label: Label      = $"BottomBar/FreezeBtn/Label"

@onready var heal_btn:     BaseButton = $"BottomBar/HealBtn"
@onready var heal_label:   Label      = $"BottomBar/HealBtn/Label"

@onready var summon_btn:   BaseButton = $"BottomBar/SummonBtn"
@onready var summon_label: Label      = $"BottomBar/SummonBtn/Label"

# --- Barre droite : Vente ---
@onready var sell_btn:     BaseButton = $"RightBar/SellBtn"

# --- Lien vers contrôleurs externes ---
@export var power_controller_path: NodePath
@export var build_controller_path: NodePath
@export var spawner_path:          NodePath
var powers: Node = null
var build:   Node = null
var spawner: Node = null

# --- Cristaux (phase finale) ---
@export_range(0.1, 60.0, 0.1, "or_greater") var crystal_tick_seconds: float = 2.0

@onready var crystal_panel: Control = $"CrystalPanel"
@onready var crystal_label2: Label = $"CrystalPanel/HBoxContainer/CrystalLabel"
@onready var crystal_timer: Timer = $"CrystalTimer"

var _crystal_running := false

# --- États locaux ---
var _last_left: float = 0.0
var _is_sell_mode: bool = false

# --- Mode LevelDirector ---
signal next_clicked()
var _director_cd_active := false
var _director_cd_left   := 0.0

# --- Scènes & prix ---
const BLUE_TOWER_SCN      := preload("res://scene/tower/blue_tower.tscn")
const BLUE_TOWER_PRICE    := 100
const SNIPE_TOWER_SCN     := preload("res://scene/tower/snipe_tower.tscn")
const SNIPE_TOWER_PRICE   := 200
const MISSILE_TOWER_SCN   := preload("res://scene/tower/missile_tower.tscn")
const MISSILE_TOWER_PRICE := 300
const BARRACKS_TOWER_SCN  := preload("res://scene/tower/barracks_tower.tscn")
const BARRACKS_TOWER_PRICE := 50

# =========================================================
#                OPTIONS MENU (pause / music / speed)
# =========================================================
@export var option_btn_path: NodePath = NodePath("HBoxContainer2/optionBtn")
@export var options_panel_path: NodePath = NodePath("TextureRect")

@export var play_btn_path: NodePath = NodePath("TextureRect/playBtn") # reprendre
@export var exit_btn_path: NodePath = NodePath("TextureRect/exitBtn") # menu principal

@export var music_btn_path: NodePath = NodePath("TextureRect/musicBtn")
@export var speed_x1_btn_path: NodePath = NodePath("TextureRect/speedX1Btn")
@export var speed_x2_btn_path: NodePath = NodePath("TextureRect/speedX2Btn")
@export var speed_x4_btn_path: NodePath = NodePath("TextureRect/speedX4Btn")

@export_file("*.tscn") var main_menu_scene_path: String = "res://scene/MainMenu.tscn"

# Textures "vide / plein" pour tes toggles (à assigner dans l'inspecteur)
@export var toggle_empty_tex: Texture2D
@export var toggle_full_tex: Texture2D

# Feeling anim panneau
@export_range(0.05, 1.0, 0.01) var options_open_duration: float = 0.22
@export_range(0.05, 1.0, 0.01) var options_close_duration: float = 0.18
@export var options_slide_px: float = 40.0

@onready var option_btn: BaseButton = get_node_or_null(option_btn_path)
@onready var options_panel: Control = get_node_or_null(options_panel_path)

@onready var play_btn: BaseButton = get_node_or_null(play_btn_path)
@onready var exit_btn: BaseButton = get_node_or_null(exit_btn_path)

@onready var music_btn: TextureButton = get_node_or_null(music_btn_path) as TextureButton
@onready var speed_x1_btn: TextureButton = get_node_or_null(speed_x1_btn_path) as TextureButton
@onready var speed_x2_btn: TextureButton = get_node_or_null(speed_x2_btn_path) as TextureButton
@onready var speed_x4_btn: TextureButton = get_node_or_null(speed_x4_btn_path) as TextureButton

var _options_open := false
var _panel_open_pos := Vector2.ZERO
var _panel_closed_pos := Vector2.ZERO

# état actuel (réel)
var _music_on := true
var _speed_mult := 1.0

# Réf vers la musique de la scène (autoplay)
var _music_player: AudioStreamPlayer = null


func _ready() -> void:
	# Or
	Game.gold_changed.connect(_on_gold_changed)
	_on_gold_changed(Game.gold)

	$"HBoxContainer".mouse_filter = Control.MOUSE_FILTER_IGNORE

	# PV
	if Game.has_signal("health_changed"):
		Game.health_changed.connect(_on_health_changed)
	_on_health_changed(Game.health)

	# Build
	build = get_node_or_null(build_controller_path)
	if build_btn: build_btn.pressed.connect(_on_build_blue_pressed)
	if build_snipe_btn: build_snipe_btn.pressed.connect(_on_build_snipe_pressed)
	if build_missile_btn: build_missile_btn.pressed.connect(_on_build_missile_pressed)
	if build_barracks_btn: build_barracks_btn.pressed.connect(_on_build_barracks_pressed)
	if build and build.has_signal("sell_mode_changed"):
		build.sell_mode_changed.connect(_on_sell_mode_changed)

	# Bouton "Prochaine vague"
	if next_btn:
		next_btn.visible = false
		next_btn.disabled = true
		next_btn.pressed.connect(_on_next_wave_pressed)

	# Bouton Vendre
	if sell_btn:
		sell_btn.pressed.connect(_on_sell_pressed)
		sell_btn.tooltip_text = "Vendre une tour (75% de sa valeur)"
		_update_sell_visual(false)

	# Spawner initial
	var initial_spawner := get_node_or_null(spawner_path)
	if initial_spawner:
		set_spawner(initial_spawner)

	timer_label.text = ""

	# =========================
	# Cristaux : init + debug
	# =========================
	if DBG_CRYSTAL:
		print("[CRYSTAL] _ready() tick_seconds=", crystal_tick_seconds)
		print("[CRYSTAL] nodes:", "panel=", crystal_panel, " label=", crystal_label2, " timer=", crystal_timer)

	if crystal_panel:
		crystal_panel.visible = false
		if DBG_CRYSTAL:
			print("[CRYSTAL] panel forced invisible at start")

	# Connect signal Game -> HUD (cristaux de RUN)
	if Game.has_signal("run_crystals_changed"):
		if not Game.run_crystals_changed.is_connected(_on_run_crystals_changed):
			Game.run_crystals_changed.connect(_on_run_crystals_changed)
			if DBG_CRYSTAL:
				print("[CRYSTAL] connected Game.run_crystals_changed -> _on_run_crystals_changed")
	else:
		if DBG_CRYSTAL:
			print("[CRYSTAL] WARNING: Game has no signal run_crystals_changed")

	# Valeur initiale (run)
	var init_val: int = 0
	if "run_crystals" in Game:
		init_val = int(Game.run_crystals)
	if DBG_CRYSTAL:
		print("[CRYSTAL] init run_crystals from Game =", init_val)
	_on_run_crystals_changed(init_val)

	# Timer
	if crystal_timer:
		crystal_timer.wait_time = crystal_tick_seconds
		if not crystal_timer.timeout.is_connected(_on_crystal_timer_timeout):
			crystal_timer.timeout.connect(_on_crystal_timer_timeout)
			if DBG_CRYSTAL:
				print("[CRYSTAL] connected crystal_timer.timeout -> _on_crystal_timer_timeout")
		if DBG_CRYSTAL:
			print("[CRYSTAL] timer configured wait_time=", crystal_timer.wait_time, " one_shot=", crystal_timer.one_shot, " autostart=", crystal_timer.autostart)
	else:
		if DBG_CRYSTAL:
			print("[CRYSTAL] WARNING: CrystalTimer node is null (path issue?)")

	# Pouvoirs
	powers = get_node_or_null(power_controller_path)
	if freeze_btn: freeze_btn.pressed.connect(_on_freeze_pressed)
	if heal_btn:   heal_btn.pressed.connect(_on_heal_pressed)
	if summon_btn: summon_btn.pressed.connect(_on_summon_pressed)

	# Init values powers depuis Game (inchangé)
	if powers and powers.has_method("set_freeze_cooldown"):
		var cd := 20.0
		if Game and Game.has_method("get_freeze_cooldown_seconds"):
			cd = float(Game.get_freeze_cooldown_seconds())
		powers.call("set_freeze_cooldown", cd)

	if powers and powers.has_method("set_freeze_max_concurrent"):
		var n := 1
		if Game and Game.has_method("get_freeze_max_concurrent"):
			n = int(Game.get_freeze_max_concurrent())
		powers.call("set_freeze_max_concurrent", n)

	_update_freeze_button_ui()

	if powers and powers.has_method("set_heal_cooldown"):
		var cd2 := 20.0
		if Game and Game.has_method("get_heal_cooldown_seconds"):
			cd2 = float(Game.get_heal_cooldown_seconds())
		powers.call("set_heal_cooldown", cd2)

	if powers and powers.has_method("set_heal_invincible_duration"):
		var dur := 5.0
		if Game and Game.has_method("get_heal_invincible_seconds"):
			dur = float(Game.get_heal_invincible_seconds())
		powers.call("set_heal_invincible_duration", dur)

	if powers and powers.has_method("set_heal_revive_bonus_per_barracks"):
		var bonus := 0
		if Game and Game.has_method("get_heal_revive_bonus"):
			bonus = int(Game.get_heal_revive_bonus())
		powers.call("set_heal_revive_bonus_per_barracks", bonus)

	if powers and powers.has_method("set_summon_cooldown"):
		var cd3 := 20.0
		if Game and Game.has_method("get_summon_cooldown_seconds"):
			cd3 = float(Game.get_summon_cooldown_seconds())
		powers.call("set_summon_cooldown", cd3)

	if powers and powers.has_method("set_summon_count"):
		var count := 3
		if Game and Game.has_method("get_summon_marine_count"):
			count = int(Game.get_summon_marine_count())
		powers.call("set_summon_count", count)

	if powers and powers.has_method("set_summon_marine_tier"):
		var tier := 1
		if Game and Game.has_method("get_summon_marine_tier"):
			tier = int(Game.get_summon_marine_tier())
		powers.call("set_summon_marine_tier", tier)

	# Relais signals Game -> PowerController (inchangé)
	if Game:
		if Game.has_signal("heal_cooldown_level_changed"):
			Game.heal_cooldown_level_changed.connect(func(_lvl:int):
				if powers and powers.has_method("set_heal_cooldown") and Game.has_method("get_heal_cooldown_seconds"):
					powers.call("set_heal_cooldown", float(Game.get_heal_cooldown_seconds()))
			)
		if Game.has_signal("heal_invincible_level_changed"):
			Game.heal_invincible_level_changed.connect(func(_lvl:int):
				if powers and powers.has_method("set_heal_invincible_duration") and Game.has_method("get_heal_invincible_seconds"):
					powers.call("set_heal_invincible_duration", float(Game.get_heal_invincible_seconds()))
			)
		if Game.has_signal("heal_revive_level_changed"):
			Game.heal_revive_level_changed.connect(func(_lvl:int):
				if powers and powers.has_method("set_heal_revive_bonus_per_barracks") and Game.has_method("get_heal_revive_bonus"):
					powers.call("set_heal_revive_bonus_per_barracks", int(Game.get_heal_revive_bonus()))
			)

		if Game.has_signal("summon_cooldown_level_changed"):
			Game.summon_cooldown_level_changed.connect(func(_lvl:int):
				if powers and powers.has_method("set_summon_cooldown") and Game.has_method("get_summon_cooldown_seconds"):
					powers.call("set_summon_cooldown", float(Game.get_summon_cooldown_seconds()))
			)
		if Game.has_signal("summon_marine_level_changed"):
			Game.summon_marine_level_changed.connect(func(_lvl:int):
				if powers and powers.has_method("set_summon_marine_tier") and Game.has_method("get_summon_marine_tier"):
					powers.call("set_summon_marine_tier", int(Game.get_summon_marine_tier()))
			)
		if Game.has_signal("summon_number_level_changed"):
			Game.summon_number_level_changed.connect(func(_lvl:int):
				if powers and powers.has_method("set_summon_count") and Game.has_method("get_summon_marine_count"):
					powers.call("set_summon_count", int(Game.get_summon_marine_count()))
			)

	# 🔒 Masquer au départ ce qui n'est pas débloqué (niveau 1 inchangé)
	_init_locked_elements()

	# ✅ Mode non-tuto : on ré-ouvre selon Game (uniquement si export true)
	if auto_unlock_from_game:
		_apply_unlocks_from_game()

	# =========================
	# Options menu : init (pause/music/speed)
	# =========================
	_init_options_menu()

	set_process(true)


# =========================================================
#         Mode "piloté par LevelDirector"
# =========================================================
func director_countdown_start(total: float) -> void:
	_director_cd_active = true
	_director_cd_left   = total
	timer_label.text = "Prochaine vague : %ds" % int(ceil(total))
	_update_next_button_state()

func director_countdown_tick(left: float) -> void:
	_director_cd_left = left
	if _director_cd_active:
		timer_label.text = "Prochaine vague : %ds" % int(ceil(max(left,0.0)))
		_update_next_button_state()

func director_countdown_done() -> void:
	_director_cd_active = false
	timer_label.text = "Vague en cours…"
	_update_next_button_state()


# =========================================================
#         Bascule dynamique du spawner
# =========================================================
func set_spawner(new_spawner: Node) -> void:
	# Débrancher l'ancien
	if spawner:
		if spawner.has_signal("countdown_started") and spawner.countdown_started.is_connected(_on_countdown_started):
			spawner.countdown_started.disconnect(_on_countdown_started)
		if spawner.has_signal("countdown_tick") and spawner.countdown_tick.is_connected(_on_countdown_tick):
			spawner.countdown_tick.disconnect(_on_countdown_tick)
		if spawner.has_signal("countdown_done") and spawner.countdown_done.is_connected(_on_countdown_done):
			spawner.countdown_done.disconnect(_on_countdown_done)
		if spawner.has_signal("wave_started") and spawner.wave_started.is_connected(_on_wave_started):
			spawner.wave_started.disconnect(_on_wave_started)
		if spawner.has_signal("wave_finished") and spawner.wave_finished.is_connected(_on_wave_finished):
			spawner.wave_finished.disconnect(_on_wave_finished)

	# Mémoriser + rebrancher
	spawner = new_spawner
	if spawner:
		if spawner.has_signal("countdown_started"): spawner.countdown_started.connect(_on_countdown_started)
		if spawner.has_signal("countdown_tick"):    spawner.countdown_tick.connect(_on_countdown_tick)
		if spawner.has_signal("countdown_done"):    spawner.countdown_done.connect(_on_countdown_done)
		if spawner.has_signal("wave_started"):      spawner.wave_started.connect(_on_wave_started)
		if spawner.has_signal("wave_finished"):     spawner.wave_finished.connect(_on_wave_finished)

	timer_label.text = ""
	_update_next_button_state()


# =========================================================
#                     Game callbacks
# =========================================================
func _on_gold_changed(amount: int) -> void:
	gold_label.text = str(amount)

func _on_health_changed(hp: int) -> void:
	health_label.text = str(max(hp, 0))


# =========================================================
#                     Build
# =========================================================
func _on_build_blue_pressed() -> void:
	if build: build.call("start_placing", BLUE_TOWER_SCN, BLUE_TOWER_PRICE)

func _on_build_snipe_pressed() -> void:
	if build: build.call("start_placing", SNIPE_TOWER_SCN, SNIPE_TOWER_PRICE)

func _on_build_missile_pressed() -> void:
	if build: build.call("start_placing", MISSILE_TOWER_SCN, MISSILE_TOWER_PRICE)

func _on_build_barracks_pressed() -> void:
	if build: build.call("start_placing", BARRACKS_TOWER_SCN, BARRACKS_TOWER_PRICE)


# =========================================================
#                   Vente des tours
# =========================================================
func _on_sell_pressed() -> void:
	if not build:
		push_warning("[HUD] Aucun BuildController lié.")
		return
	var target := not Game.is_selling_mode
	build.call("start_sell_mode", target)

func _update_sell_visual(active: bool) -> void:
	if not sell_btn:
		return
	if active:
		sell_btn.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		sell_btn.modulate = Color(1, 1, 0.5)
	else:
		sell_btn.add_theme_color_override("font_color", Color(1, 1, 1))
		sell_btn.modulate = Color(1, 1, 1)


# =========================================================
#          Spawner callbacks (timer à droite)
# =========================================================
func _on_countdown_started(total: float) -> void:
	_last_left = total
	timer_label.text = "Prochaine vague : %ds" % int(ceil(total))
	_update_next_button_state()

func _on_countdown_tick(left: float) -> void:
	_last_left = left
	timer_label.text = "Prochaine vague : %ds" % int(ceil(left))
	_update_next_button_state()

func _on_countdown_done() -> void:
	timer_label.text = "Vague en cours…"
	_update_next_button_state()

func _on_wave_started(_index: int, _count: int) -> void:
	timer_label.text = "Vague en cours…"
	_update_next_button_state()

func _on_wave_finished(_index: int) -> void:
	timer_label.text = "Vague terminée"
	_update_next_button_state()


# =========================================================
#             Bouton "Prochaine vague" (skip)
# =========================================================
func _update_next_button_state() -> void:
	if next_btn == null: return
	var can_skip := false
	var left := 0.0

	if _director_cd_active:
		can_skip = true
		left = _director_cd_left
	elif spawner and spawner.has_method("is_countdown_running"):
		can_skip = spawner.call("is_countdown_running")
		if spawner and spawner.has_method("get_countdown_left"):
			left = float(spawner.call("get_countdown_left"))
		else:
			left = _last_left

	next_btn.visible  = can_skip
	next_btn.disabled = not can_skip
	var reward := 0
	if Game and Game.has_method("compute_wave_skip_reward"):
		reward = int(Game.compute_wave_skip_reward(left))
	else:
		reward = int(ceil(max(left, 0.0))) # fallback sécurité

	next_btn.text = "Lancer (+" + str(reward) + " PO)"

func _on_next_wave_pressed() -> void:
	if _director_cd_active:
		next_btn.disabled = true
		emit_signal("next_clicked")
		return

	if spawner and spawner.has_method("is_countdown_running") and spawner.call("is_countdown_running"):
		var left := 0.0
		if spawner.has_method("get_countdown_left"):
			left = float(spawner.call("get_countdown_left"))
		else:
			left = _last_left
		var reward := 0
		if Game and Game.has_method("compute_wave_skip_reward"):
			reward = int(Game.compute_wave_skip_reward(left))
		else:
			reward = int(ceil(max(left, 0.0)))

		if reward > 0 and "add_gold" in Game:
			Game.add_gold(reward)
		if spawner.has_method("skip_countdown_and_start"):
			spawner.call("skip_countdown_and_start")
		next_btn.disabled = true


# =========================================================
#                   Pouvoirs
# =========================================================
func _process(_delta: float) -> void:
	# ✅ IMPORTANT : quand le menu options est ouvert, le gameplay est en pause.
	# On évite de mettre à jour les cooldowns UI en boucle.
	if get_tree().paused:
		return

	if freeze_btn and freeze_label:
		_update_freeze_button_ui()

	if heal_btn and heal_label and powers and powers.has_method("get_heal_cooldown_left"):
		var left := powers.call("get_heal_cooldown_left") as float
		if left > 0.0:
			heal_btn.disabled = true
			heal_label.text = "Soin (%.0fs)" % ceil(left)
		else:
			heal_btn.disabled = false
			heal_label.text = "Soin"

	if summon_btn and summon_label and powers and powers.has_method("get_summon_cooldown_left"):
		var left2 := powers.call("get_summon_cooldown_left") as float
		if left2 > 0.0:
			summon_btn.disabled = true
			summon_label.text = "Appel (%.0fs)" % ceil(left2)
		else:
			summon_btn.disabled = false
			summon_label.text = "Appel"


# =========================================================
#                   Actions des pouvoirs
# =========================================================
func _on_freeze_pressed() -> void:
	if powers and powers.has_method("start_place_freeze"):
		powers.call("start_place_freeze")

func _on_heal_pressed() -> void:
	if powers and powers.has_method("activate_heal_all"):
		powers.call("activate_heal_all")

func _on_summon_pressed() -> void:
	if powers and powers.has_method("start_place_summon"):
		powers.call("start_place_summon")


# =========================================================
#            Visibilité initiale & déblocage (tuto)
# =========================================================
func _init_locked_elements() -> void:
	build_barracks_btn.visible = true
	build_btn.visible = true
	build_snipe_btn.visible = false
	build_missile_btn.visible = false
	freeze_btn.visible = false
	heal_btn.visible = false
	summon_btn.visible = false
	# NB: CrystalPanel est déjà forcé invisible au _ready()

func unlock_element(name: String) -> void:
	if DBG_CRYSTAL:
		print("[CRYSTAL] unlock_element called with:", name)

	match name:
		"snipe":
			build_snipe_btn.visible = true
		"freeze":
			freeze_btn.visible = true
		"missile":
			build_missile_btn.visible = true
		"heal":
			heal_btn.visible = true
		"summon":
			summon_btn.visible = true
		"crystals":
			if DBG_CRYSTAL:
				print("[CRYSTAL] -> enabling panel + starting income (reset run)")

			if crystal_panel:
				crystal_panel.visible = true
				if DBG_CRYSTAL:
					print("[CRYSTAL] panel is now visible =", crystal_panel.visible)
			else:
				if DBG_CRYSTAL:
					print("[CRYSTAL] ERROR: crystal_panel is null")

			if "reset_run_crystals" in Game:
				Game.reset_run_crystals()

			_start_crystal_income()

		_:
			push_warning("[HUD] Élément inconnu : %s" % name)


# =========================================================
#     MODE "NON-TUTO" : ouvrir selon Game (lvl2)
# =========================================================
func _apply_unlocks_from_game() -> void:
	# Base : toujours dispo
	if build_barracks_btn: build_barracks_btn.visible = true
	if build_btn: build_btn.visible = true

	# Niveau 2 : on affiche les tours/pouvoirs (tu pourras affiner plus tard via Game)
	if build_snipe_btn: build_snipe_btn.visible = true
	if build_missile_btn: build_missile_btn.visible = true

	if freeze_btn: freeze_btn.visible = true
	if heal_btn: heal_btn.visible = true
	if summon_btn: summon_btn.visible = true

	# Cristaux : optionnel
	if show_crystal_panel_on_start:
		_enable_crystals_panel_and_income()


func _enable_crystals_panel_and_income() -> void:
	if crystal_panel:
		crystal_panel.visible = true

	if "reset_run_crystals" in Game:
		Game.reset_run_crystals()

	_start_crystal_income()


func _on_sell_mode_changed(active: bool) -> void:
	_is_sell_mode = active
	_update_sell_visual(active)


# =========================================================
#                   Cristaux
# =========================================================
func _on_run_crystals_changed(v: int) -> void:
	if DBG_CRYSTAL:
		print("[CRYSTAL] Game.run_crystals_changed ->", v)
	if crystal_label2:
		crystal_label2.text = str(v)

func _on_crystal_timer_timeout() -> void:
	if DBG_CRYSTAL:
		print("[CRYSTAL] timer timeout -> add_run_crystals(1)")
	Game.add_run_crystals(1)

func _start_crystal_income() -> void:
	if _crystal_running:
		if DBG_CRYSTAL:
			print("[CRYSTAL] income already running -> skip")
		return

	_crystal_running = true

	if DBG_CRYSTAL:
		print("[CRYSTAL] start income tick every", crystal_tick_seconds, "seconds")

	if crystal_timer:
		crystal_timer.stop()
		crystal_timer.wait_time = crystal_tick_seconds
		crystal_timer.start()
		if DBG_CRYSTAL:
			print("[CRYSTAL] timer started. is_stopped? =", crystal_timer.is_stopped())


# =========================================================
#             FREEZE UI (single ou multi-slots)
# =========================================================
func _get_freeze_cooldowns_left_list() -> Array[float]:
	if powers and powers.has_method("get_freeze_cooldown_lefts"):
		var raw = powers.call("get_freeze_cooldown_lefts")
		var out: Array[float] = []
		if raw is Array:
			for v in raw:
				out.append(float(v))
		return out

	if powers and powers.has_method("get_freeze_cooldown_left"):
		return [float(powers.call("get_freeze_cooldown_left"))]

	return []

func _update_freeze_button_ui() -> void:
	if freeze_btn == null or freeze_label == null:
		return

	var lefts := _get_freeze_cooldowns_left_list()
	if lefts.is_empty():
		freeze_btn.disabled = false
		freeze_label.text = "Gel"
		return

	var has_ready := false
	for l in lefts:
		if l <= 0.0:
			has_ready = true
			break

	freeze_btn.disabled = not has_ready

	if lefts.size() == 1:
		var l0 := lefts[0]
		if l0 > 0.0:
			freeze_label.text = "Gel (%.0fs)" % ceil(l0)
		else:
			freeze_label.text = "Gel"
	else:
		var lines: Array[String] = []
		for i in lefts.size():
			var l := lefts[i]
			if l > 0.0:
				lines.append("Gel %d (%.0fs)" % [i + 1, ceil(l)])
			else:
				lines.append("Gel %d" % [i + 1])
		freeze_label.text = "\n".join(lines)


# =========================================================
#           OPTIONS MENU : implémentation réelle
# =========================================================
func _init_options_menu() -> void:
	# Le HUD doit continuer à recevoir les clics même si get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Panneau
	if options_panel:
		_panel_open_pos = options_panel.position
		_panel_closed_pos = _panel_open_pos + Vector2(0, options_slide_px)
		options_panel.visible = false
		options_panel.position = _panel_closed_pos

		# IMPORTANT : éviter que les Labels/TextureRect décoratifs mangent les clics
		_options_fix_mouse_filters()

		# Les UI doivent tourner pendant pause
		_set_process_mode_recursive(options_panel, Node.PROCESS_MODE_ALWAYS)
	else:
		push_warning("[HUD/OPTIONS] options_panel introuvable (options_panel_path)")

	# Bouton ouverture
	if option_btn:
		option_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		if not option_btn.pressed.is_connected(_on_option_pressed):
			option_btn.pressed.connect(_on_option_pressed)
	else:
		push_warning("[HUD/OPTIONS] optionBtn introuvable (option_btn_path)")

	# Reprendre
	if play_btn:
		play_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		if not play_btn.pressed.is_connected(_on_options_play_pressed):
			play_btn.pressed.connect(_on_options_play_pressed)
	else:
		push_warning("[HUD/OPTIONS] playBtn introuvable (play_btn_path)")

	# Quitter
	if exit_btn:
		exit_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		if not exit_btn.pressed.is_connected(_on_options_exit_pressed):
			exit_btn.pressed.connect(_on_options_exit_pressed)
	else:
		push_warning("[HUD/OPTIONS] exitBtn introuvable (exit_btn_path)")

	# Toggle musique
	if music_btn:
		music_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		if not music_btn.pressed.is_connected(_on_music_toggle_pressed):
			music_btn.pressed.connect(_on_music_toggle_pressed)
	else:
		push_warning("[HUD/OPTIONS] musicBtn introuvable (music_btn_path)")

	# Toggles vitesse
	if speed_x1_btn:
		speed_x1_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		if not speed_x1_btn.pressed.is_connected(_on_speed_x1_pressed):
			speed_x1_btn.pressed.connect(_on_speed_x1_pressed)

	if speed_x2_btn:
		speed_x2_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		if not speed_x2_btn.pressed.is_connected(_on_speed_x2_pressed):
			speed_x2_btn.pressed.connect(_on_speed_x2_pressed)

	if speed_x4_btn:
		speed_x4_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		if not speed_x4_btn.pressed.is_connected(_on_speed_x4_pressed):
			speed_x4_btn.pressed.connect(_on_speed_x4_pressed)

	# ✅ Trouver la musique + la laisser active pendant pause
	_music_player = _find_music_player()
	if _music_player:
		_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
		_music_player.stream_paused = false
	else:
		push_warning("[HUD/OPTIONS] Aucun AudioStreamPlayer trouvé (music toggle visuel OK, mais pas d'effet).")

	# Sync initial réel
	_music_on = true
	# si tu passes au mode BUS, tu peux lire l’état du bus ici, sinon laisse true

	# vitesse initiale
	_speed_mult = Engine.time_scale
	if _speed_mult <= 0.0:
		_speed_mult = 1.0
		Engine.time_scale = 1.0

	_refresh_options_toggles()


func _on_option_pressed() -> void:
	if _options_open:
		_close_options()
	else:
		_open_options()


func _open_options() -> void:
	_options_open = true

	# Pause réelle
	get_tree().paused = true

	# Anim panneau (tween doit tourner en pause)
	if options_panel:
		options_panel.visible = true
		options_panel.position = _panel_closed_pos

		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.set_trans(Tween.TRANS_SINE)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(options_panel, "position", _panel_open_pos, options_open_duration)


func _close_options() -> void:
	_options_open = false

	# Anim fermeture (tween en pause)
	if options_panel:
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.set_trans(Tween.TRANS_SINE)
		tw.set_ease(Tween.EASE_IN)
		tw.tween_property(options_panel, "position", _panel_closed_pos, options_close_duration)
		tw.finished.connect(func():
			if options_panel:
				options_panel.visible = false
		)

	# Unpause
	get_tree().paused = false


func _on_options_play_pressed() -> void:
	_close_options()


func _on_options_exit_pressed() -> void:
	# On ferme proprement avant de changer de scène
	get_tree().paused = false
	Engine.time_scale = 1.0

	if main_menu_scene_path != "":
		get_tree().call_deferred("change_scene_to_file", main_menu_scene_path)
	else:
		push_warning("[HUD/OPTIONS] main_menu_scene_path est vide.")


func _on_music_toggle_pressed() -> void:
	_music_on = not _music_on
	_apply_music_state()
	_refresh_options_toggles()


var _music_volume_db_before_mute := 0.0

func _apply_music_state() -> void:
	var idx := AudioServer.get_bus_index(music_bus_name)
	if idx == -1:
		# fallback si tu n’as pas de bus "Music"
		idx = AudioServer.get_bus_index(&"Master")
	if idx == -1:
		return

	AudioServer.set_bus_mute(idx, not _music_on)

	# On mémorise le volume actuel la première fois qu'on mute
	if not _music_on:
		_music_volume_db_before_mute = _music_player.volume_db
		_music_player.volume_db = -80.0
	else:
		_music_player.volume_db = _music_volume_db_before_mute


func _set_speed_multiplier(mult: float) -> void:
	_speed_mult = mult
	Engine.time_scale = mult
	_refresh_options_toggles()


func _refresh_options_toggles() -> void:
	_set_toggle_texture(music_btn, _music_on)
	_set_toggle_texture(speed_x1_btn, is_equal_approx(_speed_mult, 1.0))
	_set_toggle_texture(speed_x2_btn, is_equal_approx(_speed_mult, 2.0))
	_set_toggle_texture(speed_x4_btn, is_equal_approx(_speed_mult, 4.0))


func _set_toggle_texture(btn: TextureButton, on: bool) -> void:
	if btn == null:
		return
	if toggle_empty_tex == null or toggle_full_tex == null:
		# On ne casse pas le jeu si tu n'as pas encore assigné les textures.
		return

	var tex := toggle_full_tex if on else toggle_empty_tex
	btn.texture_normal = tex
	btn.texture_pressed = tex
	btn.texture_hover = tex
	btn.texture_disabled = tex


func _find_music_player() -> AudioStreamPlayer:
	# 1) On cherche un player qui autoplay (heuristique : playing dès le start)
	# 2) Sinon on prend le premier AudioStreamPlayer trouvé
	var candidates: Array[AudioStreamPlayer] = []

	var root := get_tree().current_scene
	if root == null:
		return null

	_collect_audio_players(root, candidates)
	if candidates.is_empty():
		return null

	# Priorité : celui qui joue déjà
	for p in candidates:
		if is_instance_valid(p) and p.playing:
			return p

	# Sinon le premier
	return candidates[0]


func _collect_audio_players(n: Node, out: Array[AudioStreamPlayer]) -> void:
	if n is AudioStreamPlayer:
		out.append(n as AudioStreamPlayer)
	for c in n.get_children():
		_collect_audio_players(c, out)

func _set_process_mode_recursive(n: Node, mode: int) -> void:
	if n == null: return
	n.process_mode = mode
	for c in n.get_children():
		_set_process_mode_recursive(c, mode)


func _options_fix_mouse_filters() -> void:
	if options_panel == null:
		return

	# Le panel bloque les clics vers le jeu derrière
	options_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Mais tous les éléments décoratifs (Labels, TextureRect, etc) doivent IGNORER la souris
	_fix_mouse_filter_recursive(options_panel)
	

func _fix_mouse_filter_recursive(n: Node) -> void:
	for c in n.get_children():
		if c is Control:
			# On laisse les vrais boutons actifs
			if c is BaseButton:
				(c as Control).mouse_filter = Control.MOUSE_FILTER_STOP
			else:
				(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

		_fix_mouse_filter_recursive(c)
		
		
func _on_speed_x1_pressed() -> void:
	_set_speed_multiplier(1.0)

func _on_speed_x2_pressed() -> void:
	_set_speed_multiplier(2.0)

func _on_speed_x4_pressed() -> void:
	_set_speed_multiplier(4.0)
