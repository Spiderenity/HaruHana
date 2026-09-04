extends RefCounted
class_name AISettings

const SETTINGS_PATH := "user://settings/ai.json"

const DEFAULT_MODEL := "openrouter::openrouter/free"

const MODEL_PRESETS: Array[Dictionary] = [
	{"label": "GPT-5.1 · OpenAI", "route": "openai::gpt-5.1", "provider": "openai"},
	{"label": "Claude Sonnet 5 · Anthropic", "route": "anthropic::claude-sonnet-5", "provider": "anthropic"},
	{"label": "Gemini 3.7 Flash · Google", "route": "google::gemini-3.7-flash", "provider": "google"},
	{"label": "DeepSeek V4 Flash · DeepSeek", "route": "deepseek::deepseek-v4-flash", "provider": "deepseek"},
	{"label": "OpenRouter Free", "route": "openrouter::openrouter/free", "provider": "openrouter"},
]

static func load_settings() -> Dictionary:
	var defaults := {
		"api_key": "",
		"model": DEFAULT_MODEL,
	}
	var loaded: Dictionary = JsonStore.load_dictionary(SETTINGS_PATH, defaults)
	return {
		"api_key": str(loaded.get("api_key", "")),
		"model": str(loaded.get("model", DEFAULT_MODEL)),
	}

static func save_settings(
	api_key: String,
	model: String
) -> Error:
	model = model.strip_edges()
	if model.is_empty():
		model = DEFAULT_MODEL
	return JsonStore.save_json(
		SETTINGS_PATH,
		{
			"api_key": api_key.strip_edges(),
			"model": model,
		}
	)

static func get_api_key() -> String:
	return str(
		load_settings().get(
			"api_key",
			""
		)
	)

static func get_model() -> String:
	return str(
		load_settings().get(
			"model",
			DEFAULT_MODEL
		)
	)
