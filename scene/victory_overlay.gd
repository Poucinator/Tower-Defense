# res://ui/overlays/VictoryOverlay.gd
extends CanvasLayer

signal continue_pressed          # Reprendre le niveau en cours (fermer VictoryOverlay)
signal menu_pressed              # Optionnel (si tu écoutes côté parent)
signal quit_pressed              # Optionnel (si tu écoutes côté parent)

# =========================================================
#                 CONFIG (scènes)
# =========================================================
@export_file("*.tscn") var main_menu_scene_path: String
@export_file("*.tscn") var labo_ui_scene_path: String   # "niveau suivant" -> LaboUI

# ✅ Fix régression : gèle vraiment le temps quand le VictoryOverlay est ouvert
@export var freeze_time_scale_when_open: bool = true

var _saved_time_scale: float = 1.0
var _time_scale_frozen: bool = false

# =========================================================
#                 UI (boutons principaux)
# =========================================================
@onready var crystal_label: Label = $"CrystalLabel"
@onready var continue_btn: BaseButton = $"ContinueBtn"
@onready var menu_btn: BaseButton = $"MenuBtn"
@onready var quit_btn: BaseButton = $"QuitBtn"

# =========================================================
#                 Confirm overlays
# =========================================================
@onready var next_level_overlay: Control = get_node_or_null("NextLevelOverlay")
@onready var exit_to_menu_overlay: Control = get_node_or_null("ExittomenuOverlay")

@onready var next_confirm_btn: BaseButton = get_node_or_null("NextLevelOverlay/NextConfirmBtn")
@onready var next_cancel_btn: BaseButton = get_node_or_null("NextLevelOverlay/NextCancelBtn")

@onready var exit_confirm_btn: BaseButton = get_node_or_null("ExittomenuOverlay/ExitConfirmBtn")
@onready var exit_cancel_btn: BaseButton = get_node_or_null("ExittomenuOverlay/ExitCancelBtn")

func _ready() -> void:
	# UI cliquable même si le jeu est en pause
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Overlays fermés par défaut
	_set_overlay_visible(next_level_overlay, false)
	_set_overlay_visible(exit_to_menu_overlay, false)

	# Boutons principaux
	if continue_btn:
		continue_btn.pressed.connect(_on_continue_pressed)
	else:
		push_warning("[VictoryOverlay] ContinueBtn introuvable")

	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)
	else:
		push_warning("[VictoryOverlay] MenuBtn introuvable")

	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)
	else:
		push_warning("[VictoryOverlay] QuitBtn introuvable")

	# Confirm overlay : Next level (LaboUI)
	if next_confirm_btn:
		next_confirm_btn.pressed.connect(_on_next_confirm_pressed)
	else:
		push_warning("[VictoryOverlay] NextConfirmBtn introuvable (NextLevelOverlay/NextConfirmBtn)")

	if next_cancel_btn:
		next_cancel_btn.pressed.connect(_on_next_cancel_pressed)
	else:
		push_warning("[VictoryOverlay] NextCancelBtn introuvable (NextLevelOverlay/NextCancelBtn)")

	# Confirm overlay : Exit to main menu
	if exit_confirm_btn:
		exit_confirm_btn.pressed.connect(_on_exit_confirm_pressed)
	else:
		push_warning("[VictoryOverlay] ExitConfirmBtn introuvable (ExittomenuOverlay/ExitConfirmBtn)")

	if exit_cancel_btn:
		exit_cancel_btn.pressed.connect(_on_exit_cancel_pressed)
	else:
		push_warning("[VictoryOverlay] ExitCancelBtn introuvable (ExittomenuOverlay/ExitCancelBtn)")

	# Si jamais tu l’as laissé visible dans l’éditeur, on applique l’état
	if visible:
		_freeze_time_scale()

func _exit_tree() -> void:
	# Sécurité : si la scène est quittée alors que le time_scale est figé, on restaure
	_restore_time_scale_if_needed()

