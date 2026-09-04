extends RefCounted
class_name UserProfileSettings

const SETTINGS_PATH: String = "user://settings/user_profile.json"
const DEFAULT_NAME: String = ""

static func load_settings() -> Dictionary:
	var settings: Dictionary = JsonStore.load_dictionary(
		SETTINGS_PATH,
		{"name": DEFAULT_NAME}
	)
	settings["name"] = str(settings.get("name", DEFAULT_NAME)).strip_edges()
	return settings

static func save_settings(settings: Dictionary) -> Error:
	var current: Dictionary = load_settings()
	for key: Variant in settings.keys():
		current[key] = settings[key]
	current["name"] = str(current.get("name", DEFAULT_NAME)).strip_edges()
	return JsonStore.save_json(SETTINGS_PATH, current)

static func get_user_name() -> String:
	return str(load_settings().get("name", DEFAULT_NAME)).strip_edges()

static func set_user_name(user_name: String) -> Error:
	return save_settings({"name": user_name.strip_edges()})

static func get_prompt_context() -> Dictionary:
	var user_name: String = get_user_name()

	if user_name.is_empty():
		return {
			"name_known": false,
			"instruction": "The user's preferred name has not been provided yet."
		}

	return {
		"name": user_name,
		"name_known": true,
		"instruction": "Use the user's name naturally when appropriate, but do not overuse it."
	}
