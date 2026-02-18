extends Resource
class_name MarineVoiceBank

@export var select_lines: Array[String] = []
@export var move_lines: Array[String] = []
@export var spam_select_lines: Array[String] = []

@export_range(0.5, 10.0, 0.1) var display_duration := 3.0
@export var y_offset := -28.0
