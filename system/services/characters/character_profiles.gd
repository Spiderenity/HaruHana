extends RefCounted
class_name CharacterProfiles

const AppLanguageScript = preload(
	"res://system/app/app_language.gd"
)

const UserProfileSettingsScript = preload(
	"res://system/app/user_profile_settings.gd"
)

const SETTINGS_PATH: String = (
	"user://settings/character_profiles.json"
)

const PACKS_FOLDER: String = (
	"res://characters"
)

const EXTERNAL_PACKS_FOLDER_NAME: String = "characters"

const DEFAULT_PACK_ID: String = "crt_chip"

static func normalize_pack_id(pack_id: String) -> String:
	return pack_id.strip_edges().to_lower()

static func _load_settings() -> Dictionary:
	return JsonStore.load_dictionary(SETTINGS_PATH, {})

static func get_current_pack() -> String:
	var settings: Dictionary = _load_settings()
	var current_pack: String = normalize_pack_id(
		str(settings.get("current_pack", ""))
	)

	if not current_pack.is_empty() and pack_exists(current_pack):
		return current_pack

	if pack_exists(DEFAULT_PACK_ID):
		return DEFAULT_PACK_ID

	var packs: Array = list_packs()
	if packs.is_empty():
		return ""

	var first_value: Variant = packs[0]
	if not (first_value is Dictionary):
		return ""

	return str(
		(first_value as Dictionary).get("id", "")
	).strip_edges()

static func set_current_pack(pack_id: String) -> Error:
	pack_id = normalize_pack_id(pack_id)

	if pack_id.is_empty() or not pack_exists(pack_id):
		return ERR_DOES_NOT_EXIST

	var settings: Dictionary = _load_settings()
	settings["current_pack"] = pack_id
	return _save_settings(settings)

static func validate_profiles(pack_id: String = "") -> Dictionary:
	pack_id = normalize_pack_id(pack_id)

	if pack_id.is_empty():
		pack_id = get_current_pack()

	var valid: Array[String] = []
	var invalid: Array[String] = []

	if pack_id.is_empty() or not pack_exists(pack_id):
		return {
			"valid": valid,
			"invalid": invalid,
		}

	for character_id: String in get_pack_character_ids(pack_id):
		var profile: Dictionary = _load_profile_for_pack(
			pack_id,
			character_id,
			false
		)

		if profile.is_empty():
			invalid.append(character_id)
		else:
			valid.append(character_id)

	return {
		"valid": valid,
		"invalid": invalid,
	}

static func _save_settings(settings: Dictionary) -> Error:
	return JsonStore.save_json(SETTINGS_PATH, settings)

static func get_pack_default_language(pack_id: String) -> String:
	var info: Dictionary = _find_pack_manifest(pack_id)
	if info.is_empty():
		return ""

	var manifest: Dictionary = info.get("manifest", {})
	var language: String = AppLanguageScript.normalize_language(
		str(manifest.get("default_language", ""))
	)
	return language

static func get_pack_supported_languages(pack_id: String) -> Array[String]:
	var result: Array[String] = []
	var info: Dictionary = _find_pack_manifest(pack_id)
	if info.is_empty():
		return result

	var manifest: Dictionary = info.get("manifest", {})
	var value: Variant = manifest.get("supported_languages", [])
	if not (value is Array):
		return result

	var languages: Array = value as Array
	for item: Variant in languages:
		var language: String = AppLanguageScript.normalize_language(str(item))
		if language.is_empty() or result.has(language):
			continue
		result.append(language)

	return result

static func get_pack_output_language(pack_id: String) -> String:
	pack_id = normalize_pack_id(pack_id)
	if pack_id.is_empty():
		pack_id = get_current_pack()

	var supported: Array[String] = get_pack_supported_languages(pack_id)
	var default_language: String = get_pack_default_language(pack_id)
	if default_language.is_empty() or not supported.has(default_language):
		return ""

	var interface_language: String = AppLanguageScript.normalize_language(
		AppLanguageScript.get_language()
	)
	if supported.has(interface_language):
		return interface_language

	return default_language

