extends RefCounted
class_name AppLanguage

const SETTINGS_PATH: String = "user://settings/interface.json"
const DEFAULT_LANGUAGE: String = "ko"
const SUPPORTED_LANGUAGES: Array[String] = [
	"en",
	"ko",
]

static func normalize_language(
	value: String
) -> String:
	var language: String = value.strip_edges().to_lower().replace("_", "-")

	if language.begins_with("ko"):
		return "ko"

	if language.begins_with("en"):
		return "en"

	if language.begins_with("ja"):
		return "ja"

	if language.begins_with("zh"):
		return "zh"

	if language.begins_with("fr"):
		return "fr"

	if language.begins_with("de"):
		return "de"

	if language.begins_with("es"):
		return "es"

	return language

static func get_language() -> String:
	var settings: Dictionary = JsonStore.load_dictionary(
		SETTINGS_PATH,
		{"language": DEFAULT_LANGUAGE}
	)
	var language: String = normalize_language(
		str(settings.get("language", DEFAULT_LANGUAGE))
	)
	if not SUPPORTED_LANGUAGES.has(language):
		return DEFAULT_LANGUAGE
	return language

static func set_language(
	language: String
) -> Error:
	language = normalize_language(language)
	if not SUPPORTED_LANGUAGES.has(language):
		return ERR_INVALID_PARAMETER
	return JsonStore.save_json(
		SETTINGS_PATH,
		{"language": language}
	)

static func text(
	english: String,
	korean: String
) -> String:
	if get_language() == "ko":
		return korean

	return english

static func get_prompt_language_name(
	language: String
) -> String:
	match normalize_language(language):
		"ko":
			return "Korean"
		"en":
			return "English"
		"ja":
			return "Japanese"
		"zh":
			return "Chinese"
		"fr":
			return "French"
		"de":
			return "German"
		"es":
			return "Spanish"
		_:
			return "language code " + language
