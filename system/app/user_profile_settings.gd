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

static func replace_user_name_placeholder(text: String, user_name: String) -> String:
	var clean_name: String = user_name.strip_edges()
	if clean_name.is_empty():
		return text.replace("{user_name}", "")

	var has_final: bool = _has_final_consonant(clean_name)
	var ends_with_rieul: bool = _ends_with_rieul(clean_name)
	var particle_pairs: Array = [
		["이라고", "라고"],
		["이에요", "예요"],
		["이랑", "랑"],
		["으로", "로"],
		["은", "는"],
		["이", "가"],
		["을", "를"],
		["과", "와"],
		["아", "야"],
	]
	var result: String = text
	for pair_value: Variant in particle_pairs:
		var pair: Array = pair_value as Array
		var final_form: String = str(pair[0])
		var vowel_form: String = str(pair[1])
		var use_final_form: bool = has_final
		if final_form == "으로" and ends_with_rieul:
			use_final_form = false
		var resolved_particle: String = final_form if use_final_form else vowel_form
		result = result.replace(
			"{user_name}" + final_form,
			clean_name + resolved_particle
		)
		result = result.replace(
			"{user_name}" + vowel_form,
			clean_name + resolved_particle
		)
	return result.replace("{user_name}", clean_name)

static func _has_final_consonant(text: String) -> bool:
	var codepoint: int = _last_hangul_syllable(text)
	return codepoint >= 0 and (codepoint - 0xAC00) % 28 != 0

static func _ends_with_rieul(text: String) -> bool:
	var codepoint: int = _last_hangul_syllable(text)
	return codepoint >= 0 and (codepoint - 0xAC00) % 28 == 8

static func _last_hangul_syllable(text: String) -> int:
	for index: int in range(text.length() - 1, -1, -1):
		var codepoint: int = text.unicode_at(index)
		if codepoint >= 0xAC00 and codepoint <= 0xD7A3:
			return codepoint
	return -1

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