static func get_current_pack_output_language() -> String:
	return get_pack_output_language(get_current_pack())

static func load_pack_localized_json(
	pack_id: String,
	filename: String,
	report_errors: bool = false
) -> Dictionary:
	pack_id = normalize_pack_id(pack_id)
	filename = filename.strip_edges().replace("\\", "/")
	if pack_id.is_empty():
		pack_id = get_current_pack()
	if pack_id.is_empty() or not _is_safe_json_filename(filename):
		return {}

	var language: String = get_pack_output_language(pack_id)
	if language.is_empty():
		if report_errors:
			push_error("Character pack has no valid output language: " + pack_id)
		return {}

	var root_path: String = get_pack_root_path(pack_id)
	if root_path.is_empty():
		return {}

	return _load_json_dictionary(
		root_path.path_join("locales").path_join(language).path_join(filename),
		report_errors
	)

static func load_pack_json(
	pack_id: String,
	filename: String,
	report_errors: bool = false
) -> Dictionary:
	pack_id = normalize_pack_id(pack_id)
	filename = filename.strip_edges().replace("\\", "/")

	if pack_id.is_empty():
		pack_id = get_current_pack()

	if pack_id.is_empty() or not _is_safe_json_filename(filename):
		return {}

	var root_path: String = get_pack_root_path(pack_id)
	if root_path.is_empty():
		return {}

	return _load_json_dictionary(
		root_path.path_join(filename),
		report_errors
	)

static func get_external_characters_directory_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path(PACKS_FOLDER)

	var executable_path: String = OS.get_executable_path()
	var base_directory: String = executable_path.get_base_dir()

	if base_directory.is_empty():
		base_directory = ProjectSettings.globalize_path("res://")

	return base_directory.path_join(EXTERNAL_PACKS_FOLDER_NAME)

static func ensure_external_characters_directory() -> Error:
	var directory_path: String = get_external_characters_directory_path()
	var error: Error = DirAccess.make_dir_recursive_absolute(directory_path)

	if error == ERR_ALREADY_EXISTS:
		return OK

	return error

static func list_packs() -> Array:
	ensure_external_characters_directory()

	var result: Array = []
	var seen_ids: Dictionary = {}

	for info: Dictionary in _collect_pack_infos_from_root(
		PACKS_FOLDER,
		"bundled"
	):
		_append_pack_summary(result, seen_ids, info)

	var external_root: String = get_external_characters_directory_path()

	for info: Dictionary in _collect_pack_infos_from_root(
		external_root,
		"external"
	):
		_append_pack_summary(result, seen_ids, info)

	result.sort_custom(
		func(a: Variant, b: Variant) -> bool:
			return str((a as Dictionary).get("display_name", "")) < str(
				(b as Dictionary).get("display_name", "")
			)
	)
	return result

static func _append_pack_summary(
	result: Array,
	seen_ids: Dictionary,
	info: Dictionary
) -> void:
	var manifest_value: Variant = info.get("manifest", {})

	if not (manifest_value is Dictionary):
		return

	var manifest: Dictionary = manifest_value as Dictionary
	var directory_name: String = str(info.get("directory", "")).strip_edges()
	var pack_id: String = normalize_pack_id(
		str(manifest.get("id", directory_name))
	)

	if pack_id.is_empty() or seen_ids.has(pack_id):
		return

	seen_ids[pack_id] = true
	var characters_value: Variant = manifest.get("characters", [])
	var character_count: int = (
		(characters_value as Array).size()
		if characters_value is Array
		else 0
	)

	result.append({
		"id": pack_id,
		"directory": directory_name,
		"display_name": str(
			manifest.get("display_name", pack_id.capitalize())
		).strip_edges(),
		"description": str(manifest.get("description", "")).strip_edges(),
		"character_count": character_count,
		"source": str(info.get("source", "bundled")),
		"root_path": str(info.get("root_path", "")),
	})

