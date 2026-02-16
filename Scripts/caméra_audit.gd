# res://debug/camera_audit.gd
extends Node
class_name CameraAudit

@export var print_every_seconds: float = 0.0 # 0 = uniquement au démarrage + changement de current

var _last_current: Camera2D = null
var _timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_dump", "READY (deferred)")

func _process(delta: float) -> void:
	var current: Camera2D = get_viewport().get_camera_2d()

	if current != _last_current:
		_last_current = current
		_dump("CURRENT CHANGED")

	if print_every_seconds > 0.0:
		_timer += delta
		if _timer >= print_every_seconds:
			_timer = 0.0
			_dump("TICK")

func _dump(reason: String) -> void:
	print("\n================ CAMERA AUDIT ================")
	print("[AUDIT] reason=", reason)

	var cur: Camera2D = get_viewport().get_camera_2d()
	if cur:
		print("[AUDIT] viewport current =", cur.name, " path=", cur.get_path())
	else:
		print("[AUDIT] viewport current = null")

	var cams: Array[Camera2D] = _collect_cameras(get_tree().root)

	print("[AUDIT] total Camera2D found =", cams.size())
	for c in cams:
		var tag_current := ""
		if c == cur:
			tag_current = "[CURRENT] "

		var tag_group := ""
		if c.is_in_group("player_camera"):
			tag_group = "[player_camera] "

		print(
			" - ",
			tag_current, tag_group, c.name,
			" enabled=", c.enabled,
			" zoom=", c.zoom,
			" offset=", c.offset,
			" anchor_mode=", c.anchor_mode,
			" path=", c.get_path()
		)

	print("================================================\n")

func _collect_cameras(node: Node) -> Array[Camera2D]:
	var res: Array[Camera2D] = []
	if node is Camera2D:
		res.append(node as Camera2D)

	for child in node.get_children():
		if child is Node:
			res.append_array(_collect_cameras(child))
	return res
