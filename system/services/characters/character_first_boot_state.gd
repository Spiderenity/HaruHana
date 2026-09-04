extends RefCounted
class_name CharacterFirstBootState

const SETTINGS_PATH: String = "user://settings/character_first_boot.json"

static func _load() -> Dictionary:
	return JsonStore.load_dictionary(SETTINGS_PATH, {"completed": []})

static func _key(pack_id: String, character_id: String) -> String:
	return pack_id.strip_edges().to_lower() + ":" + character_id.strip_edges().to_lower()

static func has_completed(pack_id: String, character_id: String) -> bool:
	var settings: Dictionary = _load()
	var completed_value: Variant = settings.get("completed", [])

	if not (completed_value is Array):
		return false

	return (completed_value as Array).has(_key(pack_id, character_id))

static func mark_completed(pack_id: String, character_id: String) -> Error:
	var settings: Dictionary = _load()
	var completed: Array = []
	var completed_value: Variant = settings.get("completed", [])
	if completed_value is Array:
		completed = (completed_value as Array).duplicate()
	var key: String = _key(pack_id, character_id)
	if not completed.has(key):
		completed.append(key)
	return JsonStore.save_json(SETTINGS_PATH, {"completed": completed})

