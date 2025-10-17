extends CanvasLayer

# --- Références UI (haut) ---
@onready var gold_label:       Label          = $"HBoxContainer/GoldLabel"
@onready var health_label:     Label          = $"HBoxContainer/HealthLabel"
@onready var build_btn:        TextureButton  = $"HBoxContainer/BuildBlueBtn"
@onready var build_snipe_btn:  TextureButton  = $"HBoxContainer/BuildSnipeBtn"
@onready var build_missile_btn: TextureButton = $"HBoxContainer/BuildMissileBtn"
@onready var build_barracks_btn: TextureButton = $"HBoxContainer/BuildBarracksBtn"

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

# --- Lien vers contrôleurs externes ---
@export var power_controller_path: NodePath
@export var build_controller_path: NodePath
@export var spawner_path:          NodePath
var powers: Node = null
var build:   Node = null
var spawner: Node = null

# --- États locaux ---
var _last_left: float = 0.0

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

	# Bouton "Prochaine vague"
	if next_btn:
		next_btn.visible = false
		next_btn.disabled = true
		next_btn.pressed.connect(_on_next_wave_pressed)

	# Spawner initial
	var initial_spawner := get_node_or_null(spawner_path)
	if initial_spawner:
		set_spawner(initial_spawner)

	timer_label.text = ""

	# Pouvoirs
	powers = get_node_or_null(power_controller_path)
	if freeze_btn: freeze_btn.pressed.connect(_on_freeze_pressed)
	if heal_btn:   heal_btn.pressed.connect(_on_heal_pressed)
	if summon_btn: summon_btn.pressed.connect(_on_summon_pressed)

	if powers and powers.has_method("set_freeze_cooldown"):
		powers.call("set_freeze_cooldown", 10.0)
	if powers and powers.has_method("set_heal_cooldown"):
		powers.call("set_heal_cooldown", 20.0)
	if powers and powers.has_method("set_summon_cooldown"):
		powers.call("set_summon_cooldown", 25.0)

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
		# prendre la valeur live du spawner si dispo
		if spawner and spawner.has_method("get_countdown_left"):
			left = float(spawner.call("get_countdown_left"))
		else:
			left = _last_left

	next_btn.visible  = can_skip
	next_btn.disabled = not can_skip
	var reward := int(ceil(max(left, 0.0)))
	next_btn.text = "Lancer (+" + str(reward) + " PO)"

func _on_next_wave_pressed() -> void:
	# 🔹 Cas 1 : compte à rebours du LevelDirector (inter-vague)
	if _director_cd_active:
		# l’award est géré coté LevelDirector pour éviter les doubles crédits
		next_btn.disabled = true
		emit_signal("next_clicked")
		return

	# 🔹 Cas 2 : compte à rebours d’un Spawner (intra-vague)
	if spawner and spawner.has_method("is_countdown_running") and spawner.call("is_countdown_running"):
		var left := 0.0
		if spawner.has_method("get_countdown_left"):
			left = float(spawner.call("get_countdown_left"))
		else:
			left = _last_left
		var reward := int(ceil(max(left, 0.0)))
		if reward > 0 and "add_gold" in Game:
			Game.add_gold(reward)
		if spawner.has_method("skip_countdown_and_start"):
			spawner.call("skip_countdown_and_start")
		next_btn.disabled = true

# =========================================================
#                   Pouvoirs
# =========================================================
func _process(_delta: float) -> void:
	# --- Pouvoir Gel ---
	if freeze_btn and freeze_label and powers and powers.has_method("get_freeze_cooldown_left"):
		var left := powers.call("get_freeze_cooldown_left") as float
		if left > 0.0:
			freeze_btn.disabled = true
			freeze_label.text = "Gel (%.0fs)" % ceil(left)
		else:
			freeze_btn.disabled = false
			freeze_label.text = "Gel"

	# --- Pouvoir Soin ---
	if heal_btn and heal_label and powers and powers.has_method("get_heal_cooldown_left"):
		var left := powers.call("get_heal_cooldown_left") as float
		if left > 0.0:
			heal_btn.disabled = true
			heal_label.text = "Soin (%.0fs)" % ceil(left)
		else:
			heal_btn.disabled = false
			heal_label.text = "Soin"

	# --- Pouvoir Appel tactique ---
	if summon_btn and summon_label and powers and powers.has_method("get_summon_cooldown_left"):
		var left := powers.call("get_summon_cooldown_left") as float
		if left > 0.0:
			summon_btn.disabled = true
			summon_label.text = "Appel (%.0fs)" % ceil(left)
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
