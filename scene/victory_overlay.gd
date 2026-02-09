extends CanvasLayer

signal continue_pressed
signal menu_pressed
signal quit_pressed

@onready var crystal_label: Label = $"CrystalLabel"
@onready var continue_btn: BaseButton = $"ContinueBtn"
@onready var menu_btn: BaseButton = $"MenuBtn"
@onready var quit_btn: BaseButton = $"QuitBtn"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

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

func set_crystals(amount: int) -> void:
	if crystal_label:
		crystal_label.text = "Cristaux récupérés : %d" % amount
	else:
		push_warning("[VictoryOverlay] CrystalLabel introuvable")

func _on_continue_pressed() -> void:
	emit_signal("continue_pressed")

func _on_menu_pressed() -> void:
	emit_signal("menu_pressed")

func _on_quit_pressed() -> void:
	emit_signal("quit_pressed")
