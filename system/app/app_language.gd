extends RefCounted
class_name AppLanguage

const SETTINGS_PATH: String = "user://settings/interface.json"
const DEFAULT_LANGUAGE: String = "ko"
static var _cached_language := ""
static var _cache_checked_msec := -2000
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
	var now := Time.get_ticks_msec()
	if not _cached_language.is_empty() and now - _cache_checked_msec < 1000:
		return _cached_language
	_cache_checked_msec = now
	var settings: Dictionary = JsonStore.load_dictionary(
		SETTINGS_PATH,
		{"language": DEFAULT_LANGUAGE}
	)
	var language: String = normalize_language(
		str(settings.get("language", DEFAULT_LANGUAGE))
	)
	if not SUPPORTED_LANGUAGES.has(language):
		language = DEFAULT_LANGUAGE
	_cached_language = language
	return _cached_language

static func set_language(
	language: String
) -> Error:
	language = normalize_language(language)
	if not SUPPORTED_LANGUAGES.has(language):
		return ERR_INVALID_PARAMETER
	var error := JsonStore.save_json(
		SETTINGS_PATH,
		{"language": language}
	)
	if error == OK:
		_cached_language = language
		_cache_checked_msec = Time.get_ticks_msec()
	return error

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
