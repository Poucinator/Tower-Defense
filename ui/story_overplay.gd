extends CanvasLayer

signal sequence_finished(id: String)

var panel: Control = null
var img: TextureRect = null
var caption: Label = null
var next_btn: Button = null
var skip_btn: Button = null

var _slides: Array = []   # [{texture: Texture2D, text: String}, ...]
var _index: int = 0
var _sequence_id: String = ""

func _ready() -> void:
	add_to_group("StoryOverPlay")  # pour que le StoryDirector puisse nous retrouver

	# 1) Récupérer/Construire l'UI
	panel = get_node_or_null("Panel") as Control
	if panel == null:
		print("[OverPlay] Panel introuvable, construction de l'UI…")
		_build_ui()
		panel = $"Panel" as Control

	# 2) Récupérer les sous-nœuds
	img      = $"Panel/TextureRect" as TextureRect
	caption  = $"Panel/Caption" as Label
	next_btn = $"Panel/HBoxContainer/NextBtn" as Button
	skip_btn = $"Panel/HBoxContainer/SkipBtn" as Button

	# 3) Vérifications
	if img == null or caption == null or next_btn == null or skip_btn == null:
		push_error("[OverPlay] Structure invalide : il faut Panel/TextureRect, Panel/Caption, Panel/HBoxContainer/NextBtn et SkipBtn.")
		return

	# 4) Paramétrage
	visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	next_btn.pressed.connect(_on_next)
	skip_btn.pressed.connect(_on_skip)
	set_process_unhandled_input(true)

func play_sequence(sequence_id: String, slides: Array) -> void:
	# Sécurité : ne joue pas si l'UI est incomplète
	if img == null or caption == null:
		push_error("[OverPlay] Impossible de jouer la séquence : TextureRect ou Caption manquant.")
		return

	print("[OverPlay] PLAY id=", sequence_id, " slides=", slides.size())
	_sequence_id = sequence_id
	_slides = slides.duplicate(true)
	_index = -1
	visible = true
	_on_next()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_next()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_on_next()
		elif event.keycode == KEY_ESCAPE:
			_on_skip()

func _on_next() -> void:
	if _slides.is_empty():
		_finish()
		return

	_index += 1
	if _index >= _slides.size():
		_finish()
		return

	var s: Dictionary = _slides[_index]   # ← TYPAGE explicite
	var tex: Texture2D = s.get("texture", null) as Texture2D
	var txt: String = s.get("text", "") as String

	if img == null or caption == null:
		push_error("[OverPlay] img/caption null pendant _on_next() — structure UI incorrecte.")
		_finish()
		return

	img.texture = tex
	caption.text = txt


func _on_skip() -> void:
	_finish()

func _finish() -> void:
	visible = false
	emit_signal("sequence_finished", _sequence_id)

# Construit l’UI si elle n’existe pas dans la scène
func _build_ui() -> void:
	var p := Panel.new()
	p.name = "Panel"
	add_child(p)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)

	var tr := TextureRect.new()
	tr.name = "TextureRect"
	# un réglage visuel raisonnable
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.offset_top = 16
	tr.offset_bottom = -80
	p.add_child(tr)

	var lb := Label.new()
	lb.name = "Caption"
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lb.offset_left = 24
	lb.offset_right = -24
	lb.offset_bottom = -40
	p.add_child(lb)

	var hb := HBoxContainer.new()
	hb.name = "HBoxContainer"
	hb.alignment = BoxContainer.ALIGNMENT_END
	p.add_child(hb)
	hb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hb.offset_right = -16
	hb.offset_bottom = -12

	var next := Button.new()
	next.name = "NextBtn"
	next.text = "Suivant"
	hb.add_child(next)

	var skip := Button.new()
	skip.name = "SkipBtn"
	skip.text = "Passer"
	hb.add_child(skip)