# =========================================================
#                 API explicite (à appeler depuis le parent)
# =========================================================
func show_victory() -> void:
	visible = true
	_close_all_confirms()
	_freeze_time_scale()

func hide_victory() -> void:
	_close_all_confirms()
	visible = false
	_restore_time_scale_if_needed()

# =========================================================
#                 Time freeze (fix régression)
# =========================================================
func _freeze_time_scale() -> void:
	if not freeze_time_scale_when_open:
		return
	if _time_scale_frozen:
		return
	_saved_time_scale = Engine.time_scale
	Engine.time_scale = 0.0
	_time_scale_frozen = true

func _restore_time_scale_if_needed() -> void:
	if not _time_scale_frozen:
		return
	Engine.time_scale = _saved_time_scale
	_time_scale_frozen = false

# =========================================================
#                 Public API
# =========================================================
func set_crystals(amount: int) -> void:
	if crystal_label:
		crystal_label.text = "Cristaux récupérés : %d" % amount
	else:
		push_warning("[VictoryOverlay] CrystalLabel introuvable")

# =========================================================
#                 Boutons principaux
# =========================================================
func _on_continue_pressed() -> void:
	# Reprendre le niveau en cours
	hide_victory()
	emit_signal("continue_pressed")

func _on_menu_pressed() -> void:
	# "Niveau suivant" => confirmation puis LaboUI
	_open_next_level_overlay()

func _on_quit_pressed() -> void:
	# Quit => confirmation puis retour menu principal
	_open_exit_to_menu_overlay()

# =========================================================
#                 NextLevelOverlay -> LaboUI
# =========================================================
func _open_next_level_overlay() -> void:
	_set_overlay_visible(exit_to_menu_overlay, false)

	if not next_level_overlay:
		push_warning("[VictoryOverlay] NextLevelOverlay introuvable")
		return

	_set_overlay_visible(next_level_overlay, true)
	if next_confirm_btn:
		next_confirm_btn.grab_focus()

func _on_next_confirm_pressed() -> void:
	_set_overlay_visible(next_level_overlay, false)
	emit_signal("menu_pressed")

	if labo_ui_scene_path.is_empty():
		push_warning("[VictoryOverlay] labo_ui_scene_path vide : assigne la scène LaboUI dans l’inspecteur")
		return

	_restore_time_scale_if_needed()
	get_tree().paused = false
	get_tree().change_scene_to_file(labo_ui_scene_path)

func _on_next_cancel_pressed() -> void:
	_set_overlay_visible(next_level_overlay, false)
	if menu_btn:
		menu_btn.grab_focus()

# =========================================================
#                 ExittomenuOverlay -> Main menu
# =========================================================
func _open_exit_to_menu_overlay() -> void:
	_set_overlay_visible(next_level_overlay, false)

	if not exit_to_menu_overlay:
		push_warning("[VictoryOverlay] ExittomenuOverlay introuvable")
		return

	_set_overlay_visible(exit_to_menu_overlay, true)
	if exit_confirm_btn:
		exit_confirm_btn.grab_focus()

func _on_exit_confirm_pressed() -> void:
	_set_overlay_visible(exit_to_menu_overlay, false)
	emit_signal("quit_pressed")

	if main_menu_scene_path.is_empty():
		push_warning("[VictoryOverlay] main_menu_scene_path vide : assigne la scène menu principal dans l’inspecteur")
		return

	_restore_time_scale_if_needed()
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene_path)

func _on_exit_cancel_pressed() -> void:
	_set_overlay_visible(exit_to_menu_overlay, false)
	if quit_btn:
		quit_btn.grab_focus()

# =========================================================
#                 Helpers
# =========================================================
func _close_all_confirms() -> void:
	_set_overlay_visible(next_level_overlay, false)
	_set_overlay_visible(exit_to_menu_overlay, false)

func _set_overlay_visible(overlay: CanvasItem, visible_now: bool) -> void:
	if overlay:
		overlay.visible = visible_now