static func _collect_pack_infos_from_root(
	root_path: String,
	source: String
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var root := DirAccess.open(root_path)

	if root == null:
		return result

	root.list_dir_begin()

	while true:
		var directory_name: String = root.get_next()

		if directory_name.is_empty():
			break

		if not root.current_is_dir() or directory_name.begins_with("."):
			continue

		var manifest: Dictionary = _load_pack_manifest_from_root(
			root_path,
			directory_name,
			false
		)

		if manifest.is_empty():
			continue

		result.append({
			"directory": directory_name,
			"manifest": manifest,
			"source": source,
			"root_path": root_path.path_join(directory_name),
		})

	root.list_dir_end()
	return result

static func pack_exists(pack_id: String) -> bool:
	return not _find_pack_manifest(pack_id).is_empty()

static func get_pack_root_path(pack_id: String) -> String:
	var info: Dictionary = _find_pack_manifest(pack_id)
	return str(info.get("root_path", "")).strip_edges()

static func get_pack_character_ids(pack_id: String) -> Array[String]:
	var result: Array[String] = []
	var info: Dictionary = _find_pack_manifest(pack_id)

	if info.is_empty():
		return result

	var manifest: Dictionary = info.get("manifest", {})
	var characters_value: Variant = manifest.get("characters", [])

	if not (characters_value is Array):
		return result

	for value: Variant in characters_value:
		if not (value is Dictionary):
			continue

		var character_id: String = str(
			(value as Dictionary).get("id", "")
		).strip_edges().to_lower()

		if character_id.is_empty() or result.has(character_id):
			continue

		result.append(character_id)

	return result

static func get_character_definition(
	pack_id: String,
	character_id: String
) -> Dictionary:
	character_id = character_id.strip_edges().to_lower()
	var info: Dictionary = _find_pack_manifest(pack_id)

	if info.is_empty() or character_id.is_empty():
		return {}

	var manifest: Dictionary = info.get("manifest", {})
	var characters_value: Variant = manifest.get("characters", [])

	if not (characters_value is Array):
		return {}

	for value: Variant in characters_value:
		if not (value is Dictionary):
			continue

		var definition: Dictionary = value as Dictionary
		if str(definition.get("id", "")).strip_edges().to_lower() == character_id:
			return definition.duplicate(true)

	return {}

static func get_pack_profile_filename(
	pack_id: String,
	character_id: String
) -> String:
	var definition: Dictionary = get_character_definition(
		pack_id,
		character_id
	)
	var filename: String = str(
		definition.get("profile_file", "")
	).strip_edges().replace("\\", "/")

	if not _is_safe_json_filename(filename):
		return ""

	return filename

static func get_character_dialogue_filename(
	pack_id: String,
	character_id: String
) -> String:
	var definition: Dictionary = get_character_definition(
		pack_id,
		character_id
	)
	var filename: String = str(
		definition.get("dialogue_file", "")
	).strip_edges().replace("\\", "/")

	if not _is_safe_json_filename(filename):
		return ""

	return filename

static func load_character_dialogue_data(
	character_id: String,
	report_errors: bool = false
) -> Dictionary:
	character_id = character_id.strip_edges().to_lower()

	if character_id.is_empty():
		return {}

	var pack_id: String = get_current_pack()
	if pack_id.is_empty() or not get_pack_character_ids(pack_id).has(character_id):
		return {}

	var filename: String = get_character_dialogue_filename(
		pack_id,
		character_id
	)
	if filename.is_empty():
		return {}

	return load_pack_localized_json(
		pack_id,
		filename,
		report_errors
	)

static func get_fallback_dialogue(
	character_id: String
) -> Dictionary:
	var dialogue_data: Dictionary = load_character_dialogue_data(
		character_id,
		false
	)
	var value: Variant = dialogue_data.get(
		"fallback_dialogue",
		{}
	)

	if value is Dictionary:
		return (value as Dictionary).duplicate(true)

	return {}

static func get_fallback_line(
	character_id: String,
	key: String,
	replacements: Dictionary = {}
) -> String:
	var fallback: Dictionary = get_fallback_dialogue(character_id)
	var lines_value: Variant = fallback.get(key, [])

	if not (lines_value is Array):
		return ""

	var lines: Array = lines_value as Array
	if lines.is_empty():
		return ""

	var result: String = str(
		lines[
			randi_range(
				0,
				lines.size() - 1
			)
		]
	)

	var resolved_replacements: Dictionary = replacements.duplicate()
	var user_name: String = str(
		resolved_replacements.get(
			"{user_name}",
			UserProfileSettingsScript.get_user_name()
		)
	).strip_edges()
	if user_name.is_empty():
		var output_language: String = get_pack_output_language(get_current_pack())
		user_name = "너" if output_language == "ko" else "you"
	resolved_replacements["{user_name}"] = user_name

	for replacement_key: Variant in resolved_replacements.keys():
		result = result.replace(
			str(replacement_key),
			str(resolved_replacements[replacement_key])
		)

	result = result.replace("\r", " ").replace("\n", " ").strip_edges()
	while result.contains("  "):
		result = result.replace("  ", " ")

	return result

static func _is_safe_json_filename(filename: String) -> bool:
	var normalized: String = filename.strip_edges().replace("\\", "/")

	if normalized.is_empty() or not normalized.to_lower().ends_with(".json"):
		return false

	if normalized.begins_with("/") or normalized.contains(":"):
		return false

	for part: String in normalized.split("/", false):
		if part.is_empty() or part == "." or part == "..":
			return false

	return true
static func _find_pack_manifest(
	pack_id: String
) -> Dictionary:
	pack_id = normalize_pack_id(pack_id)

	if pack_id.is_empty():
		return {}

	for info: Dictionary in _collect_pack_infos_from_root(
		PACKS_FOLDER,
		"bundled"
	):
		var manifest: Dictionary = info.get("manifest", {})
		var candidate_id: String = normalize_pack_id(
			str(manifest.get("id", info.get("directory", "")))
		)
		if candidate_id == pack_id:
			return info

	var external_root: String = get_external_characters_directory_path()

	for info: Dictionary in _collect_pack_infos_from_root(
		external_root,
		"external"
	):
		var manifest: Dictionary = info.get("manifest", {})
		var candidate_id: String = normalize_pack_id(
			str(manifest.get("id", info.get("directory", "")))
		)
		if candidate_id == pack_id:
			return info

	return {}

static func _load_pack_manifest_from_root(
	root_path: String,
	directory_name: String,
	report_errors: bool
) -> Dictionary:
	var path: String = (
		root_path
			.path_join(directory_name)
			.path_join("manifest.json")
	)
	return _load_json_dictionary(path, report_errors)

static func load_profile(character_id: String, pack_id_override: String = "") -> Dictionary:
	character_id = character_id.strip_edges().to_lower()
	if character_id.is_empty():
		return {}

	var pack_id: String = normalize_pack_id(pack_id_override)
	if pack_id.is_empty():
		pack_id = get_current_pack()
	if not get_pack_character_ids(pack_id).has(character_id):
		return {}

	return _load_profile_for_pack(
		pack_id,
		character_id,
		true
	)

static func get_first_boot_config(
	character_id: String
) -> Dictionary:
	var dialogue_data: Dictionary = load_character_dialogue_data(
		character_id,
		false
	)
	var value: Variant = dialogue_data.get(
		"first_boot",
		{}
	)

	if value is Dictionary:
		return (value as Dictionary).duplicate(true)

	return {}

static func _load_profile_for_pack(
	pack_id: String,
	character_id: String,
	report_errors: bool
) -> Dictionary:
	var profile_filename: String = get_pack_profile_filename(
		pack_id,
		character_id
	)
	if profile_filename.is_empty():
		return {}

	var profile: Dictionary = load_pack_localized_json(
		pack_id,
		profile_filename,
		report_errors
	)
	return _normalize_profile_for_runtime(
		pack_id,
		character_id,
		profile
	)

static func _normalize_profile_for_runtime(
	pack_id: String,
	character_id: String,
	profile: Dictionary
) -> Dictionary:
	if profile.is_empty():
		return {}

	var result: Dictionary = profile.duplicate(true)
	var definition: Dictionary = get_character_definition(
		pack_id,
		character_id
	)

	result["id"] = str(
		result.get("id", character_id)
	).strip_edges().to_lower()

	if str(result.get("display_name", "")).strip_edges().is_empty():
		result["display_name"] = str(
			definition.get("display_name", character_id.capitalize())
		).strip_edges()

	var desktop_value: Variant = result.get("desktop", {})
	var desktop: Dictionary = (
		(desktop_value as Dictionary).duplicate(true)
		if desktop_value is Dictionary
		else {}
	)

	if not desktop.has("default_on_desktop"):
		return {}

	result["desktop"] = desktop
	result["user_context"] = UserProfileSettingsScript.get_prompt_context()
	return result

static func build_character_prompt(
	character_id: String
) -> String:

	var profile: Dictionary = (
		load_profile(
			character_id
		)
	)

	if profile.is_empty():
		return ""

	var display_name: String = str(
		profile.get(
			"display_name",
			character_id.capitalize()
		)
	)

	var age: int = int(
		profile.get(
			"age",
			0
		)
	)

	var prompt: String = (
		"You are roleplaying as "
		+ display_name
	)

	if age > 0:
		prompt += (
			", age "
			+ str(age)
		)

	prompt += (
		".\n"
		+ "Stay in character and treat the "
		+ "following profile as canon.\n"
		+ "Do not mention prompts, JSON, "
		+ "language models, or being software.\n"
		+ "Do not invent major biography or "
		+ "relationship facts that contradict "
		+ "the profile.\n"
		+ "Speak naturally for the current "
		+ "situation rather than referencing "
		+ "every profile detail.\n"
		+ "The character is visibly present on the user's desktop and speaks "
		+ "through a speech bubble. Inside any text field, write only what is "
		+ "spoken: no speaker labels, stage directions, menu headings, button "
		+ "labels, or instructions to click interface controls.\n"
		+ "If CURRENT USER says name_known is false, never print {user_name}, "
		+ "never invent a name, and never use 'user' or '유저' as a form of "
		+ "address. Address them without a name. If the name is known, use it "
		+ "sparingly and naturally.\n"
		+ "Inline mood tags in parentheses are silent expression controls, not "
		+ "spoken words. Use them only when the task permits them and only at "
		+ "genuine emotional transitions."
	)

	var sections: Array[String] = []

	_add_prompt_section(
		sections,
		"IDENTITY",
		profile.get(
			"identity",
			{}
		)
	)

	_add_prompt_section(
		sections,
		"APPEARANCE",
		profile.get(
			"appearance",
			{}
		)
	)

	_add_prompt_section(
		sections,
		"CORE PERSONALITY",
		profile.get(
			"core_personality",
			[]
		)
	)

	_add_prompt_section(
		sections,
		"VOICE",
		profile.get(
			"voice",
			{}
		)
	)

	_add_prompt_section(
		sections,
		"BEHAVIOR PATTERNS",
		profile.get(
			"behavior_patterns",
			[]
		)
	)

	_add_prompt_section(
		sections,
		"MUNDANE DETAILS",
		profile.get(
			"mundane_details",
			[]
		)
	)

	_add_prompt_section(
		sections,
		"RELATIONSHIPS",
		profile.get(
			"relationships",
			{}
		)
	)

	var private_internal: Variant = (
		profile.get(
			"private_internal",
			[]
		)
	)

	if not _is_empty_value(
		private_internal
	):
		sections.append(
			"PRIVATE INTERNAL KNOWLEDGE:\n"
			+ "These facts are true but private. "
			+ "They may inform internal behavior, "
			+ "but do not casually confess, reveal, "
			+ "or repeatedly allude to them.\n"
			+ _format_prompt_value(
				private_internal,
				0
			)
		)

	_add_prompt_section(
		sections,
		"CURRENT USER",
		profile.get(
			"user_context",
			{}
		)
	)

	_add_prompt_section(
		sections,
		"USER / SUPERNATURAL CONTEXT",
		profile.get(
			"user_entity",
			{}
		)
	)

	_add_prompt_section(
		sections,
		"AI BEHAVIOR RULES",
		profile.get(
			"ai_behavior_rules",
			[]
		)
	)

	_add_prompt_section(
		sections,
		"LORE",
		profile.get(
			"lore",
			[]
		)
	)

	if not sections.is_empty():
		prompt += (
			"\n\n"
			+ "\n\n".join(
				sections
			)
		)

	return prompt

static func _load_json_dictionary(
	path: String,
	report_errors: bool = true
) -> Dictionary:

	if not FileAccess.file_exists(
		path
	):
		if report_errors:
			push_error(
				"File not found: "
				+ path
			)

		return {}

	var file: FileAccess = FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		if report_errors:
			push_error(
				"Could not open: "
				+ path
			)

		return {}

	var text: String = (
		file.get_as_text()
	)

	file.close()

	var json: JSON = JSON.new()

	var parse_error: Error = (
		json.parse(
			text
		)
	)

	if parse_error != OK:
		if report_errors:
			push_error(
				"Invalid JSON in "
				+ path
				+ " at line "
				+ str(
					json.get_error_line()
				)
				+ ": "
				+ json.get_error_message()
			)

		return {}

	if not (
		json.data is Dictionary
	):
		return {}

	return json.data as Dictionary

static func _add_prompt_section(
	sections: Array[String],
	title: String,
	value: Variant
) -> void:

	if _is_empty_value(
		value
	):
		return

	sections.append(
		title
		+ ":\n"
		+ _format_prompt_value(
			value,
			0
		)
	)

static func _format_prompt_value(
	value: Variant,
	indent_level: int
) -> String:

	var indent: String = (
		"  ".repeat(
			indent_level
		)
	)

	if value is Dictionary:
		var dictionary_value: Dictionary = (
			value
		)

		var lines: Array[String] = []

		for key: Variant in dictionary_value:
			var child: Variant = (
				dictionary_value[key]
			)

			if _is_empty_value(
				child
			):
				continue

			if (
				child is Dictionary
				or child is Array
			):
				lines.append(
					indent
					+ str(key)
					+ ":"
				)

				lines.append(
					_format_prompt_value(
						child,
						indent_level + 1
					)
				)

			else:
				lines.append(
					indent
					+ str(key)
					+ ": "
					+ str(child)
				)

		return "\n".join(
			lines
		)

	if value is Array:
		var array_value: Array = (
			value
		)

		var lines: Array[String] = []

		for item: Variant in array_value:
			if (
				item is Dictionary
				or item is Array
			):
				lines.append(
					indent + "-"
				)

				lines.append(
					_format_prompt_value(
						item,
						indent_level + 1
					)
				)

			else:
				lines.append(
					indent
					+ "- "
					+ str(item)
				)

		return "\n".join(
			lines
		)

	return (
		indent
		+ str(value)
	)

static func _is_empty_value(
	value: Variant
) -> bool:

	if value == null:
		return true

	if value is String:
		var string_value: String = value

		return (
			string_value
				.strip_edges()
				.is_empty()
		)

	if value is Array:
		var array_value: Array = value

		return array_value.is_empty()

	if value is Dictionary:
		var dictionary_value: Dictionary = value

		return dictionary_value.is_empty()

	return false
