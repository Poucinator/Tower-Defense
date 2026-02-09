extends Resource
class_name UpgradeTexts

# key: StringName  ->  value: UpgradeInfo
@export var entries: Dictionary = {}

func get_info(key: StringName) -> UpgradeInfo:
	# Supporte aussi le cas où la clé est stockée en String (dans l’inspecteur)
	if entries.has(key):
		return entries[key] as UpgradeInfo

	var s := String(key)
	if entries.has(s):
		return entries[s] as UpgradeInfo

	return null
