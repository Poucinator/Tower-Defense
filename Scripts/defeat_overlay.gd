extends CanvasLayer

signal continue_pressed
signal menu_pressed
signal quit_pressed

@onready var continue_btn: BaseButton = $"ContinueBtn"
@onready var menu_btn: BaseButton = $"MenuBtn"
@onready var quit_btn: BaseButton = $"QuitBtn"

func _ready() -> void:
	# Important : si tu pauses le jeu, l'overlay doit continuer à fonctionner
	process_mode = Node.PROCESS_MODE_ALWAYS

	if continue_btn:
		continue_btn.pressed.connect(_on_continue_pressed)
	else:
		push_warning("[DefeatOverlay] ContinueBtn introuvable")

	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)
	else:
		push_warning("[DefeatOverlay] MenuBtn introuvable")

	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)
	else:
		push_warning("[DefeatOverlay] QuitBtn introuvable")

func _on_continue_pressed() -> void:
	emit_signal("continue_pressed")

func _on_menu_pressed() -> void:
	emit_signal("menu_pressed")

func _on_quit_pressed() -> void:
	emit_signal("quit_pressed")
